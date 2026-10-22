#!/usr/bin/env python3
"""Shared App Store Connect API helpers (was part of upload_screenshots.py).
Original doc: Upload App Store screenshots with the App Store Connect API (no fastlane).
Uses the variables Codemagic sets for the App Store Connect integration.
Replaces the iPhone 6.9"/6.7" screenshots of every localization of the version
that is in "Prepare for Submission". Never submits anything for review.

usage: upload_screenshots.py <dir with <locale>/*.png> <bundle id>"""
import hashlib, json, os, re, sys, time, urllib.request, urllib.error
from pathlib import Path
import jwt  # PyJWT

API = "https://api.appstoreconnect.apple.com/v1"


def private_key():
    """Return a PEM the `cryptography` package can load, whatever form the variable has."""
    import base64
    from cryptography.hazmat.primitives.serialization import load_pem_private_key
    raw = os.environ["APP_STORE_CONNECT_PRIVATE_KEY"].strip().strip('"').strip("'")
    for _ in range(3):  # Codemagic may store a reference: @file:/path or @env:NAME
        if raw.startswith("@file:"):
            raw = Path(os.path.expanduser(raw[6:])).read_text().strip()
        elif raw.startswith("@env:"):
            raw = os.environ[raw[5:]].strip()
    raw = raw.replace("\\n", "\n").replace("\r", "")
    cands = [raw]
    try:
        dec = base64.b64decode("".join(raw.split()), validate=False).decode("utf-8", "ignore")
        if "BEGIN" in dec:
            cands.append(dec.strip())
    except Exception:
        pass
    for c in list(cands):
        body = "".join(re.sub(r"-----[^-]+-----", "", c).split())
        cands.append("-----BEGIN PRIVATE KEY-----\n" + "\n".join(body[i:i + 64] for i in range(0, len(body), 64))
                     + "\n-----END PRIVATE KEY-----\n")
    for i, c in enumerate(cands):
        if not c.endswith("\n"):
            c += "\n"
        try:
            load_pem_private_key(c.encode(), password=None)
            print("key format ok (variant", i, ")")
            return c
        except Exception as e:
            print("key variant", i, "failed:", type(e).__name__, "len", len(c), "has BEGIN:", "BEGIN" in c)
    sys.exit("could not load APP_STORE_CONNECT_PRIVATE_KEY")


def token():
    now = int(time.time())
    return jwt.encode({"iss": os.environ["APP_STORE_CONNECT_ISSUER_ID"].strip(), "iat": now, "exp": now + 1100,
                       "aud": "appstoreconnect-v1"}, private_key(), algorithm="ES256",
                      headers={"kid": os.environ["APP_STORE_CONNECT_KEY_IDENTIFIER"].strip(), "typ": "JWT"})


TOKEN = token()


def call(method, path, body=None):
    url = path if path.startswith("http") else API + path
    req = urllib.request.Request(url, method=method, data=json.dumps(body).encode() if body else None,
                                 headers={"Authorization": "Bearer " + TOKEN, "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req) as r:
            txt = r.read().decode()
            return json.loads(txt) if txt else {}
    except urllib.error.HTTPError as e:
        print(method, path, e.code, e.read().decode()[:600])
        raise


