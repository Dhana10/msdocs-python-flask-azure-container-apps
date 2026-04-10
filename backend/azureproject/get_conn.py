import os

from flask import current_app


def get_conn():
    uri = current_app.config.get('DATABASE_URI')
    # SQLite — return as-is, no token needed.
    if uri and uri.startswith('sqlite'):
        return uri
    # PostgreSQL on Azure — swap the placeholder with a short-lived AAD token.
    from azure.identity import DefaultAzureCredential
    token = DefaultAzureCredential().get_token('https://ossrdbms-aad.database.windows.net/.default')
    return uri.replace('PASSWORDORTOKEN', token.token)
