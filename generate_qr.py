import qrcode

# بيانات Hosny Abd-Elghafar بدون العنوان
data = """BEGIN:VCARD
VERSION:3.0
N:Abd-Elghafar;Hosny
FN:Hosny Abd-Elghafar
TITLE:Supply Chain Manager
TEL;TYPE=CELL:+201022401666
EMAIL:purchasing@gisipharmagroup.com
END:VCARD"""

# إنشاء كود QR
qr = qrcode.QRCode(
    version=1,
    error_correction=qrcode.constants.ERROR_CORRECT_L,
    box_size=10,
    border=4,
)

qr.add_data(data)
qr.make(fit=True)

# حفظ الصورة
img = qr.make_image(fill_color="black", back_color="white")
img.save("hosny_qr.png")

print("✅ تم إنشاء ملف QR باسم hosny_qr.png")


import pandas as pd

# -------------------------------
# 1️⃣ تعريف التركيبة الأساسية
# -------------------------------
composition = {
    'المادة الخام': [
        'Distilled Water', 'Ethanol 96%', 'Propylene Glycol', 'Vegetable Glycerin', 
        'Polysorbate 20', 'Aloe Vera Extract', 'Panthenol', 'Preservatives (Benzoate + Sorbate)',
        'Chocolate Fragrance', 'Vanilla Fragrance', 'Tonka Bean Fragrance', 'White Flowers', 'White Musk'
    ],
    'النسبة (%)': [
        61, 25, 3, 1.5, 2, 0.5, 0.3, 0.2,
        30/80*8, 12/80*8, 6/80*8, 24/80*8, 8/80*8
    ]
}

df = pd.DataFrame(composition)

# -------------------------------
# 2️⃣ دالة احترافية لحساب الكميات
# -------------------------------
def calculate_quantities(num_bottles: int, bottle_volume_ml: float):
    """
    تحسب كمية كل مادة باللتر والمل حسب عدد الزجاجات وحجم كل زجاجة
    :param num_bottles: عدد الزجاجات
    :param bottle_volume_ml: حجم الزجاجة بالمل
    :return: DataFrame مع كمية كل مادة
    """
    total_volume_liters = num_bottles * bottle_volume_ml / 1000  # تحويل مل إلى لتر
    df_result = df.copy()
    df_result['كمية المادة (لتر)'] = df_result['النسبة (%)'] / 100 * total_volume_liters
    df_result['كمية المادة (مل)'] = df_result['كمية المادة (لتر)'] * 1000
    return df_result, total_volume_liters

# -------------------------------
# 3️⃣ مثال استخدام
# -------------------------------
if __name__ == "__main__":
    # إدخال المستخدم
    num_bottles = int(input("أدخل عدد الزجاجات: "))
    bottle_volume_ml = float(input("أدخل حجم الزجاجة بالمل: "))

    df_final, total_volume = calculate_quantities(num_bottles, bottle_volume_ml)
    
    # حفظ الملف
    output_file = f'Body_Splash_Chocolate_{num_bottles}_bottles.xlsx'
    df_final.to_excel(output_file, index=False)
    
    print(f"\n✅ تم حساب الكميات! الحجم الإجمالي: {total_volume:.2f} لتر")
    print(f"✅ تم حفظ الملف في: {output_file}")
    print("\nPreview:")
    print(df_final)
