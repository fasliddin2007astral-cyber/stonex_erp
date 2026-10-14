"""API integratsiya testi (SQLite). Kerak: pip install -r requirements.txt"""
import os
import tempfile
import unittest

_db = os.path.join(tempfile.mkdtemp(), "test.db")
os.environ["DATABASE_URL"] = f"sqlite:///{_db}"
os.environ["ADMIN_PASSWORD"] = "admin-test-123"

from fastapi.testclient import TestClient  # noqa: E402

from app import seed  # noqa: E402
from app.main import app  # noqa: E402


class ApiTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        seed.main()
        cls.c = TestClient(app)
        r = cls.c.post("/auth/login", json={"username": "admin", "password": "admin-test-123"})
        cls.h = {"Authorization": f"Bearer {r.json()['access_token']}"}
        for u, role in (("kassir1", "kassir"), ("ishchi1", "ishchi")):
            cls.c.post("/users", headers=cls.h, json={
                "username": u, "full_name": u, "password": "parol12345", "role": role})

    def login(self, u):
        r = self.c.post("/auth/login", json={"username": u, "password": "parol12345"})
        return {"Authorization": f"Bearer {r.json()['access_token']}"}

    def product(self, name):
        items = self.c.get("/products", headers=self.h).json()
        return next(p for p in items if p["name"] == name)

    def test_role_mismatch_rejected(self):
        r = self.c.post("/auth/login", json={"username": "kassir1", "password": "parol12345",
                                              "role": "admin"})
        self.assertEqual(r.status_code, 403)

    def test_cashier_cannot_manage_products(self):
        r = self.c.post("/products", headers=self.login("kassir1"),
                        json={"name": "X", "unit": "dona", "price": 1})
        self.assertEqual(r.status_code, 403)

    def test_sale_in_dona_reduces_stock_and_tracks_debt(self):
        before = self.product("Angola")
        k = self.login("kassir1")
        r = self.c.post("/sales", headers=k, json={
            "items": [{"product_id": before["id"], "quantity": 8, "unit": "dona"}],  # 2 m2
            "paid_amount": 100000, "customer_name": "Ali"})
        self.assertEqual(r.status_code, 201, r.text)
        s = r.json()
        self.assertEqual(float(s["total"]), 360000.0)
        self.assertEqual(float(s["debt"]), 260000.0)
        after = self.product("Angola")
        self.assertEqual(float(before["stock"]) - float(after["stock"]), 2.0)
        # nasiya to'lovi
        r = self.c.post(f"/sales/{s['id']}/payments", headers=k, json={"amount": 260000})
        self.assertEqual(float(r.json()["debt"]), 0.0)

    def test_cannot_oversell(self):
        p = self.product("Disk")
        r = self.c.post("/sales", headers=self.login("kassir1"), json={
            "items": [{"product_id": p["id"], "quantity": 9999}], "paid_amount": 0,
            "customer_name": "Vali"})
        self.assertEqual(r.status_code, 400)

    def test_debt_requires_customer(self):
        p = self.product("Kley")
        r = self.c.post("/sales", headers=self.login("kassir1"), json={
            "items": [{"product_id": p["id"], "quantity": 1}], "paid_amount": 0})
        self.assertEqual(r.status_code, 400)

    def test_dona_not_allowed_for_non_stone(self):
        p = self.product("Kley")
        r = self.c.post("/sales", headers=self.login("kassir1"), json={
            "items": [{"product_id": p["id"], "quantity": 1, "unit": "dona"}], "paid_amount": 0,
            "customer_name": "Z"})
        self.assertEqual(r.status_code, 400)


if __name__ == "__main__":
    unittest.main()
