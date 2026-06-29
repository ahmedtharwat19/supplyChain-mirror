// lib/pages/no_internet_page.dart

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class NoInternetPage extends StatelessWidget {
  const NoInternetPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/images/no_internet.png', height: 200), // أضف صورة مناسبة
              const SizedBox(height: 24),
              Text(
                'no_internet_title'.tr(),
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'no_internet_message'.tr(),
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  // إعادة المحاولة (يمكنك تنفيذ فحص اتصال هنا)
                  Navigator.pop(context);
                },
                child: Text('try_again'.tr()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
