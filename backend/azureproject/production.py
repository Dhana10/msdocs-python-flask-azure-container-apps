import os
import secrets

# SECURITY WARNING: keep the secret key used in production secret!
SECRET_KEY = os.getenv('AZURE_SECRET_KEY') or secrets.token_hex()

DEBUG = False

_origins = [o.strip() for o in os.environ.get('CORS_ORIGINS', '').split(',') if o.strip()]
CSRF_TRUSTED_ORIGINS = [o if o.startswith('http') else 'https://' + o for o in _origins]

# If DBHOST is set, use PostgreSQL with Azure AD token auth.
# Otherwise fall back to SQLite (no cost, data is ephemeral between restarts).
if os.environ.get('DBHOST'):
    DATABASE_URI = 'postgresql+psycopg2://{dbuser}:{dbpass}@{dbhost}/{dbname}?sslmode=require'.format(
        dbuser=os.environ['DBUSER'],
        dbpass='PASSWORDORTOKEN',
        dbhost=os.environ['DBHOST'] + '.postgres.database.azure.com',
        dbname=os.environ.get('DBNAME', 'restaurants_reviews'),
    )
else:
    DATABASE_URI = 'sqlite:////app/data/db.sqlite'
