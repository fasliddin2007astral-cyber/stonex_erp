"""Telegram bildirishnomalar servisi.

TELEGRAM_BOT_TOKEN va TELEGRAM_CHAT_ID o'rnatilgan bo'lsa, xabarlarni
avtomatik tarzda Telegram guruh/kanaliga yoki haydovchiga yuboradi.
Agar o'rnatilmagan bo'lsa, xatolik chiqarmaydi (graceful skip).
"""
import json
import logging
import os
import urllib.request

logger = logging.getLogger("telegram_service")


def send_telegram_notification(text: str, chat_id: str | None = None) -> bool:
    token = os.getenv("TELEGRAM_BOT_TOKEN")
    target_chat = chat_id or os.getenv("TELEGRAM_CHAT_ID")

    if not token or not target_chat:
        return False

    url = f"https://api.telegram.org/bot{token}/sendMessage"
    payload = json.dumps({
        "chat_id": target_chat,
        "text": text,
        "parse_mode": "HTML",
        "disable_web_page_preview": True,
    }).encode("utf-8")

    try:
        req = urllib.request.Request(
            url,
            data=payload,
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        with urllib.request.urlopen(req, timeout=4) as resp:
            return resp.status == 200
    except Exception as e:
        logger.warning(f"Telegram notification error: {e}")
        return False


def notify_new_delivery(delivery_id: int, driver_name: str, vehicle: str, recipient: str, address: str, fee: float):
    msg = (
        f"🚚 <b>Yangi Yetkazib Berish topshirig'i (#{delivery_id})</b>\n\n"
        f"👤 <b>Haydovchi:</b> {driver_name} ({vehicle})\n"
        f"📍 <b>Mijoz:</b> {recipient}\n"
        f"🏠 <b>Manzil:</b> {address or 'Ko‘rsatilmagan'}\n"
        f"💰 <b>Yetkazish haqi:</b> {int(fee):,} so‘m\n\n"
        f"<i>StoneX ERP Logistika tizimi</i>"
    )
    send_telegram_notification(msg)

