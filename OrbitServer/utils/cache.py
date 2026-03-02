"""Simple thread-safe TTL cache for frequently-read Datastore entities."""

import threading
import time


class TTLCache:
    """In-memory key→value cache with per-entry expiration.

    Usage:
        _cache = TTLCache(default_ttl=60)
        _cache.get(key)          # returns value or None
        _cache.set(key, value)   # stores with default TTL
        _cache.invalidate(key)   # removes entry
        _cache.clear()           # removes all entries
    """

    def __init__(self, default_ttl=60):
        self._store = {}          # key -> (value, expires_at)
        self._lock = threading.Lock()
        self._default_ttl = default_ttl

    def get(self, key):
        with self._lock:
            entry = self._store.get(key)
            if entry is None:
                return None
            value, expires_at = entry
            if time.monotonic() > expires_at:
                del self._store[key]
                return None
            return value

    def set(self, key, value, ttl=None):
        if ttl is None:
            ttl = self._default_ttl
        with self._lock:
            self._store[key] = (value, time.monotonic() + ttl)

    def invalidate(self, key):
        with self._lock:
            self._store.pop(key, None)

    def clear(self):
        with self._lock:
            self._store.clear()


# Shared cache instances
mission_cache = TTLCache(default_ttl=60)
pod_cache = TTLCache(default_ttl=30)
user_cache = TTLCache(default_ttl=120)
