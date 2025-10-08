# 📁 pharmaceutical_quality_analyzer.py

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
import json

# إضافة دالة لتحميل خط يدعم Unicode
def setup_unicode_font(pdf):
    """إعداد خط يدعم الرموز Unicode"""
    try:
        # محاولة استخدام خط Arial الذي يدعم Unicode
        pdf.add_font('Arial', '', 'arial.ttf', uni=True)
        pdf.add_font('Arial', 'B', 'arialbd.ttf', uni=True)
        pdf.add_font('Arial', 'I', 'ariali.ttf', uni=True)
        pdf.add_font('Arial', 'BI', 'arialbi.ttf', uni=True)
        return 'Arial'
    except:
        try:
            # استخدام الخط الافتراضي إذا لم يتوفر Arial
            pdf.set_font("helvetica", size=10)
            return "helvetica"
        except:
            return "courier"

class USPStandardsDatabase:
    """فئة لمحاكاة قاعدة بيانات المواصفات القياسية من USP"""
    
    def __init__(self):
        self.usp_database = self._initialize_usp_database()
        self.custom_materials_file = "custom_materials.json"
        self.load_custom_materials()
    
    def _initialize_usp_database(self):
        """تهيئة قاعدة بيانات USP مع مجموعة واسعة من المواد"""
        return {
            "Sucrose": self._get_sucrose_standards(),
            "Sugar": self._get_sucrose_standards(),  # اسم بديل
            "Sorbitol": self._get_excipient_standards("Sorbitol"),
            "Sorbitol 70% Solution": self._get_sorbitol_solution_standards(),
            "Sorbitol 70.0% Solution (Non-Crystallizing)": self._get_sorbitol_solution_standards(),
            "Mannitol": self._get_excipient_standards("Mannitol"),
            "Lactose": self._get_excipient_standards("Lactose"),
            "Microcrystalline Cellulose": self._get_excipient_standards("MCC"),
            "Paracetamol": self._get_api_standards("Paracetamol"),
            "Ibuprofen": self._get_api_standards("Ibuprofen"),
            "Amoxicillin": self._get_api_standards("Amoxicillin"),
        }
    
    def _get_sucrose_standards(self):
        """معايير السكروز مع الاختبارات المطلوبة"""
        return {
            "description": "Sugar USP - Pharmaceutical Grade Sucrose",
            "required_tests": [
                {
                    "parameter": "Sulfite",
                    "specification": {"max": 10, "unit": "ppm"},
                    "method": "Ion Chromatography",
                    "test_type": "limit"
                },
                {
                    "parameter": "Appearance of solution",
                    "specification": {"requirement": "Colorless and clear solution"},
                    "method": "Visual",
                    "test_type": "requirement"
                },
                {
                    "parameter": "Solubility",
                    "specification": {"requirement": "Freely soluble in water"},
                    "method": "Visual",
                    "test_type": "requirement"
                }
            ],
            "additional_tests": {
                "assay": {"min": 98.0, "max": 102.0, "unit": "%", "method": "HPLC"},
                "water_content": {"max": 0.5, "unit": "%", "method": "Karl Fischer"},
                "sulfated_ash": {"max": 0.1, "unit": "%", "method": "Gravimetric"},
                "heavy_metals": {"max": 5, "unit": "ppm", "method": "ICP-MS"},
                "microbial_limit": {"max": 1000, "unit": "CFU/g", "method": "Microbiology"},
                "specific_rotation": {"min": 66.3, "max": 67.0, "unit": "°", "method": "Polarimetry"},
                "conductivity": {"max": 50, "unit": "µS/cm", "method": "Conductometry"},
            },
            "chromatography_conditions": {
                "column": "Carbohydrate Analysis Column",
                "mobile_phase": "Acetonitrile:Water (75:25)",
                "flow_rate": 1.0,
                "detection": "RID"
            }
        }
    
    def _get_excipient_standards(self, excipient_name):
        """معايير المواد المساعدة والخام"""
        standards = {
            "Sorbitol": {
                "description": "Sorbitol USP - Sweetening Agent",
                "required_tests": [
                    {
                        "parameter": "Assay",
                        "specification": {"min": 98.0, "max": 101.0, "unit": "%"},
                        "method": "HPLC",
                        "test_type": "range"
                    }
                ],
                "additional_tests": {
                    "water_content": {"max": 1.0, "unit": "%", "method": "Karl Fischer"},
                    "reducing_sugars": {"max": 0.3, "unit": "%", "method": "Titration"},
                }
            },
            "Mannitol": {
                "description": "Mannitol USP - Tablet Diluent",
                "required_tests": [],
                "additional_tests": {
                    "assay": {"min": 98.0, "max": 102.0, "unit": "%", "method": "HPLC"},
                    "water_content": {"max": 0.5, "unit": "%", "method": "Karl Fischer"},
                }
            },
            "Lactose": {
                "description": "Lactose Monohydrate USP - Filler",
                "required_tests": [],
                "additional_tests": {
                    "assay": {"min": 98.0, "max": 102.0, "unit": "%", "method": "HPLC"},
                    "water_content": {"min": 4.5, "max": 5.5, "unit": "%", "method": "Karl Fischer"},
                }
            },
            "MCC": {
                "description": "Microcrystalline Cellulose USP - Binder",
                "required_tests": [],
                "additional_tests": {
                    "particle_size": {"min": 50, "max": 150, "unit": "µm", "method": "Laser Diffraction"},
                    "bulk_density": {"min": 0.25, "max": 0.45, "unit": "g/ml", "method": "Volumetric"},
                }
            }
        }
        return standards.get(excipient_name, standards["Sorbitol"])
    
    def _get_sorbitol_solution_standards(self):
        """معايير محلول السوربيتول 70%"""
        return {
            "description": "Sorbitol Solution 70% USP - Non-Crystallizing Liquid",
            "required_tests": [
                {
                    "parameter": "Assay",
                    "specification": {"min": 69.0, "max": 71.0, "unit": "% w/w"},
                    "method": "HPLC",
                    "test_type": "range"
                }
            ],
            "additional_tests": {
                "water_content": {"min": 29.0, "max": 31.0, "unit": "% w/w", "method": "Karl Fischer"},
                "specific_gravity": {"min": 1.285, "max": 1.315, "unit": "g/ml", "method": "Pycnometer"},
            }
        }
    
    def _get_api_standards(self, api_name):
        """معايير المواد الفعالة (APIs)"""
        standards = {
            "Paracetamol": {
                "description": "Acetaminophen USP - Analgesic",
                "required_tests": [
                    {
                        "parameter": "Assay",
                        "specification": {"min": 98.0, "max": 102.0, "unit": "%"},
                        "method": "HPLC",
                        "test_type": "range"
                    },
                    {
                        "parameter": "Related substances",
                        "specification": {"max": 0.1, "unit": "%"},
                        "method": "HPLC",
                        "test_type": "limit"
                    }
                ],
                "additional_tests": {
                    "sulfite": {"max": 10, "unit": "ppm", "method": "Ion Chromatography"},
                    "water_content": {"max": 0.5, "unit": "%", "method": "Karl Fischer"},
                }
            },
            "Ibuprofen": {
                "description": "Ibuprofen USP - NSAID",
                "required_tests": [],
                "additional_tests": {
                    "assay": {"min": 97.0, "max": 103.0, "unit": "%", "method": "HPLC"},
                    "related_substances": {"max": 0.3, "unit": "%", "method": "HPLC"},
                }
            },
            "Amoxicillin": {
                "description": "Amoxicillin USP - Antibiotic",
                "required_tests": [],
                "additional_tests": {
                    "assay": {"min": 95.0, "max": 102.0, "unit": "%", "method": "HPLC"},
                    "water_content": {"max": 13.5, "unit": "%", "method": "Karl Fischer"},
                }
            }
        }
        return standards.get(api_name, standards["Paracetamol"])
    
    def load_custom_materials(self):
        """تحميل المواد المخصصة من ملف"""
        try:
            if os.path.exists(self.custom_materials_file):
                with open(self.custom_materials_file, 'r', encoding='utf-8') as f:
                    custom_materials = json.load(f)
                    self.usp_database.update(custom_materials)
        except Exception as e:
            st.error(f"خطأ في تحميل المواد المخصصة: {e}")
    
    def save_custom_materials(self):
        """حفظ المواد المخصصة إلى ملف"""
        try:
            custom_materials = {}
            base_materials = self._initialize_usp_database().keys()
            
            for material, standards in self.usp_database.items():
                if material not in base_materials:
                    custom_materials[material] = standards
            
            with open(self.custom_materials_file, 'w', encoding='utf-8') as f:
                json.dump(custom_materials, f, ensure_ascii=False, indent=2)
        except Exception as e:
            st.error(f"خطأ في حفظ المواد المخصصة: {e}")
    
    def search_material(self, material_name):
        """البحث عن مادة في قاعدة البيانات"""
        # البحث الدقيق أولاً
        if material_name in self.usp_database:
            return self.usp_database[material_name]
        
        # البحث التقريبي
        material_lower = material_name.lower()
        for stored_material in self.usp_database.keys():
            if material_lower in stored_material.lower() or stored_material.lower() in material_lower:
                return self.usp_database[stored_material]
        
        return None
    
    def get_required_tests(self, material_name):
        """الحصول على الاختبارات المطلوبة للمادة"""
        standards = self.search_material(material_name)
        if standards and "required_tests" in standards:
            return standards["required_tests"]
        return []
    
    def get_additional_tests(self, material_name):
        """الحصول على الاختبارات الإضافية للمادة"""
        standards = self.search_material(material_name)
        if standards and "additional_tests" in standards:
            return standards["additional_tests"]
        return {}
    
    def get_material_categories(self):
        """الحصول على فئات المواد المتاحة"""
        return {
            "مواد خام ومحليات": ["Sucrose", "Sugar", "Sorbitol", "Sorbitol 70% Solution", "Sorbitol 70.0% Solution (Non-Crystallizing)", "Mannitol", "Lactose"],
            "مواد مساعدة": ["Microcrystalline Cellulose"],
            "مواد فعالة (APIs)": ["Paracetamol", "Ibuprofen", "Amoxicillin"]
        }

class PharmaceuticalMaterialAnalyzer:
    def __init__(self):
        self.fid_number = random.randint(1, 3)
        self.run_time = random.randint(15, 40)
        self.generate_analysis_dates()
        self.analysis_id = f"ANA-{datetime.datetime.now().strftime('%Y%m%d')}-{random.randint(1000, 9999)}"
        self.usp_db = USPStandardsDatabase()
        
    def generate_analysis_dates(self):
        """توليد تواريخ التحليل والمعالجة"""
        self.analysis_date = datetime.datetime.now()
        self.report_date = datetime.datetime.now()
    
    def clean_text(self, text):
        """تنظيف النص من الرموز غير المدعومة"""
        if not isinstance(text, str):
            text = str(text)
        
        # استبدال الرموز غير المدعومة برموز بديلة
        replacements = {
            '≤': '<=',  # استبدال أقل من أو يساوي
            '≥': '>=',  # استبدال أكبر من أو يساوي
            '°': 'deg', # استبدال درجة
            'µ': 'u',   # استبدال ميكرو
            '₂': '2', '₃': '3', '₄': '4', '₅': '5', '₆': '6',
            '₇': '7', '₈': '8', '₉': '9', '₀': '0', '₁': '1',
            '²': '2', '³': '3', '⁴': '4', '•': '-', '·': '-'
        }
        
        for old, new in replacements.items():
            text = text.replace(old, new)
        
        return text

    def _format_specification(self, spec):
        """تنسيق المواصفة بشكل مقروء مع تجنب الرموز غير المدعومة"""
        if "min" in spec and "max" in spec:
            return f"{spec['min']} - {spec['max']} {spec.get('unit', '')}"
        elif "max" in spec:
            return f"<= {spec['max']} {spec.get('unit', '')}"  # استخدام <= بدلاً من ≤
        elif "min" in spec:
            return f">= {spec['min']} {spec.get('unit', '')}"  # استخدام >= بدلاً من ≥
        elif "requirement" in spec:
            return spec['requirement']
        else:
            return "As per USP"

    def generate_required_test_results(self, required_tests):
        """توليد نتائج للاختبارات المطلوبة"""
        results = []
        
        for test in required_tests:
            param = test["parameter"]
            spec = test["specification"]
            method = test["method"]
            test_type = test["test_type"]
            
            if test_type == "limit" and "max" in spec:
                # اختبارات لها حد أقصى
                result = random.uniform(spec["max"] * 0.1, spec["max"] * 0.8)
                status = result <= spec["max"]
                specification = f"<= {spec['max']} {spec.get('unit', '')}"  # استخدام <=
                
            elif test_type == "range" and "min" in spec and "max" in spec:
                # اختبارات لها مدى
                result = random.uniform(spec["min"] + 0.1, spec["max"] - 0.1)
                status = spec["min"] <= result <= spec["max"]
                specification = f"{spec['min']} - {spec['max']} {spec.get('unit', '')}"
                
            elif test_type == "requirement" and "requirement" in spec:
                # اختبارات وصفية
                result = spec["requirement"]
                status = True  # نفترض المطابقة للاختبارات الوصفية
                specification = spec["requirement"]
                
            else:
                continue
            
            results.append({
                'parameter': param,
                'result': result,
                'unit': spec.get('unit', ''),
                'specification': specification,
                'status': status,
                'method': method
            })
        
        return results

    def generate_additional_test_results(self, additional_tests):
        """توليد نتائج للاختبارات الإضافية"""
        results = []
        
        for param, spec in additional_tests.items():
            if "min" in spec and "max" in spec:
                # معاملات لها حد أدنى وأقصى
                target = (spec["min"] + spec["max"]) / 2
                variation = random.uniform(-2, 2)
                result = target + variation
                status = spec["min"] <= result <= spec["max"]
                specification = f"{spec['min']} - {spec['max']} {spec.get('unit', '')}"
                
            elif "max" in spec:
                # معاملات لها حد أقصى فقط
                result = random.uniform(spec["max"] * 0.1, spec["max"] * 0.9)
                status = result <= spec["max"]
                specification = f"<= {spec['max']} {spec.get('unit', '')}"  # استخدام <=
                
            elif "min" in spec:
                # معاملات لها حد أدنى فقط
                result = random.uniform(spec["min"] * 1.1, spec["min"] * 1.5)
                status = result >= spec["min"]
                specification = f">= {spec['min']} {spec.get('unit', '')}"  # استخدام >=
            else:
                continue
            
            results.append({
                'parameter': param,
                'result': result,
                'unit': spec.get('unit', ''),
                'specification': specification,
                'status': status,
                'method': spec.get('method', 'Standard')
            })
        
        return results

    def generate_certificate_of_analysis(self, material_data, analysis_results, output_path):
        """توليد شهادة تحليل"""
        pdf = FPDF()
        pdf.add_page()
        
        # إعداد الخط
        font_name = setup_unicode_font(pdf)
        
        # الهيدر
        pdf.set_font(font_name, 'B', 16)
        pdf.cell(0, 10, "CERTIFICATE OF ANALYSIS", new_x=XPos.LMARGIN, new_y=YPos.NEXT, align='C')
        
        pdf.set_font(font_name, 'B', 12)
        pdf.cell(0, 8, "PHARMACEUTICAL QUALITY CONTROL LABORATORY", new_x=XPos.LMARGIN, new_y=YPos.NEXT, align='C')
        
        # معلومات المادة
        pdf.ln(10)
        pdf.set_font(font_name, 'B', 12)
        pdf.cell(0, 8, "MATERIAL INFORMATION", new_x=XPos.LMARGIN, new_y=YPos.NEXT, align='L')
        
        pdf.set_font(font_name, '', 10)
        info_data = [
            ["Material Name:", material_data['material_name']],
            ["Batch Number:", material_data['batch_number']],
            ["Supplier:", material_data['supplier']],
            ["Analysis ID:", self.analysis_id],
            ["Date of Analysis:", self.analysis_date.strftime('%d-%b-%Y')],
        ]
        
        for label, value in info_data:
            pdf.cell(50, 6, label, border=0)
            pdf.cell(0, 6, str(value), border=0, new_x=XPos.LMARGIN, new_y=YPos.NEXT)
        
        # نتائج التحليل
        pdf.ln(10)
        pdf.set_font(font_name, 'B', 12)
        pdf.cell(0, 8, "ANALYSIS RESULTS", new_x=XPos.LMARGIN, new_y=YPos.NEXT, align='L')
        
        # جدول النتائج
        col_widths = [70, 30, 25, 40, 25]
        headers = ["Parameter", "Result", "Unit", "Specification", "Status"]
        
        pdf.set_font(font_name, 'B', 10)
        for i, header in enumerate(headers):
            if i == len(headers) - 1:
                pdf.cell(col_widths[i], 8, header, border=1, align='C', new_x=XPos.LMARGIN, new_y=YPos.NEXT)
            else:
                pdf.cell(col_widths[i], 8, header, border=1, align='C', new_x=XPos.RIGHT, new_y=YPos.TOP)
        
        pdf.set_font(font_name, '', 9)
        for result in analysis_results:
            status = "PASS" if result['status'] else "FAIL"
            result_value = f"{result['result']}" if isinstance(result['result'], str) else f"{result['result']:.3f}"
            
            # تنظيف النص من الرموز غير المدعومة
            clean_parameter = self.clean_text(result['parameter'])
            clean_specification = self.clean_text(result['specification'])
            
            pdf.cell(col_widths[0], 6, clean_parameter, border='LR')
            pdf.cell(col_widths[1], 6, result_value, border='LR', align='C')
            pdf.cell(col_widths[2], 6, result['unit'], border='LR', align='C')
            pdf.cell(col_widths[3], 6, clean_specification, border='LR', align='C')
            pdf.cell(col_widths[4], 6, status, border='LR', align='C', 
                    new_x=XPos.LMARGIN, new_y=YPos.NEXT)
        
        # الخط السفلي للجدول
        pdf.cell(sum(col_widths), 0, '', border='T', new_x=XPos.LMARGIN, new_y=YPos.NEXT)
        
        # الخلاصة
        pdf.ln(10)
        pdf.set_font(font_name, 'B', 12)
        pdf.cell(0, 8, "CONCLUSION", new_x=XPos.LMARGIN, new_y=YPos.NEXT, align='L')
        
        all_passed = all(result['status'] for result in analysis_results)
        conclusion_text = "MATERIAL MEETS ALL SPECIFICATIONS - APPROVED FOR USE" if all_passed else "MATERIAL DOES NOT MEET SPECIFICATIONS - REJECTED"
        
        pdf.set_font(font_name, 'B', 11)
        pdf.cell(0, 6, conclusion_text, new_x=XPos.LMARGIN, new_y=YPos.NEXT, align='C')
        
        # التوقيعات
        pdf.ln(15)
        col_width = 60
        pdf.set_font(font_name, 'B', 10)
        pdf.cell(col_width, 6, "Analyst:", border='T', align='C')
        pdf.cell(col_width, 6, "Reviewer:", border='T', align='C')
        pdf.cell(col_width, 6, "QA Manager:", border='T', align='C', 
                new_x=XPos.LMARGIN, new_y=YPos.NEXT)
        
        pdf.set_font(font_name, 'I', 9)
        pdf.cell(col_width, 4, material_data['analyst'], align='C')
        pdf.cell(col_width, 4, "Dr. Quality Control", align='C')
        pdf.cell(col_width, 4, "QA Department", align='C', 
                new_x=XPos.LMARGIN, new_y=YPos.NEXT)
        
        pdf.output(output_path)
        return output_path

    def generate_chromatogram_report(self, material_data, analysis_results, output_path):
        """توليد تقرير الكروموتوجرام"""
        pdf = FPDF()
        pdf.add_page()
        
        # إعداد الخط
        font_name = setup_unicode_font(pdf)
        
        # عنوان التقرير
        pdf.set_font(font_name, 'B', 16)
        pdf.cell(0, 10, "CHROMATOGRAM ANALYSIS REPORT", new_x=XPos.LMARGIN, new_y=YPos.NEXT, align='C')
        
        # معلومات العينة
        pdf.set_font(font_name, 'B', 12)
        pdf.cell(0, 8, "SAMPLE INFORMATION", new_x=XPos.LMARGIN, new_y=YPos.NEXT, align='L')
        
        pdf.set_font(font_name, '', 10)
        info_data = [
            ["Material Name:", material_data['material_name']],
            ["Batch Number:", material_data['batch_number']],
            ["Analysis ID:", self.analysis_id],
            ["Date of Analysis:", self.analysis_date.strftime('%d-%b-%Y')],
            ["Run Time:", f"{self.run_time} min"],
            ["Detector:", f"RID-{self.fid_number}"],
        ]
        
        for label, value in info_data:
            pdf.cell(40, 6, label, border=0)
            pdf.cell(0, 6, str(value), border=0, new_x=XPos.LMARGIN, new_y=YPos.NEXT)
        
        # إضافة صورة الكروموتوجرام إذا كانت موجودة
        pdf.ln(10)
        if os.path.exists("chromatogram.png"):
            pdf.set_font(font_name, 'B', 12)
            pdf.cell(0, 8, "CHROMATOGRAM", new_x=XPos.LMARGIN, new_y=YPos.NEXT, align='L')
            pdf.image("chromatogram.png", x=10, w=190)
            pdf.ln(5)
        
        # جدول بيانات القمم
        pdf.set_font(font_name, 'B', 12)
        pdf.cell(0, 8, "PEAK ANALYSIS DATA", new_x=XPos.LMARGIN, new_y=YPos.NEXT, align='L')
        
        col_widths = [50, 30, 35, 35, 40]
        headers = ["Component", "RT (min)", "Area", "Height", "Status"]
        
        pdf.set_font(font_name, 'B', 10)
        for i, header in enumerate(headers):
            if i == len(headers) - 1:
                pdf.cell(col_widths[i], 8, header, border=1, align='C', new_x=XPos.LMARGIN, new_y=YPos.NEXT)
            else:
                pdf.cell(col_widths[i], 8, header, border=1, align='C', new_x=XPos.RIGHT, new_y=YPos.TOP)
        
        # بيانات القمم (يمكن تخصيصها حسب المادة)
        peak_data = [
            {"component": "Sucrose", "rt": 8.5, "area": "750,250", "height": "185,320", "status": "PASS"},
            {"component": "Impurity A", "rt": 5.2, "area": "1,250", "height": "320", "status": "PASS"},
            {"component": "Sulfite", "rt": 3.8, "area": "4,150", "height": "980", "status": "PASS"},
        ]
        
        pdf.set_font(font_name, '', 9)
        for peak in peak_data:
            pdf.cell(col_widths[0], 6, peak["component"], border='LR', align='C')
            pdf.cell(col_widths[1], 6, f"{peak['rt']:.1f}", border='LR', align='C')
            pdf.cell(col_widths[2], 6, peak["area"], border='LR', align='C')
            pdf.cell(col_widths[3], 6, peak["height"], border='LR', align='C')
            pdf.cell(col_widths[4], 6, peak["status"], border='LR', align='C', 
                    new_x=XPos.LMARGIN, new_y=YPos.NEXT)
        
        # الخط السفلي للجدول
        pdf.cell(sum(col_widths), 0, '', border='T', new_x=XPos.LMARGIN, new_y=YPos.NEXT)
        
        # ملائمة النظام
        pdf.ln(10)
        pdf.set_font(font_name, 'B', 12)
        pdf.cell(0, 8, "SYSTEM SUITABILITY", new_x=XPos.LMARGIN, new_y=YPos.NEXT, align='L')
        
        suitability_data = [
            {"Parameter": "Retention Time RSD", "Requirement": "<= 2.0%", "Result": "0.11%", "Status": "Pass"},  # استخدام <=
            {"Parameter": "Tailing Factor", "Requirement": "<= 2.0", "Result": "1.03", "Status": "Pass"},  # استخدام <=
            {"Parameter": "Theoretical Plates (N)", "Requirement": ">= 2000", "Result": "7520", "Status": "Pass"}  # استخدام >=
        ]
        
        col_widths_suit = [60, 40, 35, 25]
        headers_suit = ["Parameter", "Requirement", "Result", "Status"]
        
        pdf.set_font(font_name, 'B', 10)
        for i, header in enumerate(headers_suit):
            if i == len(headers_suit) - 1:
                pdf.cell(col_widths_suit[i], 8, header, border=1, align='C', new_x=XPos.LMARGIN, new_y=YPos.NEXT)
            else:
                pdf.cell(col_widths_suit[i], 8, header, border=1, align='C', new_x=XPos.RIGHT, new_y=YPos.TOP)
        
        pdf.set_font(font_name, '', 9)
        for data in suitability_data:
            pdf.cell(col_widths_suit[0], 6, data["Parameter"], border='LR', align='C')
            pdf.cell(col_widths_suit[1], 6, data["Requirement"], border='LR', align='C')
            pdf.cell(col_widths_suit[2], 6, data["Result"], border='LR', align='C')
            pdf.cell(col_widths_suit[3], 6, data["Status"], border='LR', align='C', 
                    new_x=XPos.LMARGIN, new_y=YPos.NEXT)
        
        pdf.cell(sum(col_widths_suit), 0, '', border='T', new_x=XPos.LMARGIN, new_y=YPos.NEXT)
        
        pdf.output(output_path)
        return output_path

    def draw_chromatogram(self, material_name, filename="chromatogram.png"):
        """رسم كروموتوجرام للمادة"""
        time = np.arange(0, self.run_time + 0.1, 0.1)
        signal = np.zeros_like(time)
        
        # خط أساس مع ضوضاء واقعية
        baseline = 3 * np.exp(-time / 12)
        noise = np.random.normal(0, 0.3, len(time))
        signal = baseline + noise
        
        # إضافة قمم للمواد المختلفة
        if material_name.lower() in ['sucrose', 'sugar']:
            peaks = [
                {'ret_time': 3.8, 'height': 980, 'name': 'Sulfite'},
                {'ret_time': 5.2, 'height': 320, 'name': 'Impurity A'},
                {'ret_time': 8.5, 'height': 18500, 'name': 'Sucrose'},
            ]
        else:
            peaks = [
                {'ret_time': 4.5, 'height': 1200, 'name': 'Impurity'},
                {'ret_time': 9.2, 'height': 15000, 'name': 'Main Peak'},
            ]
        
        # إضافة القمم للإشارة
        for peak in peaks:
            peak_signal = peak['height'] * np.exp(-((time - peak['ret_time']) ** 2) / (2 * 0.04 ** 2))
            signal += peak_signal
        
        # الرسم
        plt.figure(figsize=(12, 6))
        plt.plot(time, signal, color='#2E86AB', linewidth=2, label='Signal')
        
        # إضافة مؤشرات القمم
        for peak in peaks:
            peak_index = np.argmin(np.abs(time - peak['ret_time']))
            peak_value = signal[peak_index]
            plt.plot(peak['ret_time'], peak_value, 'ro', markersize=8, 
                    markeredgecolor='red', markerfacecolor='yellow')
            
            plt.annotate(
                f"{peak['name']}\n{peak['ret_time']:.1f} min",
                xy=(peak['ret_time'], peak_value),
                xytext=(peak['ret_time'] + 0.8, peak_value + peak['height'] * 0.1),
                arrowprops=dict(facecolor='green', arrowstyle='->', alpha=0.7),
                fontsize=10,
                ha='left'
            )
        
        plt.title(f"Chromatogram - {material_name}", fontsize=14, fontweight='bold')
        plt.xlabel("Time (min)", fontsize=12)
        plt.ylabel("Signal (mV)", fontsize=12)
        plt.xlim(0, self.run_time)
        plt.ylim(0, max(signal) + max(signal) * 0.2)
        plt.grid(True, alpha=0.3)
        plt.legend()
        
        plt.tight_layout()
        plt.savefig(filename, dpi=150, bbox_inches='tight')
        plt.close()

def get_local_ip():
    """الحصول على عنوان IP المحلي"""
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip_address = s.getsockname()[0]
        s.close()
        return ip_address
    except:
        return "localhost"

def main():
    st.set_page_config(
        page_title="Pharmaceutical Material Analyzer",
        page_icon="💊",
        layout="wide",
        initial_sidebar_state="expanded"
    )
    
    # الحصول على عنوان IP للوصول من الموبايل
    local_ip = get_local_ip()
    
    st.title("💊 Pharmaceutical Material Analyzer")
    st.markdown("### نظام تحليل الخامات الدوائية بناءً على مواصفات USP")
    
    # معلومات الوصول من الموبايل
    with st.sidebar:
        st.header("📱 Mobile Access")
        st.info(f"**URL:** http://{local_ip}:8501")
        st.info("**Instructions:**\n- Connect phone to same WiFi\n- Open browser and enter the URL")
        st.markdown("---")
        
        st.header("⚙️ إعدادات التحليل")
        
        st.subheader("اختيار المادة")
        if 'analyzer' not in st.session_state:
            st.session_state.analyzer = PharmaceuticalMaterialAnalyzer()
        
        analyzer = st.session_state.analyzer
        
        material_categories = analyzer.usp_db.get_material_categories()
        
        selected_category = st.selectbox(
            "اختر فئة المادة",
            list(material_categories.keys())
        )
        
        if selected_category:
            materials_in_category = material_categories[selected_category]
            selected_material = st.selectbox(
                "اختر المادة",
                materials_in_category
            )
        else:
            selected_material = st.text_input("أو اكتب اسم المادة يدوياً")
        
        st.subheader("معلومات العينة")
        batch_number = st.text_input("رقم التشغيلة", "25259")
        supplier = st.text_input("المورد", "Sina Pharma")
        analyst_name = st.text_input("اسم المحلل", "Quality Control Lab")
    
    # البحث عن مواصفات USP للمادة المحددة
    usp_standards = None
    if selected_material:
        usp_standards = analyzer.usp_db.search_material(selected_material)
    
    # عرض مواصفات USP
    if usp_standards:
        st.success(f"✅ تم العثور على مواصفات USP للمادة: {selected_material}")
        
        col1, col2 = st.columns([2, 1])
        
        with col1:
            st.subheader("📋 مواصفات USP للمادة")
            
            # عرض الوصف
            if "description" in usp_standards:
                st.info(f"**الوصف:** {usp_standards['description']}")
            
            # عرض الاختبارات المطلوبة
            required_tests = analyzer.usp_db.get_required_tests(selected_material)
            if required_tests:
                st.write("**الاختبارات المطلوبة:**")
                required_data = []
                for test in required_tests:
                    required_data.append({
                        "الاختبار": test["parameter"],
                        "المواصفة": analyzer._format_specification(test["specification"]),
                        "الطريقة": test["method"]
                    })
                
                required_df = pd.DataFrame(required_data)
                st.dataframe(required_df, use_container_width=True)
            
            # عرض الاختبارات الإضافية
            additional_tests = analyzer.usp_db.get_additional_tests(selected_material)
            if additional_tests:
                st.write("**الاختبارات الإضافية:**")
                additional_data = []
                for param, spec in additional_tests.items():
                    additional_data.append({
                        "المعامل": param,
                        "المواصفة": analyzer._format_specification(spec),
                        "الطريقة": spec.get('method', 'قياسي')
                    })
                
                additional_df = pd.DataFrame(additional_data)
                st.dataframe(additional_df, use_container_width=True)
        
        with col2:
            st.subheader("🔍 معلومات إضافية")
            
            if "chromatography_conditions" in usp_standards:
                st.write("**ظروف الكروماتوجرافي:**")
                for key, value in usp_standards["chromatography_conditions"].items():
                    st.write(f"- {key}: {value}")
            
            st.write(f"**رقم التحليل:** {analyzer.analysis_id}")
            st.write(f"**تاريخ التحليل:** {analyzer.analysis_date.strftime('%Y-%m-%d')}")
    
    else:
        st.warning(f"⚠️ لم يتم العثور على مواصفات USP للمادة: {selected_material}")
    
    # توليد وعرض نتائج التحليل
    if usp_standards and st.button("🔬 توليد نتائج التحليل", type="primary", use_container_width=True):
        with st.spinner("جاري تحليل العينة بناءً على مواصفات USP..."):
            # توليد نتائج الاختبارات المطلوبة
            required_tests = analyzer.usp_db.get_required_tests(selected_material)
            required_results = analyzer.generate_required_test_results(required_tests)
            
            # توليد نتائج الاختبارات الإضافية
            additional_tests = analyzer.usp_db.get_additional_tests(selected_material)
            additional_results = analyzer.generate_additional_test_results(additional_tests)
            
            # دمج النتائج
            all_results = required_results + additional_results
            
            st.subheader("📊 نتائج التحليل")
            
            # عرض نتائج الاختبارات المطلوبة أولاً
            if required_results:
                st.markdown("#### 🎯 الاختبارات المطلوبة")
                required_data = []
                for result in required_results:
                    status_icon = "✅" if result['status'] else "❌"
                    required_data.append({
                        "الاختبار": result['parameter'],
                        "النتيجة": f"{result['result']}" if isinstance(result['result'], str) else f"{result['result']:.3f}",
                        "الوحدة": result['unit'],
                        "المواصفة": result['specification'],
                        "الحالة": f"{status_icon} {'مطابق' if result['status'] else 'غير مطابق'}"
                    })
                
                required_results_df = pd.DataFrame(required_data)
                st.dataframe(required_results_df, use_container_width=True)
            
            # عرض الاختبارات الإضافية
            if additional_results:
                st.markdown("#### 📈 الاختبارات الإضافية")
                additional_data = []
                for result in additional_results:
                    status_icon = "✅" if result['status'] else "❌"
                    additional_data.append({
                        "المعامل": result['parameter'],
                        "النتيجة": f"{result['result']:.3f}",
                        "الوحدة": result['unit'],
                        "المواصفة": result['specification'],
                        "الحالة": f"{status_icon} {'مطابق' if result['status'] else 'غير مطابق'}"
                    })
                
                additional_results_df = pd.DataFrame(additional_data)
                st.dataframe(additional_results_df, use_container_width=True)
            
            # حساب نسبة المطابقة
            total_tests = len(all_results)
            passed_tests = sum(1 for r in all_results if r['status'])
            compliance_rate = (passed_tests / total_tests) * 100 if total_tests > 0 else 0
            
            st.metric("نسبة المطابقة", f"{compliance_rate:.1f}%")
            
            if compliance_rate == 100:
                st.success("🎉 جميع النتائج مطابقة لمواصفات USP!")
            elif compliance_rate >= 90:
                st.warning("⚠️ معظم النتائج مطابقة مع وجود بعض الانحرافات الطفيفة")
            else:
                st.error("❌ هناك انحرافات كبيرة عن مواصفات USP")
            
            # حفظ النتائج في session state للاستخدام في التقارير
            st.session_state.analysis_results = all_results
            st.session_state.material_data = {
                'material_name': selected_material,
                'batch_number': batch_number,
                'supplier': supplier,
                'analyst': analyst_name
            }

    # أزرار التصدير
    if st.session_state.get('analysis_results') and st.session_state.get('material_data'):
        col1, col2 = st.columns(2)
        
        with col1:
            if st.button("📄 إصدار شهادة التحليل", type="primary", use_container_width=True):
                with st.spinner("جاري إصدار شهادة التحليل..."):
                    try:
                        material_data = st.session_state.material_data
                        analysis_results = st.session_state.analysis_results
                        
                        cert_filename = f"COA_{material_data['material_name'].replace(' ', '_')}_{material_data['batch_number']}.pdf"
                        cert_path = analyzer.generate_certificate_of_analysis(material_data, analysis_results, cert_filename)
                        
                        with open(cert_path, "rb") as f:
                            st.download_button(
                                label="📥 تحميل شهادة التحليل",
                                data=f,
                                file_name=cert_filename,
                                mime="application/pdf",
                                use_container_width=True
                            )
                        
                        st.success("✅ تم إصدار شهادة التحليل بنجاح!")
                        
                    except Exception as e:
                        st.error(f"❌ خطأ في إصدار الشهادة: {str(e)}")
        
        with col2:
            if st.button("📊 إصدار تقرير الكروموتوجرام", type="secondary", use_container_width=True):
                with st.spinner("جاري إصدار تقرير الكروموتوجرام..."):
                    try:
                        material_data = st.session_state.material_data
                        analysis_results = st.session_state.analysis_results
                        
                        # رسم الكروموتوجرام أولاً
                        analyzer.draw_chromatogram(material_data['material_name'])
                        
                        report_filename = f"Chromatogram_Report_{material_data['material_name'].replace(' ', '_')}_{material_data['batch_number']}.pdf"
                        report_path = analyzer.generate_chromatogram_report(material_data, analysis_results, report_filename)
                        
                        with open(report_path, "rb") as f:
                            st.download_button(
                                label="📥 تحميل تقرير الكروموتوجرام",
                                data=f,
                                file_name=report_filename,
                                mime="application/pdf",
                                use_container_width=True
                            )
                        
                        st.success("✅ تم إصدار تقرير الكروموتوجرام بنجاح!")
                        
                    except Exception as e:
                        st.error(f"❌ خطأ في إصدار التقرير: {str(e)}")

    # زر توليد تحليل جديد
    if st.button("🔄 توليد تحليل جديد", use_container_width=True):
        st.session_state.analyzer = PharmaceuticalMaterialAnalyzer()
        if 'analysis_results' in st.session_state:
            del st.session_state.analysis_results
        if 'material_data' in st.session_state:
            del st.session_state.material_data
        st.rerun()

if __name__ == "__main__":
    main()