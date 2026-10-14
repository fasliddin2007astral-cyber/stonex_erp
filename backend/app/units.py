"""Miqdor va pul yaxlitlash hamda birlik o'tkazish.

Qoida: faqat dona_m2 belgilangan mahsulotlar (masalan Angola, Miramir, Tan Brown)
uchun 1 dona = 0,25 m². Boshqa mahsulotlarga bu qoida TATBIQ ETILMAYDI.
"""
from decimal import ROUND_HALF_UP, Decimal

DEFAULT_STONE_DONA_M2 = Decimal("0.25")


def q2(x) -> Decimal:
    """Pul: 2 xona."""
    return Decimal(x).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)


def q3(x) -> Decimal:
    """Miqdor: 3 xona."""
    return Decimal(x).quantize(Decimal("0.001"), rounding=ROUND_HALF_UP)


def dona_to_base(dona, dona_m2) -> Decimal:
    if dona_m2 is None or Decimal(dona_m2) <= 0:
        raise ValueError("Bu mahsulot dona bilan sotilmaydi (dona_m2 belgilanmagan)")
    return q3(Decimal(dona) * Decimal(dona_m2))


def base_to_dona(base, dona_m2) -> Decimal:
    if dona_m2 is None or Decimal(dona_m2) <= 0:
        raise ValueError("Bu mahsulot uchun dona qiymati yo'q")
    return q3(Decimal(base) / Decimal(dona_m2))
