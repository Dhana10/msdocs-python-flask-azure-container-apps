import os
from datetime import datetime

from flask import Blueprint, Flask, jsonify, redirect, render_template, request, send_from_directory, url_for
from flask_cors import CORS
from flask_migrate import Migrate
from flask_sqlalchemy import SQLAlchemy
from flask_wtf.csrf import CSRFProtect
from requests import RequestException

from azureproject.get_conn import get_conn

app = Flask(__name__, static_folder='static')
csrf = CSRFProtect(app)

if 'RUNNING_IN_PRODUCTION' not in os.environ:
    print('Loading config.development and environment variables from .env file.')
    app.config.from_object('azureproject.development')
else:
    print('Loading config.production.')
    app.config.from_object('azureproject.production')

with app.app_context():
    app.config.update(
        SQLALCHEMY_TRACK_MODIFICATIONS=False,
        SQLALCHEMY_DATABASE_URI=get_conn(),
    )

db = SQLAlchemy(app)
migrate = Migrate(app, db)

from models import Restaurant, Review  # noqa: E402

_cors_origins = [o.strip() for o in os.environ.get('CORS_ORIGINS', '').split(',') if o.strip()]
if _cors_origins:
    CORS(
        app,
        resources={r'/api/*': {'origins': _cors_origins}},
        supports_credentials=False,
    )

api_bp = Blueprint('api', __name__, url_prefix='/api')


@api_bp.route('/health', methods=['GET'])
def api_health():
    return jsonify({'status': 'ok'})


@api_bp.route('/restaurants', methods=['GET'])
@csrf.exempt
def api_list_restaurants():
    rows = Restaurant.query.order_by(Restaurant.name).all()
    return jsonify([r.to_dict() for r in rows])


@api_bp.route('/restaurants', methods=['POST'])
@csrf.exempt
def api_create_restaurant():
    data = request.get_json(silent=True) or {}
    name = (data.get('name') or '').strip()
    description = (data.get('description') or '').strip()
    street_address = (data.get('street_address') or '').strip()
    if not name or not description:
        return jsonify({'error': 'name and description are required'}), 400
    restaurant = Restaurant(name=name, street_address=street_address, description=description)
    db.session.add(restaurant)
    db.session.commit()
    return jsonify(restaurant.to_dict()), 201


@api_bp.route('/restaurants/<int:restaurant_id>', methods=['GET'])
@csrf.exempt
def api_restaurant_detail(restaurant_id):
    restaurant = Restaurant.query.filter_by(id=restaurant_id).first()
    if not restaurant:
        return jsonify({'error': 'not found'}), 404
    reviews = Review.query.filter_by(restaurant=restaurant_id).order_by(Review.review_date.desc()).all()
    body = restaurant.to_dict()
    body['reviews'] = [r.to_dict() for r in reviews]
    return jsonify(body)


@api_bp.route('/restaurants/<int:restaurant_id>/reviews', methods=['POST'])
@csrf.exempt
def api_add_review(restaurant_id):
    if not Restaurant.query.filter_by(id=restaurant_id).first():
        return jsonify({'error': 'restaurant not found'}), 404
    data = request.get_json(silent=True) or {}
    user_name = (data.get('user_name') or '').strip()
    rating = data.get('rating')
    review_text = (data.get('review_text') or '').strip()
    if not user_name or rating is None:
        return jsonify({'error': 'user_name and rating are required'}), 400
    try:
        rating_int = int(rating)
        if rating_int < 1 or rating_int > 5:
            raise ValueError()
    except (TypeError, ValueError):
        return jsonify({'error': 'rating must be 1-5'}), 400
    review = Review(
        restaurant=restaurant_id,
        review_date=datetime.now(),
        user_name=user_name,
        rating=rating_int,
        review_text=review_text,
    )
    db.session.add(review)
    db.session.commit()
    return jsonify(review.to_dict()), 201


app.register_blueprint(api_bp)


def render_details_page(rid, message=''):
    restaurant = Restaurant.query.filter_by(id=rid).first()
    reviews = Review.query.filter_by(restaurant=rid)
    return render_template('details.html', restaurant=restaurant, reviews=reviews, message=message)


@app.route('/', methods=['GET'])
def index():
    print('Request for index page received')
    restaurants = Restaurant.query.all()
    return render_template('index.html', restaurants=restaurants)


@app.route('/<int:id>', methods=['GET'])
def details(id):
    return render_details_page(id, '')


@app.route('/create', methods=['GET'])
def create_restaurant():
    print('Request for add restaurant page received')
    return render_template('create_restaurant.html')


@app.route('/add', methods=['POST'])
@csrf.exempt
def add_restaurant():
    try:
        name = request.values.get('restaurant_name')
        street_address = request.values.get('street_address')
        description = request.values.get('description')
        if name == '' or description == '':
            raise RequestException()
    except (KeyError, RequestException):
        return render_template(
            'create_restaurant.html',
            message='Restaurant not added. Include at least a restaurant name and description.',
        )
    else:
        restaurant = Restaurant()
        restaurant.name = name
        restaurant.street_address = street_address
        restaurant.description = description
        db.session.add(restaurant)
        db.session.commit()
        return redirect(url_for('details', id=restaurant.id))


@app.route('/review/<int:id>', methods=['POST'])
@csrf.exempt
def add_review(id):
    try:
        user_name = request.values.get('user_name')
        rating = request.values.get('rating')
        review_text = request.values.get('review_text')
        if user_name == '' or rating is None:
            raise RequestException()
    except (KeyError, RequestException):
        return render_details_page(
            id,
            'Review not added. Include at least a name and rating for review.',
        )
    else:
        review = Review()
        review.restaurant = id
        review.review_date = datetime.now()
        review.user_name = user_name
        review.rating = int(rating)
        review.review_text = review_text
        db.session.add(review)
        db.session.commit()

    return redirect(url_for('details', id=id))


@app.context_processor
def utility_processor():
    def star_rating(rid):
        reviews = Review.query.filter_by(restaurant=rid)
        ratings = []
        review_count = 0
        for review in reviews:
            ratings += [review.rating]
            review_count += 1
        avg_rating = round(sum(ratings) / len(ratings), 2) if ratings else 0
        stars_percent = round((avg_rating / 5.0) * 100) if review_count > 0 else 0
        return {'avg_rating': avg_rating, 'review_count': review_count, 'stars_percent': stars_percent}

    return dict(star_rating=star_rating)


@app.route('/favicon.ico')
def favicon():
    return send_from_directory(
        os.path.join(app.root_path, 'static'),
        'favicon.ico',
        mimetype='image/vnd.microsoft.icon',
    )


if __name__ == '__main__':
    app.run()
