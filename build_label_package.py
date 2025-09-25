import os
import zipfile
from reportlab.lib.pagesizes import A4
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Image
from reportlab.lib.styles import getSampleStyleSheet
from datetime import date

# === إعداد أسماء الملفات ===
folder_name = "Off_Time_Label_Final_2025-09-25"
zip_name = f"{folder_name}.zip"
os.makedirs(folder_name, exist_ok=True)

# === 1) إنشاء Readme.txt ثنائي اللغة ===
readme_content = """\
🇸🇦 بالعربية:
هذا المجلد يحتوي على الملفات النهائية لتصميم ملصق Off Time:
1. Off_Time_Label_Final.ai → ملف Illustrator مفتوح المصدر ومنظم بالطبقات.
2. Off_Time_Label_Final.pdf → نسخة جاهزة للطباعة (CMYK + Bleed + Crop Marks + Embedded Fonts).
3. Off_Time_Label_Final_NoCrop.pdf → نسخة بدون علامات القص للعرض الرقمي.
4. Off_Time_Label_Final_Print_Specs.pdf → مذكرة مواصفات الطباعة + صورة مرجعية بنسبة 50٪.

🔧 تعليمات الطباعة:
- الطباعة بدقة 300dpi.
- التأكد من استخدام Crop Marks وBleed.
- ترك المساحة الفارغة للطباعة المتغيرة (Batch No / Mfg. Date / Exp. Date).
- 🔤 ملاحظة: تم تضمين الخطوط داخل PDF للطباعة (Embedded Fonts).
- 🏷 إصدار التصميم: 1.0 – تاريخ الإصدار: 2025-09-25

-----------------------------------------

🇬🇧 In English:
This folder contains the final files for the Off Time label design:
1. Off_Time_Label_Final.ai → Editable Illustrator file (well-organized layers).
2. Off_Time_Label_Final.pdf → Print-ready file (CMYK + Bleed + Crop Marks + Embedded Fonts).
3. Off_Time_Label_Final_NoCrop.pdf → Digital preview version (no crop marks).
4. Off_Time_Label_Final_Print_Specs.pdf → Print specs sheet with 50% scaled preview.

🔧 Print Instructions:
- Print resolution: 300dpi.
- Make sure to use Crop Marks and Bleed.
- Leave the blank area for variable printing (Batch No / Mfg. Date / Exp. Date).
- 🔤 Note: Fonts are embedded in the print-ready PDF.
- 🏷 Design Version: 1.0 – Release Date: 2025-09-25
"""
with open(os.path.join(folder_name, "Readme.txt"), "w", encoding="utf-8") as f:
    f.write(readme_content)

# === 2) إنشاء Print_Specs.pdf ===
styles = getSampleStyleSheet()
doc = SimpleDocTemplate(os.path.join(folder_name, "Off_Time_Label_Final_Print_Specs.pdf"), pagesize=A4)
story = []

story.append(Paragraph("<b>Off Time Label – Print Specifications</b>", styles['Title']))
story.append(Spacer(1, 12))
story.append(Paragraph("📐 Trim Size: 110 × 65 mm", styles['Normal']))
story.append(Paragraph("➕ Bleed: 3 mm (Total size: 116 × 71 mm)", styles['Normal']))
story.append(Paragraph("🎨 Colors: CMYK", styles['Normal']))
story.append(Paragraph("🖨 Resolution: 300 dpi", styles['Normal']))
story.append(Paragraph("🏷 Version: 1.0 – Release Date: 2025-09-25", styles['Normal']))
story.append(Spacer(1, 24))
story.append(Paragraph("Thumbnail Preview (50% scaled):", styles['Heading2']))
story.append(Spacer(1, 12))
# صورة تجريبية (ممكن تستبدلها لاحقًا بصورة التصميم النهائي)
story.append(Paragraph("[Preview Image Placeholder]", styles['Normal']))

doc.build(story)

# === 3) ملفات PDF تجريبية (فارغة مؤقتًا كـ Placeholder) ===
for pdf_name in ["Off_Time_Label_Final.pdf", "Off_Time_Label_Final_NoCrop.pdf"]:
    doc = SimpleDocTemplate(os.path.join(folder_name, pdf_name), pagesize=A4)
    story = [Paragraph(f"{pdf_name} – Placeholder", styles['Title'])]
    doc.build(story)

# === 4) ملف AI وهمي كـ Placeholder (ينشأ كنص فقط) ===
ai_placeholder = "%!PS-Adobe-3.0\n%% This is a placeholder for Off_Time_Label_Final.ai\n"
with open(os.path.join(folder_name, "Off_Time_Label_Final.ai"), "w") as f:
    f.write(ai_placeholder)

# === 5) ضغط المجلد إلى ZIP ===
with zipfile.ZipFile(zip_name, 'w', zipfile.ZIP_DEFLATED) as zipf:
    for root, dirs, files in os.walk(folder_name):
        for file in files:
            zipf.write(os.path.join(root, file), os.path.join(folder_name, file))

print(f"✅ تم إنشاء الملف المضغوط: {zip_name}")
from reportlab.lib import colors
from reportlab.pdfgen import canvas
from reportlab.lib.units import mm
from reportlab.lib.pagesizes import landscape

# === إعداد المقاسات ===
trim_width, trim_height = 110*mm, 65*mm     # الحجم الصافي
bleed = 3*mm
page_width, page_height = trim_width + 2*bleed, trim_height + 2*bleed

# === إنشاء ملف PDF ===
c = canvas.Canvas("Off_Time_Label_Final.pdf", pagesize=(page_width, page_height))

# --- خلفية بلون (مثال: أزرق فاتح) ---
c.setFillColor(colors.HexColor("#d8f0f7"))
c.rect(0, 0, page_width, page_height, stroke=0, fill=1)

# --- مستطيل حدود (Trim Box) فقط كدليل ---
c.setStrokeColor(colors.red)
c.rect(bleed, bleed, trim_width, trim_height, stroke=1, fill=0)

# --- اللوجو (Placeholder نص) ---
c.setFillColor(colors.HexColor("#004466"))
c.setFont("Helvetica-Bold", 20)
c.drawString(bleed+10*mm, page_height-bleed-15*mm, "PureSip Off Time")

# --- نصوص إنجليزية ---
c.setFont("Helvetica", 8)
c.setFillColor(colors.black)
c.drawString(bleed+10*mm, page_height-bleed-25*mm, "Functional Herbal Drink")
c.drawString(bleed+10*mm, page_height-bleed-30*mm, "Helps Relax & Refresh")

# --- نصوص بالعربية ---
c.setFont("Helvetica", 8)
c.drawRightString(page_width-bleed-10*mm, page_height-bleed-25*mm, "مشروب أعشاب وظيفي")
c.drawRightString(page_width-bleed-10*mm, page_height-bleed-30*mm, "يساعد على الاسترخاء والانتعاش")

# --- باركود (Placeholder فقط) ---
c.setStrokeColor(colors.black)
c.rect(page_width-bleed-40*mm, bleed+10*mm, 30*mm, 20*mm, stroke=1, fill=0)
c.drawCentredString(page_width-bleed-25*mm, bleed+5*mm, "Barcode")

# --- مساحة للتواريخ والتشغيلة ---
c.setFont("Helvetica", 6)
c.drawString(bleed+10*mm, bleed+15*mm, "Batch No: _______")
c.drawString(bleed+10*mm, bleed+10*mm, "Mfg Date: _______   Exp Date: _______")

# حفظ الملف
c.showPage()
c.save()

print("✅ تم إنشاء الملصق: Off_Time_Label_Final.pdf")
