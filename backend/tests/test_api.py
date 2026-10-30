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

    def test_product_image_upload(self):
        # 1. Rasm faylini yuklash
        fake_image = b"\xff\xd8\xff\xe0\x00\x10JFIF\x00\x01\x01\x01\x00`\x00`\x00\x00"
        r = self.c.post("/products/upload-image", headers=self.h,
                        files={"file": ("granit.jpg", fake_image, "image/jpeg")})
        self.assertEqual(r.status_code, 200)
        img_url = r.json()["image_url"]
        self.assertTrue(img_url.startswith("/uploads/products/"))

        # 2. Yangi mahsulotni ushbu rasm bilan yaratish
        r = self.c.post("/products", headers=self.h, json={
            "name": "Granit Plita", "unit": "m2", "price": 220000, "image_url": img_url
        })
        self.assertEqual(r.status_code, 201)
        created = r.json()
        self.assertEqual(created["image_url"], img_url)

        # 3. Mavjud mahsulotga to'g'ridan-to'g'ri rasm yuklash
        r = self.c.post(f"/products/{created['id']}/image", headers=self.h,
                        files={"file": ("granit_new.png", fake_image, "image/png")})
        self.assertEqual(r.status_code, 200)
        self.assertTrue(r.json()["image_url"].endswith(".png"))

    def test_attendance_and_salary_calculation(self):
        # 1. Yangi xodim maoshi bilan
        r = self.c.post("/users", headers=self.h, json={
            "username": "usta_davron",
            "full_name": "Davron Usta",
            "password": "parol12345",
            "role": "ishchi",
            "salary": 5200000,
            "salary_type": "monthly"
        })
        self.assertEqual(r.status_code, 201)
        uid = r.json()["id"]

        # 2. Check-in (keldi)
        r = self.c.post("/attendance/check-in", headers=self.h, json={
            "user_id": uid,
            "date": "2026-10-15",
            "check_in": "2026-10-15T08:30:00"
        })
        self.assertEqual(r.status_code, 200)
        self.assertEqual(r.json()["status"], "present")

        # 3. Check-out (ketdi)
        r = self.c.post("/attendance/check-out", headers=self.h, json={
            "user_id": uid,
            "date": "2026-10-15",
            "check_out": "2026-10-15T18:00:00"
        })
        self.assertEqual(r.status_code, 200)
        self.assertEqual(float(r.json()["worked_hours"]), 9.5)

        # 4. Kechikkan kun (9:30 da kelgan)
        r = self.c.post("/attendance/check-in", headers=self.h, json={
            "user_id": uid,
            "date": "2026-10-16",
            "check_in": "2026-10-16T09:30:00"
        })
        self.assertEqual(r.status_code, 200)
        self.assertEqual(r.json()["status"], "late")

        # 5. Oylik hisoboti
        r = self.c.get("/attendance/salary-report?month=2026-10&total_working_days=26", headers=self.h)
        self.assertEqual(r.status_code, 200)
        rep = next(x for x in r.json() if x["user_id"] == uid)
        self.assertEqual(rep["days_worked"], 2)
        self.assertEqual(rep["days_late"], 1)
        self.assertGreater(float(rep["calculated_salary"]), 0)


if __name__ == "__main__":
    unittest.main()
