"""College directory and distance helpers.

The college list is the single source of truth for both the API
(GET /api/colleges) and server-side distance filtering. iOS fetches the
list at runtime, so adding a school here is all that's needed.
"""

import math

# id -> {name, lat, lng}. Coordinates are approximate campus centers.
COLLEGES = {
    'uc_davis':          {'name': 'UC Davis',                  'lat': 38.5382, 'lng': -121.7617},
    'uc_berkeley':       {'name': 'UC Berkeley',               'lat': 37.8719, 'lng': -122.2585},
    'uc_merced':         {'name': 'UC Merced',                 'lat': 37.3660, 'lng': -120.4246},
    'uc_santa_cruz':     {'name': 'UC Santa Cruz',             'lat': 36.9914, 'lng': -122.0609},
    'ucsf':              {'name': 'UC San Francisco',          'lat': 37.7631, 'lng': -122.4586},
    'ucla':              {'name': 'UCLA',                      'lat': 34.0689, 'lng': -118.4452},
    'uc_san_diego':      {'name': 'UC San Diego',              'lat': 32.8801, 'lng': -117.2340},
    'uc_irvine':         {'name': 'UC Irvine',                 'lat': 33.6405, 'lng': -117.8443},
    'uc_santa_barbara':  {'name': 'UC Santa Barbara',          'lat': 34.4140, 'lng': -119.8489},
    'uc_riverside':      {'name': 'UC Riverside',              'lat': 33.9737, 'lng': -117.3281},
    'sac_state':         {'name': 'Sacramento State',          'lat': 38.5610, 'lng': -121.4238},
    'sjsu':              {'name': 'San Jose State',            'lat': 37.3352, 'lng': -121.8811},
    'sf_state':          {'name': 'San Francisco State',       'lat': 37.7241, 'lng': -122.4799},
    'csu_chico':         {'name': 'Chico State',               'lat': 39.7285, 'lng': -121.8475},
    'csu_east_bay':      {'name': 'CSU East Bay',              'lat': 37.6560, 'lng': -122.0568},
    'csu_stanislaus':    {'name': 'Stanislaus State',          'lat': 37.5251, 'lng': -120.8558},
    'csu_monterey_bay':  {'name': 'CSU Monterey Bay',          'lat': 36.6544, 'lng': -121.7961},
    'sonoma_state':      {'name': 'Sonoma State',              'lat': 38.3396, 'lng': -122.6744},
    'cal_poly_slo':      {'name': 'Cal Poly San Luis Obispo',  'lat': 35.3050, 'lng': -120.6625},
    'stanford':          {'name': 'Stanford',                  'lat': 37.4275, 'lng': -122.1697},
    'santa_clara':       {'name': 'Santa Clara University',    'lat': 37.3496, 'lng': -121.9390},
    'usf':               {'name': 'University of San Francisco', 'lat': 37.7766, 'lng': -122.4506},
    'saint_marys':       {'name': "Saint Mary's College of CA", 'lat': 37.8410, 'lng': -122.1097},
    'uop':               {'name': 'University of the Pacific', 'lat': 37.9793, 'lng': -121.3120},
    'usc':               {'name': 'USC',                       'lat': 34.0224, 'lng': -118.2851},
}

_EARTH_RADIUS_MILES = 3958.8


def haversine_miles(lat1, lng1, lat2, lng2):
    """Great-circle distance in miles between two lat/lng points."""
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlmb = math.radians(lng2 - lng1)
    a = math.sin(dphi / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(dlmb / 2) ** 2
    return 2 * _EARTH_RADIUS_MILES * math.asin(math.sqrt(a))


def college_distance_miles(college_id_a, college_id_b):
    """Distance between two colleges, or None if either id is unknown/empty."""
    a = COLLEGES.get(college_id_a or '')
    b = COLLEGES.get(college_id_b or '')
    if not a or not b:
        return None
    return haversine_miles(a['lat'], a['lng'], b['lat'], b['lng'])


def filter_by_distance(items, user):
    """Drop items whose stamped college is farther than the user's radius.

    No-op unless the user has both a college and a positive
    max_distance_miles. Items with no college (seeded/AI/legacy) are
    always kept so they remain visible everywhere.
    """
    user_college = (user or {}).get('college') or ''
    try:
        max_miles = int((user or {}).get('max_distance_miles') or 0)
    except (TypeError, ValueError):
        max_miles = 0
    if not user_college or max_miles <= 0 or user_college not in COLLEGES:
        return items

    kept = []
    for item in items:
        item_college = item.get('college') or ''
        if not item_college:
            kept.append(item)
            continue
        dist = college_distance_miles(user_college, item_college)
        if dist is None or dist <= max_miles:
            kept.append(item)
    return kept


def college_list():
    """List of {id, name, lat, lng} dicts sorted by name (for GET /api/colleges)."""
    return sorted(
        [{'id': cid, **info} for cid, info in COLLEGES.items()],
        key=lambda c: c['name'],
    )
