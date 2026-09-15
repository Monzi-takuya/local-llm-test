#!/usr/bin/env python3
"""One-page UI that forwards the form JSON to llama-server POST /completion.

Does not call /v1/chat/completions. Does not apply a chat template.
Needs: Flask, repo .venv (Python 3.12). llama-server already listening.

  source .venv/bin/activate
  python scripts/raw_complete.py

Open http://127.0.0.1:8090  (8080 is llama-server)
"""

from __future__ import annotations

import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

from flask import Flask, Response, request

if sys.version_info >= (3, 14):
    raise SystemExit("Use the repo .venv (Python 3.12), not system 3.14")

HERE = Path(__file__).resolve().parent
HTML = HERE / "raw_complete.html"
LLAMA = os.environ.get("LLAMA_COMPLETION_URL", "http://127.0.0.1:8080/completion")
HOST = os.environ.get("RAW_HOST", "127.0.0.1")
PORT = int(os.environ.get("RAW_PORT", "8090"))

app = Flask(__name__)


@app.get("/")
def index() -> Response:
    return Response(HTML.read_text(encoding="utf-8"), mimetype="text/html; charset=utf-8")


def _completion_url(url: str) -> str:
    parsed = urllib.parse.urlparse(url.strip())
    if parsed.scheme != "http" or parsed.hostname not in {"127.0.0.1", "localhost"}:
        raise ValueError("llama_url must be http://127.0.0.1/...")
    if parsed.path.rstrip("/") != "/completion":
        raise ValueError("llama_url path must be /completion")
    return urllib.parse.urlunparse(parsed)


@app.post("/api/completion")
def api_completion():
    payload = request.get_json(force=True, silent=False)
    if not isinstance(payload, dict):
        return {"error": "JSON object required"}, 400
    try:
        llama_url = _completion_url(str(payload.pop("llama_url", "") or LLAMA))
    except ValueError as exc:
        return {"error": str(exc)}, 400
    raw = json.dumps(payload, ensure_ascii=False).encode("utf-8")
    req = urllib.request.Request(
        llama_url,
        data=raw,
        method="POST",
        headers={"Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=180) as resp:
            body = resp.read().decode("utf-8")
            status = resp.status
    except urllib.error.HTTPError as exc:
        err_body = exc.read().decode("utf-8", errors="replace")
        return (
            {
                "error": f"llama-server HTTP {exc.code}",
                "llama_url": llama_url,
                "request": payload,
                "response_text": err_body,
            },
            exc.code,
        )
    except urllib.error.URLError as exc:
        return (
            {
                "error": f"cannot reach llama-server: {exc.reason}",
                "llama_url": llama_url,
                "request": payload,
            },
            502,
        )

    try:
        parsed = json.loads(body)
    except json.JSONDecodeError:
        parsed = {"_unparsed": body}

    return {
        "llama_url": llama_url,
        "request": payload,
        "status": status,
        "response": parsed,
    }


def main() -> None:
    if not HTML.is_file():
        raise SystemExit(f"missing {HTML}")
    print(f"python: {sys.version.split()[0]}")
    print(f"html: {HTML}")
    print(f"llama: {LLAMA}")
    print(f"open: http://{HOST}:{PORT}/")
    print("not: /v1/chat/completions, llama-server Web UI, Jinja")
    app.run(host=HOST, port=PORT, debug=False)


if __name__ == "__main__":
    main()
