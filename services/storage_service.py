import os
import uuid

from google.cloud import storage

GCS_BUCKET_NAME = os.environ.get('GCS_BUCKET_NAME', 'orbit-app-photos')


def upload_file(file, folder='photos'):
    storage_client = storage.Client()
    bucket = storage_client.bucket(GCS_BUCKET_NAME)

    ext = file.filename.rsplit('.', 1)[-1] if '.' in file.filename else 'jpg'
    blob_name = f"{folder}/{uuid.uuid4().hex}.{ext}"
    blob = bucket.blob(blob_name)

    blob.upload_from_file(file, content_type=file.content_type)
    blob.make_public()

    return blob.public_url
