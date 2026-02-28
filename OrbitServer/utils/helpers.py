def safe_int(value, default=None):
    """Safely convert a value to int. Returns default on failure."""
    try:
        return int(value)
    except (TypeError, ValueError):
        return default
