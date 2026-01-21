import json
import sys
import time

from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.by import By
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.support.ui import Select, WebDriverWait


def get_url():
    options = Options()
    options.add_argument("--headless=new")
    options.add_argument("--no-sandbox")
    options.add_argument("--disable-dev-shm-usage")
    options.add_argument("--window-size=1920,1080")
    options.add_argument(
        "user-agent=Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36"
    )

    driver = webdriver.Chrome(options=options)

    try:
        driver.get("https://www.microsoft.com/software-download/windows11")

        # 1. Select Edition
        edition_dropdown = WebDriverWait(driver, 20).until(
            EC.element_to_be_clickable((By.ID, "product-edition"))
        )
        Select(edition_dropdown).select_by_index(1)

        # Click the first 'Download' button
        driver.find_element(By.ID, "submit-product-edition").click()

        # 2. Select Language
        # Wait for the language dropdown to appear AND have options
        lang_el = WebDriverWait(driver, 20).until(
            EC.visibility_of_element_located((By.ID, "product-languages"))
        )

        # Give the AJAX a moment to populate the list
        time.sleep(2)
        lang_select = Select(lang_el)

        # Match "English" but avoid "International" if possible
        target_text = ""
        for option in lang_select.options:
            if "English" in option.text and "International" not in option.text:
                target_text = option.text
                break

        if target_text:
            lang_select.select_by_visible_text(target_text)
        else:
            lang_select.select_by_index(1)  # Fallback to first available lang

        # 3. Click the 'Confirm' button (ID is submit-sku)
        confirm_btn = WebDriverWait(driver, 20).until(
            EC.element_to_be_clickable((By.ID, "submit-sku"))
        )
        confirm_btn.click()

        # 4. Get the 64-bit Link
        download_link = WebDriverWait(driver, 20).until(
            EC.presence_of_element_located(
                (By.XPATH, "//a[contains(normalize-space(.), '64-bit')]")
            )
        )

        return download_link.get_attribute("href")

    except Exception as e:
        # Save a screenshot inside the container for debugging if it fails
        driver.save_screenshot("debug_error.png")
        raise e
    finally:
        driver.quit()


if __name__ == "__main__":
    try:
        url = get_url()
        print(json.dumps({"url": url}))
    except Exception as e:
        print(json.dumps({"error": str(e)}))
        sys.exit(1)
