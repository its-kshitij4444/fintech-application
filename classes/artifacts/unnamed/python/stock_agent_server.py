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

import yfinance as yf
import pytz
from datetime import datetime


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

def stock_data_yfinance(symbol: str) -> str:
    """Returns latest quote data from yfinance in a format compatible with /quote."""
    try:
        symbol = symbol.upper().strip()
        symbol = re.sub(r"\.(NS|BO|NSE|BSE)$", "", symbol)

        yf_symbol = f"{symbol}.NS"
        ticker = yf.Ticker(yf_symbol)

        hist = ticker.history(period="2d", interval="1d")

        if hist.empty:
            return json.dumps({"error": f"No yfinance quote for {symbol}"})

        latest = hist.iloc[-1]

        open_price = float(latest["Open"]) if pd.notna(latest["Open"]) else 0
        high_price = float(latest["High"]) if pd.notna(latest["High"]) else 0
        low_price  = float(latest["Low"]) if pd.notna(latest["Low"]) else 0
        close_price = float(latest["Close"]) if pd.notna(latest["Close"]) else 0
        volume = int(latest["Volume"]) if pd.notna(latest["Volume"]) else 0

        if open_price:
            change_amt = round(close_price - open_price, 2)
            change_pct = round(((close_price - open_price) / open_price) * 100, 2)
        else:
            change_amt = "N/A"
            change_pct = "N/A"

        time_str = str(hist.index[-1])

        return json.dumps({
            "symbol": symbol,
            "price": round(close_price, 2),
            "open": round(open_price, 2),
            "high": round(high_price, 2),
            "low": round(low_price, 2),
            "change_amt": change_amt,
            "change_pct": change_pct,
            "volume": volume,
            "time": time_str
        })

    except Exception as e:
        return json.dumps({"error": str(e)})

# ─────────────────────────────────────────────
# SYSTEM PROMPT
# ─────────────────────────────────────────────
SYSTEM_PROMPT = """You are StockSense, an intelligent NSE stock market analyst assistant designed for both beginners and professional traders. You always fetch live data before answering any stock-related question.

Reply ONLY with a single JSON object. No extra text, no markdown, no explanation outside the JSON.

─── STRICT BOUNDARIES (NON-NEGOTIABLE) ───
You are ONLY a stock market and trading assistant. You exist solely to help users with:
- NSE/BSE stock prices and analysis
- Trading strategies and concepts
- Market education for beginners and professionals
- Risk management and finance

You MUST REFUSE any message that is not related to stocks, trading, finance, or investing.
For ANY off-topic message — sports, movies, weather, personal advice, coding, general chat — respond ONLY with:
{"step": "OUTPUT", "content": "I'm StockSense, a dedicated stock market assistant. I can only help with stocks, trading strategies, market analysis, and finance topics. What would you like to know about the markets? 📊"}

NEVER deviate from this. NEVER call the TOOL for non-stock messages.
NEVER treat a random word as a stock symbol unless the user explicitly asks for its price or analysis.

─── STEP TYPES ───

For greetings / general chat:
{"step": "OUTPUT", "content": "your reply"}

To fetch stock data (ALWAYS do this first for any stock question):
{"step": "TOOL", "tool": "stock_data", "input": "<name or symbol exactly as user said>"}

After receiving tool data — produce a rich analysis:
{"step": "OUTPUT", "content": "your full analysis here"}

─── ANALYSIS FORMAT (after tool data) ───

Structure your response like this (plain text, no JSON inside content):

📊 [Company Name] ([SYMBOL]) — Live Analysis
━━━━━━━━━━━━━━━━━━━━━━━━━━

💰 Current Price: ₹[price]
📈 Today: Open ₹[open] | High ₹[high] | Low ₹[low] | Change [change]%

📅 52-Week Range: ₹[52w_low] → ₹[52w_high]
   • Currently [X]% below 52-week high
   • Currently [X]% above 52-week low

📉 30-Day Momentum: [+/-X]% — [briefly explain what this means]

⚡ Volatility: [X]% annualised — Risk Level: [Low/Medium/High]
   • [1 sentence explaining what this means for the user]

🎯 Risk Assessment:
   • [2-3 sentences: is it risky to buy NOW based on volatility + momentum + 52w position?]
   • [Mention if near 52w high = stretched, near 52w low = potential value or falling knife]
   • [Mention if momentum is positive or negative]

💡 Key Takeaway:
   • For beginners: [simple 1-sentence advice]
   • For traders: [technical 1-sentence insight]

⚠️ Disclaimer: This is not financial advice. Always do your own research.

─── RULES ───
- ALWAYS call the TOOL first before any stock analysis — never guess or fabricate data
- Put the stock name EXACTLY as the user said it in "input"
- US stocks are NOT supported — inform the user politely
- If data is missing (N/A), skip that field gracefully
- Increase max_tokens is set to 1024 so use the full format above
"""


# ─────────────────────────────────────────────
# AGENT LOOP — unchanged logic, powers chat.jsp
# ─────────────────────────────────────────────
def run_agent(user_prompt, model=None):
    if model is None:
        model = LLM_MODEL
    print(f"🤖 Using model: {model}")
    messages = [{"role": "user", "content": user_prompt}]

    for iteration in range(6):
        try:
            print(f"📨 [{iteration}] Messages sent: {[m['role']+':'+m['content'][:40] for m in messages]}")
            response = groq_client.chat.completions.create(
                model=model,
                messages=[
                    {"role": "system", "content": SYSTEM_PROMPT},
                    *messages
                ],
                temperature=0.1,
                max_tokens=1024,
                stream=False,
            )
            raw_output = response.choices[0].message.content.strip()
            print(f"🔍 [{iteration}] RAW: {repr(raw_output)}")
            raw_output = re.sub(r'```(?:json)?\s*', '', raw_output).strip().replace('```', '')
            raw_output = re.sub(r'\}+$', '}', raw_output)
            print(f"🔍 [{iteration}] CLEANED: {repr(raw_output)}")

            match = re.search(r'\{.*?\}', raw_output, re.DOTALL)
            if match:
                raw_output = match.group(0)

            json_objects = []
            buffer = ""
            for line in raw_output.split('\n'):
                buffer += line
                try:
                    json_obj = json.loads(buffer)
                    json_objects.append(json_obj)
                    buffer = ""
                except:
                    pass

            if not json_objects:
                try:
                    obj = json.loads(raw_output)
                    json_objects.append(obj)
                except json.JSONDecodeError:
                    return "❌ Failed to parse response"

            if not json_objects:
                break

            parsed = json_objects[0]
            print(f"📌 Iteration {iteration} | step={parsed.get('step')} | content={parsed.get('content','')[:60]}")

            step = parsed.get("step", "")
            content = parsed.get("content", "")
            tool_input = parsed.get("input", "")

            if step == "OUTPUT":
                tool_was_called = any("TOOL" in str(m) for m in messages)
                stock_keywords = ["price", "stock", "share", "nse", "bse", "market", "ltp"]
                is_stock_query = any(kw in user_prompt.lower() for kw in stock_keywords)
                if is_stock_query and not tool_was_called:
                    messages.append({"role": "assistant", "content": raw_output})
                    messages.append({"role": "user", "content": "You MUST call TOOL step first!"})
                    continue
                return content

            elif step == "TOOL":
                print(f"🔧 TOOL called with input: '{tool_input}'")
                result = stock_data(tool_input)
                print(f"📊 Tool result: {result}")
                messages.append({"role": "assistant", "content": raw_output})
                messages.append({
                    "role": "user",
                    "content": f'Data: {result}. Respond with: {{"step": "OUTPUT", "content": "..."}}'
                })

            else:
                messages.append({"role": "assistant", "content": raw_output})

        except Exception as e:
            print(f"💥 EXCEPTION at iteration {iteration}: {repr(e)}")
            return f"❌ Error: {str(e)}"

    return "Unable to get response from agent"

# ─────────────────────────────────────────────
# ROUTES
# ─────────────────────────────────────────────


# Used by ChatServlet → chat.jsp
@app.route('/chat', methods=['POST'])
def chat():
    try:
        data = request.get_json()
        user_message = data.get('message', '')
        model = data.get('model', 'qwen/qwen3-32b')  # ← read model

        if not user_message:
            return jsonify({"error": "Message required"}), 400

        reply = run_agent(user_message, model=model)  # ← pass to agent
        return jsonify({"reply": reply})
    except Exception as e:
        return jsonify({"error": str(e)}), 500

IST = pytz.timezone("Asia/Kolkata")
def is_market_open() -> bool:
    now = datetime.now(IST)
    market_open  = now.replace(hour=9,  minute=15, second=0, microsecond=0)
    market_close = now.replace(hour=15, minute=30, second=0, microsecond=0)
    return now.weekday() < 5 and market_open <= now <= market_close

@app.route('/quote', methods=['GET'])
def quote():
    try:
        stock_code    = request.args.get('stock_code', '').upper().strip()
        exchange_code = request.args.get('exchange_code', 'NSE').upper().strip()

        if not stock_code:
            return jsonify({"error": "stock_code is required"}), 400

        if not is_market_open():
            # ── OFF HOURS → yfinance ──────────────────────────────
            print(f"🕐 Market closed — yfinance for {stock_code}")
            raw = json.loads(stock_data_yfinance(stock_code))
            if "error" in raw:
                return jsonify(raw), 500
            return jsonify({
                "symbol":   stock_code,
                "ltp":      raw["price"],
                "open":     raw["open"],
                "high":     raw["high"],
                "low":      raw["low"],
                "change":   raw["change_amt"],
                "change%":  raw["change_pct"],
                "volume":   raw["volume"],
                "time":     raw["time"],
                "exchange": exchange_code,
                "source":   "yfinance (market closed)"
            })

        # ── MARKET HOURS → Breeze ─────────────────────────────────
        init_breeze_session()
        response = breeze.get_quotes(
            stock_code=stock_code,
            exchange_code=exchange_code,
            expiry_date="",
            product_type="cash",
            right="others",
            strike_price="0"
        )
        if response.get("Status") == 200 and response.get("Success"):
            q = response["Success"][0]
            return jsonify({
                "symbol":   stock_code,
                "ltp":      q.get("ltp", "N/A"),
                "open":     q.get("open", "N/A"),
                "high":     q.get("high", "N/A"),
                "low":      q.get("low", "N/A"),
                "change":   q.get("ltp_change", "N/A"),
                "change%":  q.get("ltp_change_percentage", "N/A"),
                "volume":   q.get("total_quantity_traded", "N/A"),
                "time":     q.get("last_update_time", "N/A"),
                "exchange": exchange_code,
                "source":   "breeze (live)"
            })
        return jsonify({"error": response.get("Error", "No data")}), 500

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
    try:
        stock_code    = request.args.get("stock_code", "").upper().strip()
        exchange_code = request.args.get("exchange_code", "NSE").upper().strip()
        days          = int(request.args.get("days", 1))

        if not stock_code:
            return jsonify({"error": "stock_code required"}), 400

        if not is_market_open():
            # ── OFF HOURS → yfinance OHLC history ────────────────
            print(f"🕐 Market closed — yfinance history for {stock_code}")
            return get_history_yfinance(stock_code, days)

        # ── MARKET HOURS → Breeze ─────────────────────────────────
        init_breeze_session()
        to_dt   = datetime.now()
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


def get_history_yfinance(symbol: str, days: int):
    """Returns OHLC history from yfinance in same format as Breeze."""
    try:
        yf_symbol = f"{symbol}.NS"
        ticker    = yf.Ticker(yf_symbol)

        # Match interval logic to Breeze
        if days <= 1:
            hist     = ticker.history(period="1d", interval="1m")
        elif days <= 5:
            hist     = ticker.history(period="5d", interval="5m")
        else:
            hist     = ticker.history(period="1mo", interval="1d")

        if hist.empty:
            return jsonify({"error": f"No yfinance history for {symbol}"}), 500

        rows = []
        for dt, row in hist.iterrows():
            rows.append({
                "datetime": str(dt),
                "open":     round(float(row["Open"]),   2),
                "high":     round(float(row["High"]),   2),
                "low":      round(float(row["Low"]),    2),
                "close":    round(float(row["Close"]),  2),
                "volume":   int(row["Volume"]),
                "source":   "yfinance"
            })

        return jsonify(rows)

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


# print("\n========== ROUTES ==========")
#
# for rule in app.url_map.iter_rules():
#     print(rule)
#
# print("============================\n")

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