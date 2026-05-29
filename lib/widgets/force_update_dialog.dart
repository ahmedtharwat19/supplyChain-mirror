import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher_string.dart';

Future<void> showForceUpdateDialog(BuildContext context,
    {required String message}) async {
  return showDialog(
    context: context,
    barrierDismissible: false, // المستخدم مش هايقد يخرج منها
    builder: (BuildContext context) {
      return PopScope(
        canPop:
            false, // يمنع تماماً سحب الشاشة أو الضغط على زر الرجوع في أندرويد
        onPopInvokedWithResult: (didPop, result) {
          // لا نفعل شيئاً هنا لأننا نريد قفل الشاشة وإجبار المستخدم على التحديث
        },
        child: AlertDialog(
          title: Text('update_required'.tr()),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              onPressed: () async {
                final url = Platform.isAndroid
                    ? 'https://play.google.com/store/apps/details?id=com.puresip.purchasing'
                    : 'https://apps.apple.com/app/1:80836764748:ios:9b72a97f887d353649c0e9'; // غيّر الرابط
                if (await canLaunchUrlString(url)) {
                  await launchUrlString(url);
                }
              },
              child: Text('update_now'.tr()),
            ),
          ],
        ),
      );
    },
  );
}
