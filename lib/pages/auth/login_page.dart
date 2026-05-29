import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/auth/auth_cubit.dart';
import '../../widgets/auth/login_form.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AuthCubit(),
      child: Scaffold(
        appBar: AppBar(
          title: Text('login'.tr()),
          actions: [
            PopupMenuButton<Locale>(
              icon: const Icon(Icons.language),
              // جلب اللغة الحالية للتطبيق لتحديد العنصر المختار تلقائياً
              initialValue: context.locale,
              onSelected: (locale) async {
                await context.setLocale(locale);
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                    value: Locale('en'),
                    child: Row(children: [
                      Text('🇬🇧'),
                      SizedBox(width: 8),
                      Text('English')
                    ])),
                const PopupMenuItem(
                    value: Locale('ar'),
                    child: Row(children: [
                      Text('🇸🇦'),
                      SizedBox(width: 8),
                      Text('العربية')
                    ])),
                const PopupMenuItem(
                    value: Locale('fr'),
                    child: Row(children: [
                      Text('🇫🇷'),
                      SizedBox(width: 8),
                      Text('Français')
                    ])),
                const PopupMenuItem(
                    value: Locale('es'),
                    child: Row(children: [
                      Text('🇪🇸'),
                      SizedBox(width: 8),
                      Text('Español')
                    ])),
                const PopupMenuItem(
                    value: Locale('de'),
                    child: Row(children: [
                      Text('🇩🇪'),
                      SizedBox(width: 8),
                      Text('Deutsch')
                    ])),
                const PopupMenuItem(
                    value: Locale('tr'),
                    child: Row(children: [
                      Text('🇹🇷'),
                      SizedBox(width: 8),
                      Text('Türkçe')
                    ])),
              ],
            ),
          ],
        ),
        body: const Padding(
          padding: EdgeInsets.all(16.0),
          child: LoginForm(),
        ),
      ),
    );
  }
}
