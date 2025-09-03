import 'package:flutter/foundation.dart';

class AppStateProvider with ChangeNotifier, DiagnosticableTreeMixin {
  bool _isAppInForeground = true;
  final Map<String, dynamic> _cachedState = {};
  
  bool get isAppInForeground => _isAppInForeground;
  Map<String, dynamic> get cachedState => _cachedState;
  
  // حفظ حالة التطبيق
  void saveState(String key, dynamic value) {
    _cachedState[key] = value;
    notifyListeners();
  }
  
  // استرجاع حالة محفوظة
  dynamic getState(String key) {
    return _cachedState[key];
  }
  
  // مسح الحالة المحفوظة
  void clearState() {
    _cachedState.clear();
    notifyListeners();
  }
  
  // تحديث حالة التطبيق (في الواجهة أو الخلفية)
  void updateAppState(bool inForeground) {
    _isAppInForeground = inForeground;
    notifyListeners();
  }
  
  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty('isAppInForeground', _isAppInForeground));
    properties.add(DiagnosticsProperty('cachedState', _cachedState));
  }
}