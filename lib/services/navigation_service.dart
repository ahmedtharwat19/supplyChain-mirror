// services/navigation_service.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:puresip_purchasing/debug_helper.dart';

class NavigationService {
  static final NavigationService _instance = NavigationService._internal();
  factory NavigationService() => _instance;
  NavigationService._internal();

  // ✅ خريطة لتخزين الصفحات المحملة مسبقاً
  
  // ✅ قائمة الصفحات التي سيتم تحميلها مسبقاً
  final List<String> _pagesToPreload = [
    '/companies',
    '/suppliers',
    '/items',
    '/purchase-orders',
    '/factories',
    '/reports',
    '/stock_movements',
    '/manufacturing_orders',
    '/finished_products',
  ];

  // ✅ تحميل الصفحات مسبقاً
  Future<void> preloadPages(BuildContext context) async {
    for (final route in _pagesToPreload) {
      try {
        // تحميل الصفحة في الخلفية
        await _preloadPage(route);
        safeDebugPrint('✅ Preloaded: $route');
      } catch (e) {
        safeDebugPrint('⚠️ Failed to preload $route: $e');
      }
    }
  }

  Future<void> _preloadPage(String route) async {
    // مجرد محاكاة للتحميل - يمكنك إضافة منطق حقيقي هنا
    await Future.delayed(Duration.zero);
  }

  // ✅ التنقل السريع
  void navigateTo(BuildContext context, String route, {Object? extra}) {
    // إضافة تأثير بسيط للتغذية الراجعة
    HapticFeedback.lightImpact();
    
    // التنقل الفوري
    context.push(route, extra: extra);
  }

  // ✅ العودة السريعة
  void pop(BuildContext context, {Object? result}) {
    Navigator.pop(context, result);
  }
}