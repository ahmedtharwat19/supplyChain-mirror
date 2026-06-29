// lib/services/locale_service.dart
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleService {
  static const String _languageKey = 'app_language';
  
  // الحصول على اللغة الابتدائية عند بدء التشغيل
  static Future<Locale> getStartLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLanguage = prefs.getString(_languageKey);
    
    // إذا كان هناك لغة محفوظة
    if (savedLanguage != null) {
      if (savedLanguage == 'en') {
        return const Locale('en', 'US');
      } else if (savedLanguage == 'ar') {
        return const Locale('ar', 'EG');
      }
    }
    
    // محاولة الحصول على لغة الجهاز
    final deviceLocale = await _getSafeDeviceLocale();
    
    // إذا كانت لغة الجهاز إنجليزية بأي صيغة، استخدم en-US
    if (deviceLocale.languageCode == 'en') {
      return const Locale('en', 'US');
    }
    
    // افتراضياً العربية
    return const Locale('ar', 'EG');
  }
  
  // الحصول على لغة الجهاز بأمان
  static Future<Locale> _getSafeDeviceLocale() async {
    try {
      final String systemLocale = await _getSystemLocale();
      if (systemLocale.startsWith('en')) {
        return const Locale('en', 'US');
      }
      return const Locale('ar', 'EG');
    } catch (e) {
      return const Locale('ar', 'EG');
    }
  }
  
  static Future<String> _getSystemLocale() async {
    // محاولة الحصول على لغة النظام
    try {
      // هذه الطريقة تعمل على معظم الأجهزة
      return PlatformDispatcher.instance.locale.toString();
    } catch (e) {
      return 'ar_EG';
    }
  }
  
  // ✅ تغيير اللغة إلى العربية - الطريقة الآمنة
  static Future<void> setArabic(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, 'ar');
    
    // التحقق من أن الـ Context لا يزال صالحاً (mounted)
    if (context.mounted) {
      await context.setLocale(const Locale('ar', 'EG'));
    }
  }
  
  // ✅ تغيير اللغة إلى الإنجليزية - الطريقة الآمنة
  static Future<void> setEnglish(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, 'en');
    
    // التحقق من أن الـ Context لا يزال صالحاً (mounted)
    if (context.mounted) {
      await context.setLocale(const Locale('en', 'US'));
    }
  }
  
  // ✅ طريقة بديلة لتغيير اللغة بدون استخدام BuildContext في async gap
  static Future<void> setLanguageWithoutContext(String languageCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, languageCode);
    // ملاحظة: هذا لا يغير اللغة مباشرة، يحتاج إلى إعادة تشغيل التطبيق
  }
  
  // ✅ الحصول على اللغة المحفوظة (للاستخدام خارج الـ Widget)
  static Future<String> getSavedLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_languageKey) ?? 'ar';
  }
  
  // التحقق إذا كانت اللغة عربية (متزامن - آمن للاستخدام داخل build)
  static bool isArabic(BuildContext context) {
    return context.locale.languageCode == 'ar';
  }
  
  // التحقق إذا كانت اللغة إنجليزية (متزامن - آمن للاستخدام داخل build)
  static bool isEnglish(BuildContext context) {
    return context.locale.languageCode == 'en';
  }
  
  // الحصول على النص حسب اللغة الحالية (متزامن - آمن)
  static String getText(BuildContext context, String arText, String enText) {
    return isArabic(context) ? arText : enText;
  }
}