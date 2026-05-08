#!/usr/bin/env python3
"""
Flask server wrapper for stock agent
Handles HTTP requests from ChatServlet and getPrice.jsp
Uses ICICI BreezeConnect instead of Yahoo Finance
"""

from flask import Flask, request, jsonify
from breeze_connect import BreezeConnect
from flask_cors import CORS
from groq import Groq

import json
import os
import re
import time
import zipfile
import urllib.request
import statistics

import pandas as pd

from datetime import datetime, timedelta
from difflib import get_close_matches
from dotenv import load_dotenv

load_dotenv()

# ─────────────────────────────────────────────
# FLASK APP
# ─────────────────────────────────────────────
app = Flask(__name__)
CORS(app)

# ─────────────────────────────────────────────
# ENV VARIABLES
# ─────────────────────────────────────────────
GROQ_API_KEY = os.environ.get("GROQ_API_KEY")
LLM_MODEL = os.environ.get("LLM_MODEL", "qwen/qwen3-32b")

BREEZE_API_KEY = os.environ.get("BREEZE_API_KEY")
BREEZE_API_SECRET = os.environ.get("BREEZE_API_SECRET")

groq_client = Groq(api_key=GROQ_API_KEY)

# ─────────────────────────────────────────────
# SCRIP MASTER CONFIG
# ─────────────────────────────────────────────
SCRIP_MASTER_URL = "https://directlink.icicidirect.com/NewSecurityMaster/SecurityMaster.zip"
ZIP_PATH = "SecurityMaster.zip"

_scrip_df = None


def get_scrip_filename():
    today = datetime.now().strftime("%Y-%m-%d")
    return f"NSEScripMaster_{today}.csv"


def download_scrip_master():
    filename = get_scrip_filename()

    # Use cached today's file
    if os.path.exists(filename):
        print(f"✅ Scrip master already exists for today: {filename}")
        return filename

    # Delete old cache files
    for f in os.listdir("."):
        if f.startswith("NSEScripMaster_") and f.endswith(".csv"):
            os.remove(f)
            print(f"🗑️ Deleted old scrip master: {f}")

    print("⬇️ Downloading Security Master...")

    urllib.request.urlretrieve(SCRIP_MASTER_URL, ZIP_PATH)

    with zipfile.ZipFile(ZIP_PATH, 'r') as z:
        print("📦 ZIP CONTENTS:", z.namelist())

        # ICICI currently stores equities here
        selected_file = "NSEScripMaster.txt"

        z.extract(selected_file, ".")

        os.rename(selected_file, filename)

        print(f"📦 Extracted and renamed to: {filename}")

    os.remove(ZIP_PATH)

    print("🗑️ Deleted zip file")

    return filename


def load_scrip_master():
    global _scrip_df

    if _scrip_df is not None:
        return _scrip_df

    try:
        filename = download_scrip_master()

        df = pd.read_csv(filename, low_memory=False)

        # Clean column names
        df.columns = [
            c.strip().strip('"')
            for c in df.columns
        ]

        print("📋 Columns:", df.columns.tolist())

        # Rename required columns
        df = df.rename(columns={
            "ShortName": "stock_code",
            "CompanyName": "company_name"
        })

        # Clean values
        df["stock_code"] = (
            df["stock_code"]
            .astype(str)
            .str.upper()
            .str.strip()
        )

        df["company_name"] = (
            df["company_name"]
            .astype(str)
            .str.upper()
            .str.strip()
        )

        # Remove duplicates/nulls
        df = df.drop_duplicates(subset=["stock_code"])

        df = df.dropna(
            subset=["stock_code", "company_name"]
        )

        # Final dataframe
        _scrip_df = df[
            ["stock_code", "company_name"]
        ].reset_index(drop=True)

        print(f"✅ Scrip master loaded: {len(_scrip_df)} symbols")

    except Exception as e:
        print(f"⚠️ Could not load scrip master: {e}")

        _scrip_df = pd.DataFrame(
            columns=["stock_code", "company_name"]
        )

    return _scrip_df


# ─────────────────────────────────────────────
# SYMBOL RESOLUTION
# ─────────────────────────────────────────────
def resolve_symbol(text: str) -> str:
    df = load_scrip_master()

    if df.empty:
        return text.upper().strip()

    query = text.upper().strip()

    # Exact symbol match
    exact = df[df["stock_code"] == query]
    if not exact.empty:
        return exact.iloc[0]["stock_code"]

    # Startswith symbol
    starts = df[df["stock_code"].str.startswith(query)]
    if not starts.empty:
        return starts.iloc[0]["stock_code"]

    # Company name contains all words
    words = query.split()

    mask = df["company_name"].apply(
        lambda n: all(w in n for w in words)
    )

    contains = df[mask]

    if not contains.empty:
        return contains.iloc[0]["stock_code"]

    # Fuzzy match
    close = get_close_matches(
        query,
        df["company_name"].tolist(),
        n=1,
        cutoff=0.4
    )

    if close:
        row = df[df["company_name"] == close[0]]

        if not row.empty:
            return row.iloc[0]["stock_code"]

    # Partial word search
    for word in words:
        if len(word) < 3:
            continue

        partial = df[
            df["company_name"].str.contains(word, na=False)
        ]

        if not partial.empty:
            return partial.iloc[0]["stock_code"]

    return query


# ─────────────────────────────────────────────
# BREEZE CONFIGURATION
# ─────────────────────────────────────────────
BREEZE_SESSION = ""

breeze = BreezeConnect(api_key=BREEZE_API_KEY)

_session_initialized = False


def init_breeze_session():
    global _session_initialized

    if not _session_initialized:
        breeze.generate_session(
            api_secret=BREEZE_API_SECRET,
            session_token=BREEZE_SESSION
        )

        _session_initialized = True

        print("✅ Breeze session initialized")


# ─────────────────────────────────────────────
# STOCK DATA TOOL
# ─────────────────────────────────────────────
def stock_data(symbol: str) -> str:
    try:
        init_breeze_session()

        symbol = symbol.upper().strip()

        symbol = re.sub(
            r"\.(NS|BO|NSE|BSE)$",
            "",
            symbol
        )

        symbol = resolve_symbol(symbol)

        print(f"🔍 Resolved symbol: {symbol}")

        # Live quote
        response = breeze.get_quotes(
            stock_code=symbol,
            exchange_code="NSE",
            expiry_date="",
            product_type="cash",
            right="others",
            strike_price="0"
        )

        if not (
            response.get("Status") == 200
            and response.get("Success")
        ):
            return json.dumps({
                "error": f"No data for {symbol}"
            })

        q = response["Success"][0]

        ltp = float(q.get("ltp") or 0)

        open_price = float(q.get("open") or 0)

        # Price change
        if open_price and open_price != 0:
            change_pct = round(
                ((ltp - open_price) / open_price) * 100,
                2
            )

            change_amt = round(
                ltp - open_price,
                2
            )

        else:
            change_pct = "N/A"
            change_amt = "N/A"

        # Historical data
        to_dt = datetime.now()

        from_1y = to_dt - timedelta(days=365)

        hist_1y = breeze.get_historical_data_v2(
            interval="1day",
            from_date=from_1y.strftime("%Y-%m-%dT00:00:00.000Z"),
            to_date=to_dt.strftime("%Y-%m-%dT00:00:00.000Z"),
            stock_code=symbol,
            exchange_code="NSE",
            product_type="cash",
        )

        week52_high = None
        week52_low = None
        avg_volume = None

        daily_returns = []
        recent_closes = []

        if (
            hist_1y.get("Status") == 200
            and hist_1y.get("Success")
        ):
            closes = [
                float(c["close"])
                for c in hist_1y["Success"]
                if c.get("close")
            ]

            volumes = [
                float(c.get("volume", 0))
                for c in hist_1y["Success"]
            ]

            if closes:
                week52_high = round(max(closes), 2)
                week52_low = round(min(closes), 2)

            if volumes:
                avg_volume = round(
                    sum(volumes) / len(volumes),
                    0
                )

            recent_closes = (
                closes[-30:]
                if len(closes) >= 30
                else closes
            )

            if len(recent_closes) > 1:
                daily_returns = [
                    (
                        recent_closes[i]
                        - recent_closes[i - 1]
                    ) / recent_closes[i - 1]
                    for i in range(1, len(recent_closes))
                ]

        # Volatility
        volatility_pct = None
        risk_level = "Unknown"

        if daily_returns:
            std_daily = statistics.stdev(daily_returns)

            volatility_pct = round(
                std_daily * (252 ** 0.5) * 100,
                2
            )

            if volatility_pct < 20:
                risk_level = "Low"
            elif volatility_pct < 40:
                risk_level = "Medium"
            else:
                risk_level = "High"

        # Momentum
        momentum_pct = None

        if recent_closes and len(recent_closes) >= 2:
            momentum_pct = round(
                (
                    (ltp - recent_closes[0])
                    / recent_closes[0]
                ) * 100,
                2
            )

        # 52w positioning
        pct_from_52w_high = None
        pct_from_52w_low = None

        if week52_high and week52_low and ltp:
            pct_from_52w_high = round(
                ((ltp - week52_high) / week52_high) * 100,
                2
            )

            pct_from_52w_low = round(
                ((ltp - week52_low) / week52_low) * 100,
                2
            )

        return json.dumps({
            "symbol": symbol,
            "price": ltp,
            "open": q.get("open", "N/A"),
            "high": q.get("high", "N/A"),
            "low": q.get("low", "N/A"),
            "change_pct": change_pct,
            "change_amt": change_amt,
            "volume": q.get("total_quantity_traded", "N/A"),
            "avg_volume_30d": avg_volume,
            "week52_high": week52_high,
            "week52_low": week52_low,
            "pct_from_52w_high": pct_from_52w_high,
            "pct_from_52w_low": pct_from_52w_low,
            "volatility_pct": volatility_pct,
            "risk_level": risk_level,
            "momentum_30d_pct": momentum_pct,
            "time": q.get("last_update_time", "N/A"),
        })

    except Exception as e:
        return json.dumps({"error": str(e)})


# ─────────────────────────────────────────────
# ROUTES
# ─────────────────────────────────────────────
@app.route('/quote', methods=['GET'])
def quote():
    try:
        stock_code = request.args.get(
            'stock_code',
            ''
        ).upper().strip()

        exchange_code = request.args.get(
            'exchange_code',
            'NSE'
        ).upper().strip()

        if not stock_code:
            return jsonify({
                "error": "stock_code is required"
            }), 400

        init_breeze_session()

        response = breeze.get_quotes(
            stock_code=stock_code,
            exchange_code=exchange_code,
            expiry_date="",
            product_type="cash",
            right="others",
            strike_price="0"
        )

        if (
            response.get("Status") == 200
            and response.get("Success")
        ):
            q = response["Success"][0]

            return jsonify({
                "symbol": stock_code,
                "ltp": q.get("ltp", "N/A"),
                "open": q.get("open", "N/A"),
                "high": q.get("high", "N/A"),
                "low": q.get("low", "N/A"),
                "change": q.get("ltp_change", "N/A"),
                "change%": q.get("ltp_change_percentage", "N/A"),
                "volume": q.get("total_quantity_traded", "N/A"),
                "time": q.get("last_update_time", "N/A"),
                "exchange": exchange_code,
            })

        return jsonify({
            "error": response.get(
                "Error",
                "No data returned"
            )
        }), 500

    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route('/scrip-list', methods=['GET'])
def scrip_list():
    try:
        df = load_scrip_master()

        result = df.to_dict(orient="records")

        print(f"✅ Returning {len(result)} stocks")

        return jsonify(result)

    except Exception as e:
        print("❌ Scrip list error:", e)

        return jsonify({
            "error": str(e)
        }), 500

@app.route('/history', methods=['GET'])
def history():
    """Serves OHLC history for Plotly candlestick chart in stockChart.js"""
    from datetime import datetime, timedelta
    try:
        stock_code = request.args.get("stock_code", "").upper().strip()
        exchange_code = request.args.get("exchange_code", "NSE").upper().strip()
        days = int(request.args.get("days", 1))

        if not stock_code:
            return jsonify({"error": "stock_code required"}), 400

        init_breeze_session()

        to_dt = datetime.now()
        from_dt = to_dt - timedelta(days=days)
        interval = "1minute" if days <= 1 else ("5minute" if days <= 5 else "1day")

        resp = breeze.get_historical_data_v2(
            interval=interval,
            from_date=from_dt.strftime("%Y-%m-%dT%H:%M:%S.000Z"),
            to_date=to_dt.strftime("%Y-%m-%dT%H:%M:%S.000Z"),
            stock_code=stock_code,
            exchange_code=exchange_code,
            product_type="cash",
        )

        if resp.get("Status") == 200 and resp.get("Success"):
            return jsonify(resp["Success"])

        return jsonify({"error": resp.get("Error", "No data")}), 500

    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route('/init-session', methods=['POST'])
def reinit_session():
    global BREEZE_SESSION
    global _session_initialized

    body = request.get_json() or {}

    new_token = body.get("session_token", "")

    print(f"🔑 Flask received token: [{new_token}]")

    if not new_token:
        return jsonify({
            "error": "session_token required"
        }), 400

    BREEZE_SESSION = new_token

    _session_initialized = False

    init_breeze_session()

    return jsonify({
        "status": "Session reinitialized"
    })


@app.route('/health', methods=['GET'])
def health():
    return jsonify({
        "status": "ok",
        "session_ready": _session_initialized
    })


print("\n========== ROUTES ==========")

for rule in app.url_map.iter_rules():
    print(rule)

print("============================\n")

# ─────────────────────────────────────────────
# MAIN
# ─────────────────────────────────────────────
if __name__ == '__main__':
    port = int(os.environ.get("PORT", 5000))

    print(f"🚀 Starting Stock Agent Server on port {port}")

    app.run(
        host='0.0.0.0',
        port=port,
        debug=False
    )