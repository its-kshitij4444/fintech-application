#!/usr/bin/env python3
"""
Flask server wrapper for stock agent
Handles HTTP requests from ChatServlet
"""

from flask import Flask, request, jsonify
import json
import requests
import time
import re
import ollama
from datetime import datetime

app = Flask(__name__)

def stock_data(symbol: str):
    """Fetch stock price from Yahoo Finance"""
    try:
        headers = {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        }
        url = f"https://query1.finance.yahoo.com/v8/finance/chart/{symbol}?interval=1m&range=1d"
        time.sleep(0.5)
        response = requests.get(url, headers=headers, timeout=10)

        if response.status_code == 200:
            data = response.json()
            if 'chart' in data and 'result' in data['chart'] and data['chart']['result']:
                result = data['chart']['result'][0]
                meta = result['meta']

                timestamp = meta.get('regularMarketTime', 0)
                formatted_time = datetime.fromtimestamp(timestamp).strftime('%Y-%m-%d %H:%M:%S') if timestamp else "N/A"

                price = meta.get('regularMarketPrice', 'N/A')
                open_p = meta.get('regularMarketOpen', 'N/A')
                high = meta.get('regularMarketDayHigh', 'N/A')
                low = meta.get('regularMarketDayLow', 'N/A')

                return json.dumps({
                    "symbol": symbol,
                    "price": price,
                    "open": open_p,
                    "high": high,
                    "low": low,
                    "time": formatted_time,
                })
        return json.dumps({"error": "Unable to fetch data"})
    except Exception as e:
        return json.dumps({"error": str(e)})

SYSTEM_PROMPT = """Reply ONLY with one JSON object. No extra text before or after.

Greetings/general chat:
{"step": "OUTPUT", "content": "Hello! How can I help you?"}

Stock price request:
{"step": "TOOL", "tool": "stock_data", "input": "SYMBOL"}

Rules:
- Indian stocks: TCS→TCS.NS, RELIANCE→RELIANCE.NS, INFY→INFY.NS
- US stocks: GOOGLE→GOOG, APPLE→AAPL, MICROSOFT→MSFT
- Never guess prices, never use .US or .NYSE suffixes
- After tool data is given, reply: {"step": "OUTPUT", "content": "Price is X"}"""


def run_agent(user_prompt):
    """Run stock market agent with Mistral"""
    messages = [{"role": "user", "content": user_prompt}]

    for iteration in range(6):
        try:
            print(f"📨 [{iteration}] Messages sent: {[m['role']+':'+m['content'][:40] for m in messages]}")
            response = ollama.chat(
                model="gemma2:2b",
                messages=[
                    {"role": "system", "content": SYSTEM_PROMPT},
                    *messages
                ],
                stream=False,
            )

            raw_output = response['message']['content'].strip()
            print(f"🔍 [{iteration}] RAW: {repr(raw_output)}")
            raw_output = re.sub(r'```(?:json)?\s*', '', raw_output).strip().replace('```', '')
            raw_output = re.sub(r'\}+$', '}', raw_output)
            print(f"🔍 [{iteration}] CLEANED: {repr(raw_output)}")
            
            
            # Extract first JSON object
            match = re.search(r'\{.*?\}', raw_output, re.DOTALL)
            if match:
                raw_output = match.group(0)

            # Parse JSON
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
            tool = parsed.get("tool", "")
            tool_input = parsed.get("input", "")

            if step == "OUTPUT":
                # Check if TOOL was called
                tool_was_called = any("TOOL" in str(m) for m in messages)
                stock_keywords = ["price", "stock", "share", "nse", "bse", "market", ".ns"]
                is_stock_query = any(kw in user_prompt.lower() for kw in stock_keywords)
                if is_stock_query and not tool_was_called:
                    messages.append({"role": "assistant", "content": raw_output})
                    messages.append({
                        "role": "user", 
                        "content": 'You MUST call TOOL step first!'
                    })
                    continue
                else:
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

@app.route('/chat', methods=['POST'])
def chat():
    """Handle chat requests from ChatServlet"""
    try:
        data = request.get_json()
        user_message = data.get('message', '')
        
        print(f"📥 Received message: {user_message}")  # ADD THIS
        
        if not user_message:
            return jsonify({"error": "Message required"}), 400
        
        # Run agent
        reply = run_agent(user_message)
        print(f"📤 Sending reply: {reply}")  # ADD THIS
        
        return jsonify({"reply": reply})
    
    except Exception as e:
        print(f"❌ Error: {e}")
        import traceback
        traceback.print_exc()  # ADD THIS for full stack trace
        return jsonify({"error": str(e)}), 500


if __name__ == '__main__':
    print("Starting Stock Agent Server on http://localhost:5000")
    app.run(host='0.0.0.0', port=5000, debug=False)
