import pandas as pd

# قائمة المواد الخام والتغليف
raw_materials = [
    {"nameEn": "Sugar", "nameAr": "سكر", "description": "", "category": "raw_material", "unit": "kg", "unitPrice": 50, "isTaxable": True},
    {"nameEn": "Flour", "nameAr": "دقيق", "description": "", "category": "raw_material", "unit": "kg", "unitPrice": 30, "isTaxable": True},
    {"nameEn": "Rice", "nameAr": "أرز", "description": "", "category": "raw_material", "unit": "kg", "unitPrice": 60, "isTaxable": True},
    {"nameEn": "Salt", "nameAr": "ملح", "description": "", "category": "raw_material", "unit": "kg", "unitPrice": 10, "isTaxable": False},
    {"nameEn": "Olive Oil", "nameAr": "زيت زيتون", "description": "", "category": "raw_material", "unit": "litre", "unitPrice": 80, "isTaxable": True},
    {"nameEn": "Vegetable Oil", "nameAr": "زيت نباتي", "description": "", "category": "raw_material", "unit": "litre", "unitPrice": 40, "isTaxable": True},
    {"nameEn": "Butter", "nameAr": "زبدة", "description": "", "category": "raw_material", "unit": "kg", "unitPrice": 90, "isTaxable": True},
    {"nameEn": "Milk Powder", "nameAr": "حليب بودرة", "description": "", "category": "raw_material", "unit": "kg", "unitPrice": 70, "isTaxable": True},
    {"nameEn": "Yeast", "nameAr": "خميرة", "description": "", "category": "raw_material", "unit": "kg", "unitPrice": 25, "isTaxable": True},
    {"nameEn": "Baking Soda", "nameAr": "بيكربونات الصوديوم", "description": "", "category": "raw_material", "unit": "kg", "unitPrice": 20, "isTaxable": False},
    {"nameEn": "Packaging Film", "nameAr": "فيلم تغليف", "description": "", "category": "packaging_material", "unit": "m2", "unitPrice": 15, "isTaxable": True},
    {"nameEn": "Cardboard Boxes", "nameAr": "كرتون تغليف", "description": "", "category": "packaging_material", "unit": "piece", "unitPrice": 5, "isTaxable": True},
    {"nameEn": "Plastic Bottles", "nameAr": "زجاجات بلاستيكية", "description": "", "category": "packaging_material", "unit": "piece", "unitPrice": 2, "isTaxable": True},
    {"nameEn": "Glass Jars", "nameAr": "مرطبانات زجاجية", "description": "", "category": "packaging_material", "unit": "piece", "unitPrice": 3, "isTaxable": True},
    {"nameEn": "Aluminum Foil", "nameAr": "ورق ألومنيوم", "description": "", "category": "packaging_material", "unit": "roll", "unitPrice": 12, "isTaxable": True},
    {"nameEn": "Shrink Wrap", "nameAr": "غلاف انكماشي", "description": "", "category": "packaging_material", "unit": "roll", "unitPrice": 10, "isTaxable": True},
    {"nameEn": "Label Stickers", "nameAr": "ملصقات تعريف", "description": "", "category": "packaging_material", "unit": "sheet", "unitPrice": 1.5, "isTaxable": True},
    {"nameEn": "Tapes", "nameAr": "أشرطة لاصقة", "description": "", "category": "packaging_material", "unit": "roll", "unitPrice": 4, "isTaxable": True},
    {"nameEn": "Caps and Lids", "nameAr": "أغطية وقبعات", "description": "", "category": "packaging_material", "unit": "piece", "unitPrice": 1, "isTaxable": True},
    {"nameEn": "Paper Bags", "nameAr": "أكياس ورقية", "description": "", "category": "packaging_material", "unit": "piece", "unitPrice": 2.5, "isTaxable": True},
]

# تحويل البيانات إلى جدول
df = pd.DataFrame(raw_materials)

# حفظ إلى ملف Excel
df.to_excel("raw_and_packaging_materials.xlsx", index=False)
