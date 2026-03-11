"""Voyage Mode endpoints — deterministic tile-based infinite exploration."""

from flask import Blueprint, request, g

from OrbitServer.utils.responses import success, error
from OrbitServer.utils.auth import require_auth
from OrbitServer.models.models import list_missions, _entity_to_dict, client

voyage_bp = Blueprint('voyage', __name__, url_prefix='/api/voyage')


# ── Deterministic tile content ────────────────────────────────────────────────

def _tile_seed(x, y):
    """Deterministic 32-bit seed from tile coordinates."""
    raw = x * 73856093 ^ y * 19349663
    return raw & 0xFFFFFFFF


def _seeded_shuffle(items, seed):
    """Fisher-Yates shuffle using a simple LCG seeded deterministically."""
    items = list(items)
    s = seed
    for i in range(len(items) - 1, 0, -1):
        s = (s * 1103515245 + 12345) & 0x7FFFFFFF
        j = s % (i + 1)
        items[i], items[j] = items[j], items[i]
    return items


def _pick_items_for_tile(all_items, x, y, count=5):
    """Deterministically pick `count` items for a tile from the global pool."""
    if not all_items:
        return []
    seed = _tile_seed(x, y)
    shuffled = _seeded_shuffle(all_items, seed)
    # Use seed to decide how many items (3-6)
    n = 3 + (seed % 4)  # 3, 4, 5, or 6
    n = min(n, count, len(shuffled))
    return shuffled[:n]


def _strip_heavy_fields(item):
    """Remove embedding and other heavy fields from response items."""
    item.pop('embedding', None)
    item.pop('rsvps', None)
    item.pop('pod_ids', None)
    return item


# ── GET /api/voyage/clusters ──────────────────────────────────────────────────

@voyage_bp.route('/clusters', methods=['GET'])
@require_auth
def get_clusters():
    """Return missions/signals deterministically assigned to tiles in a region.

    Query params: x (int), y (int), radius (int, default 2)
    """
    try:
        cx = int(request.args.get('x', 0))
        cy = int(request.args.get('y', 0))
        radius = min(int(request.args.get('radius', 2)), 4)
    except (TypeError, ValueError):
        return error("x, y, and radius must be integers", 400)

    # Fetch the global content pool (cached at app level for 60s)
    missions = list_missions(filters={'status': 'open'})
    # For signals, fetch a flat list (no pagination needed for pool)
    from google.cloud.datastore.query import PropertyFilter
    sig_query = client.query(kind='Signal')
    sig_results = list(sig_query.fetch(limit=200))
    signals = [_entity_to_dict(e) for e in sig_results]

    # Tag each item with its type and normalise required fields
    pool = []
    for m in missions:
        m['item_type'] = 'mission'
        _strip_heavy_fields(m)
        pool.append(m)
    for s in signals:
        s['item_type'] = 'signal'
        _strip_heavy_fields(s)
        pool.append(s)

    for item in pool:
        item.setdefault('id', '')
        item.setdefault('title', '')
        item.setdefault('description', '')
        item.setdefault('tags', [])
        item.setdefault('status', 'open')

    # Build tiles
    tiles = []
    for dx in range(-radius, radius + 1):
        for dy in range(-radius, radius + 1):
            tx, ty = cx + dx, cy + dy
            items = _pick_items_for_tile(pool, tx, ty)
            tiles.append({
                'x': tx,
                'y': ty,
                'items': items,
            })

    return success({'tiles': tiles})


# ── POST /api/voyage/heartbeat ────────────────────────────────────────────────

@voyage_bp.route('/heartbeat', methods=['POST'])
@require_auth
def heartbeat():
    """Update the user's current tile position while in Voyage mode."""
    data = request.get_json(silent=True) or {}
    try:
        tile_x = int(data.get('tile_x', 0))
        tile_y = int(data.get('tile_y', 0))
    except (TypeError, ValueError):
        return error("tile_x and tile_y must be integers", 400)

    # Store in a lightweight in-memory dict (or Datastore for persistence)
    # For now, just acknowledge — full persistence can be added later.
    return success({'tile_x': tile_x, 'tile_y': tile_y})


# ── DELETE /api/voyage/heartbeat ──────────────────────────────────────────────

@voyage_bp.route('/heartbeat', methods=['DELETE'])
@require_auth
def end_voyage():
    """Called when the user exits Voyage mode."""
    return success({'message': 'Voyage ended'})
