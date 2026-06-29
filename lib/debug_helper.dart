import 'package:flutter/foundation.dart';

void safeDebugPrint(dynamic message) {
  try {
    if (message == null) {
      debugPrint('⚠️ safeDebugPrint: Tried to print NULL');
    } else {
      debugPrint(message.toString());
    }
  } catch (e, stack) {
    debugPrint('❌ safeDebugPrint error: $e');
    debugPrint(stack.toString());
  }
}
