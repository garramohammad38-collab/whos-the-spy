#!/usr/bin/env python3
"""Upload App Store screenshots with the App Store Connect API (no fastlane).
Uses the variables Codemagic sets for the App Store Connect integration.
Replaces the iPhone 6.9"/6.7" screenshots of every localization of the version
that is in "Prepare for Submission". Never submits anything for review.

usage: upload_screenshots.py <dir with <locale>/*.png> <bundle id>"""
import hashlib, json, os, re, sys, time, urllib.request, urllib.error
from pathlib import Path
from pathlib import Path
import importlib.util
root, bundle_id = Path(sys.argv[1]), sys.argv[2]
spec = importlib.util.spec_from_file_location("asc", Path(__file__).with_name("asc_api.py"))
asc = importlib.util.module_from_spec(spec); spec.loader.exec_module(asc)
call = asc.call

app = call("GET", f"/apps?filter[bundleId]={bundle_id}")["data"][0]
versions = call("GET", f"/apps/{app['id']}/appStoreVersions?filter[platform]=IOS&limit=10")["data"]
version = next(v for v in versions if v["attributes"]["appStoreState"] in
               ("PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED"))
print("version", version["attributes"]["versionString"], version["attributes"]["appStoreState"])
locs = call("GET", f"/appStoreVersions/{version['id']}/appStoreVersionLocalizations")["data"]
for loc in locs:
    locale = loc["attributes"]["locale"]
    folder = root / locale
    if not folder.exists():
        alt = [p for p in root.iterdir() if p.name.split("-")[0] == locale.split("-")[0]]
        folder = alt[0] if alt else None
    if not folder:
        print("no screenshots for", locale); continue
    files = sorted(folder.glob("*.png"))
    sets = call("GET", f"/appStoreVersionLocalizations/{loc['id']}/appScreenshotSets")["data"]
    sset = next((s for s in sets if s["attributes"]["screenshotDisplayType"] == "APP_IPHONE_67"), None)
    if sset is None:
        sset = call("POST", "/appScreenshotSets", {"data": {"type": "appScreenshotSets",
                    "attributes": {"screenshotDisplayType": "APP_IPHONE_67"},
                    "relationships": {"appStoreVersionLocalization": {"data": {"type": "appStoreVersionLocalizations", "id": loc["id"]}}}}})["data"]
    for old in call("GET", f"/appScreenshotSets/{sset['id']}/appScreenshots")["data"]:
        call("DELETE", f"/appScreenshots/{old['id']}")
    for f in files:
        data = f.read_bytes()
        shot = call("POST", "/appScreenshots", {"data": {"type": "appScreenshots",
                    "attributes": {"fileName": f.name, "fileSize": len(data)},
                    "relationships": {"appScreenshotSet": {"data": {"type": "appScreenshotSets", "id": sset["id"]}}}}})["data"]
        for op in shot["attributes"]["uploadOperations"]:
            chunk = data[op["offset"]:op["offset"] + op["length"]]
            req = urllib.request.Request(op["url"], method=op["method"], data=chunk,
                                         headers={h["name"]: h["value"] for h in op["requestHeaders"]})
            urllib.request.urlopen(req).read()
        call("PATCH", f"/appScreenshots/{shot['id']}", {"data": {"type": "appScreenshots", "id": shot["id"],
             "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(data).hexdigest()}}})
        print("uploaded", locale, f.name)
print("done")
