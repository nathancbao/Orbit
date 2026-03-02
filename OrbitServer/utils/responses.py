from flask import jsonify


def success(data=None, status=200):
    body = {"success": True}
    if data is not None:
        body["data"] = data
    return jsonify(body), status


def error(message, status=400):
    if isinstance(message, list):
        message = '; '.join(str(m) for m in message)
    return jsonify({"success": False, "error": message}), status
