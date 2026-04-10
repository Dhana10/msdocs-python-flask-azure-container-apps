from app import db
from sqlalchemy import Column, DateTime, ForeignKey, Integer, String
from sqlalchemy.orm import declarative_base, validates

Base = declarative_base()


class Restaurant(db.Model):
    __tablename__ = 'restaurant'
    id = Column(Integer, primary_key=True)
    name = Column(String(50))
    street_address = Column(String(50))
    description = Column(String(250))

    def __str__(self):
        return self.name

    def to_dict(self):
        return {
            'id': self.id,
            'name': self.name,
            'street_address': self.street_address or '',
            'description': self.description or '',
        }


class Review(db.Model):
    __tablename__ = 'review'
    id = Column(Integer, primary_key=True)
    restaurant = Column(Integer, ForeignKey('restaurant.id', ondelete='CASCADE'))
    user_name = Column(String(30))
    rating = Column(Integer)
    review_text = Column(String(500))
    review_date = Column(DateTime)

    @validates('rating')
    def validate_rating(self, key, value):
        assert value is None or (1 <= value <= 5)
        return value

    def __str__(self):
        return f'review {self.id}'

    def to_dict(self):
        return {
            'id': self.id,
            'restaurant_id': self.restaurant,
            'user_name': self.user_name,
            'rating': self.rating,
            'review_text': self.review_text or '',
            'review_date': self.review_date.isoformat() if self.review_date else None,
        }
