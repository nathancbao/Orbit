import os
import uuid

from google.cloud import storage

GCS_BUCKET_NAME = os.environ.get('GCS_BUCKET_NAME', 'orbit-app-photos')

ALLOWED_EXTENSIONS = {'jpg', 'jpeg', 'png', 'webp'}
MAX_FILE_SIZE = 5 * 1024 * 1024  # 5 MB


def upload_file(file, folder='photos'):
    """Upload a photo to GCS after validating extension and size.

    Returns the public URL on success.
    Raises ValueError for validation errors, RuntimeError for GCS failures.
    """
    # Validate file extension
    ext = ''
    if file.filename and '.' in file.filename:
        ext = file.filename.rsplit('.', 1)[-1].lower()
    if ext not in ALLOWED_EXTENSIONS:
        raise ValueError(f"File type '.{ext}' is not allowed. Accepted: {', '.join(sorted(ALLOWED_EXTENSIONS))}")

    # Validate file size — read into memory to check length
    file_data = file.read()
    if len(file_data) > MAX_FILE_SIZE:
        raise ValueError(f"File exceeds maximum size of {MAX_FILE_SIZE // (1024 * 1024)}MB")

    blob_name = f"{folder}/{uuid.uuid4().hex}.{ext}"

    try:
        storage_client = storage.Client()
        bucket = storage_client.bucket(GCS_BUCKET_NAME)
        blob = bucket.blob(blob_name)
        blob.upload_from_string(file_data, content_type=file.content_type)
        # Intentionally public: profile photos need to be accessible by all app users
        blob.make_public()
    except Exception as e:
        raise RuntimeError(f"Failed to upload file to storage: {e}")

    return f"https://storage.googleapis.com/{GCS_BUCKET_NAME}/{blob_name}"
