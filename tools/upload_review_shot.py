#!/usr/bin/env python3
"""Upload the paywall screenshot as the App Review screenshot of every subscription in the app
(App Store Connect API). Replaces an existing one. Never submits anything.

usage: upload_review_shot.py <png> <bundle id>"""
import hashlib, sys, urllib.request
from pathlib import Path
import importlib.util
spec = importlib.util.spec_from_file_location("asc", Path(__file__).with_name("asc_api.py"))
asc = importlib.util.module_from_spec(spec); spec.loader.exec_module(asc)
call = asc.call

png = Path(sys.argv[1]); data = png.read_bytes()
app = call("GET", f"/apps?filter[bundleId]={sys.argv[2]}")["data"][0]
groups = call("GET", f"/apps/{app['id']}/subscriptionGroups")["data"]
for g in groups:
    for sub in call("GET", f"/subscriptionGroups/{g['id']}/subscriptions")["data"]:
        pid = sub["attributes"]["productId"]
        try:
            old = call("GET", f"/subscriptions/{sub['id']}/appStoreReviewScreenshot").get("data")
        except Exception:
            old = None
        if old:
            call("DELETE", f"/subscriptionAppStoreReviewScreenshots/{old['id']}")
        shot = call("POST", "/subscriptionAppStoreReviewScreenshots", {"data": {
            "type": "subscriptionAppStoreReviewScreenshots",
            "attributes": {"fileName": png.name, "fileSize": len(data)},
            "relationships": {"subscription": {"data": {"type": "subscriptions", "id": sub["id"]}}}}})["data"]
        for op in shot["attributes"]["uploadOperations"]:
            chunk = data[op["offset"]:op["offset"] + op["length"]]
            req = urllib.request.Request(op["url"], method=op["method"], data=chunk,
                                         headers={h["name"]: h["value"] for h in op["requestHeaders"]})
            urllib.request.urlopen(req).read()
        call("PATCH", f"/subscriptionAppStoreReviewScreenshots/{shot['id']}", {"data": {
            "type": "subscriptionAppStoreReviewScreenshots", "id": shot["id"],
            "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(data).hexdigest()}}})
        print("review screenshot uploaded for", pid)
print("done")
