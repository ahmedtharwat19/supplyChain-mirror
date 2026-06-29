// pages/reset_page.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';

class ResetPage extends StatelessWidget {
  const ResetPage({super.key});

  Future<void> _resetAndLogout(BuildContext context) async {
    // مسح جميع البيانات
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    
    const secureStorage = FlutterSecureStorage();
    await secureStorage.deleteAll();
    
    await FirebaseAuth.instance.signOut();
    
    if (context.mounted) {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('reset_app'))),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.warning_amber_rounded, size: 80, color: Colors.orange),
            const SizedBox(height: 20),
            Text(tr('reset_app_message'), textAlign: TextAlign.center),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () => _resetAndLogout(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              ),
              child: Text(tr('reset_and_logout'), style: const TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}