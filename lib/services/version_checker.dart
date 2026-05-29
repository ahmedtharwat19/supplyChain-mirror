import 'package:firebase_remote_config/firebase_remote_config.dart';
import '../debug_helper.dart';

class VersionChecker {
  static final FirebaseRemoteConfig remoteConfig = FirebaseRemoteConfig.instance;

  // الدالة اللي هنناديها مرة واحدة عند بداية التشغيل
  static Future<void> init() async {
    try {
      await remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(minutes: 1),
          minimumFetchInterval: const Duration(hours: 1), // يحدّث كل ساعة عشان ما يضغطش على ال API
        ),
      );
      await remoteConfig.fetchAndActivate();
    } catch (e) {
      safeDebugPrint("⚠️ Error initializing remote config: $e");
    }
  }

  // جلب الحد الأدنى للنسخة من Firebase
  static String getMinVersion() => remoteConfig.getString('minimum_version');
  static String getLatestVersion() => remoteConfig.getString('latest_version');
  static String getForceUpdateMessage() => remoteConfig.getString('force_update_message');
}