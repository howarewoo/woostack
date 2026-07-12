#!/usr/bin/env python3
"""Derive the sole operation type from a GraphQL executable document."""

from __future__ import annotations

import re
import sys
from pathlib import Path

_NAME = re.compile(r"[_A-Za-z][_0-9A-Za-z]*")
_IGNORED = {" ", "\t", "\r", "\n", ",", "\ufeff"}


class InvalidDocument(ValueError):
    pass


def tokenize(source: str) -> list[tuple[str, str]]:
    tokens: list[tuple[str, str]] = []
    index = 0
    size = len(source)
    while index < size:
        char = source[index]
        if char in _IGNORED:
            index += 1
            continue
        if char == "#":
            index += 1
            while index < size and source[index] not in "\r\n":
                index += 1
            continue
        if source.startswith('"""', index):
            index += 3
            while index < size:
                if source.startswith('\\"""', index):
                    index += 4
                elif source.startswith('"""', index):
                    index += 3
                    break
                else:
                    index += 1
            else:
                raise InvalidDocument("unterminated block string")
            tokens.append(("STRING", ""))
            continue
        if char == '"':
            index += 1
            while index < size:
                if source[index] == '"':
                    index += 1
                    break
                if source[index] == "\\":
                    index += 2
                    continue
                if source[index] in "\r\n":
                    raise InvalidDocument("newline in quoted string")
                index += 1
            else:
                raise InvalidDocument("unterminated quoted string")
            tokens.append(("STRING", ""))
            continue
        name = _NAME.match(source, index)
        if name:
            tokens.append(("NAME", name.group(0)))
            index = name.end()
            continue
        if source.startswith("...", index):
            tokens.append(("PUNCT", "..."))
            index += 3
            continue
        tokens.append(("PUNCT", char))
        index += 1
    return tokens


def skip_selection(tokens: list[tuple[str, str]], index: int) -> int:
    depth = 0
    while index < len(tokens):
        value = tokens[index][1]
        if value == "{":
            depth += 1
        elif value == "}":
            depth -= 1
            if depth == 0:
                return index + 1
            if depth < 0:
                raise InvalidDocument("unbalanced selection")
        index += 1
    raise InvalidDocument("unterminated selection")


def find_selection(tokens: list[tuple[str, str]], index: int) -> int:
    parentheses = 0
    brackets = 0
    while index < len(tokens):
        value = tokens[index][1]
        if value == "(":
            parentheses += 1
        elif value == ")":
            parentheses -= 1
            if parentheses < 0:
                raise InvalidDocument("unbalanced parentheses")
        elif value == "[":
            brackets += 1
        elif value == "]":
            brackets -= 1
            if brackets < 0:
                raise InvalidDocument("unbalanced brackets")
        elif value == "{" and parentheses == 0 and brackets == 0:
            return skip_selection(tokens, index)
        index += 1
    raise InvalidDocument("missing selection")


def classify(source: str) -> str:
    tokens = tokenize(source)
    operations: list[str] = []
    index = 0
    while index < len(tokens):
        kind, value = tokens[index]
        if value == "{":
            operations.append("query")
            index = skip_selection(tokens, index)
            continue
        if kind != "NAME":
            raise InvalidDocument("unexpected top-level token")
        if value in {"query", "mutation", "subscription"}:
            operations.append(value)
            index = find_selection(tokens, index + 1)
            continue
        if value == "fragment":
            index = find_selection(tokens, index + 1)
            continue
        raise InvalidDocument("unsupported definition")

    if len(operations) > 1:
        return "ambiguous_operation"
    if not operations:
        return "invalid_operation"
    if operations[0] == "subscription":
        return "unsupported_operation"
    return operations[0]


def main() -> int:
    if len(sys.argv) != 2:
        print("invalid_operation")
        return 0
    try:
        source = Path(sys.argv[1]).read_text(encoding="utf-8")
        print(classify(source))
    except (OSError, UnicodeError, InvalidDocument):
        print("invalid_operation")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
