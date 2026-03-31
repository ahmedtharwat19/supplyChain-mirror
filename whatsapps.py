# whatsapps_auto_send_wait.py
from selenium import webdriver
from selenium.webdriver.edge.service import Service
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.common.exceptions import TimeoutException
from selenium.webdriver.common.keys import Keys
import time
import urllib.parse
import os

EDGE_DRIVER_PATH = r"C:\Tools\msedgedriver.exe"
EDGE_PROFILE_PATH = r"C:\Users\ahmed.tharwat\AppData\Local\Microsoft\Edge\User Data\SeleniumProfile"

def start_driver():
    edge_options = webdriver.EdgeOptions()
    edge_options.use_chromium = True
    edge_options.add_argument(f"user-data-dir={EDGE_PROFILE_PATH}")
    edge_options.add_argument("--start-maximized")
    service = Service(EDGE_DRIVER_PATH)
    driver = webdriver.Edge(service=service, options=edge_options)
    return driver

def send_whatsapp_message(driver, phone_number, message, image_path=None):
    try:
        # افتح صفحة WhatsApp للمستخدم المحدد
        driver.get(f"https://web.whatsapp.com/send?phone={phone_number}")
        
        # انتظر حتى يتم تحميل الصفحة بشكل كامل
        time.sleep(5)
        
        # ==============================
        # الطريقة المحسنة: معالجة الصورة أولاً
        # ==============================
        if image_path and os.path.exists(image_path):
            # انتظر زر المرفقات
            attach_btn = WebDriverWait(driver, 30).until(
                EC.element_to_be_clickable((By.XPATH, '//div[@title="إرفاق"]'))
            )
            time.sleep(2)
            attach_btn.click()
            time.sleep(2)

            # ابحث عن حقل رفع الصورة
            image_input = driver.find_element(By.XPATH, '//input[@accept="image/*,video/mp4,video/3gpp,video/quicktime"]')
            image_input.send_keys(image_path)
            
            print(f"📸 تم تحميل الصورة للرقم {phone_number}")
            time.sleep(3)  # انتظر حتى يتم تحميل الصورة
            
            # اكتب الرسالة النصية بعد تحميل الصورة
            message_box = WebDriverWait(driver, 20).until(
                EC.presence_of_element_located((By.XPATH, '//div[@contenteditable="true"][@data-tab="10"]'))
            )
            time.sleep(1)
            message_box.click()
            message_box.clear()
            message_box.send_keys(message)
            time.sleep(1)
            
            # اضغط على زر الإرسال
            send_button = WebDriverWait(driver, 20).until(
                EC.element_to_be_clickable((By.XPATH, '//span[@data-icon="send"]'))
            )
            send_button.click()
            
        else:
            # إذا لم تكن هناك صورة، أرسل الرسالة النصية فقط
            encoded_message = urllib.parse.quote(message)
            driver.get(f"https://web.whatsapp.com/send?phone={phone_number}&text={encoded_message}")
            time.sleep(5)
            
            # انتظر حتى يظهر حقل الرسالة
            message_box = WebDriverWait(driver, 30).until(
                EC.presence_of_element_located((By.XPATH, '//div[@contenteditable="true"][@data-tab="10"]'))
            )
            time.sleep(2)
            
            # تأكد من وجود النص في الحقل
            message_box.click()
            message_box.clear()
            message_box.send_keys(Keys.ENTER)

        print(f"✅ تم إرسال الرسالة إلى {phone_number}")
        time.sleep(3)  # انتظر قبل الانتقال للرقم التالي

    except TimeoutException:
        print(f"❌ تعذر إرسال الرسالة للرقم {phone_number}، ربما WhatsApp لم يتم تحميله بعد.")
    except Exception as e:
        print(f"⚠️ حدث خطأ للرقم {phone_number}: {str(e)}")

def wait_for_login(driver):
    """انتظر حتى يتم تسجيل الدخول إلى WhatsApp Web"""
    print("⏳ يرجى مسح رمز QR code للدخول إلى WhatsApp Web...")
    try:
        # انتظر حتى تختفي شاشة QR code
        WebDriverWait(driver, 60).until(
            EC.invisibility_of_element_located((By.XPATH, '//div[@data-testid="qrcode"]'))
        )
        print("✅ تم تسجيل الدخول بنجاح!")
        time.sleep(3)
        return True
    except TimeoutException:
        print("❌ انتهت مهلة انتظار تسجيل الدخول")
        return False

if __name__ == "__main__":
    # أرقام الهواتف (يجب أن تحتوي على رمز الدولة)
    users = [
        "201061007999",  # تأكد من أن الرقم يحتوي على رمز الدولة
        "201234567890",
        # أضف باقي الأرقام هنا
    ]
    
    message = "مرحبا، هذه رسالة تجريبية مع انتظار التحميل!"
    image_path = r"E:\purchasing\image.jpg"  # تأكد من صحة المسار
    
    driver = start_driver()
    
    # انتظر تسجيل الدخول أولاً
    if wait_for_login(driver):
        for phone in users:
            send_whatsapp_message(driver, phone, message, image_path)
    
    input("اضغط Enter لإغلاق المتصفح...")
    driver.quit()