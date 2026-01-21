import json
import sys

from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.common.by import By
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.support.ui import Select, WebDriverWait


def get_url():
    options = Options()
    options.add_argument("--headless=new")  # Modern headless mode
    options.add_argument("--no-sandbox")  # Required for many Linux environments
    options.add_argument("--disable-dev-shm-usage")  # Overcomes limited resource issues

    # Create a service object that points to a log file
    service = Service(log_output="webdriver.log")

    driver = webdriver.Chrome(options=options, service=service)

    try:
        driver.get("https://www.microsoft.com/software-download/windows11")

        # 1. Select the Edition
        select_element = WebDriverWait(driver, 10).until(
            EC.presence_of_element_located((By.ID, "product-edition"))
        )
        select = Select(select_element)
        # Usually the first option is the multi-edition ISO
        select.select_by_index(1)

        # 2. Click the first Download button
        submit_btn = driver.find_element(By.ID, "submit-product-edition")
        submit_btn.click()

        # 3. WAIT for the language dropdown to actually contain options
        # Sometimes the element exists but is empty while loading
        WebDriverWait(driver, 15).until(
            lambda d: len(Select(d.find_element(By.ID, "product-languages")).options)
            > 1
        )

        lang_select_el = driver.find_element(By.ID, "product-languages")
        select = Select(lang_select_el)

        # Loop through options and find one that CONTAINS "English"
        # This avoids issues with hidden characters or "United States" vs "US"
        found = False
        for option in select.options:
            if "English" in option.text:
                select.select_by_visible_text(option.text)
                found = True
                break

        if not found:
            raise Exception("Could not find an English language option in the dropdown")

        # 4. Click the final Confirm button
        confirm_btn = WebDriverWait(driver, 10).until(
            EC.element_to_be_clickable((By.ID, "submit-sku"))
        )
        confirm_btn.click()

        # 5. Extract the 64-bit Download Link
        download_btn = WebDriverWait(driver, 20).until(
            EC.presence_of_element_located(
                (By.XPATH, "//a[contains(normalize-space(.), '64-bit')]")
            )
        )

        final_url = download_btn.get_attribute("href")
        print(json.dumps({"url": final_url}))
        return final_url
    except Exception as e:
        sys.stderr.write(f"Scraper Error: {str(e)}\n")
        # Take a screenshot for GH Actions debugging
        driver.save_screenshot("error_state.png")
        sys.exit(1)

    finally:
        driver.quit()


if __name__ == "__main__":
    try:
        url = get_url()
        # Terraform expects a JSON map of strings
        print(json.dumps({"url": url}))
    except Exception as e:
        sys.stderr.write(str(e))
        sys.exit(1)
