#!/usr/bin/env python3
"""Leveragers: sends a TestFlight build to the open test group (public link).

Run by .github/workflows/leveragers-testflight.yml after the upload. Through the App Store Connect API it
waits until Apple has processed the build, sets its "What to Test" text, adds it to the external group and
submits it to Apple's beta review. Testers on the public link get it once Apple approves it. Safe to run
again on the same build: each step is skipped when already done.

Environment: ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_P8 (contents of the key), APP_ID, GROUP_ID, BUILD_NUMBER,
WHATS_NEW_FR, WHATS_NEW_EN, and optionally PROCESSING_TIMEOUT_MINUTES (60 by default).
"""
import json
import os
import sys
import time
import urllib.error
import urllib.request

import jwt

API = "https://api.appstoreconnect.apple.com"


def token() -> str:
    now = int(time.time())
    return jwt.encode({"iss": os.environ["ASC_ISSUER_ID"], "iat": now, "exp": now + 900, "aud": "appstoreconnect-v1"},
                      os.environ["ASC_KEY_P8"], algorithm="ES256", headers={"kid": os.environ["ASC_KEY_ID"], "typ": "JWT"})


def call(method: str, path: str, body: dict | None = None) -> tuple[int, dict]:
    request = urllib.request.Request(API + path, method=method,
                                     data=json.dumps(body).encode() if body is not None else None,
                                     headers={"Authorization": "Bearer " + token(), "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            raw = response.read()
            return response.status, json.loads(raw) if raw else {}
    except urllib.error.HTTPError as error:
        raw = error.read()
        try:
            return error.code, json.loads(raw)
        except ValueError:
            return error.code, {"raw": raw.decode(errors="replace")[:500]}


def must(status: int, data: dict, what: str, ok=(200, 201, 204)) -> dict:
    if status not in ok:
        sys.exit(f"::error::{what}: HTTP {status} {json.dumps(data)[:800]}")
    return data


def wait_for_processed_build(app_id: str, build_number: str, timeout_minutes: int) -> dict:
    deadline = time.monotonic() + timeout_minutes * 60
    while True:
        status, data = call("GET", f"/v1/builds?filter[app]={app_id}&filter[version]={build_number}"
                                   "&fields[builds]=version,processingState")
        builds = must(status, data, "Reading the build").get("data", [])
        state = builds[0]["attributes"]["processingState"] if builds else "NOT_LISTED_YET"
        print(f"Build {build_number}: {state}", flush=True)
        if state == "VALID":
            return builds[0]
        if state in ("FAILED", "INVALID"):
            sys.exit(f"::error::Apple refused build {build_number}: {state}")
        if time.monotonic() > deadline:
            sys.exit(f"::error::Build {build_number} still {state} after {timeout_minutes} minutes")
        time.sleep(30)


def set_whats_new(build_id: str, texts: dict[str, str]) -> None:
    status, data = call("GET", f"/v1/builds/{build_id}/betaBuildLocalizations")
    existing = {item["attributes"]["locale"]: item["id"] for item in must(status, data, "Reading What to Test").get("data", [])}
    for locale, text in texts.items():
        if locale in existing:
            status, data = call("PATCH", f"/v1/betaBuildLocalizations/{existing[locale]}",
                                {"data": {"type": "betaBuildLocalizations", "id": existing[locale], "attributes": {"whatsNew": text}}})
        else:
            status, data = call("POST", "/v1/betaBuildLocalizations",
                                {"data": {"type": "betaBuildLocalizations", "attributes": {"locale": locale, "whatsNew": text},
                                          "relationships": {"build": {"data": {"type": "builds", "id": build_id}}}}})
        must(status, data, f"What to Test ({locale})")
        print(f"What to Test ({locale}) set", flush=True)


def main() -> None:
    app_id, group_id, build_number = os.environ["APP_ID"], os.environ["GROUP_ID"], os.environ["BUILD_NUMBER"]
    build = wait_for_processed_build(app_id, build_number, int(os.environ.get("PROCESSING_TIMEOUT_MINUTES", "60")))
    build_id = build["id"]

    set_whats_new(build_id, {"fr-FR": os.environ["WHATS_NEW_FR"], "en-US": os.environ["WHATS_NEW_EN"]})

    # Adding a build already in the group is accepted as well.
    status, data = call("POST", f"/v1/betaGroups/{group_id}/relationships/builds", {"data": [{"type": "builds", "id": build_id}]})
    must(status, data, "Adding the build to the open test group")
    print("Added to the open test group", flush=True)

    status, data = call("GET", f"/v1/builds/{build_id}/buildBetaDetail")
    external_state = must(status, data, "Reading the external state")["data"]["attributes"]["externalBuildState"]
    print(f"External state: {external_state}", flush=True)
    if external_state == "MISSING_EXPORT_COMPLIANCE":
        sys.exit("::error::The build waits for its export compliance answer in App Store Connect")
    if external_state != "READY_FOR_BETA_SUBMISSION":
        print("Already submitted to Apple's beta review, nothing more to do")
        return

    status, data = call("POST", "/v1/betaAppReviewSubmissions",
                        {"data": {"type": "betaAppReviewSubmissions", "relationships": {"build": {"data": {"type": "builds", "id": build_id}}}}})
    review_state = must(status, data, "Submitting to Apple's beta review")["data"]["attributes"]["betaReviewState"]
    print(f"Submitted to Apple's beta review: {review_state}. The public link serves it once Apple approves it.", flush=True)


if __name__ == "__main__":
    main()
