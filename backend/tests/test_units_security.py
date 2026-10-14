import unittest
from decimal import Decimal

from app.security import create_token, decode_token, hash_password, verify_password
from app.units import base_to_dona, dona_to_base, q2


class UnitsTest(unittest.TestCase):
    def test_dona_to_m2(self):
        self.assertEqual(dona_to_base(4, Decimal("0.25")), Decimal("1.000"))
        self.assertEqual(dona_to_base(10, Decimal("0.25")), Decimal("2.500"))

    def test_m2_to_dona(self):
        self.assertEqual(base_to_dona(Decimal("2.5"), Decimal("0.25")), Decimal("10.000"))

    def test_non_stone_has_no_dona_rule(self):
        with self.assertRaises(ValueError):
            dona_to_base(3, None)

    def test_money_rounding(self):
        self.assertEqual(q2("10.005"), Decimal("10.01"))


class SecurityTest(unittest.TestCase):
    def test_password(self):
        h = hash_password("sir-parol-123")
        self.assertNotIn("sir-parol", h)
        self.assertTrue(verify_password("sir-parol-123", h))
        self.assertFalse(verify_password("boshqa", h))

    def test_token(self):
        t = create_token("7", "secret", 5)
        self.assertEqual(decode_token(t, "secret"), "7")
        self.assertIsNone(decode_token(t, "wrong"))
        self.assertIsNone(decode_token(create_token("7", "secret", -1), "secret"))
        self.assertIsNone(decode_token("garbage", "secret"))


if __name__ == "__main__":
    unittest.main()
