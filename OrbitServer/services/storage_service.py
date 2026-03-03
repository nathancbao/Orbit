import logging
import os
import uuid

from google.cloud import storage

logger = logging.getLogger(__name__)

GCS_BUCKET_NAME = os.environ.get('GCS_BUCKET_NAME', 'orbit-app-photos')

ALLOWED_EXTENSIONS = {'jpg', 'jpeg', 'png', 'webp'}
MAX_FILE_SIZE = 5 * 1024 * 1024  # 5 MB

# Reuse storage client across requests
_storage_client = None


def _get_storage_client():
    global _storage_client
    if _storage_client is None:
        _storage_client = storage.Client()
    return _storage_client


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
        client = _get_storage_client()
        bucket = client.bucket(GCS_BUCKET_NAME)
        blob = bucket.blob(blob_name)
        blob.upload_from_string(file_data, content_type=file.content_type)
    except Exception as e:
        raise RuntimeError(f"Failed to upload file to storage: {e}")

    # Try to make the blob public (works with fine-grained ACL buckets).
    # If the bucket uses uniform bucket-level access (GCS default for new
    # buckets), this will fail with 403 — that's OK, the bucket's IAM
    # policy should grant allUsers read access instead.
    try:
        blob.make_public()
    except Exception:
        logger.info("make_public() skipped for %s (bucket likely uses uniform access)", blob_name)

    return f"https://storage.googleapis.com/{GCS_BUCKET_NAME}/{blob_name}"
