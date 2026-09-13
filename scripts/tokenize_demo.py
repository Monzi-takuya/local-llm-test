#!/usr/bin/env python3
"""Tokenizer-only demo. Does not load model weights or use GPU.

Needs: transformers, tokenizers, huggingface_hub, jinja2 (chat template).
"""

from __future__ import annotations

from transformers import AutoTokenizer

MODEL_ID = "Qwen/Qwen2.5-7B-Instruct"

SENTENCES = [
    "WSLからローカルLLMを動かしたい。",
    "Summarize why quantization helps 8GB VRAM.",
]


def show_tokens(title: str, tokenizer: AutoTokenizer, text: str) -> list[int]:
    encoded = tokenizer(text, add_special_tokens=False)
    ids: list[int] = encoded["input_ids"]
    pieces = tokenizer.convert_ids_to_tokens(ids)
    print(f"\n=== {title} ===")
    print(f"chars: {len(text)}")
    print(f"tokens: {len(ids)}")
    print("id -> token -> decode")
    for token_id, piece in zip(ids, pieces, strict=True):
        decoded = tokenizer.decode([token_id], clean_up_tokenization_spaces=False)
        print(f"  {token_id:>8}  {piece!r}  {decoded!r}")
    return ids


def main() -> None:
    print(f"model (tokenizer only): {MODEL_ID}")
    tokenizer = AutoTokenizer.from_pretrained(MODEL_ID)
    print(f"vocab_size: {tokenizer.vocab_size}")
    print(f"bos: {tokenizer.bos_token!r} id={tokenizer.bos_token_id}")
    print(f"eos: {tokenizer.eos_token!r} id={tokenizer.eos_token_id}")
    print(f"pad: {tokenizer.pad_token!r} id={tokenizer.pad_token_id}")
    print(f"unk: {tokenizer.unk_token!r} id={tokenizer.unk_token_id}")

    for sentence in SENTENCES:
        raw_ids = show_tokens(f"raw: {sentence}", tokenizer, sentence)
        messages = [{"role": "user", "content": sentence}]
        templated = tokenizer.apply_chat_template(
            messages,
            tokenize=False,
            add_generation_prompt=True,
        )
        print("\n--- chat template string ---")
        print(templated)
        templated_ids = show_tokens("chat template applied", tokenizer, templated)
        print(
            f"\nID count change: raw {len(raw_ids)} -> templated {len(templated_ids)}"
        )
        print(f"same as raw? {raw_ids == templated_ids}")


if __name__ == "__main__":
    main()
