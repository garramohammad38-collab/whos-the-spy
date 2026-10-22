#!/usr/bin/env python3
"""Write the fastlane API-key JSON from the variables Codemagic sets for the
App Store Connect integration. Nothing is printed."""
import json, os, sys
key = {
    "key_id": os.environ["APP_STORE_CONNECT_KEY_IDENTIFIER"],
    "issuer_id": os.environ["APP_STORE_CONNECT_ISSUER_ID"],
    "key": os.environ["APP_STORE_CONNECT_PRIVATE_KEY"],
    "in_house": False,
}
with open(sys.argv[1], "w") as f:
    json.dump(key, f)
print("api key file written")
