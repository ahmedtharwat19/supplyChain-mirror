/* import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class LicenseNotifications {
  static final _notifications = FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings();

    await _notifications.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
    );
  }

  static Future<void> sendApprovalNotification({
    required String userId,
    required String licenseKey,
    required String requestId,
  }) async {
    // استخدم هذا البديل الحديث
    await FirebaseMessaging.instance.subscribeToTopic('user_$userId');

    // أو استخدم الإشعارات المحلية فقط
    _showLocalNotification(
      title: 'license_approved_title'.tr(),
      body:  'license_approved_body'.tr(args: [licenseKey]),//'Your license $licenseKey has been approved',
    );
  }

  static Future<void> _showLocalNotification({
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'license_channel',
      'License Notifications',
      importance: Importance.high,
    );

    await _notifications.show(
      0,
      title,
      body,
      const NotificationDetails(android: androidDetails),
    );
  }
  /* static Future<void> sendApprovalNotification({
    required String userId,
    required String licenseKey,
    required String requestId,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'license_channel',
      'License Notifications',
      channelDescription: 'Notifications for license status changes',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails();
    
    await _notifications.show(
      0,
      'license_approved_title'.tr(),
      'license_approved_body'.tr(args: [licenseKey]),
      const NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      ),
      payload: 'license/$licenseKey',
    );

    // Also send via FCM for background delivery
    await FirebaseMessaging.instance.subscribeToTopic('user_$userId');
      /*       to: '/topics/user_$userId',
            data: {
              'type': 'license_approved',
              'licenseKey': licenseKey,
              'requestId': requestId,
            },
          ); */
  } */
}
 */
/* 
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class LicenseNotifications {
  static final _notifications = FlutterLocalNotificationsPlugin();
  static final _fcm = FirebaseMessaging.instance;

  static Future<void> initialize() async {
    // تهيئة الإشعارات المحلية
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _notifications.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // تهيئة FCM
    await _setupFCM();
  }

  static Future<void> _setupFCM() async {
    await _fcm.requestPermission();
    FirebaseMessaging.onMessage.listen(showFcmNotification);
  }

  static void _onNotificationTap(NotificationResponse response) {
    // معالجة النقر على الإشعار
    // يمكنك استخدام Navigator هنا للتنقل للصفحة المناسبة
  }

  static Future<void> sendApprovalNotification({
    required String userId,
    required String licenseKey,
    required String requestId,
  }) async {
    // إرسال إشعار محلي
    await _showLocalNotification(
      title: 'license_approved_title'.tr(),
      body: 'license_approved_body'.tr(args: [licenseKey]),
      payload: 'license/$licenseKey',
    );

    // إرسال إشعار FCM
    await _sendFcmNotification(
      topic: 'user_$userId',
      data: {
        'type': 'license_approved',
        'licenseKey': licenseKey,
        'requestId': requestId,
      },
    );
  }

  static Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    // Changed from const to final
    final androidDetails = AndroidNotificationDetails(
      'license_channel',
      'License Notifications',
      channelDescription: 'license_notifications_channel_desc'.tr(),
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    final iosDetails = const DarwinNotificationDetails();

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch % 100000,
      title,
      body,
      NotificationDetails(
        // Removed const
        android: androidDetails,
        iOS: iosDetails,
      ),
      payload: payload,
    );
  }

  static Future<void> showFcmNotification(RemoteMessage message) async {
    await _showLocalNotification(
      title: message.notification?.title ?? 'new_notification'.tr(),
      body: message.notification?.body ?? 'new_license_notification'.tr(),
      payload: message.data['type'],
    );
  }

  static Future<void> _sendFcmNotification({
    required String topic,
    required Map<String, dynamic> data,
  }) async {
    await _fcm.subscribeToTopic(topic);
    // يمكنك هنا إضافة كود لإرسال الإشعار عبر سيرفرك الخاص إذا لزم الأمر
  }

  static Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }
}
 */

import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class LicenseNotifications {
  static final _notifications = FlutterLocalNotificationsPlugin();
  static final _fcm = FirebaseMessaging.instance;

  /// تهيئة الإشعارات المحلية و FCM
  static Future<void> initialize() async {
    // إعدادات Android
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // إعدادات iOS
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // تهيئة الإشعارات المحلية
    await _notifications.initialize(
      settings: const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // تهيئة FCM
    await _setupFCM();
  }

  /// تهيئة Firebase Cloud Messaging
  static Future<void> _setupFCM() async {
    await _fcm.requestPermission();
    FirebaseMessaging.onMessage.listen(showFcmNotification);
  }

  /// عند النقر على الإشعار
  static void _onNotificationTap(NotificationResponse response) {
    // معالجة النقر على الإشعار
    // يمكن استخدام Navigator هنا للتنقل للصفحة المناسبة
  }

  /// إرسال إشعار موافقة على الترخيص
  static Future<void> sendApprovalNotification({
    required String userId,
    required String licenseKey,
    required String requestId,
  }) async {
    // إشعار محلي
    await _showLocalNotification(
      title: 'license_approved_title'.tr(),
      body: 'license_approved_body'.tr(args: [licenseKey]),
      payload: 'license/$licenseKey',
    );

    // إشعار FCM
    await _sendFcmNotification(
      topic: 'user_$userId',
      data: {
        'type': 'license_approved',
        'licenseKey': licenseKey,
        'requestId': requestId,
      },
    );
  }

  /// عرض إشعار محلي
  static Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      'license_channel',
      'License Notifications',
      channelDescription: 'license_notifications_channel_desc'.tr(),
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails();

    await _notifications.show(
      id: DateTime.now().millisecondsSinceEpoch % 100000,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      ),
      payload: payload,
    );
  }

  /// عرض إشعار وارد من FCM
  static Future<void> showFcmNotification(RemoteMessage message) async {
    await _showLocalNotification(
      title: message.notification?.title ?? 'new_notification'.tr(),
      body: message.notification?.body ?? 'new_license_notification'.tr(),
      payload: message.data['type'],
    );
  }

  /// إرسال إشعار عبر FCM إلى topic
  static Future<void> _sendFcmNotification({
    required String topic,
    required Map<String, dynamic> data,
  }) async {
    await _fcm.subscribeToTopic(topic);
    // إذا كان لديك سيرفر لإرسال FCM، يمكن استدعاؤه هنا
  }

  /// إلغاء جميع الإشعارات
  static Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }
}