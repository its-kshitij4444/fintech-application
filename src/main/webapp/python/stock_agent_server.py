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
        symbol = resolve_symbol(symbol)

        yf_symbol = f"{symbol}.NS"
        ticker = yf.Ticker(yf_symbol)

        hist = ticker.history(period="5d", interval="1d", auto_adjust=False)

        if hist.empty:
            return json.dumps({"error": f"No yfinance quote for {symbol}"})

        valid_hist = hist.dropna(subset=["Close"])

        if valid_hist.empty:
            return json.dumps({"error": f"No valid close price for {symbol}"})

        latest = valid_hist.iloc[-1]

        open_price = float(latest["Open"]) if pd.notna(latest["Open"]) else None
        high_price = float(latest["High"]) if pd.notna(latest["High"]) else None
        low_price = float(latest["Low"]) if pd.notna(latest["Low"]) else None
        close_price = float(latest["Close"]) if pd.notna(latest["Close"]) else None
        volume = int(latest["Volume"]) if pd.notna(latest["Volume"]) else "N/A"

        if close_price is None:
            return json.dumps({"error": f"Invalid close price for {symbol}"})

        if open_price is not None and open_price > 0:
            change_amt = round(close_price - open_price, 2)
            change_pct = round(((close_price - open_price) / open_price) * 100, 2)
        else:
            change_amt = "N/A"
            change_pct = "N/A"

        return json.dumps({
            "symbol": symbol,
            "price": round(close_price, 2),
            "open": round(open_price, 2) if open_price is not None else "N/A",
            "high": round(high_price, 2) if high_price is not None else "N/A",
            "low": round(low_price, 2) if low_price is not None else "N/A",
            "change_amt": change_amt,
            "change_pct": change_pct,
            "volume": volume,
            "time": str(latest.name)
        })

    except Exception as e:
        return json.dumps({"error": str(e)})

# ─────────────────────────────────────────────
# SYSTEM PROMPT
# ─────────────────────────────────────────────
SYSTEM_PROMPT = """You are StockSense, an intelligent NSE/BSE stock market analyst assistant for beginners and professional traders.

Reply ONLY with a single valid JSON object. No markdown, no explanations outside the JSON, no code fences.

You help only with:
- NSE/BSE stock prices and analysis
- trading strategies and concepts
- investing, finance, and market education
- follow-up questions about the current stock discussion

IMPORTANT:
- Follow-up questions that refer to prior stock conversation are ALLOWED.
- Examples of allowed follow-ups: "What are the risks?", "Which stock did I just ask for?", "And for beginners?", "Summarize that", "Should I worry about volatility?"
- Greetings are ALLOWED and should get a short friendly finance-related reply.
- Truly unrelated topics such as sports, movies, weather, personal advice, coding, politics, jokes, or random chat must be refused.

For unrelated topics, respond ONLY with:
{"step":"OUTPUT","content":"I'm StockSense, a dedicated stock market assistant. I can help with stocks, trading strategies, market analysis, and finance topics. What would you like to know about the markets? 📊"}

STEP TYPES:

For greetings:
{"step":"OUTPUT","content":"short friendly greeting"}

For stock questions that need market data:
{"step":"TOOL","tool":"stock_data","input":"<stock name or symbol exactly as user said>"}

After receiving tool data:
{"step":"OUTPUT","content":"full analysis"}

RULES:
- ALWAYS call TOOL first for a new stock price/analysis request.
- DO NOT call TOOL for greetings, follow-up questions, or meta questions about the current stock being discussed.
- Use conversation context for follow-up questions.
- NEVER invent stock data.
- Put the stock name exactly as the user said it in TOOL input.
- US stocks are not supported; politely say so in OUTPUT JSON.
- If data is missing, skip that field gracefully.
- Output must always be exactly one valid JSON object.

ANALYSIS FORMAT inside content:
📊 [Company Name] ([SYMBOL]) — Live Analysis
━━━━━━━━━━━━━━━━━━━━━━━━━━

💰 Current Price: ₹[price]
📈 Today: Open ₹[open] | High ₹[high] | Low ₹[low] | Change [change]%

📅 52-Week Range: ₹[52w_low] → ₹[52w_high]
• Currently [X]% below 52-week high
• Currently [X]% above 52-week low

📉 30-Day Momentum: [+/-X]% — [brief explanation]

⚡ Volatility: [X]% annualised — Risk Level: [Low/Medium/High]
• [1 sentence explanation]

🎯 Risk Assessment:
• [2-3 short lines]

💡 Key Takeaway:
• For beginners: [1 line]
• For traders: [1 line]

⚠️ Disclaimer: This is not financial advice. Always do your own research.
"""


# ─────────────────────────────────────────────
# AGENT LOOP — unchanged logic, powers chat.jsp
# ─────────────────────────────────────────────
def run_agent(user_prompt, model=None, history=None):
    if model is None:
        model = LLM_MODEL

    print(f"🤖 Using model: {model}")
    messages = []

    if history and isinstance(history, list):
        for msg in history[-6:]:
            role = msg.get("role")
            content = msg.get("content", "")
            if role in ["user", "assistant"] and content:
                messages.append({"role": role, "content": content})

    if not messages or messages[-1]["role"] != "user":
        messages.append({"role": "user", "content": user_prompt})

    def extract_json_objects(text):
        objs = []
        stack = []
        start_idx = None
        in_string = False
        escape = False

        for i, ch in enumerate(text):
            if escape:
                escape = False
                continue

            if ch == '\\':
                escape = True
                continue

            if ch == '"':
                in_string = not in_string
                continue

            if in_string:
                continue

            if ch == '{':
                if not stack:
                    start_idx = i
                stack.append(ch)

            elif ch == '}':
                if stack:
                    stack.pop()
                    if not stack and start_idx is not None:
                        candidate = text[start_idx:i+1]
                        try:
                            objs.append(json.loads(candidate))
                        except:
                            pass
                        start_idx = None

        return objs

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
                reasoning_format="hidden"
            )

            raw_output = response.choices[0].message.content.strip()
            print(f"🔍 [{iteration}] RAW: {repr(raw_output)}")

            raw_output = re.sub(r'```(?:json)?\s*', '', raw_output).replace('```', '').strip()
            print(f"🔍 [{iteration}] CLEANED: {repr(raw_output)}")

            json_objects = extract_json_objects(raw_output)

            if not json_objects:
                try:
                    parsed = json.loads(raw_output)
                    json_objects = [parsed]
                except json.JSONDecodeError:
                    return raw_output[:500]

            parsed = json_objects[-1]
            print(f"📌 Iteration {iteration} | step={parsed.get('step')} | content={parsed.get('content','')[:60]}")

            step = parsed.get("step", "")
            content = parsed.get("content", "")
            tool_input = parsed.get("input", "")

            if step == "OUTPUT":
                # tool_was_called = any('"step": "TOOL"' in str(m.get("content", "")) for m in messages)
                # stock_keywords = ["price", "stock", "share", "nse", "bse", "market", "ltp"]
                # is_stock_query = any(kw in user_prompt.lower() for kw in stock_keywords)
                #
                # if is_stock_query and not tool_was_called:
                #     messages.append({"role": "assistant", "content": json.dumps(parsed)})
                #     messages.append({"role": "user", "content": "You MUST call TOOL step first!"})
                #     continue

                return content

            elif step == "TOOL":
                print(f"🔧 TOOL called with input: '{tool_input}'")
                result = stock_data(tool_input)
                print(f"📊 Tool result: {result}")

                messages.append({"role": "assistant", "content": json.dumps(parsed)})
                messages.append({
                    "role": "user",
                    "content": f'Data: {result}. Respond ONLY with valid JSON in the form {{"step":"OUTPUT","content":"..."}}'
                })

            else:
                messages.append({"role": "assistant", "content": json.dumps(parsed)})

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
        data = request.get_json() or {}
        user_message = data.get('message', '')
        model = data.get('model', 'qwen/qwen3-32b')
        history = data.get('history', [])

        if not user_message:
            return jsonify({"error": "Message required"}), 400

        reply = run_agent(user_message, model=model, history=history)
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