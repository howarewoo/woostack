#!/usr/bin/env python3
"""Deterministically sanitize telemetry and validate tracked-write candidates."""

from __future__ import annotations

import argparse
import ipaddress
import json
import os
import re
import sys
import tempfile
from pathlib import Path
from typing import Any

TOKEN = "[REDACTED_TOKEN]"
EMAIL = "[REDACTED_EMAIL]"
IP = "[REDACTED_IP]"
USER = "[REDACTED_USER]"
BODY = "[REDACTED_BODY]"
HOME = "[REDACTED_HOME]"
PHONE = "[REDACTED_PHONE]"
CARD = "[REDACTED_CARD]"
NAME = "[REDACTED_NAME]"
ADDRESS = "[REDACTED_ADDRESS]"
PLACEHOLDERS = {TOKEN, EMAIL, IP, USER, BODY, HOME, PHONE, CARD, NAME, ADDRESS}


def normalized_key(key: str) -> str:
    return re.sub(r"[^a-z0-9]", "", key.lower())


BODY_KEYS = {"body", "requestbody", "responsebody", "payload", "rawpayload"}
USER_KEYS = {"user", "userid", "username", "phone", "phonenumber", "customer", "accountuser"}
CREDENTIAL_KEYS = {
    "authorization", "authentication", "credential", "credentials",
    "password", "passwd", "pwd", "secret", "token", "apikey", "accesskey",
    "cookie", "session", "sessionid", "databaseurl", "connectionstring",
    "privatekey", "signingkey", "secretkey", "encryptionkey", "keymaterial",
    "xamzsignature", "xgoogsignature", "pem", "pkcs8", "pkcs1",
}
CREDENTIAL_KEY_SUFFIXES = (
    "authorization", "authentication", "credential", "credentials", "password",
    "passwd", "secret", "token", "apikey", "accesskey", "secretkey", "signingkey",
    "privatekey", "encryptionkey", "keymaterial", "cookie", "sessionid",
    "databaseurl", "connectionstring",
)
KEY_MATERIAL_TAILS = {"pem", "pkcs8", "pkcs1"}
# Aggregate/metric key tails whose values are counts or dimensions, never secrets.
METRIC_KEY_TOKENS = {
    "count", "total", "sum", "duration", "latency", "elapsed", "ms", "millis",
    "milliseconds", "seconds", "secs", "nanos", "failures", "failure", "errors",
    "error", "successes", "attempts", "retries", "hits", "misses", "size", "bytes",
    "length", "rate", "ratio", "percent", "pct", "avg", "average", "mean", "median",
    "min", "max", "p50", "p90", "p95", "p99", "quantile", "score",
}
EMAIL_KEYS = {"email", "emailaddress"}
IP_KEYS = {"ip", "clientip", "remoteip", "peerip", "ipaddress"}
NAME_KEYS = {
    "name", "fullname", "firstname", "lastname", "middlename", "givenname", "forename",
    "surname", "familyname", "maidenname", "displayname", "legalname", "personname",
    "customername", "clientname", "contactname", "recipientname", "patientname",
    "cardholder", "cardholdername", "accountholder", "accountholdername",
    "billingname", "shippingname",
}
NAME_KEY_SUFFIXES = (
    "fullname", "firstname", "lastname", "givenname", "surname", "familyname",
    "customername", "contactname", "recipientname", "personname", "holdername",
    "billingname", "shippingname", "legalname",
)
ADDRESS_KEYS = {
    "address", "streetaddress", "shippingaddress", "billingaddress", "mailingaddress",
    "homeaddress", "postaladdress", "deliveryaddress", "street", "addressline",
    "addressline1", "addressline2", "postalcode", "postcode", "zipcode",
}
ADDRESS_KEY_SUFFIXES = (
    "streetaddress", "shippingaddress", "billingaddress", "mailingaddress",
    "homeaddress", "postaladdress", "deliveryaddress", "recipientaddress",
    "senderaddress", "postalcode", "zipcode",
)
ADDRESS_LINE_QUALIFIERS = (
    "shipping", "billing", "mailing", "home", "postal", "delivery",
    "recipient", "sender", "contact",
)

EMAIL_RE = re.compile(r"(?i)\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b")
IPV4_RE = re.compile(r"(?<![\w.])(?:\d{1,3}\.){3}\d{1,3}(?![\w.])")
IPV6_CANDIDATE_RE = re.compile(r"(?<![\w:])(?:[0-9A-Fa-f]{0,4}:){2,7}[0-9A-Fa-f]{0,4}(?![\w:])")
HOME_RES = (
    re.compile(r"(?<![\w])/(?:Users|home)/[^/\\\s]+"),
    re.compile(r"(?i)(?<![\w])(?:[A-Z]:\\Users\\)[^\\/\s]+"),
)
SECRET_VALUE_RES = (
    re.compile(r"(?i)\b(?:bearer|basic)\s+[A-Za-z0-9._~+/=-]{8,}"),
    re.compile(r"\b(?:ghp|github_pat|sk_(?:live|test)|sess|api)_[A-Za-z0-9_-]{12,}\b", re.I),
    re.compile(r"\bxox(?:a|b|p|r)-[A-Za-z0-9-]{10,}\b", re.I),
    re.compile(r"(?i)\b(?:postgres(?:ql)?|mysql|mongodb(?:\+srv)?|redis)://[^\s]+"),
    re.compile(r"\b(?:AKIA|ASIA|AGPA|AIDA|AROA|AIPA|ANPA|ANVA|ASCA)[0-9A-Z]{16}\b"),
    re.compile(r"\bAIza[0-9A-Za-z_-]{35}\b"),
    re.compile(r"\beyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{5,}\.[A-Za-z0-9_-]*"),
    re.compile(r"\bMII[A-Za-z0-9+/]+IBADANBgkqhkiG[A-Za-z0-9+/=]*"),
)
RESIDUAL_ONLY_RES = (
    re.compile(r"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----"),
)
MARKDOWN_KEY_RE = re.compile(
    r"(?im)^\s*(?:[-*]\s*)?(?:[`\"']?)(authorization|authentication|credential|password|passwd|secret|token|api[ _-]?key|cookie|session(?:[ _-]?id)?|database[ _-]?url|connection[ _-]?string|request[ _-]?body|response[ _-]?body|user(?:[ _-]?id)?|private[ _-]?key|signing[ _-]?key|pem|full[ _-]?name|first[ _-]?name|last[ _-]?name|customer[ _-]?name|street[ _-]?address|shipping[ _-]?address|billing[ _-]?address|postal[ _-]?code|zip[ _-]?code)(?:[`\"']?)\s*[:=]"
)

CARD_CANDIDATE_RE = re.compile(r"(?<![\w])(?:\d[ -]?){12,18}\d(?![\w])")
PHONE_CANDIDATE_RE = re.compile(r"(?<![\w])\+?\d[\d ().-]{7,}\d(?![\w])")
QUERY_CRED_RE = re.compile(
    r"(?i)([?&#](?:access[_-]?token|refresh[_-]?token|id[_-]?token|client[_-]?secret|"
    r"api[_-]?key|apikey|authorization|auth[_-]?token|password|passwd|pwd|secret|token|"
    r"sig|signature|session(?:[_-]?id)?|credential|code|"
    r"x[_-]?amz[_-]?signature|x[_-]?amz[_-]?credential|x[_-]?amz[_-]?security[_-]?token|"
    r"x[_-]?goog[_-]?signature|x[_-]?goog[_-]?credential)=)(?!\[REDACTED_)[^&\s#]+"
)
INLINE_CREDENTIAL_RE = re.compile(
    r"(?i)(\b(?:authorization|authentication|credential|password|passwd|pwd|secret|token|"
    r"api[_ -]?key|cookie|session(?:[_ -]?id)?)\s*[:=]\s*)(?!\[REDACTED_)[^\s,;\"'&#]+"
)


def luhn_ok(digits: str) -> bool:
    total = 0
    parity = len(digits) % 2
    for index, char in enumerate(digits):
        digit = ord(char) - 48
        if index % 2 == parity:
            digit *= 2
            if digit > 9:
                digit -= 9
        total += digit
    return total % 10 == 0


def card_span(candidate: str) -> bool:
    digits = re.sub(r"\D", "", candidate)
    return 13 <= len(digits) <= 19 and luhn_ok(digits)


def phone_span(candidate: str) -> bool:
    if "+" not in candidate and not any(separator in candidate for separator in " ().-"):
        return False
    return 10 <= len(re.sub(r"\D", "", candidate)) <= 15


def redact_cards(value: str) -> str:
    return CARD_CANDIDATE_RE.sub(lambda match: CARD if card_span(match.group(0)) else match.group(0), value)


def redact_phones(value: str) -> str:
    return PHONE_CANDIDATE_RE.sub(lambda match: PHONE if phone_span(match.group(0)) else match.group(0), value)


def _last_token(key: str) -> str:
    spaced = re.sub(r"(?<=[a-z0-9])(?=[A-Z])", "_", key)
    parts = [part for part in re.split(r"[^A-Za-z0-9]+", spaced) if part]
    return parts[-1].lower() if parts else ""


def _is_credential_key(key: str, norm: str, last: str) -> bool:
    if norm in CREDENTIAL_KEYS:
        return True
    if last in KEY_MATERIAL_TAILS:
        return True
    return any(norm.endswith(suffix) for suffix in CREDENTIAL_KEY_SUFFIXES)


def _is_address_key(norm: str) -> bool:
    stem = norm.rstrip("0123456789")
    for candidate in (norm, stem):
        if candidate in ADDRESS_KEYS:
            return True
        if any(candidate.endswith(suffix) for suffix in ADDRESS_KEY_SUFFIXES):
            return True
    if not stem.endswith("addressline"):
        return False
    qualifier = stem[:-len("addressline")]
    return qualifier.endswith(ADDRESS_LINE_QUALIFIERS)


def key_class(key: str) -> str | None:
    norm = normalized_key(key)
    last = _last_token(key)
    if norm in BODY_KEYS or last == "body":
        return "body"
    if norm in USER_KEYS or norm.endswith("userid"):
        return "user"
    if last not in METRIC_KEY_TOKENS and _is_credential_key(key, norm, last):
        return "token"
    if norm in EMAIL_KEYS or norm.endswith("email"):
        return "email"
    if norm in IP_KEYS or last == "ip":
        return "ip"
    if norm in NAME_KEYS or any(norm.endswith(suffix) for suffix in NAME_KEY_SUFFIXES):
        return "name"
    if _is_address_key(norm):
        return "address"
    return None


def replace_ipv6(text: str) -> str:
    def redact(match: re.Match[str]) -> str:
        candidate = match.group(0)
        try:
            return IP if ipaddress.ip_address(candidate).version == 6 else candidate
        except ValueError:
            return candidate
    return IPV6_CANDIDATE_RE.sub(redact, text)


def replace_ipv4(text: str) -> str:
    def redact(match: re.Match[str]) -> str:
        candidate = match.group(0)
        try:
            return IP if ipaddress.ip_address(candidate).version == 4 else candidate
        except ValueError:
            return candidate
    return IPV4_RE.sub(redact, text)


def redact_string(value: str) -> str:
    result = value
    for pattern in SECRET_VALUE_RES:
        result = pattern.sub(TOKEN, result)
    result = INLINE_CREDENTIAL_RE.sub(lambda match: match.group(1) + TOKEN, result)
    result = QUERY_CRED_RE.sub(lambda match: match.group(1) + TOKEN, result)
    for pattern in HOME_RES:
        result = pattern.sub(HOME, result)
    result = EMAIL_RE.sub(EMAIL, result)
    result = replace_ipv4(result)
    result = replace_ipv6(result)
    result = redact_cards(result)
    result = redact_phones(result)
    return result


def sanitize(value: Any) -> Any:
    if isinstance(value, dict):
        result: dict[str, Any] = {}
        for key, child in value.items():
            safe_key = redact_string(key)
            if safe_key in result:
                raise ValueError(f"sensitive key redaction collision: {safe_key}")
            category = key_class(key)
            if category == "body":
                result[safe_key] = BODY
            elif category == "user":
                result[safe_key] = USER
            elif category == "token":
                result[safe_key] = TOKEN
            elif category == "email":
                result[safe_key] = EMAIL
            elif category == "ip":
                result[safe_key] = IP
            elif category == "name":
                result[safe_key] = NAME
            elif category == "address":
                result[safe_key] = ADDRESS
            else:
                result[safe_key] = sanitize(child)
        return result
    if isinstance(value, list):
        return [sanitize(item) for item in value]
    if isinstance(value, str):
        return redact_string(value)
    if isinstance(value, bool):
        return value
    if isinstance(value, (int, float)):
        rendered = json.dumps(value)
        redacted = redact_string(rendered)
        return redacted if redacted != rendered else value
    return value


def forbidden_string(value: str) -> str | None:
    if value in PLACEHOLDERS:
        return None
    for pattern in SECRET_VALUE_RES:
        if pattern.search(value):
            return "secret-shaped value"
    if QUERY_CRED_RE.search(value):
        return "credential in URL query"
    if INLINE_CREDENTIAL_RE.search(value):
        return "inline credential assignment"
    for pattern in RESIDUAL_ONLY_RES:
        if pattern.search(value):
            return "private-key material"
    for match in CARD_CANDIDATE_RE.finditer(value):
        if card_span(match.group(0)):
            return "payment card number"
    for match in PHONE_CANDIDATE_RE.finditer(value):
        if phone_span(match.group(0)):
            return "phone number"
    if EMAIL_RE.search(value):
        return "email address"
    for match in IPV4_RE.finditer(value):
        try:
            ipaddress.ip_address(match.group(0))
            return "IP address"
        except ValueError:
            pass
    for match in IPV6_CANDIDATE_RE.finditer(value):
        try:
            if ipaddress.ip_address(match.group(0)).version == 6:
                return "IP address"
        except ValueError:
            pass
    for pattern in HOME_RES:
        if pattern.search(value):
            return "home path"
    return None


def validate_json(value: Any, location: str = "$") -> None:
    if isinstance(value, dict):
        for key, child in value.items():
            reason = forbidden_string(key)
            if reason:
                raise ValueError(f"{reason} in key at {location}")
            category = None if key in PLACEHOLDERS else key_class(key)
            expected = {"body": BODY, "user": USER, "token": TOKEN, "email": EMAIL, "ip": IP, "name": NAME, "address": ADDRESS}.get(category)
            if category and child != expected:
                raise ValueError(f"forbidden key at {location}.{key}")
            validate_json(child, f"{location}.{key}")
    elif isinstance(value, list):
        for index, child in enumerate(value):
            validate_json(child, f"{location}[{index}]")
    elif isinstance(value, str):
        reason = forbidden_string(value)
        if reason:
            raise ValueError(f"{reason} at {location}")
    elif isinstance(value, (int, float)) and not isinstance(value, bool):
        reason = forbidden_string(json.dumps(value))
        if reason:
            raise ValueError(f"{reason} at {location}")


def validate_text(text: str) -> None:
    match = MARKDOWN_KEY_RE.search(text)
    if match:
        raise ValueError(f"forbidden key in text: {match.group(1)}")
    reason = forbidden_string(text)
    if reason:
        raise ValueError(f"{reason} in text")


def validate_candidate(text: str) -> None:
    try:
        parsed = json.loads(text)
    except json.JSONDecodeError:
        validate_text(text)
    else:
        validate_json(parsed)


def transform(input_path: Path, output_path: Path) -> None:
    parsed = json.loads(input_path.read_text(encoding="utf-8"))
    rendered = json.dumps(sanitize(parsed), indent=2, sort_keys=True, ensure_ascii=False) + "\n"
    output_path.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary_name = tempfile.mkstemp(prefix=f".{output_path.name}.", suffix=".tmp", dir=output_path.parent)
    temporary = Path(temporary_name)
    try:
        with os.fdopen(fd, "w", encoding="utf-8", newline="\n") as handle:
            handle.write(rendered)
            handle.flush()
            os.fsync(handle.fileno())
        validate_candidate(temporary.read_text(encoding="utf-8"))
        os.replace(temporary, output_path)
    except BaseException:
        temporary.unlink(missing_ok=True)
        raise


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--check", type=Path, metavar="FILE")
    mode.add_argument("--input", type=Path, metavar="FILE")
    parser.add_argument("--output", type=Path, metavar="FILE")
    args = parser.parse_args()
    if args.input is not None and args.output is None:
        parser.error("--output is required with --input")
    if args.check is not None and args.output is not None:
        parser.error("--output is invalid with --check")
    return args


def main() -> int:
    args = parse_args()
    try:
        if args.check is not None:
            validate_candidate(args.check.read_text(encoding="utf-8"))
        else:
            transform(args.input, args.output)
    except (OSError, UnicodeError, json.JSONDecodeError, ValueError) as error:
        print(f"sanitize-telemetry: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
