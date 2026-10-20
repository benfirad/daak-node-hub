#!/usr/bin/env python3
"""
DAAK Node — Mail Harcama & Fatura Toplayıcı (Expense & Receipt Engine)
Apple Mail, E-posta gövdeleri, fatura metinleri ve makbuzlardan otomatik harcama çıkarımı yapar.
Termal fiş dökümü (receipt slip) ve DAAK Node UI entegrasyonu sağlar.
"""

from __future__ import annotations

import argparse
import datetime
import hashlib
import json
import os
import re
import subprocess
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

APP_SUPPORT = Path.home() / "Library" / "Application Support" / "DAAK"
EXPENSES_FILE = APP_SUPPORT / "expenses.json"
CACHE_FILE = APP_SUPPORT / "expenses_mail_cache.json"

# Kategoriler
CAT_SOFTWARE_AI = "Yazılım & AI"
CAT_INFRA_SERVER = "Altyapı & Sunucu"
CAT_GARAGE_FUEL = "Araç & Yakıt (RM Garage)"
CAT_OFFICE_LIVING = "Ofis, Kira & Yaşam"
CAT_TELECOM_HARDWARE = "İletişim & Donanım"
CAT_TAX_LEGAL = "Kamu, Vergi & Sosyal Güvenlik"
CAT_OTHER = "Genel Gider"

VENDOR_CATEGORY_MAP = {
    "apple": CAT_SOFTWARE_AI,
    "openai": CAT_SOFTWARE_AI,
    "chatgpt": CAT_SOFTWARE_AI,
    "anthropic": CAT_SOFTWARE_AI,
    "claude": CAT_SOFTWARE_AI,
    "cursor": CAT_SOFTWARE_AI,
    "anysphere": CAT_SOFTWARE_AI,
    "midjourney": CAT_SOFTWARE_AI,
    "google": CAT_SOFTWARE_AI,
    "github": CAT_SOFTWARE_AI,
    "adobe": CAT_SOFTWARE_AI,
    "spotify": CAT_SOFTWARE_AI,
    "netflix": CAT_SOFTWARE_AI,
    "fuser": CAT_SOFTWARE_AI,
    "ionos": CAT_INFRA_SERVER,
    "hetzner": CAT_INFRA_SERVER,
    "aws": CAT_INFRA_SERVER,
    "cloudflare": CAT_INFRA_SERVER,
    "digitalocean": CAT_INFRA_SERVER,
    "solred": CAT_GARAGE_FUEL,
    "repsol": CAT_GARAGE_FUEL,
    "cepsa": CAT_GARAGE_FUEL,
    "copart": CAT_GARAGE_FUEL,
    "opel": CAT_GARAGE_FUEL,
    "garaj": CAT_GARAGE_FUEL,
    "codomo": CAT_OFFICE_LIVING,
    "baski": CAT_OFFICE_LIVING,
    "bepsas": CAT_OFFICE_LIVING,
    "enerjisa": CAT_OFFICE_LIVING,
    "endesa": CAT_OFFICE_LIVING,
    "iberdrola": CAT_OFFICE_LIVING,
    "vodafone": CAT_TELECOM_HARDWARE,
    "turkcell": CAT_TELECOM_HARDWARE,
    "simyo": CAT_TELECOM_HARDWARE,
    "digi": CAT_TELECOM_HARDWARE,
    "reta": CAT_TAX_LEGAL,
    "tgss": CAT_TAX_LEGAL,
    "aeat": CAT_TAX_LEGAL,
    "is bankasi": CAT_OFFICE_LIVING,
    "türkiye iş bankası": CAT_OFFICE_LIVING,
}

CURRENCY_SYMBOLS = {
    "€": "EUR",
    "EUR": "EUR",
    "$": "USD",
    "USD": "USD",
    "₺": "TRY",
    "TL": "TRY",
    "TRY": "TRY",
    "£": "GBP",
    "GBP": "GBP",
}


def sanitize_text(text: str) -> str:
    return re.sub(r"\s+", " ", text).strip()


def parse_date_string(date_str: str) -> str:
    """Parses various date formats (Spanish, Turkish, English, ISO) into YYYY-MM-DD."""
    if not date_str:
        return datetime.date.today().isoformat()

    # Spanish months
    es_months = {
        "enero": 1, "febrero": 2, "marzo": 3, "abril": 4, "mayo": 5, "junio": 6,
        "julio": 7, "agosto": 8, "septiembre": 9, "octubre": 10, "noviembre": 11, "diciembre": 12,
        "sept": 9, "oct": 10, "nov": 11, "dic": 12
    }
    # Turkish months
    tr_months = {
        "ocak": 1, "şubat": 2, "mart": 3, "nisan": 4, "mayıs": 5, "haziran": 6,
        "temmuz": 7, "ağustos": 8, "eylül": 9, "ekim": 10, "kasım": 11, "aralık": 12
    }
    # English months
    en_months = {
        "january": 1, "february": 2, "march": 3, "april": 4, "may": 5, "june": 6,
        "july": 7, "august": 8, "september": 9, "october": 10, "november": 11, "december": 12,
        "jan": 1, "feb": 2, "mar": 3, "apr": 4, "may": 5, "jun": 6, "jul": 7, "aug": 8, "sep": 9, "oct": 10, "nov": 11, "dec": 12
    }

    clean = date_str.lower().strip()
    
    # ISO pattern: 2026-09-30
    m_iso = re.search(r"(\b202\d)-(\d{1,2})-(\d{1,2})", clean)
    if m_iso:
        y, m, d = int(m_iso.group(1)), int(m_iso.group(2)), int(m_iso.group(3))
        return f"{y:04d}-{m:02d}-{d:02d}"

    # DD.MM.YYYY or DD/MM/YYYY or DD-MM-YYYY
    m_dmy = re.search(r"(\b\d{1,2})[./-](\d{1,2})[./-](202\d)\b", clean)
    if m_dmy:
        d, m, y = int(m_dmy.group(1)), int(m_dmy.group(2)), int(m_dmy.group(3))
        return f"{y:04d}-{m:02d}-{d:02d}"

    # Textual month (e.g. 29 September 2026 or 3 de octubre de 2026 or 15 Ekim 2026)
    all_months = {**es_months, **tr_months, **en_months}
    m_text = re.search(r"(\b\d{1,2})\s+(?:de\s+)?([a-zğüşıöç]+)\s+(?:de\s+)?(202\d)", clean)
    if m_text:
        d = int(m_text.group(1))
        month_name = m_text.group(2)
        y = int(m_text.group(3))
        if month_name in all_months:
            m = all_months[month_name]
            return f"{y:04d}-{m:02d}-{d:02d}"

    # Month Text Day, Year (e.g. October 15, 2026)
    m_text2 = re.search(r"([a-zğüşıöç]+)\s+(\d{1,2}),?\s+(202\d)", clean)
    if m_text2:
        month_name = m_text2.group(1)
        d = int(m_text2.group(2))
        y = int(m_text2.group(3))
        if month_name in all_months:
            m = all_months[month_name]
            return f"{y:04d}-{m:02d}-{d:02d}"

    return datetime.date.today().isoformat()


def extract_amount_and_currency(text: str) -> Tuple[float, str, float]:
    """Extracts gross amount, currency, and tax amount if detected."""
    # Look for total / amount patterns
    # EUR patterns: 2,99 € or €2.99 or 2.99 EUR
    # TRY patterns: 2,429.25 TL or 338.00 TL or ₺338,00
    # USD patterns: $20.00 or 20.00 USD
    
    # Check for VAT / Tax first
    vat_amount = 0.0
    vat_match = re.search(r"(?:VAT charged at \d+%|Inclusive of VAT at \d+%|KDV|IVA|Vergi|Impuestos)[\s:]*([0-9.,]+)\s*([€$₺]|EUR|TL|TRY|USD)?", text, re.IGNORECASE)
    if vat_match:
        raw_val = vat_match.group(1).replace(",", ".")
        # If multiple dots, e.g. 1.250,50
        if raw_val.count(".") > 1:
            raw_val = raw_val.replace(".", "", raw_val.count(".") - 1)
        try:
            vat_amount = float(raw_val)
        except ValueError:
            pass

    # Look for total amount
    # Priority keywords: Total, Toplam, Ödeme Tutarı, Tutar, Subtotal, Amount Paid
    priority_patterns = [
        r"(?:toplam|total|ödeme tutarı|tutar|importe|amount paid|billed amount)[\s:]*([0-9.,]+)\s*([€$₺]|EUR|TL|TRY|USD)?",
        r"(?:Mastercard|Visa|Wise|Card|Kart)[\s•*\d]*\s*([0-9.,]+)\s*([€$₺]|EUR|TL|TRY|USD)",
        r"([0-9.,]+)\s*([€$₺]|EUR|TL|TRY|USD)\b",
        r"([€$₺])\s*([0-9.,]+)",
    ]

    for pat in priority_patterns:
        matches = list(re.finditer(pat, text, re.IGNORECASE))
        if matches:
            # Pick the most likely total (often the last or the one after "total")
            match = matches[-1]
            groups = match.groups()
            val_str = ""
            curr_str = "EUR"
            
            if len(groups) == 2:
                if groups[0] in ("€", "$", "₺"):
                    curr_str = groups[0]
                    val_str = groups[1]
                else:
                    val_str = groups[0]
                    curr_str = groups[1] if groups[1] else "EUR"
            
            curr_code = CURRENCY_SYMBOLS.get(curr_str.upper() if curr_str else "EUR", "EUR")
            
            # Format European/Turkish number: 2.429,25 or 2,429.25 or 2,99
            clean_num = val_str.strip()
            if "," in clean_num and "." in clean_num:
                # 2,429.25 vs 2.429,25
                if clean_num.rfind(",") > clean_num.rfind("."):
                    # European: 2.429,25 -> 2429.25
                    clean_num = clean_num.replace(".", "").replace(",", ".")
                else:
                    # US/UK: 2,429.25 -> 2429.25
                    clean_num = clean_num.replace(",", "")
            elif "," in clean_num:
                clean_num = clean_num.replace(",", ".")
                
            try:
                amt = float(clean_num)
                if amt > 0:
                    return amt, curr_code, vat_amount
            except ValueError:
                continue

    return 0.0, "EUR", vat_amount


def infer_vendor_and_category(subject: str, sender: str, content: str) -> Tuple[str, str]:
    combined = f"{subject} {sender} {content}".lower()
    
    # 1. Apple
    if "apple" in combined:
        return "Apple Distribution International", CAT_SOFTWARE_AI
    
    # 2. OpenAI / ChatGPT
    if "openai" in combined or "chatgpt" in combined:
        return "OpenAI, LLC", CAT_SOFTWARE_AI
        
    # 3. Anthropic / Claude
    if "anthropic" in combined or "claude" in combined:
        return "Anthropic PBC", CAT_SOFTWARE_AI
        
    # 4. Cursor / Anysphere
    if "cursor" in combined or "anysphere" in combined:
        return "Cursor / Anysphere", CAT_SOFTWARE_AI

    # 5. Solred / Repsol
    if "solred" in combined or "repsol" in combined:
        return "Solred / Repsol (RM Garage)", CAT_GARAGE_FUEL

    # 6. İş Bankası / Balıkesir Su / CK Bepsaş
    if "isbank" in combined or "iş bankası" in combined:
        if "balıkesir" in combined or "baski" in combined:
            return "BASKİ - Su & Kanalizasyon", CAT_OFFICE_LIVING
        if "boğaziçi" in combined or "bepsaş" in combined or "ck" in combined:
            return "CK Boğaziçi Elektrik", CAT_OFFICE_LIVING
        return "Türkiye İş Bankası (Otomatik Fatura)", CAT_OFFICE_LIVING

    # 7. IONOS
    if "ionos" in combined:
        return "IONOS SE", CAT_INFRA_SERVER

    # 8. Google / Workspace
    if "google" in combined:
        return "Google Cloud / Workspace", CAT_SOFTWARE_AI

    # 9. Hetzner
    if "hetzner" in combined:
        return "Hetzner Online GmbH", CAT_INFRA_SERVER

    # 10. Endesa / Iberdrola
    if "endesa" in combined:
        return "Endesa Energía", CAT_OFFICE_LIVING
    if "iberdrola" in combined:
        return "Iberdrola Clientes", CAT_OFFICE_LIVING

    # 11. Vodafone / Turkcell / Digi / Simyo
    if "vodafone" in combined:
        return "Vodafone España", CAT_TELECOM_HARDWARE
    if "turkcell" in combined:
        return "Turkcell İletişim", CAT_TELECOM_HARDWARE
    if "simyo" in combined:
        return "Simyo Telecom", CAT_TELECOM_HARDWARE
    if "digi" in combined:
        return "DIGI Spain Telecom", CAT_TELECOM_HARDWARE

    # 12. Midjourney
    if "midjourney" in combined:
        return "Midjourney Inc.", CAT_SOFTWARE_AI

    # 13. GitHub
    if "github" in combined:
        return "GitHub Inc.", CAT_SOFTWARE_AI

    # 14. Fallback from sender
    sender_clean = re.sub(r"<.*?>", "", sender).strip()
    if sender_clean:
        return sender_clean, CAT_OTHER

    return "Bilinmeyen Tedarikçi", CAT_OTHER


def extract_invoice_number(text: str) -> str:
    patterns = [
        r"(?:order id|sipariş no|belge no|document|factura|fatura no|invoice(?: no)?)[\s:#]*([A-Z0-9-]{5,24})\b",
        r"(?:sequence)[\s:#]*([0-9-]{8,24})\b",
        r"(?:id)[\s:#]*([A-Z0-9]{8,20})\b",
    ]
    for pat in patterns:
        m = re.search(pat, text, re.IGNORECASE)
        if m:
            return m.group(1).strip()
    return ""


def extract_payment_method(text: str) -> str:
    patterns = [
        r"(Mastercard[^\n\r,•]*[•*]+\s*\d{4})",
        r"(Visa[^\n\r,•]*[•*]+\s*\d{4})",
        r"(Wise[^\n\r,•]*[•*]+\s*\d{4})",
        r"(Apple Pay[^\n\r,]*)",
        r"(Otomatik [Öö]deme Talimat[^\n\r,]*)",
        r"(Banka Havalesi|Transfer)",
    ]
    for pat in patterns:
        m = re.search(pat, text, re.IGNORECASE)
        if m:
            return sanitize_text(m.group(1))
    return "Kart / Otomatik Tahsilat"


def extract_line_items(text: str, merchant: str, total_amount: float, currency: str) -> List[Dict[str, Any]]:
    items = []
    # Try to extract specific lines (e.g. Apple receipt lines)
    if "apple" in merchant.lower():
        lines = text.splitlines()
        for idx, line in enumerate(lines):
            line_str = line.strip()
            if any(term in line_str.lower() for term in ("mensual", "monthly", "icloud", "storage", "developer", "arcade", "subscription")):
                # Check next line for price
                price = total_amount
                for lookahead in lines[idx:min(len(lines), idx + 4)]:
                    look_amt, _, _ = extract_amount_and_currency(lookahead)
                    if look_amt > 0:
                        price = look_amt
                        break
                items.append({"name": line_str, "qty": 1, "price": price, "currency": currency})
                break
    elif "balıkesir" in merchant.lower():
        items.append({"name": "Balıkesir Su & Kanalizasyon Faturası", "qty": 1, "price": total_amount, "currency": currency})
    elif "boğaziçi" in merchant.lower():
        items.append({"name": "CK Boğaziçi Elektrik Tüketim Bedeli", "qty": 1, "price": total_amount, "currency": currency})
    elif "solred" in merchant.lower() or "repsol" in merchant.lower():
        items.append({"name": "Dizel / Akaryakıt İkmal (RM Garage)", "qty": 1, "price": total_amount, "currency": currency})

    if not items:
        items.append({"name": f"{merchant} Hizmet Bedeli", "qty": 1, "price": total_amount, "currency": currency})

    return items


def parse_email_message(subject: str, sender: str, date_received: str, content: str, msg_id: str) -> Optional[Dict[str, Any]]:
    amt, curr, vat = extract_amount_and_currency(f"{subject}\n{content}")
    if amt <= 0.0:
        # Check if subject mentions an invoice without explicit price in body snippet
        if not any(k in subject.lower() for k in ("fatura", "invoice", "factura", "solred")):
            return None

    merchant, category = infer_vendor_and_category(subject, sender, content)
    date_val = parse_date_string(f"{date_received}\n{content}")
    inv_num = extract_invoice_number(f"{subject}\n{content}")
    pay_method = extract_payment_method(content)
    line_items = extract_line_items(content, merchant, amt, curr)

    # Tax calculation fallback
    if vat == 0.0 and curr == "EUR":
        # Spain default 21% IVA if not explicitly 0
        if category in (CAT_SOFTWARE_AI, CAT_GARAGE_FUEL, CAT_TELECOM_HARDWARE):
            vat = round(amt - (amt / 1.21), 2)

    unique_hash = hashlib.sha256(f"{merchant}:{date_val}:{amt}:{curr}:{inv_num}".encode()).hexdigest()[:12]
    exp_id = f"EXP-{date_val[:7].replace('-', '')}-{unique_hash.upper()}"

    snippet = sanitize_text(content[:280]) if content else sanitize_text(subject)

    return {
        "id": exp_id,
        "date": date_val,
        "merchant": merchant,
        "category": category,
        "amount": amt,
        "currency": curr,
        "taxAmount": vat,
        "taxRate": 21.0 if (curr == "EUR" and vat > 0) else 0.0,
        "paymentMethod": pay_method,
        "invoiceNumber": inv_num if inv_num else f"REF-{unique_hash.upper()}",
        "status": "Ödendi",
        "source": f"Apple Mail ({sender[:30]})",
        "mailMessageId": str(msg_id),
        "subject": subject,
        "items": line_items,
        "rawSnippet": snippet,
        "notes": f"Apple Mail üzerinden otomatik işlendi ({datetime.date.today().isoformat()})"
    }


def scan_apple_mail(limit: int = 100) -> List[Dict[str, Any]]:
    """Scans Apple Mail for receipts and invoices using AppleScript."""
    script = """
    tell application "Mail"
        set accList to accounts
        set out to ""
        repeat with acc in accList
            try
                set ib to mailbox "INBOX" of acc
                set msgs to (messages of ib whose subject contains "fatura" or subject contains "invoice" or subject contains "receipt" or subject contains "dekont" or subject contains "factura" or subject contains "solred" or subject contains "Ödeme")
                set c to count of msgs
                if c > 0 then
                    repeat with i from 1 to c
                        set m to item i of msgs
                        set out to out & (subject of m) & "<|DAAK|>" & (sender of m) & "<|DAAK|>" & ((date received of m) as string) & "<|DAAK|>" & (id of m) & "<|DAAK|>" & (name of acc) & "\n"
                    end repeat
                end if
            end try
        end repeat
        return out
    end tell
    """
    try:
        proc = subprocess.run(["osascript", "-e", script], capture_output=True, text=True, timeout=15)
    except Exception as e:
        print(f"Mail scan failed: {e}", file=sys.stderr)
        return []

    lines = [l.strip() for l in proc.stdout.splitlines() if l.strip()]
    candidates = []
    for line in lines[:limit]:
        parts = line.split("<|DAAK|>")
        if len(parts) >= 4:
            subj = parts[0].strip()
            sender = parts[1].strip()
            date_str = parts[2].strip()
            msg_id = parts[3].strip()
            account_name = parts[4].strip() if len(parts) > 4 else "Mail"
            candidates.append((subj, sender, date_str, msg_id, account_name))

    results = []
    # For each candidate, fetch content (or use subject/cached info)
    for subj, sender, date_str, msg_id, acc in candidates:
        content_script = f"""
        tell application "Mail"
            try
                set ib to mailbox "INBOX" of account "{acc}"
                set m to (first message of ib whose id is {msg_id})
                set c to (content of m)
                if (length of c) > 1000 then
                    return text 1 thru 1000 of c
                else
                    return c
                end if
            on error
                return ""
            end try
        end tell
        """
        try:
            c_proc = subprocess.run(["osascript", "-e", content_script], capture_output=True, text=True, timeout=5)
            content = c_proc.stdout.strip()
        except Exception:
            content = ""

        parsed = parse_email_message(subj, sender, date_str, content, msg_id)
        if parsed:
            results.append(parsed)

    return results


def load_database() -> Dict[str, Any]:
    if not EXPENSES_FILE.is_file():
        return {
            "version": "1.0.0",
            "updated_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
            "currency_rates": {"EUR": 1.0, "USD": 1.08, "TRY": 38.5},
            "stats": {},
            "expenses": []
        }
    try:
        with open(EXPENSES_FILE, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return {
            "version": "1.0.0",
            "updated_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
            "currency_rates": {"EUR": 1.0, "USD": 1.08, "TRY": 38.5},
            "stats": {},
            "expenses": []
        }


def save_database(data: Dict[str, Any]) -> None:
    APP_SUPPORT.mkdir(parents=True, exist_ok=True)
    recompute_stats(data)
    data["updated_at"] = datetime.datetime.now(datetime.timezone.utc).isoformat()
    with open(EXPENSES_FILE, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)


def recompute_stats(data: Dict[str, Any]) -> None:
    expenses = data.get("expenses", [])
    rates = data.get("currency_rates", {"EUR": 1.0, "USD": 1.08, "TRY": 38.5})
    
    total_eur = 0.0
    by_currency = {"EUR": 0.0, "USD": 0.0, "TRY": 0.0, "GBP": 0.0}
    by_category = {}
    by_month = {}
    total_tax_eur = 0.0

    for exp in expenses:
        amt = float(exp.get("amount", 0.0))
        curr = exp.get("currency", "EUR")
        cat = exp.get("category", CAT_OTHER)
        tax = float(exp.get("taxAmount", 0.0))
        d_str = exp.get("date", "")
        month_key = d_str[:7] if len(d_str) >= 7 else "Bilinmeyen"

        by_currency[curr] = by_currency.get(curr, 0.0) + amt

        # Convert to EUR equivalent
        eur_equiv = amt
        tax_eur_equiv = tax
        if curr == "USD":
            eur_equiv = amt / rates.get("USD", 1.08)
            tax_eur_equiv = tax / rates.get("USD", 1.08)
        elif curr in ("TRY", "TL"):
            eur_equiv = amt / rates.get("TRY", 38.5)
            tax_eur_equiv = tax / rates.get("TRY", 38.5)

        total_eur += eur_equiv
        total_tax_eur += tax_eur_equiv

        by_category[cat] = by_category.get(cat, 0.0) + eur_equiv
        by_month[month_key] = by_month.get(month_key, 0.0) + eur_equiv

    data["stats"] = {
        "total_count": len(expenses),
        "total_eur_equivalent": round(total_eur, 2),
        "total_tax_eur_equivalent": round(total_tax_eur, 2),
        "by_currency": {k: round(v, 2) for k, v in by_currency.items() if v > 0},
        "by_category_eur": {k: round(v, 2) for k, v in by_category.items()},
        "by_month_eur": {k: round(v, 2) for k, v in sorted(by_month.items(), reverse=True)},
    }


def seed_historical_holded_expenses(data: Dict[str, Any]) -> int:
    """Seeds historical Q1/Q2/Q3 expenses from RM-OS Holded audit records if not already added."""
    existing_ids = {e["id"] for e in data.get("expenses", [])}
    historical = [
        {"merchant": "Codomo Living (Kira & Ofis)", "date": "2026-06-01", "amount": 414.00, "currency": "EUR", "tax": 0.0, "cat": CAT_OFFICE_LIVING, "inv": "CODOMO-2026-06"},
        {"merchant": "Codomo Living (Kira & Ofis)", "date": "2026-05-01", "amount": 414.00, "currency": "EUR", "tax": 0.0, "cat": CAT_OFFICE_LIVING, "inv": "CODOMO-2026-05"},
        {"merchant": "Codomo Living (Kira & Ofis)", "date": "2026-04-01", "amount": 414.00, "currency": "EUR", "tax": 0.0, "cat": CAT_OFFICE_LIVING, "inv": "CODOMO-2026-04"},
        {"merchant": "OpenAI / ChatGPT Plus", "date": "2026-09-12", "amount": 23.00, "currency": "EUR", "tax": 3.99, "cat": CAT_SOFTWARE_AI, "inv": "OPENAI-2026-09"},
        {"merchant": "OpenAI / ChatGPT Plus", "date": "2026-08-12", "amount": 23.00, "currency": "EUR", "tax": 3.99, "cat": CAT_SOFTWARE_AI, "inv": "OPENAI-2026-08"},
        {"merchant": "Anthropic Claude Pro", "date": "2026-09-18", "amount": 21.78, "currency": "EUR", "tax": 3.78, "cat": CAT_SOFTWARE_AI, "inv": "CLAUDE-2026-09"},
        {"merchant": "Cursor Pro (Anysphere)", "date": "2026-09-05", "amount": 20.00, "currency": "USD", "tax": 0.0, "cat": CAT_SOFTWARE_AI, "inv": "CURSOR-2026-09"},
        {"merchant": "IONOS SE (Cloud & Domain)", "date": "2026-08-15", "amount": 28.45, "currency": "EUR", "tax": 4.94, "cat": CAT_INFRA_SERVER, "inv": "IONOS-2026-08"},
        {"merchant": "Apple Developer Program & iCloud+", "date": "2026-08-20", "amount": 9.99, "currency": "EUR", "tax": 1.73, "cat": CAT_SOFTWARE_AI, "inv": "APPLE-2026-08"},
        {"merchant": "Simyo Telecom (İletişim)", "date": "2026-09-01", "amount": 14.50, "currency": "EUR", "tax": 2.52, "cat": CAT_TELECOM_HARDWARE, "inv": "SIMYO-2026-09"},
        {"merchant": "Solred Repsol (Dizel Yakıt)", "date": "2026-09-25", "amount": 62.40, "currency": "EUR", "tax": 10.83, "cat": CAT_GARAGE_FUEL, "inv": "SOLRED-2026-09-25"},
        {"merchant": "RETA / TGSS (Sosyal Güvenlik)", "date": "2026-09-30", "amount": 80.00, "currency": "EUR", "tax": 0.0, "cat": CAT_TAX_LEGAL, "inv": "TGSS-2026-09"},
        {"merchant": "Google Workspace Business", "date": "2026-09-02", "amount": 15.80, "currency": "EUR", "tax": 2.74, "cat": CAT_SOFTWARE_AI, "inv": "GSUITE-2026-09"},
        {"merchant": "BASKİ - Su Faturası", "date": "2026-09-01", "amount": 338.00, "currency": "TRY", "tax": 33.80, "cat": CAT_OFFICE_LIVING, "inv": "BASKI-40016453"},
        {"merchant": "CK Boğaziçi Elektrik", "date": "2026-09-05", "amount": 684.50, "currency": "TRY", "tax": 68.45, "cat": CAT_OFFICE_LIVING, "inv": "CK-367977182090"}
    ]

    added = 0
    for h in historical:
        h_id = f"EXP-{h['date'][:7].replace('-', '')}-{hashlib.md5(h['inv'].encode()).hexdigest()[:8].upper()}"
        if h_id in existing_ids:
            continue
        record = {
            "id": h_id,
            "date": h["date"],
            "merchant": h["merchant"],
            "category": h["cat"],
            "amount": h["amount"],
            "currency": h["currency"],
            "taxAmount": h["tax"],
            "taxRate": 21.0 if h["currency"] == "EUR" and h["tax"] > 0 else (10.0 if h["currency"] == "TRY" else 0.0),
            "paymentMethod": "Otomatik Ödeme / Kart",
            "invoiceNumber": h["inv"],
            "status": "Ödendi",
            "source": "RM-OS & Holded Kütüğü",
            "mailMessageId": "",
            "subject": f"{h['merchant']} Faturası",
            "items": [{"name": f"{h['merchant']} Hizmet Bedeli", "qty": 1, "price": h["amount"], "currency": h["currency"]}],
            "rawSnippet": f"Holded ve RM-OS mutabakatlı gider kaydı ({h['merchant']} - {h['date']})",
            "notes": "Tarihsel RM-OS muhasebe doğrulamalı gider."
        }
        data["expenses"].append(record)
        existing_ids.add(h_id)
        added += 1

    return added


def generate_thermal_slip_ascii(exp: Dict[str, Any]) -> str:
    """Formats an individual expense into an authentic thermal receipt slip."""
    w = 40
    d = exp.get("date", "2026-00-00")
    m = exp.get("merchant", "TEDARİKÇİ")[:32]
    c = exp.get("currency", "EUR")
    curr_sym = "€" if c == "EUR" else ("$" if c == "USD" else ("₺" if c in ("TRY", "TL") else c))
    amt = float(exp.get("amount", 0.0))
    tax = float(exp.get("taxAmount", 0.0))
    sub = amt - tax if amt >= tax else amt
    inv = exp.get("invoiceNumber", "N/A")[:20]
    pm = exp.get("paymentMethod", "KART")[:24]
    cat = exp.get("category", "GENEL")[:24]

    lines = [
        "- - - - - - - - - - - - - - - - - - - -",
        "         DAAK NODE FINANCIAL           ",
        "        RESMİ GİDER & MALİ FİŞ         ",
        "   LOLILE-M3  ·  GRANADA / ISTANBUL    ",
        "========================================",
        f"FİŞ NO   : {exp.get('id', 'EXP-000')}",
        f"TARİH    : {d}",
        f"BELGE NO : {inv}",
        f"KATEGORİ : {cat}",
        f"ÖDEME    : {pm}",
        "----------------------------------------",
        f"TEDARİKÇİ:\n  {m}",
        "----------------------------------------",
        "ÜRÜN / HİZMET                  TUTAR   ",
    ]

    items = exp.get("items", [])
    if items:
        for it in items:
            name = it.get("name", "Kalem")[:26]
            price = float(it.get("price", 0.0))
            lines.append(f"{name:<28}{curr_sym}{price:>8.2f}")
    else:
        lines.append(f"{m:<28}{curr_sym}{amt:>8.2f}")

    lines.extend([
        "----------------------------------------",
        f"ARA TOPLAM (NET)             {curr_sym}{sub:>8.2f}",
        f"KDV / IVA (%21)              {curr_sym}{tax:>8.2f}",
        "========================================",
        f"TOPLAM TUTAR                 {curr_sym}{amt:>8.2f}",
        "========================================",
        "                                        ",
        "        [ ✔ ÖDENDİ / MUTABIK ]          ",
        "                                        ",
        "    *** MALİ MUHASEBE ARŞİVİDİR ***     ",
        "        DAAKNODE v2.22 / RM-OS         ",
        "- - - - - - - - - - - - - - - - - - - -",
    ])
    return "\n".join(lines)


def generate_summary_slip_ascii(data: Dict[str, Any]) -> str:
    """Formats the comprehensive accounting / 'hesap veren' thermal receipt roll."""
    stats = data.get("stats", {})
    by_curr = stats.get("by_currency", {})
    by_cat = stats.get("by_category_eur", {})
    total_eur = stats.get("total_eur_equivalent", 0.0)
    tax_eur = stats.get("total_tax_eur_equivalent", 0.0)
    count = stats.get("total_count", 0)

    now = datetime.datetime.now().strftime("%d.%m.%Y %H:%M")

    lines = [
        "- - - - - - - - - - - - - - - - - - - - - - - -",
        "           DAAK KONTROL MERKEZİ                ",
        "        AYLIK RESMİ HESAP VERME RAPORU         ",
        "        NODE: LOLILE-M3  ·  KULLANICI: FIRAT   ",
        f"        TARİH & SAAT: {now}     ",
        "================================================",
        "MALİ ÖZET & HARCAMA İCMALİ                     ",
        "------------------------------------------------",
        f"KAYITLI FİŞ / FATURA ADEDİ : {count:>12}",
        f"TOPLAM NET NAKİT ÇIKIŞI    : €{total_eur:>11.2f}",
        f"TOPLAM ÖDENEN KDV / IVA    : €{tax_eur:>11.2f}",
        "------------------------------------------------",
        "PARA BİRİMLERİNE GÖRE DAĞILIM:                 ",
    ]

    for curr, amt in by_curr.items():
        sym = "€" if curr == "EUR" else ("$" if curr == "USD" else ("₺" if curr in ("TRY", "TL") else curr))
        lines.append(f"  · {curr:<8} : {sym}{amt:>14.2f}")

    lines.extend([
        "------------------------------------------------",
        "KATEGORİ BAZLI HARCAMA DAĞILIMI (EUR BAZLI):    ",
    ])

    for cat, amt in sorted(by_cat.items(), key=lambda x: x[1], reverse=True):
        pct = (amt / total_eur * 100) if total_eur > 0 else 0
        lines.append(f"  · {cat:<24} : €{amt:>8.2f} (%{pct:4.1f})")

    lines.extend([
        "================================================",
        "           [ ✔ DAAK KONSOLİDE RAPOR ]           ",
        "        TÜM KALEMLER MUTABIK VE ARŞİVDE         ",
        "        DAAK NODE v2.22.0 · RM-OS PERSIST       ",
        "- - - - - - - - - - - - - - - - - - - - - - - -",
    ])

    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description="DAAK Node Expense & Receipt Collector")
    parser.add_argument("command", choices=["scan", "list", "add", "parse-text", "slip", "summary-slip", "seed"], default="list", nargs="?")
    parser.add_argument("--limit", type=int, default=50, help="Scan limit for emails")
    parser.add_argument("--id", type=str, help="Expense ID for slip generation")
    parser.add_argument("--text", type=str, help="Raw text to parse")
    parser.add_argument("--json", action="store_true", help="Output raw JSON")

    args = parser.parse_args()
    db = load_database()

    # Always ensure baseline seed exists if database is empty
    if not db.get("expenses"):
        seed_historical_holded_expenses(db)
        save_database(db)

    if args.command == "seed":
        added = seed_historical_holded_expenses(db)
        save_database(db)
        print(f"Historical expenses seeded: {added} new records.")

    elif args.command == "scan":
        print(f"Scanning Apple Mail for new receipts and invoices (limit={args.limit})...", file=sys.stderr)
        scanned = scan_apple_mail(args.limit)
        existing_ids = {e["id"] for e in db.get("expenses", [])}
        new_added = 0
        for item in scanned:
            if item["id"] not in existing_ids:
                db["expenses"].insert(0, item)
                existing_ids.add(item["id"])
                new_added += 1

        # Also sort by date descending
        db["expenses"].sort(key=lambda x: x.get("date", ""), reverse=True)
        save_database(db)
        print(json.dumps({"ok": True, "scanned": len(scanned), "newly_added": new_added, "total": len(db["expenses"])}))

    elif args.command == "list":
        save_database(db)  # triggers recompute stats
        print(json.dumps(db, ensure_ascii=False))

    elif args.command == "slip":
        target_id = args.id
        if not target_id and db.get("expenses"):
            target_id = db["expenses"][0]["id"]
        exp = next((e for e in db.get("expenses", []) if e["id"] == target_id), None)
        if exp:
            print(generate_thermal_slip_ascii(exp))
        else:
            print(f"Expense {target_id} not found", file=sys.stderr)
            sys.exit(1)

    elif args.command == "summary-slip":
        save_database(db)
        print(generate_summary_slip_ascii(db))

    elif args.command == "parse-text":
        raw_text = args.text
        if not raw_text:
            raw_text = sys.stdin.read()
        amt, curr, vat = extract_amount_and_currency(raw_text)
        merchant, cat = infer_vendor_and_category(raw_text[:80], "Manual Entry", raw_text)
        d_val = parse_date_string(raw_text)
        inv = extract_invoice_number(raw_text)
        pm = extract_payment_method(raw_text)
        items = extract_line_items(raw_text, merchant, amt, curr)
        h = hashlib.sha256(f"{merchant}:{amt}:{curr}:{d_val}".encode()).hexdigest()[:8]

        res = {
            "id": f"EXP-{d_val[:7].replace('-', '')}-{h.upper()}",
            "date": d_val,
            "merchant": merchant,
            "category": cat,
            "amount": amt,
            "currency": curr,
            "taxAmount": vat,
            "taxRate": 21.0 if curr == "EUR" and vat > 0 else 0.0,
            "paymentMethod": pm,
            "invoiceNumber": inv if inv else f"MAN-{h.upper()}",
            "status": "Ödendi",
            "source": "Akıllı Metin Ayrıştırma",
            "items": items,
            "rawSnippet": sanitize_text(raw_text[:200]),
            "notes": "Kullanıcı tarafından yapıştırılan fatura metninden ayrıştırıldı."
        }
        print(json.dumps(res, ensure_ascii=False))


if __name__ == "__main__":
    main()
