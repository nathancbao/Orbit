import datetime

from google.cloud import datastore

client = datastore.Client()


def _deep_convert(obj):
    """Recursively convert embedded Datastore entities and datetimes to JSON-safe types."""
    if isinstance(obj, datetime.datetime):
        return obj.replace(tzinfo=None).isoformat() + 'Z'
    if isinstance(obj, datetime.date):
        return obj.isoformat()
    if hasattr(obj, 'items'):
        return {k: _deep_convert(v) for k, v in obj.items()}
    if isinstance(obj, list):
        return [_deep_convert(item) for item in obj]
    return obj


def _entity_to_dict(entity):
    if entity is None:
        return None
    d = _deep_convert(dict(entity))
    d['id'] = str(entity.key.id_or_name)
    return d
