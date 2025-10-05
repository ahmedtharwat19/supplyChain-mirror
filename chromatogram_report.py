# 📁 chromatogram_report_multi_peaks.py

import streamlit as st
import matplotlib.pyplot as plt
import pandas as pd
import numpy as np
from fpdf import FPDF
import datetime
import random
from fpdf.enums import XPos, YPos


# ======= رسم الكروموتوجرام لعدة ذُرى =======
def draw_chromatogram_multi(peaks, filename="chromatogram.png"):
    time = [i / 10 for i in range(0, 260)]
    signal = [0] * len(time)

    for peak in peaks:
        for i, t in enumerate(time):
            peak_signal = peak['height'] * np.exp(-((t - peak['ret_time']) ** 2) / (2 * 0.3 ** 2))
            signal[i] += peak_signal

    plt.figure(figsize=(12, 4))
    plt.plot(time, signal, color='black', linewidth=1)

    for peak in peaks:
        plt.annotate(
            f"{peak['ret_time']:.3f} min - {peak['component_name']}",
            xy=(peak['ret_time'], peak['height']),
            xytext=(peak['ret_time'] + 1, peak['height'] + peak['height'] * 0.2),
            arrowprops=dict(facecolor='black', arrowstyle="->"),
            fontsize=9
        )

    plt.title("Range from 0.0 min. to 26.0 min.", loc='left')
    plt.xlabel("Time (min)")
    plt.ylabel("Signal (mV)")
    plt.xlim(0, 26)
    plt.ylim(0, max(signal) + max(signal) * 0.5)
    plt.grid(False)
    ax = plt.gca()
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)

    plt.tight_layout()
    plt.savefig(filename, dpi=300)
    plt.close()

fid_number = random.randint(1, 3)

def multi_line_cell(pdf, w, h, txt, border=0, align='C'):
    # تقسيم النص حسب '\n'
    lines = txt.split('\n')
    line_height = h / len(lines)
    x = pdf.get_x()
    y = pdf.get_y()

    for i, line in enumerate(lines):
        pdf.set_xy(x, y + i*line_height)
        pdf.cell(w, line_height, line, border=0, align=align)

    # رسم حدود الخلية حول كامل المساحة فقط إذا كان border=1
    if border == 1:
        pdf.rect(x, y, w, h)

    pdf.set_xy(x + w, y)  # تحريك المؤشر بعد الخلية


# ======= توليد تقرير PDF =======
def generate_pdf(sample_name, analyst_name, component_name, df, run_number, batch_number):
    pdf = FPDF()
    pdf.add_page()
    
    # إضافة الخطوط بدون معلمة uni (تم إزالتها في الإصدارات الحديثة)
    pdf.add_font('DejaVu', '', 'DejaVuSans.ttf')
    pdf.add_font('DejaVu', 'B', 'DejaVuSans-Bold.ttf')
    pdf.add_font('DejaVu', 'I', 'DejaVuSans-Oblique.ttf')

    pdf.set_font('DejaVu', 'B', 16)
    pdf.cell(0, 10, "ANALYSIS REPORT", new_x=XPos.LMARGIN, new_y=YPos.NEXT, align='C')

    pdf.set_font('DejaVu', '', 9)
    pdf.ln(3)

    
    sample_number = run_number
    now = datetime.datetime.now()
    analysis_date = now.strftime('%Y-%m-%d %H:%M:%S')
    
    instrument = "Chromatec-Crystal 9000  S/N: 691424  Firmware version: v 03.21.17.703"
    method = f"{component_name}_method.chrx"

    pdf.cell(0, 6, f"Analyst: {analyst_name}", new_x=XPos.LMARGIN, new_y=YPos.NEXT)
    pdf.cell(0, 6, f"Chromatogram: №{sample_number} {analysis_date} FID-{fid_number}", new_x=XPos.LMARGIN, new_y=YPos.NEXT)
    pdf.cell(0, 6, f"Instrument: {instrument}", new_x=XPos.LMARGIN, new_y=YPos.NEXT)
    pdf.cell(0, 6, f"Method: {method}", new_x=XPos.LMARGIN, new_y=YPos.NEXT)
    pdf.cell(0, 6, f"Sample Name: {sample_name}", new_x=XPos.LMARGIN, new_y=YPos.NEXT)
    pdf.cell(0, 6, f"Batch No.: {batch_number}", new_x=XPos.LMARGIN, new_y=YPos.NEXT)
    pdf.cell(0, 6, f"Sample Volume: 1.0 µL", new_x=XPos.LMARGIN, new_y=YPos.NEXT)
    pdf.cell(0, 6, f"Dilution: 1:1", new_x=XPos.LMARGIN, new_y=YPos.NEXT)
    pdf.cell(0, 6, f"Column: HP-INNOWAX 30m x 0.25mm x 0.25µm", new_x=XPos.LMARGIN, new_y=YPos.NEXT)
    pdf.cell(0, 6, f"Comments: {component_name} analysis", new_x=XPos.LMARGIN, new_y=YPos.NEXT)

    pdf.ln()
    pdf.set_font('DejaVu', 'B', 12)
    pdf.cell(0, 10, "Chromatogram:", new_x=XPos.LMARGIN, new_y=YPos.NEXT)
    pdf.cell(0, 9, f"FID-{fid_number}", new_x=XPos.LMARGIN, new_y=YPos.NEXT)
    y_pos = pdf.get_y()
    pdf.image("chromatogram.png", x=10, y=y_pos, w=180, h=70)
    pdf.set_line_width(0.3)
    pdf.rect(x=10, y=y_pos, w=180, h=70)


    pdf.ln(75)
    # قسم نتائج الحساب
    pdf.set_font('DejaVu', 'B', 12)
    pdf.cell(0, 8, "Calculation result", new_x=XPos.LMARGIN, new_y=YPos.NEXT)
   
    pdf.ln(2)
    
    # جدول النتائج
    column_widths = [60, 25, 25, 25, 25, 25]

    # رسم خط أفقي فوق الـ headers
    current_y = pdf.get_y()
    pdf.set_draw_color(0, 0, 0)
    pdf.set_line_width(0.3)
    pdf.line(10, current_y, 200, current_y)
    pdf.ln(2)

    # رأس الجدول - بدون حدود
    pdf.set_font('DejaVu', 'B', 9)
    headers = ["Component", "Ret. time\n(min)", "Area\n(mV*s)", "Height\n(mV)", "Concentration\nUnit", "Detector"]
    
    header_height = 8  # ارتفاع الخلية لتقسيمها لسطرين
    for i, header in enumerate(headers):
        # استخدام new_x بدلاً من ln
            if i == len(column_widths) - 1:  # آخر خلية في الصف
                #pdf.cell(width, 8, value, border=0, align='C', new_x=XPos.LMARGIN, new_y=YPos.NEXT)
                multi_line_cell(pdf, column_widths[i], header_height, header, border=0, align='C')
            else:
                #pdf.cell(width, 8, value, border=0, align='L', new_x=XPos.RIGHT, new_y=YPos.TOP)
                multi_line_cell(pdf, column_widths[i], header_height, header, border=0, align='L')
    pdf.ln(header_height)

    # رسم خط أفقي تحت الـ headers وفوق البيانات
    current_y = pdf.get_y()
    pdf.set_draw_color(0, 0, 0)
    pdf.set_line_width(0.3)
    pdf.line(10, current_y, 200, current_y)
    pdf.ln(2)

    # بيانات الجدول - مع حدود
    pdf.set_font('DejaVu', '', 9)
    for index, row in df.iterrows():
        for i, width in enumerate(column_widths):
            if i == 0:  # Component
                value = str(row["Component"])
            elif i == 1:  # Ret. time
                value = f"{float(row['Ret. time (min)']):.3f}"
            elif i == 2:  # Area
                value = f"{float(row['Area (mV*s)']):.1f}"
            elif i == 3:  # Height
                value = f"{float(row['Height (mV)']):.1f}"
            elif i == 4:  # Concentration
                value = f"{float(row['Concentration (uL)']):.3f}"
            elif i == 5:  # Detector
                value = str(row["Detector"])
            
            # استخدام new_x بدلاً من ln
            if i == len(column_widths) - 1:  # آخر خلية في الصف
                pdf.cell(width, 8, value, border=0, align='C', new_x=XPos.LMARGIN, new_y=YPos.NEXT)
            else:
                pdf.cell(width, 8, value, border=0, align='L', new_x=XPos.RIGHT, new_y=YPos.TOP)
        
        # رسم خط منقط بعد كل صف من البيانات
        if index < len(df) - 1:  # لا نرسم خط بعد آخر صف
            current_y = pdf.get_y()
            pdf.set_draw_color(0, 0, 0)
            pdf.set_line_width(0.2)
            
            # رسم خط منقط يدوياً
            dash_length = 0.5
            gap_length = 0.5
            x_start = 10
            x_end = 200
            x = x_start
            
            while x < x_end:
                pdf.line(x, current_y, min(x + dash_length, x_end), current_y)
                x += dash_length + gap_length
            
            pdf.ln(1)

    # رسم خط أفقي في الأسفل بعد آخر صف
    current_y = pdf.get_y()
    pdf.set_draw_color(0, 0, 0)
    pdf.set_line_width(0.3)
    pdf.line(10, current_y, 200, current_y)

    # خط أفقي في الأسفل
    pdf.set_y(-26)
    pdf.set_draw_color(0, 0, 0)
    pdf.set_line_width(0.5)
    pdf.line(10, pdf.get_y(), 200, pdf.get_y())
    pdf.ln(0)

    # تذييل الصفحة
    pdf.set_font('DejaVu', 'I', 6)
    pdf.cell(0, 3, f"Analyst: {analyst_name}", new_x=XPos.RIGHT, new_y=YPos.TOP)
    pdf.cell(0, 3, "Page 1 of 1", new_x=XPos.LMARGIN, new_y=YPos.NEXT, align='R')
    pdf.cell(0, 3, f"Report: {analysis_date}", new_x=XPos.LMARGIN, new_y=YPos.NEXT)

    output_path = f"{component_name}_{sample_name.replace(' ', '_')}.pdf"
    pdf.output(output_path)
    return output_path
# ======= واجهة Streamlit =======
st.set_page_config(page_title="تقرير كروموتوجرام متعدد الذُرى", layout="centered")
st.title("🧪 إنشاء تقرير تحليل يحتوي على عدة ذُرى (Peaks)")

with st.form("analysis_form"):
    st.subheader("📥 بيانات العينة")
    sample_name = st.text_input("اسم العينة", "Quebracho cortex fluid extract")
    analyst_name = st.text_input("اسم المحلل", "Reda Said")
    run_number = st.text_input("رقم التشغيل", "001")
    batch_number = st.text_input("رقم التشغيله", "001")

    st.subheader("📊 جدول البيانات التحليلية")

    default_data = pd.DataFrame([
        {"Component": "Ethanol", "Ret. time (min)": 10.013, "Area (mV*s)": 715.252,
         "Height (mV)": 189.692, "Concentration (uL)": 77.164, "Detector": "FID-1"},
        {"Component": "Ethanol", "Ret. time (min)": 10.099, "Area (mV*s)": 211.675,
         "Height (mV)": 56.571, "Concentration (uL)": 22.836, "Detector": "FID-1"},
    ])

    # استخدام width='stretch' بدلاً من use_container_width=True
    df = st.data_editor(default_data, num_rows="dynamic", width='stretch')

    submitted = st.form_submit_button("✅ إنشاء التقرير")

if submitted:
    # تحديث عمود "Detector" تلقائيًا
    df["Detector"] = f"FID-{fid_number}"

    # استخراج القمم لرسمها
    peaks = []
    for _, row in df.iterrows():
        peaks.append({
            "ret_time": float(row["Ret. time (min)"]),
            "height": float(row["Height (mV)"]),
            "component_name": str(row["Component"])
        })

    # رسم الكروموتوجرام
    draw_chromatogram_multi(peaks)

    # اسم المكون الأول فقط للملف
    component_name = df.iloc[0]["Component"]
    pdf_path = generate_pdf(sample_name, analyst_name, component_name, df, run_number, batch_number)

    st.success("📄 تم إنشاء التقرير بنجاح!")
    with open(pdf_path, "rb") as f:
        st.download_button(
            label="📥 تحميل تقرير PDF",
            data=f,
            file_name=pdf_path,
            mime="application/pdf"
        )