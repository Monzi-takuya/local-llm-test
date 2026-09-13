#!/usr/bin/env python3
"""Call a local OpenAI-compatible /v1/chat/completions server.

Uses the repo .venv (Python 3.12). Does not call api.openai.com.
Local servers usually ignore the API key; a dummy is sent anyway.
"""

from __future__ import annotations

import argparse
import os
import sys

from openai import OpenAI


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--base-url",
        default=os.environ.get("OPENAI_BASE_URL", "http://127.0.0.1:8080/v1"),
        help="OpenAI-compatible base URL (include /v1)",
    )
    parser.add_argument(
        "--model",
        default=os.environ.get("OPENAI_MODEL", "qwen2.5-7b-instruct"),
        help="Server-side model name (llama-server --alias, or ollama tag)",
    )
    parser.add_argument(
        "--prompt",
        default="1+1は？短く答えて。",
    )
    parser.add_argument(
        "--max-tokens",
        type=int,
        default=64,
    )
    parser.add_argument(
        "--stream",
        action="store_true",
        help="Print tokens as they arrive (SSE under the hood)",
    )
    parser.add_argument(
        "--api-key",
        default=os.environ.get("OPENAI_API_KEY", "local-unused"),
        help="Sent as Authorization. Local servers usually do not check it.",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    if sys.version_info >= (3, 14):
        raise SystemExit("Use the repo .venv (Python 3.12), not system 3.14")

    client = OpenAI(base_url=args.base_url, api_key=args.api_key)
    messages = [{"role": "user", "content": args.prompt}]

    print(f"python: {sys.version.split()[0]}")
    print(f"base_url: {args.base_url}")
    print(f"model: {args.model}")
    print(f"stream: {args.stream}")

    if args.stream:
        stream = client.chat.completions.create(
            model=args.model,
            messages=messages,
            max_tokens=args.max_tokens,
            stream=True,
        )
        print("--- stream ---")
        for chunk in stream:
            if not chunk.choices:
                continue
            delta = chunk.choices[0].delta.content
            if delta:
                print(delta, end="", flush=True)
        print()
        return

    resp = client.chat.completions.create(
        model=args.model,
        messages=messages,
        max_tokens=args.max_tokens,
        stream=False,
    )
    print("--- message ---")
    print(resp.choices[0].message.content)
    print(f"finish_reason: {resp.choices[0].finish_reason}")
    if resp.usage:
        print(
            "usage:"
            f" prompt={resp.usage.prompt_tokens}"
            f" completion={resp.usage.completion_tokens}"
        )


if __name__ == "__main__":
    main()
