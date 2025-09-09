//import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:puresip_purchasing/models/manufacturing_order_model.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:puresip_purchasing/pages/manufacturing/services/manufacturing_service.dart';
import 'package:puresip_purchasing/debug_helper.dart';


class AlertService {
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  final ManufacturingService _manufacturingService;

  AlertService(this._manufacturingService) {
    _initializeNotifications();
    _startMonitoring();
  }

  void _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    
    await _notifications.initialize(initializationSettings);
  }

  void _startMonitoring() {
    // مراقبة المنتجات المنتهية الصلاحية
    _manufacturingService.getExpiringProducts().listen((orders) {
      for (final order in orders) {
        _showExpiryAlert(order);
      }
    });

    // مراقبة المخزون المنخفض - مع معالجة الخطأ
    try {
      _manufacturingService.getLowStockMaterials().listen((materials) {
        for (final material in materials) {
          _showLowStockAlert(material);
        }
      }, onError: (error) {
        safeDebugPrint('Error monitoring low stock: $error');
      });
    } catch (e) {
      safeDebugPrint('Failed to start low stock monitoring: $e');
    }
  }

void _showExpiryAlert(ManufacturingOrder order) async {
  const AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
    'expiry_alerts',
    'تنبيهات انتهاء الصلاحية',
    importance: Importance.max,
    priority: Priority.high,
  );

  const NotificationDetails platformChannelSpecifics =
      NotificationDetails(android: androidPlatformChannelSpecifics);

  await _notifications.show(
    0,
    'manufacturing.alerts.expiry_alert'.tr(),
    'manufacturing.alerts.expiry_message'.tr(
      args: [
        order.productName,
        order.runs.isNotEmpty ? order.runs.first.batchNumber : 'N/A',
        '${order.expiryDate.year}/${order.expiryDate.month}/${order.expiryDate.day}'
      ],
    ),
    platformChannelSpecifics,
  );
}



  void _showLowStockAlert(RawMaterial material) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'stock_alerts',
      'تنبيهات المخزون',
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await _notifications.show(
      1,
      'manufacturing.alerts.low_stock'.tr(),
      'manufacturing.alerts.low_stock_message'.tr(args: [material.materialName]),
      platformChannelSpecifics,
    );
  }

  Future<void> showCustomNotification(String title, String body) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'custom_alerts',
      'تنبيهات مخصصة',
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      platformChannelSpecifics,
    );
  }
  
}