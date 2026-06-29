import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/auth/signup_form.dart';

class SignupPage extends StatelessWidget {
  const SignupPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('signup'.tr()),
                  actions: [
            PopupMenuButton<Locale>(
              icon: const Icon(Icons.language),
              onSelected: (locale) {
                context.setLocale(locale);
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: const Locale('en'),
                  child: Text('language_en'.tr()),
                ),
                PopupMenuItem(
                  value: const Locale('ar'),
                  child: Text('language_ar'.tr()),
                ),
              ],
            ),
          ],
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/login'), // الرجوع لصفحة تسجيل الدخول
        ),
      ),
      body: const SignupForm(),
    );
  }
}


/* // lib/pages/auth/signup_page.dart

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/auth/auth_cubit.dart';
import '../../widgets/auth/signup_form.dart';

class SignupPage extends StatelessWidget {
  const SignupPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AuthCubit(),
      child: Scaffold(
        appBar: AppBar(title: Text('signup'.tr())),
        body: const Padding(
          padding: EdgeInsets.all(16),
          child: SignupForm(),
        ),
      ),
    );
  }
}
 */