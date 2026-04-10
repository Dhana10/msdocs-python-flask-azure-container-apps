#!/bin/sh
set -e
export FLASK_APP=app.py
cd /app
python -m flask db upgrade
exec gunicorn \
  --bind 0.0.0.0:5000 \
  --workers 2 \
  --threads 2 \
  --timeout 120 \
  --access-logfile - \
  --error-logfile - \
  "app:app"
