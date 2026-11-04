import re


def normalize_phone(val: str | None) -> str:
    """Telefon raqamni toza standart formatga keltiradi (+998901234567 yoki raqamlar ketma-ketligi)."""
    if not val:
        return ""
    digits = re.sub(r"\D", "", val)
    if len(digits) == 9:
        return f"+998{digits}"
    if len(digits) == 12 and digits.startswith("998"):
        return f"+{digits}"
    return f"+{digits}" if digits else ""

