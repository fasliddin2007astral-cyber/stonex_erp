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

    def test_sale_return_rules(self):
        # 1. Yangi mahsulot
        pr = self.c.post("/products", headers=self.h, json={
            "name": "Kafel Granit Oq", "unit": "m2", "price": 100000, "cost_price": 60000, "initial_stock": 50
        })
        self.assertEqual(pr.status_code, 201)
        pid = pr.json()["id"]

        # 2. Savdo qilish (3 m2 butun, 2 m2 kesilgan)
        sr = self.c.post("/sales", headers=self.h, json={
            "items": [
                {"product_id": pid, "quantity": 3, "unit": "base"},
                {"product_id": pid, "quantity": 2, "unit": "base", "custom_name": "Kafel Granit Oq [1.2x0.6m (4 dona)]"}
            ],
            "paid_amount": 500000
        })
        self.assertEqual(sr.status_code, 201)
        sale_id = sr.json()["id"]

        # 3. Kesilgan mahsulotni qaytarishga urinish (bloklanishi shart)
        ret_fail = self.c.post(f"/sales/{sale_id}/return", headers=self.h, json={
            "items": [{"product_id": pid, "quantity": 1}],
            "reason": "Kesilgan tosh"
        })
        self.assertEqual(ret_fail.status_code, 400)
        self.assertIn("kesilgan", ret_fail.json()["detail"].lower())

        # 4. Faqat butun mahsulotli yangi savdo
        pr2 = self.c.post("/products", headers=self.h, json={
            "name": "Butun Kafel 60x60", "unit": "dona", "price": 50000, "cost_price": 30000, "initial_stock": 100
        })
        pid2 = pr2.json()["id"]

        sr2 = self.c.post("/sales", headers=self.h, json={
            "items": [{"product_id": pid2, "quantity": 10, "unit": "base"}],
            "paid_amount": 500000
        })
        sale2_id = sr2.json()["id"]

        # 5. Butun mahsulotdan 3 dona qaytarish
        ret_ok = self.c.post(f"/sales/{sale2_id}/return", headers=self.h, json={
            "items": [{"product_id": pid2, "quantity": 3}],
            "reason": "Mijoz ortib qolgan butun kafelni qaytardi"
        })
        self.assertEqual(ret_ok.status_code, 200)
        # Ombordagi qoldiq tiklanishi kerak: 100 - 10 + 3 = 93
        prod_check = self.c.get("/products", headers=self.h)
        p_obj = next(x for x in prod_check.json() if x["id"] == pid2)
        self.assertEqual(float(p_obj["stock"]), 93.0)

    def test_currency_rate_and_dual_currency_sale(self):
        # 1. CBU Kursini olish
        res = self.c.get("/finance/currency-rate")
        self.assertEqual(res.status_code, 200)
        data = res.json()
        self.assertIn("rate", data)
        self.assertGreater(data["rate"], 10000)

        # 2. Mahsulot yaratish
        pr = self.c.post("/products", headers=self.h, json={
            "name": "Marmar Plita Dollar Test", "unit": "m2", "price": 120000, "cost_price": 80000, "initial_stock": 50
        })
        pid = pr.json()["id"]

        # 3. So'm va dollarda aralash to'lov (masalan $5 + 60 000 so'm, kurs 12 000 bo'lsa)
        rate = 12000.0
        sale_res = self.c.post("/sales", headers=self.h, json={
            "items": [{"product_id": pid, "quantity": 1, "unit": "base"}],
            "paid_amount": 120000,
            "currency_rate": rate,
            "paid_uzs": 60000,
            "paid_usd": 5.0,
        })
        self.assertEqual(sale_res.status_code, 201)
        s_data = sale_res.json()
        self.assertEqual(float(s_data["currency_rate"]), rate)
        self.assertEqual(float(s_data["paid_uzs"]), 60000.0)
        self.assertEqual(float(s_data["paid_usd"]), 5.0)


if __name__ == "__main__":
    unittest.main()
