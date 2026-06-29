import 'package:flutter/material.dart';

enum SnackType { success, warning, error, info }

void showAppSnack(
  BuildContext context,
  String message, {
  SnackType type = SnackType.info,
}) {
  ScaffoldMessenger.of(context).clearSnackBars();

  final theme = Theme.of(context);
  IconData icon;
  Color bgColor;

  switch (type) {
    case SnackType.success:
      icon = Icons.check_circle;
      bgColor = Colors.green;
      break;
    case SnackType.warning:
      icon = Icons.warning;
      bgColor = Colors.orange;
      break;
    case SnackType.error:
      icon = Icons.error;
      bgColor = Colors.red;
      break;
    case SnackType.info:
   
      icon = Icons.info;
      bgColor = theme.colorScheme.primary;
      break;
  }

  final snackBar = SnackBar(
    content: Row(
      children: [
        Icon(icon, color: Colors.white),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ],
    ),
    backgroundColor: bgColor,
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    duration: const Duration(seconds: 3),
    margin: const EdgeInsets.all(16),
  );

  ScaffoldMessenger.of(context).showSnackBar(snackBar);
}




/*

إذا أردت أن يتغير لون info تلقائيًا حسب الثيم (مثلاً داكن يستخدم لون أفتح)، بإمكانك تعديل هذا السطر:
bgColor = theme.brightness == Brightness.dark
    ? Colors.tealAccent.shade700
    : theme.colorScheme.primary;
*/