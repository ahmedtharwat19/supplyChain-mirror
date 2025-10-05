# 📁 professional_chromatogram_analyzer.py

import streamlit as st
import matplotlib.pyplot as plt
import pandas as pd
import numpy as np
from fpdf import FPDF
import datetime
import random
from fpdf.enums import XPos, YPos
import os
import socket

class ProfessionalChromatogramAnalyzer:
    def __init__(self):
        self.fid_number = random.randint(1, 3)
        self.run_time = random.randint(10, 45)  # وقت تشغيل عشوائي بين 10-45 دقيقة
        
        # توليد تواريخ عشوائية
        self.generate_random_dates()
        
    def generate_random_dates(self):
        """توليد تواريخ عشوائية للتحليل"""
        # تاريخ التحليل عشوائي في الأشهر الـ6 الماضية
        days_ago_acquired = random.randint(1, 180)
        self.acquired_date = datetime.datetime.now() - datetime.timedelta(days=days_ago_acquired)
        
        # تاريخ المعالجة بعد ساعات عشوائية من التحليل (ليس أيام)
        hours_ago_processed = random.randint(1, 24)  # معالجة بعد 1-24 ساعة من التحليل
        self.processed_date = self.acquired_date + datetime.timedelta(hours=hours_ago_processed)
        
    def draw_chromatogram(self, peaks, sample_name, filename="chromatogram.png"):
        """رسم كروموتوجرام احترافي مع مؤشرات على القمم"""
        time = np.arange(0, self.run_time + 0.1, 0.1)
        signal = np.zeros_like(time)
        
        # رسم منحنى أساسي مع ضوضاء خفيفة
        baseline = 5 * np.exp(-time / 10)  # خط أساس متناقص
        noise = np.random.normal(0, 0.5, len(time))  # ضوضاء عشوائية
        signal = baseline + noise
        
        # إضافة القمم
        for peak in peaks:
            peak_signal = peak['height'] * np.exp(-((time - peak['ret_time']) ** 2) / (2 * 0.05 ** 2))
            signal += peak_signal
        
        plt.figure(figsize=(10, 4))
        plt.plot(time, signal, color='#2E86AB', linewidth=1.5, label='Signal')
        
        # إضافة مؤشرات على القمم
        for peak in peaks:
            # رسم خط عمودي عند وقت الاحتفاظ
            plt.axvline(x=peak['ret_time'], color='red', linestyle='--', alpha=0.7, linewidth=1)
            
            # رسم نقطة عند القمة
            peak_index = np.argmin(np.abs(time - peak['ret_time']))
            peak_value = signal[peak_index]
            plt.plot(peak['ret_time'], peak_value, 'ro', markersize=6, markeredgecolor='red', markerfacecolor='yellow')
            
            # إضافة نص للمؤشر
            plt.annotate(
                f"{peak['component_name']}\n({peak['ret_time']:.3f} min)",
                xy=(peak['ret_time'], peak_value),
                xytext=(peak['ret_time'] + 0.5, peak_value + peak['height'] * 0.1),
                arrowprops=dict(
                    facecolor='red',
                    arrowstyle='->',
                    connectionstyle='arc3,rad=0.1',
                    alpha=0.7
                ),
                fontsize=8,
                ha='left',
                bbox=dict(boxstyle="round,pad=0.3", facecolor='lightyellow', alpha=0.8),
                color='darkred'
            )
        
        plt.title(f"Chromatogram - {sample_name}", fontsize=12, fontweight='bold', pad=15)
        plt.xlabel("Time (min)", fontsize=10)
        plt.ylabel("Signal (mV)", fontsize=10)
        plt.xlim(0, self.run_time)
        plt.ylim(0, max(signal) + max(signal) * 0.3)
        plt.grid(True, alpha=0.3)
        plt.legend(loc='upper right', fontsize=8)
        plt.tight_layout()
        plt.savefig(filename, dpi=200, bbox_inches='tight')
        plt.close()
    
    def create_sample_info_table(self, pdf, sample_data):
        """إنشاء جدول معلومات العينة بشكل مضغوط"""
        pdf.set_font('Arial', 'B', 11)
        pdf.cell(0, 8, "SAMPLE INFORMATION", new_x=XPos.LMARGIN, new_y=YPos.NEXT, align='C')
        pdf.ln(3)
        
        # جدول معلومات العينة - مضغوط
        col_width = 40
        
        pdf.set_font('Arial', '', 8)
        
        # صفوف الجدول
        rows = [
            ["Sample Name:", sample_data['sample_name'][:20], "Acquired By:", sample_data['analyst']],
            ["Sample Type:", sample_data.get('sample_type', 'Unknown'), "Batch No:", sample_data.get('batch_number', 'N/A')],
            ["Injection #:", sample_data.get('injection_number', '1'), "Method:", sample_data['method']],
            ["Inj. Volume:", sample_data.get('injection_volume', '1.0 µL'), "Detector:", f"FID-{self.fid_number}"],
            ["Run Time:", f"{self.run_time} min", "Column:", "HP-INNOWAX"]
        ]
        
        for row in rows:
            pdf.cell(col_width, 5, row[0], border=1)
            pdf.cell(col_width, 5, row[1], border=1)
            pdf.cell(col_width, 5, row[2], border=1)
            pdf.cell(col_width, 5, row[3], border=1, new_x=XPos.LMARGIN, new_y=YPos.NEXT)
        
        pdf.ln(3)
        
        # معلومات التاريخ العشوائية
        pdf.set_font('Arial', 'I', 7)
        pdf.cell(0, 4, f"Acquired: {self.acquired_date.strftime('%d-%b-%y %H:%M')}", new_x=XPos.LMARGIN, new_y=YPos.NEXT)
        pdf.cell(0, 4, f"Processed: {self.processed_date.strftime('%d-%b-%y %H:%M')}", new_x=XPos.LMARGIN, new_y=YPos.NEXT)
        
        # إضافة معلومات نطاق الوقت
        pdf.cell(0, 4, f"Range: 0.0 to {self.run_time}.0 min", new_x=XPos.LMARGIN, new_y=YPos.NEXT)
        
        pdf.ln(5)
    
    def create_calculation_table(self, pdf, df):
        """إنشاء جدول النتائج الحسابية بشكل مضغوط"""
        pdf.set_font('Arial', 'B', 10)
        pdf.cell(0, 8, "CALCULATION RESULTS", new_x=XPos.LMARGIN, new_y=YPos.NEXT, align='L')
        pdf.ln(2)
        
        # رسم خط أفقي فوق الجدول
        current_y = pdf.get_y()
        pdf.set_draw_color(0, 0, 0)
        pdf.set_line_width(0.3)
        pdf.line(10, current_y, 200, current_y)
        pdf.ln(1)
        
        # رأس الجدول - مضغوط
        column_widths = [25, 20, 20, 20, 25, 20]
        headers = ["Component", "RT (min)", "Area", "Height", "Conc.", "Detector"]
        
        pdf.set_font('Arial', 'B', 7)
        for i, header in enumerate(headers):
            if i == len(headers) - 1:
                pdf.cell(column_widths[i], 6, header, border='B', align='C', new_x=XPos.LMARGIN, new_y=YPos.NEXT)
            else:
                pdf.cell(column_widths[i], 6, header, border='B', align='C', new_x=XPos.RIGHT, new_y=YPos.TOP)
        
        # بيانات الجدول
        pdf.set_font('Arial', '', 7)
        for index, row in df.iterrows():
            for i, width in enumerate(column_widths):
                if i == 0:  # Component
                    value = str(row["Component"])
                elif i == 1:  # Ret. time
                    value = f"{float(row['Ret. time (min)']):.3f}"
                elif i == 2:  # Area
                    value = f"{float(row['Area (mV*s)']):.0f}"
                elif i == 3:  # Height
                    value = f"{float(row['Height (mV)']):.0f}"
                elif i == 4:  # Concentration
                    value = f"{float(row['Concentration (uL)']):.1f}"
                elif i == 5:  # Detector
                    value = f"FID-{self.fid_number}"
                
                if i == len(column_widths) - 1:
                    pdf.cell(width, 5, value, border='B', align='C', new_x=XPos.LMARGIN, new_y=YPos.NEXT)
                else:
                    pdf.cell(width, 5, value, border='B', align='C', new_x=XPos.RIGHT, new_y=YPos.TOP)
    
    def add_footer(self, pdf, sample_data):
        """إضافة تذييل الصفحة"""
        pdf.set_y(-25)
        pdf.set_draw_color(0, 0, 0)
        pdf.set_line_width(0.3)
        pdf.line(10, pdf.get_y(), 200, pdf.get_y())
        pdf.ln(0)

        pdf.set_font('Arial', 'I', 6)
        
        now = datetime.datetime.now()
        footer_text = f"Reported by: {sample_data['analyst']} | {sample_data['sample_name']} | {now.strftime('%d-%b-%y %H:%M')} | Page 1/1"
        pdf.cell(0, 4, footer_text, new_x=XPos.LMARGIN, new_y=YPos.NEXT, align='C')
    
    def generate_comprehensive_report(self, sample_data, df, output_path):
        """توليد تقرير شامل في صفحة واحدة"""
        pdf = FPDF()
        pdf.add_page()
        
        # استخدام الخطوط الافتراضية بدلاً من DejaVu
        # العنوان الرئيسي
        pdf.set_font('Arial', 'B', 14)
        pdf.cell(0, 10, "ANALYSIS REPORT", new_x=XPos.LMARGIN, new_y=YPos.NEXT, align='C')
        pdf.ln(5)
        
        # معلومات العينة
        self.create_sample_info_table(pdf, sample_data)
        
        # قسم الكروموتوجرام
        pdf.set_font('Arial', 'B', 10)
        pdf.cell(0, 6, "CHROMATOGRAM", new_x=XPos.LMARGIN, new_y=YPos.NEXT)
        
        pdf.set_font('Arial', '', 8)
        pdf.cell(0, 4, f"FID-{self.fid_number} - Range: 0.0 to {self.run_time}.0 min", new_x=XPos.LMARGIN, new_y=YPos.NEXT)
        
        # خط أفقي
        current_y = pdf.get_y()
        pdf.set_draw_color(0, 0, 0)
        pdf.set_line_width(0.2)
        pdf.line(10, current_y + 1, 200, current_y + 1)
        pdf.ln(3)
        
        # إضافة صورة الكروموتوجرام بحجم أصغر
        if os.path.exists("chromatogram.png"):
            pdf.image("chromatogram.png", x=15, w=170, h=60)  # حجم أصغر
        
        pdf.ln(5)
        
        # جدول النتائج
        self.create_calculation_table(pdf, df)
        
        # إضافة التذييل
        self.add_footer(pdf, sample_data)
        
        pdf.output(output_path)
        return output_path

def generate_retention_times(num_peaks, run_time, peak_names):
    """توليد أوقات احتفاظ بفروق أجزاء من الثانية (ثواني)"""
    retention_times = []
    
    # أول قمة بين 1-3 دقائق
    first_time = random.uniform(1, 3)
    retention_times.append(round(first_time, 3))
    
    # القمم التالية بفروق 2 إلى 30 ثانية (0.033 إلى 0.5 دقيقة)
    for i in range(1, num_peaks):
        # فرق زمني عشوائي بين 2-30 ثانية
        time_diff_seconds = random.uniform(2, 30)
        time_diff_minutes = time_diff_seconds / 60  # تحويل الثواني إلى دقائق
        
        next_time = retention_times[-1] + time_diff_minutes
        
        # التأكد من أن الوقت لا يتجاوز وقت التشغيل
        if next_time < run_time - 0.5:
            retention_times.append(round(next_time, 3))
        else:
            break
    
    return retention_times

def get_local_ip():
    """الحصول على عنوان IP المحلي للجهاز"""
    try:
        # إنشاء اتصال مؤقت للحصول على IP
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip_address = s.getsockname()[0]
        s.close()
        return ip_address
    except:
        return "localhost"

def main():
    st.set_page_config(
        page_title="Professional Chromatogram Analyzer",
        page_icon="🧪",
        layout="wide",
        initial_sidebar_state="expanded"
    )
    
    # الحصول على عنوان IP للوصول من الموبايل
    local_ip = get_local_ip()
    
    st.title("🧪 Professional Chromatogram Analyzer")
    st.markdown("### Generate Comprehensive Analysis Reports")
    
    # عرض معلومات الوصول من الموبايل
    with st.sidebar:
        st.header("📱 Mobile Access")
        st.info(f"**URL:** http://{local_ip}:8501")
        st.info("**Instructions:**\n- Connect phone to same WiFi\n- Open browser and enter the URL above")
        st.markdown("---")
        
        st.header("⚙️ Configuration")
        
        st.subheader("Sample Information")
        sample_name = st.text_input("Sample Name", "Quebracho cortex fluid extract")
        analyst_name = st.text_input("Analyst Name", "Reda Said")
        batch_number = st.text_input("Batch Number", "929219")
        sample_type = st.selectbox("Sample Type", ["Unknown", "Standard", "Test", "Quality Control"])
        injection_number = st.number_input("Injection Number", min_value=1, max_value=100, value=1)
        vial_number = st.number_input("Vial Number", min_value=1, max_value=100, value=25)
        
        st.markdown("---")
        st.subheader("Analysis Parameters")
        injection_volume = st.text_input("Injection Volume", "1.0 µL")
        num_peaks = st.slider("Number of Peaks", min_value=1, max_value=5, value=2)
        
        # إدخال أسماء الـ Peaks
        st.subheader("Peak Names")
        peak_names = []
        for i in range(num_peaks):
            default_name = f"Peak {i+1}"
            peak_name = st.text_input(f"Peak {i+1} Name", value=default_name, key=f"peak_{i}")
            peak_names.append(peak_name)
    
    # إنشاء المحلل
    if 'analyzer' not in st.session_state:
        st.session_state.analyzer = ProfessionalChromatogramAnalyzer()
    
    analyzer = st.session_state.analyzer
    
    # عرض المعلومات العشوائية
    with st.sidebar:
        st.markdown("---")
        st.subheader("🎲 Random Settings")
        st.info(f"**FID:** {analyzer.fid_number}")
        st.info(f"**Run Time:** {analyzer.run_time} minutes")
        st.info(f"**Acquired:** {analyzer.acquired_date.strftime('%d-%b-%y %H:%M')}")
        st.info(f"**Processed:** {analyzer.processed_date.strftime('%d-%b-%y %H:%M')}")
        st.info(f"**Range:** 0.0 to {analyzer.run_time}.0 min")
    
    # القسم الرئيسي
    col1, col2 = st.columns([2, 1])
    
    with col1:
        st.subheader("📊 Analytical Data Table")
        
        # توليد أوقات احتفاظ بفروق أجزاء من الثانية (ثواني)
        retention_times = generate_retention_times(num_peaks, analyzer.run_time, peak_names)
        
        # إنشاء البيانات الافتراضية
        default_data = []
        for i, (rt, peak_name) in enumerate(zip(retention_times, peak_names)):
            default_data.append({
                "Component": peak_name, 
                "Ret. time (min)": rt, 
                "Area (mV*s)": random.randint(100000, 500000),
                "Height (mV)": random.randint(50000, 200000), 
                "Concentration (uL)": round(random.uniform(10, 90), 1), 
                "Detector": f"FID-{analyzer.fid_number}"
            })
        
        df = pd.DataFrame(default_data)
        
        # محرر البيانات مع إمكانية تعديل أسماء الـ Peaks
        edited_df = st.data_editor(
            df, 
            num_rows="dynamic", 
            width='stretch',
            column_config={
                "Component": st.column_config.TextColumn("Component", width="medium"),
                "Ret. time (min)": st.column_config.NumberColumn("Ret. Time (min)", format="%.3f"),
                "Area (mV*s)": st.column_config.NumberColumn("Area (mV*s)", format="%.0f"),
                "Height (mV)": st.column_config.NumberColumn("Height (mV)", format="%.0f"),
                "Concentration (uL)": st.column_config.NumberColumn("Concentration (uL)", format="%.1f"),
                "Detector": st.column_config.TextColumn("Detector", width="small")
            },
            key="data_editor"
        )
    
    with col2:
        st.subheader("📈 Preview")
        
        # معاينة البيانات
        if not edited_df.empty:
            st.dataframe(edited_df.style.format({
                'Ret. time (min)': '{:.3f}',
                'Area (mV*s)': '{:.0f}',
                'Height (mV)': '{:.0f}',
                'Concentration (uL)': '{:.1f}'
            }), width='stretch')
            
            # إحصائيات سريعة
            st.metric("Total Peaks", len(edited_df))
            if len(edited_df) > 0:
                avg_rt = edited_df['Ret. time (min)'].mean()
                st.metric("Avg Retention Time", f"{avg_rt:.3f} min")
                st.metric("Total Area", f"{edited_df['Area (mV*s)'].sum():,.0f} mV*s")
                st.metric("Run Time", f"{analyzer.run_time} min")
                
                # عرض الفروق بين القمم بالثواني
                if len(edited_df) > 1:
                    time_diffs_seconds = []
                    rts = sorted(edited_df['Ret. time (min)'].tolist())
                    for i in range(1, len(rts)):
                        diff_minutes = rts[i] - rts[i-1]
                        diff_seconds = diff_minutes * 60  # تحويل الدقائق إلى ثواني
                        time_diffs_seconds.append(f"{diff_seconds:.1f}s")
                    
                    st.metric("Time Differences", ", ".join(time_diffs_seconds))
    
    # زر إنشاء التقرير
    if st.button("🚀 Generate Comprehensive Report", type="primary", use_container_width=True):
        with st.spinner("Generating professional report..."):
            try:
                # الحصول على اسم المكون للـ method
                component_name = "Sample" if edited_df.empty else edited_df.iloc[0]["Component"]
                
                # تحضير البيانات
                sample_data = {
                    'sample_name': sample_name,
                    'analyst': analyst_name,
                    'batch_number': batch_number,
                    'sample_type': sample_type,
                    'injection_number': str(injection_number),
                    'vial': str(vial_number),
                    'injection_volume': injection_volume,
                    'run_time': f"{analyzer.run_time}",
                    'method': f"{component_name}_method"
                }
                
                # تحديث أعمدة الكاشف لاستخدام FID العشوائي
                edited_df["Detector"] = f"FID-{analyzer.fid_number}"
                
                # استخراج القمم لرسم الكروموتوجرام
                peaks = []
                for _, row in edited_df.iterrows():
                    peaks.append({
                        "ret_time": float(row["Ret. time (min)"]),
                        "height": float(row["Height (mV)"]),
                        "component_name": str(row["Component"])
                    })
                
                # رسم الكروموتوجرام
                analyzer.draw_chromatogram(peaks, sample_name)
                
                # إنشاء التقرير
                output_filename = f"Report_{sample_name.replace(' ', '_')}_{datetime.datetime.now().strftime('%Y%m%d_%H%M')}.pdf"
                pdf_path = analyzer.generate_comprehensive_report(sample_data, edited_df, output_filename)
                
                # عرض النتيجة
                st.success("✅ Professional report generated successfully in ONE page!")
                
                # زر التحميل
                with open(pdf_path, "rb") as f:
                    st.download_button(
                        label="📥 Download Professional Report",
                        data=f,
                        file_name=output_filename,
                        mime="application/pdf",
                        use_container_width=True
                    )
                
                # معاينة الصورة
                st.image("chromatogram.png", caption=f"Chromatogram ({analyzer.run_time} min)", use_container_width=True)
                
            except Exception as e:
                st.error(f"❌ Error generating report: {str(e)}")
    
    # زر لتوليد إعدادات عشوائية جديدة
    if st.sidebar.button("🔄 Generate New Random Settings", use_container_width=True):
        st.session_state.analyzer = ProfessionalChromatogramAnalyzer()
        st.rerun()

if __name__ == "__main__":
    main()


    #pip install streamlit matplotlib pandas fpdf2 numpy
    #streamlit run professional_chromatogram_analyzer.py