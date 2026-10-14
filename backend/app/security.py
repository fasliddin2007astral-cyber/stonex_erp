"""Parol xeshlash (PBKDF2) va JWT (HS256) — faqat standart kutubxona bilan.

Parollar hech qachon ochiq matnda saqlanmaydi.
"""
import base64
import hashlib
import hmac
import json
import os
import time

_ITER = 240_000


def _b64e(b: bytes) -> str:
    return base64.urlsafe_b64encode(b).rstrip(b"=").decode()


def _b64d(s: str) -> bytes:
    return base64.urlsafe_b64decode(s + "=" * (-len(s) % 4))


def hash_password(password: str) -> str:
    salt = os.urandom(16)
    dk = hashlib.pbkdf2_hmac("sha256", password.encode(), salt, _ITER)
    return f"pbkdf2_sha256${_ITER}${_b64e(salt)}${_b64e(dk)}"


def verify_password(password: str, stored: str) -> bool:
    try:
        algo, iters, salt, digest = stored.split("$")
        if algo != "pbkdf2_sha256":
            return False
        dk = hashlib.pbkdf2_hmac("sha256", password.encode(), _b64d(salt), int(iters))
        return hmac.compare_digest(dk, _b64d(digest))
    except Exception:
        return False


def create_token(subject: str, secret: str, minutes: int) -> str:
    header = _b64e(json.dumps({"alg": "HS256", "typ": "JWT"}).encode())
    payload = _b64e(json.dumps({"sub": subject, "exp": int(time.time()) + minutes * 60}).encode())
    sig = hmac.new(secret.encode(), f"{header}.{payload}".encode(), hashlib.sha256).digest()
    return f"{header}.{payload}.{_b64e(sig)}"


def decode_token(token: str, secret: str) -> str | None:
    """Yaroqli bo'lsa subject (user id) qaytaradi, aks holda None."""
    try:
        header, payload, sig = token.split(".")
        expected = hmac.new(secret.encode(), f"{header}.{payload}".encode(), hashlib.sha256).digest()
        if not hmac.compare_digest(expected, _b64d(sig)):
            return None
        data = json.loads(_b64d(payload))
        if data["exp"] < time.time():
            return None
        return str(data["sub"])
    except Exception:
        return None
