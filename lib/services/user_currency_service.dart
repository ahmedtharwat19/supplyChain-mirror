// services/user_currency_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:puresip_purchasing/debug_helper.dart';
import 'package:puresip_purchasing/services/currency_service.dart';

class UserCurrencyService {
  static const String _keyBaseCurrency = 'base_currency';
  static const String _keyExchangeRates = 'exchange_rates';
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  /// ✅ الحصول على العملة الأساسية للمستخدم
  Future<String> getUserBaseCurrency() async {
    try {
      final cached = await _secureStorage.read(key: _keyBaseCurrency);
      if (cached != null && cached.isNotEmpty) {
        return cached;
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        
        if (doc.exists) {
          final baseCurrency = doc.data()?['baseCurrency'] ?? 'EGP';
          await _secureStorage.write(key: _keyBaseCurrency, value: baseCurrency);
          return baseCurrency;
        }
      }

      return 'EGP';
    } catch (e) {
      safeDebugPrint('Error getting user base currency: $e');
      return 'EGP';
    }
  }

  /// ✅ تعيين العملة الأساسية للمستخدم
  Future<void> setUserBaseCurrency(String currencyCode) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await _secureStorage.write(key: _keyBaseCurrency, value: currencyCode);
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'baseCurrency': currencyCode,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      safeDebugPrint('✅ Base currency set to: $currencyCode');
    } catch (e) {
      safeDebugPrint('Error setting base currency: $e');
    }
  }

  /// ✅ الحصول على أسعار الصرف
  Future<Map<String, double>> getExchangeRates() async {
    try {
      // 1. محاولة القراءة من التخزين المحلي
      final cached = await _secureStorage.read(key: _keyExchangeRates);
      if (cached != null && cached.isNotEmpty) {
        final Map<String, double> rates = {};
        final pairs = cached.split('&');
        for (final pair in pairs) {
          final parts = pair.split('=');
          if (parts.length == 2) {
            final key = parts[0];
            final value = double.tryParse(parts[1]);
            if (value != null) {
              rates[key] = value;
            }
          }
        }
        if (rates.isNotEmpty) {
          return rates;
        }
      }

      // 2. محاولة القراءة من Firestore
      final today = DateTime.now().toUtc();
      final dateStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      
      final doc = await FirebaseFirestore.instance
          .collection('exchange_rates')
          .doc(dateStr)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        final rates = Map<String, double>.from(data['rates'] ?? {});
        
        final encoded = rates.entries.map((e) => '${e.key}=${e.value}').join('&');
        await _secureStorage.write(key: _keyExchangeRates, value: encoded);
        
        return rates;
      }

      // 3. القيم الافتراضية
      return {
        'EGP': 1.0,
        'USD': 48.50,
        'EUR': 52.00,
        'SAR': 12.93,
        'AED': 13.20,
      };
    } catch (e) {
      safeDebugPrint('Error getting exchange rates: $e');
      return {
        'EGP': 1.0,
        'USD': 48.50,
        'EUR': 52.00,
        'SAR': 12.93,
        'AED': 13.20,
      };
    }
  }

  /// ✅ الحصول على سعر الصرف لعملة معينة
  Future<double> getExchangeRate(String currencyCode) async {
    try {
      final rates = await getExchangeRates();
      return rates[currencyCode] ?? 1.0;
    } catch (e) {
      safeDebugPrint('Error getting exchange rate: $e');
      return 1.0;
    }
  }

  /// ✅ تحويل مبلغ من عملة إلى أخرى
  Future<double> convertCurrency({
    required double amount,
    required String fromCurrency,
    required String toCurrency,
  }) async {
    if (fromCurrency == toCurrency) return amount;

    try {
      final rates = await getExchangeRates();
      final fromRate = rates[fromCurrency] ?? 1.0;
      final toRate = rates[toCurrency] ?? 1.0;
      
      // تحويل إلى العملة الأساسية ثم إلى العملة المستهدفة
      final amountInBase = amount / fromRate;
      return amountInBase * toRate;
    } catch (e) {
      safeDebugPrint('Error converting currency: $e');
      return amount;
    }
  }

  /// ✅ تنسيق العملة بالعملة الأساسية للمستخدم
  Future<String> formatInBaseCurrency(double amount) async {
    final baseCurrency = await getUserBaseCurrency();
    // ✅ إصلاح: getSymbol يأخذ معامل واحد فقط (currencyCode)
    final symbol = CurrencyService.getSymbol(baseCurrency);
    return '$symbol${amount.toStringAsFixed(2)}';
  }
}