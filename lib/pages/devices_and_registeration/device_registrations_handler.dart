
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:puresip_purchasing/pages/devices_and_registeration/device_registration_page.dart';
import 'package:puresip_purchasing/services/user_subscription_service.dart';
import 'package:puresip_purchasing/pages/devices_and_registeration/user_license_request.dart';

// صفحة معالجة تسجيل الجهاز
class DeviceRegistrationHandler extends StatelessWidget {
  const DeviceRegistrationHandler({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<SubscriptionResult>(
        future: UserSubscriptionService().checkUserSubscription(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('error_loading_subscription'.tr()));
          }

          final result = snapshot.data!;

          if (result.isValid) {
            // إذا كان الاشتراك صالحًا، انتقل إلى Dashboard
            WidgetsBinding.instance.addPostFrameCallback((_) {
              context.go('/dashboard');
            });
            return const Center(child: CircularProgressIndicator());
          }

          if (result.needsDeviceRegistration && result.licenseId != null) {
            // إذا كان يحتاج إلى تسجيل جهاز
            return DeviceRegistrationPage(licenseId: result.licenseId!);
          }

          // إذا لم يكن هناك ترخيص صالح
          return const UserLicenseRequestPage();
        },
      ),
    );
  }
}
