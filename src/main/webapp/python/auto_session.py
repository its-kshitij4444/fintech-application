from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.chrome.options import Options
import pyotp
import urllib.parse
import time
import env_variables
import platform

import os
from dotenv import load_dotenv
load_dotenv()

API_KEY = os.environ.get("BREEZE_API_KEY")
ICICI_USER = os.environ.get("ICICI_USER")
ICICI_PASS = os.environ.get("ICICI_PASS")
TOTP_SECRET = os.environ.get("TOTP_SECRET") # explained below

def get_session_token() -> str:
    options = Options()
    # ❌ Keep headless OFF while debugging so you can see the browser
    options.add_argument("--headless=new")
    options.add_argument("--no-sandbox")
    options.add_argument("--disable-dev-shm-usage")
    options.add_argument("--disable-gpu")
    options.add_argument("--window-size=1920,1080")

    if platform.system() == "Linux":
        options.binary_location = "/usr/bin/google-chrome"

    driver = webdriver.Chrome(options=options)
    wait = WebDriverWait(driver, 20)

    login_url = "https://api.icicidirect.com/apiuser/login?api_key=" + urllib.parse.quote(API_KEY)
    driver.get(login_url)

    # print(f"[1] After page load → URL: {driver.current_url}")
    # print(f"[1] Page title: {driver.title}")

    # Enter User ID
    wait.until(EC.presence_of_element_located((By.ID, "txtuid"))).send_keys(ICICI_USER)
    # print(f"[2] After entering User ID → URL: {driver.current_url}")

    # Enter Password (with wait)
    wait.until(EC.presence_of_element_located((By.ID, "txtPass"))).send_keys(ICICI_PASS)
    # print(f"[3] After entering Password → URL: {driver.current_url}")
    
     # ✅ Check the T&C checkbox before submitting
    checkbox = wait.until(EC.presence_of_element_located((By.ID, "chkssTnc")))
    if not checkbox.is_selected():
        checkbox.click()
    # print(f"[3b] Checkbox clicked → checked: {checkbox.is_selected()}")


    # Click Login
    wait.until(EC.element_to_be_clickable((By.ID, "btnSubmit"))).click()
    # print(f"[4] After clicking Login → URL: {driver.current_url}")

    # Enter TOTP
    totp = pyotp.TOTP(TOTP_SECRET)
    otp_now = totp.now()
    # print(f"[5] Generated OTP: {otp_now}")
    # ✅ Wait for the first OTP box to appear
    wait.until(EC.presence_of_element_located((By.CSS_SELECTOR, "input[tg-nm='otp']")))

    # Get all 6 OTP boxes in order
    otp_boxes = driver.find_elements(By.CSS_SELECTOR, "input[tg-nm='otp']")
    # print(f"[5b] Found {len(otp_boxes)} OTP input boxes")

    # Type one digit into each box
    for i, digit in enumerate(otp_now):
        otp_boxes[i].send_keys(digit)

    print(f"[5c] OTP entered successfully")
    wait.until(EC.element_to_be_clickable((By.ID, "Button1"))).click()
    # print(f"[6] After clicking Verify → URL: {driver.current_url}")

    # Wait for redirect
    time.sleep(5)
    redirect_url = driver.current_url
    # print(f"[7] Final redirect URL: {redirect_url}")

    # Parse all query params so you can see everything in the URL
    parsed = urllib.parse.urlparse(redirect_url)
    params = urllib.parse.parse_qs(parsed.query)
    # print(f"[8] All URL params: {params}")

    driver.quit()

    token = params.get("apisession", [None])[0]
    if not token:
        raise Exception(f"Could not extract session token. Full URL was: {redirect_url}")

    #print(f"✅ Session token: {token[:10]}...")
    return token

if __name__ == "__main__":
    token = get_session_token()
    print(token)