// services/currency_service.dart

import 'package:easy_localization/easy_localization.dart';

class CurrencyService {
  // ✅ رموز العملات (ثابتة)
  static const Map<String, String> _symbols = {
    'EGP': 'ج.م',
    'USD': '\$',
    'EUR': '€',
    'SAR': 'ر.س',
    'AED': 'د.إ',
  };

  /// ✅ الحصول على رمز العملة
  static String getSymbol(String currencyCode) {
    return _symbols[currencyCode] ?? currencyCode;
  }

  /// ✅ تنسيق العملة حسب اللغة
  static String formatCurrency(
    double amount,
    String currencyCode,
    String languageCode,
  ) {
    final symbol = getSymbol(currencyCode);
    final isArabic = languageCode == 'ar';
    final formatted = amount.toStringAsFixed(2);
    
    if (isArabic) {
      return '$symbol $formatted';
    } else {
      return '$symbol$formatted';
    }
  }

  /// ✅ قائمة العملات المتاحة
  static List<String> getAvailableCurrencies() {
    return ['EGP', 'USD', 'EUR', 'SAR', 'AED'];
  }

  /// ✅ الحصول على اسم العملة من ملفات الترجمة
  static String getCurrencyName(String code) {
    return 'currency_${code.toLowerCase()}'.tr();
  }
}