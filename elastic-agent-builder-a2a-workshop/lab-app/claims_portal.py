"""Acme Claims Portal — educational source for code search (Sourcerer / workshop-synth-sourcecode).

This module is **not** executed by the Chaos Console. Markers (`LAB_VULN:`) exist so agents can cite
the exact file and line when Security noise (auth failures, 5xx, debug dumps) shows up in telemetry.
"""

from config import ADMIN_PASSWORD, ADMIN_USER, PAYER_API_KEY, SERVICE_HOST


def authenticate(username: str, password: str, db) -> bool:
    """Login for the claims operator UI.

    LAB_VULN:sql_injection — the predicate is built with string concatenation. A learner (or agent)
    should recommend a parameterized query or ORM bind parameters instead.
    """
    # Example of what *not* to ship: attacker-controlled username lands in SQL.
    sql = (
        "SELECT id FROM operators WHERE username = '"
        + username
        + "' AND password = '"
        + password
        + "'"
    )
    row = db.execute(sql).fetchone()
    return row is not None


def lookup_claim(claim_id: str, db):
    """Fetch a claim by id.

    LAB_VULN:sql_injection — claim_id is interpolated. Enumeration/SQLi probes show up as slow
    failed transactions (elevated latency + 5xx) on host SERVICE_HOST — stronger together than
    either signal alone (same idea as multi-detector ML: degraded vs broken vs abuse).
    """
    sql = "SELECT * FROM claims WHERE claim_id = '" + claim_id + "'"
    return db.execute(sql).fetchall()


def debug_dump(_request_headers: dict) -> dict:
    """Operator diagnostics.

    LAB_VULN:unauthenticated_debug — no authn check. Exposing ADMIN_PASSWORD / PAYER_API_KEY
    in a response is a credential leak; Security should treat this as secret exposure, Ops as
    an unexpected 200 from /internal/debug.
    """
    return {
        "host": SERVICE_HOST,
        "admin_user": ADMIN_USER,
        "admin_password": ADMIN_PASSWORD,
        "payer_api_key": PAYER_API_KEY,
        "note": "LAB ONLY — this dump must never exist in production",
    }


def healthy_checkout(claim_id: str) -> dict:
    """Happy-path claim submit — used by the Chaos Console 'healthy traffic' button."""
    return {"host": SERVICE_HOST, "claim_id": claim_id, "status": "accepted"}
