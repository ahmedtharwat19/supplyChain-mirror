/* import 'package:flutter/material.dart';

class SubscriptionNotifier {
  /// تنبيه بانتهاء الاشتراك
  static void showExpiredDialog(BuildContext context, {required DateTime expiryDate}) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Subscription Expired"),
        content: Text("Your subscription expired on ${expiryDate.toLocal()}"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  /// تحذير قبل الانتهاء
  static void showWarning(BuildContext context, {required String timeLeft}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Your subscription will expire in $timeLeft days."),
        backgroundColor: Colors.orange,
      ),
    );
    
  }
}
 */

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
//import 'package:go_router/go_router.dart';

class SubscriptionNotifier {
  /// تنبيه بانتهاء الاشتراك
  static void showExpiredDialog(BuildContext context, {required DateTime expiryDate}) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("subscription_expired".tr()),
        content: Text(
          "subscription_expired_message_date".tr(
            namedArgs: {
              'date': '${expiryDate.year}-${expiryDate.month.toString().padLeft(2, '0')}-${expiryDate.day.toString().padLeft(2, '0')}'
            }
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text("ok".tr()),
          ),
        ],
      ),
    );
  }

  /// تحذير قبل الانتهاء
  static void showWarning(BuildContext context, {required String timeLeft}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "subscription_warning_message".tr(
            namedArgs: {'time_left': timeLeft}
          ),
        ),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: "renew".tr(),
          textColor: Colors.white,
          onPressed: () {
            // Navigate to renewal page
            // context.push('/license/renew');
           // context.go( '/license/renew' );
          },
        ),
      ),
    );
  }
}