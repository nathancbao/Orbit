import os
import sys
from unittest.mock import MagicMock

# Set test environment variables before any app imports
os.environ['JWT_SECRET'] = 'test-secret-key'
os.environ['GCS_BUCKET_NAME'] = 'test-bucket'
os.environ['SENDGRID_API_KEY'] = 'fake-key'

# Mock google.cloud.datastore and google.cloud.storage before they get imported.
# This lets tests run without GCP credentials or packages installed.
mock_datastore = MagicMock()
mock_storage = MagicMock()
mock_google = MagicMock()
mock_google.cloud.datastore = mock_datastore
mock_google.cloud.storage = mock_storage

sys.modules['google'] = mock_google
sys.modules['google.cloud'] = mock_google.cloud
sys.modules['google.cloud.datastore'] = mock_datastore
sys.modules['google.cloud.storage'] = mock_storage

# Now the datastore.Client() call in models/models.py will return a MagicMock,
# and datastore.Entity will also be a MagicMock.

import pytest
from main import app as flask_app


@pytest.fixture
def app():
    flask_app.config['TESTING'] = True
    return flask_app


@pytest.fixture
def client(app):
    return app.test_client()
