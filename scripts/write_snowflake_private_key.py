#!/usr/bin/env python3
"""Write SNOWFLAKE_PRIVATE_KEY to a PKCS#8 PEM file for Snowflake CLI."""

from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path


def normalize_pem(raw: str) -> str:
    if raw.count("\n") < 2:
        raw = raw.replace("\\n", "\n").replace("\\r", "")
    return raw.replace("\r\n", "\n").strip() + "\n"


def main() -> int:
    raw = os.environ.get("SNOWFLAKE_PRIVATE_KEY", "")
    if not raw.strip():
        print("SNOWFLAKE_PRIVATE_KEY secret is empty", file=sys.stderr)
        return 1

    path = Path.home() / "snowflake_ci_key.pem"
    path.write_text(normalize_pem(raw))
    path.chmod(0o600)

    text = path.read_text()
    if "BEGIN RSA PRIVATE KEY" in text:
        pkcs8 = subprocess.check_output(
            ["openssl", "pkcs8", "-topk8", "-nocrypt", "-in", str(path)]
        )
        path.write_bytes(pkcs8)
        path.chmod(0o600)
        text = path.read_text()

    if "BEGIN PRIVATE KEY" not in text and "BEGIN ENCRYPTED PRIVATE KEY" not in text:
        print(
            "Private key is not PKCS#8 after normalization "
            f"(bytes={path.stat().st_size}, newlines={text.count(chr(10))})",
            file=sys.stderr,
        )
        return 1

    print(f"Wrote PKCS#8 key ({path.stat().st_size} bytes, {text.count(chr(10))} lines)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
