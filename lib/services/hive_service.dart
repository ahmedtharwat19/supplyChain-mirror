import 'package:hive/hive.dart';

class HiveService {
  static const String _boxName = "licenseBox";
  static const String _key = "licenseKey";

  static Future<void> saveLicense(String license) async {
    final box = await Hive.openBox(_boxName);
    await box.put(_key, license);
  }

  static Future<String?> getLicense() async {
    final box = await Hive.openBox(_boxName);
    return box.get(_key);
  }

  static Future<void> clearLicense() async {
    final box = await Hive.openBox(_boxName);
    await box.delete(_key);
  }
}
