
# نظام إدارة سلسلة التوريد | Supply Chain Management System

![Flutter](https://img.shields.io/badge/Flutter-3.13.9-02569B?logo=flutter)
![Dart](https://img.shields.io/badge/Dart-3.1.5-0175C2?logo=dart)
![Firebase](https://img.shields.io/badge/Firebase-FFCA28?logo=firebase&logoColor=black)
![License](https://img.shields.io/badge/License-MIT-green.svg)

🇬🇧 EN | 🇸🇦 العربية

A Flutter-based Supply Chain Management System integrated with Firebase (Auth & Firestore) to manage companies, suppliers, and purchase orders efficiently. This project is designed for scalability, modularity, and practical use in real-world supply chain operations.

---

## 🚀 Features

### 🔐 Authentication & Security
- User login & registration with Firebase Auth.
- Role-based access control (RBAC).

### 🏢 Company Management
- Add, edit, and view company profiles.
- Store essential business information.

### 🤝 Supplier Management
- Register and manage suppliers.
- Link suppliers to specific companies.

### 📦 Purchase Orders (POs)
- Create, view, and manage purchase orders.
- Track order status and full history in real-time.
- Integrated with Firebase Firestore.

### 📊 Inventory & Stock Movements
- Record all inbound & outbound stock transactions.
- Automatic stock quantity calculations.

### 🌍 Multi-language Support
- Seamless localization using easy_localization.
- Currently supports English (EN) and Arabic (AR).

### 📤 Export & Sharing
- Generate and export detailed reports as PDF.
- Share purchase orders and data directly via WhatsApp and other platforms.

---

## 🛠️ Tech Stack
- **Frontend Framework:** Flutter (Dart)
- **Backend & Database:** Firebase (Authentication, Firestore, Cloud Storage)
- **State Management:** Provider
- **Internationalization:** easy_localization
- **PDF Generation:** pdf package
- **Sharing Functionality:** share_plus

---

## 📂 Project Structure

```
lib/
│
├───models/           # Data models (Company, Supplier, PurchaseOrder, User...)
├───services/         # Firebase services (Auth, Database) & helper classes
├───providers/        # State management using Provider
├───screens/          # Main UI screens (Login, Dashboard, Suppliers, Orders...)
├───widgets/          # Reusable UI components (cards, dialogs, forms...)
├───utils/            # Utilities & constants (formatting, validators, movement utils...)
├───l10n/             # Localization files (/arb)
│
└───main.dart         # Application entry point
```

---

## ⚙️ Installation & Setup

Clone the repository:
```bash
git clone https://github.com/ahmedtharwat19/supplyChain.git
cd supplyChain
```

Install the dependencies:
```bash
flutter pub get
```

Set up Firebase:
- Create a new project in the Firebase Console.
- Add Android and/or iOS apps to your project and follow the setup guides.
- Download the configuration files:
  - `google-services.json` for Android → `/android/app/`
  - `GoogleService-Info.plist` for iOS → `/ios/Runner/`
- Enable **Email/Password authentication** in Firebase Auth.
- Create a Firestore Database in **production mode**.

Run the application:
```bash
flutter run
```

---

## 📈 Future Enhancements
- Offline support with local data caching (Hive/SQLite).
- Advanced role-based dashboards (Admin, Manager, Supplier).
- Push notification system for order updates.
- Barcode/QR code scanning for inventory management.
- Advanced data analytics and reporting dashboard.
- Integration with payment gateways.

---

## 🤝 Contributing
Contributions, issues, and feature requests are welcome!  
Check the [issues page](https://github.com/ahmedtharwat19/supplyChain/issues).

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

---

## 📜 License
This project is distributed under the MIT License.  
See the LICENSE file for more information.

---

## 📞 Contact
- Ahmed Tharwat - ahmed.tharwat19@gmail.com
- Project Link: [GitHub Repo](https://github.com/ahmedtharwat19/supplyChain)

---

# 🇸🇦 النسخة العربية

نظام متكامل لإدارة سلسلة التوريد مبني باستخدام Flutter وموثق مع Firebase (المصادقة و Firestore) لإدارة الشركات والموردين وأوامر الشراء بكفاءة. تم تصميم هذا المشروع ليكون قابلاً للتطوير، modularity، وعملي للاستخدام في بيئات عمل حقيقية.

---

## 🚀 المميزات الرئيسية

### 🔐 المصادقة والأمان
- تسجيل الدخول وإنشاء حسابات مستخدمين عبر Firebase Auth.
- تحكم في الصلاحيات بناءً على الأدوار (RBAC).

### 🏢 إدارة الشركات
- إضافة، تعديل، وعرض ملفات الشركات.
- تخزين المعلومات التجارية الأساسية.

### 🤝 إدارة الموردين
- تسجيل وإدارة الموردين.
- ربط الموردين بشركات محددة.

### 📦 أوامر الشراء
- إنشاء، عرض، وإدارة أوامر الشراء.
- تتبع حالة الطلب والسجل الكامل في الوقت الفعلي.
- متكامل مع Firebase Firestore.

### 📊 إدارة المخزون والحركات
- تسجيل جميع حركات المخزون الداخلة والخارجة.
- حسابات كمية المخزون التلقائية.

### 🌍 دعم多 اللغات
- دعم سلس للترجمة باستخدام easy_localization.
- يدعم حاليًا الإنجليزية (EN) والعربية (AR).

### 📤 التصدير والمشاركة
- إنشاء وتصدير تقارير مفصلة كملفات PDF.
- مشاركة أوامر الشراء والبيانات مباشرة عبر WhatsApp ومنصات أخرى.

---

## 🛠️ التقنيات المستخدمة
- **واجهة المستخدم:** Flutter (Dart)
- **قواعد البيانات والخوادم:** Firebase (المصادقة، Firestore، التخزين)
- **إدارة الحالة:** Provider
- **الترجمة والدعم المحلي:** easy_localization
- **إنشاء ملفات PDF:** pdf package
- **مشاركة الملفات:** share_plus

---

## 📂 هيكلة المشروع

```
lib/
│
├───models/           # نماذج البيانات (Company, Supplier, PurchaseOrder, User...)
├───services/         # خدمات Firebase (المصادقة، قاعدة البيانات) + كلاس المساعدة
├───providers/        # إدارة الحالة باستخدام Provider
├───screens/          # شاشات واجهة المستخدم الرئيسية (Login, Dashboard, Suppliers, Orders...)
├───widgets/          # مكونات واجهة مستخدم قابلة لإعادة الاستخدام (cards, forms, dialogs...)
├───utils/            # أدوات وثوابت (تنسيقات، فالاتدات، أدوات الحركة...)
├───l10n/             # ملفات الترجمة (/arb)
│
└───main.dart         # نقطة دخول التطبيق
```

---

## ⚙️ خطوات التثبيت والتشغيل
(نفس الخطوات الموضحة في النسخة الإنجليزية أعلاه)

---

## 📈 التطوير المستقبلي
(نفس القائمة الموضحة أعلاه)

---

## 🤝 المساهمة
المساهمات والاقتراحات والإبلاغ عن الأخطاء مرحب بها!  
تفضل بزيارة [صفحة Issues](https://github.com/ahmedtharwat19/supplyChain/issues).

---

## 📜 الترخيص
هذا المشروع مرخص برخصة MIT.  
راجع ملف LICENSE للمزيد من التفاصيل.

---

## 📞 التواصل
- أحمد ثروت - ahmed.tharwat19@gmail.com
- رابط المشروع: [GitHub Repo](https://github.com/ahmedtharwat19/supplyChain)
#   s u p p l y c h a i n - r e l e a s e s  
 