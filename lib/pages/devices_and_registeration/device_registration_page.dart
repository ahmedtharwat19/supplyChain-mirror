
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:puresip_purchasing/services/user_subscription_service.dart';


// صفحة تسجيل الجهاز
class DeviceRegistrationPage extends StatefulWidget {
  final String licenseId;

  const DeviceRegistrationPage({super.key, required this.licenseId});

  @override
  State<DeviceRegistrationPage> createState() => _DeviceRegistrationPageState();
}

class _DeviceRegistrationPageState extends State<DeviceRegistrationPage> {
  final UserSubscriptionService _service = UserSubscriptionService();
  bool _isRegistering = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('device_registration'.tr())),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('device_not_registered'.tr(), 
                 style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 20),
            Text('register_device_description'.tr(), textAlign: TextAlign.center),
            const SizedBox(height: 30),
            if (_isRegistering)
              const CircularProgressIndicator()
            else
              ElevatedButton(
                onPressed: _registerDevice,
                child: Text('register_device'.tr()),
              ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () => context.push('/device-management', extra: widget.licenseId),
              child: Text('manage_devices'.tr()),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _registerDevice() async {
    setState(() => _isRegistering = true);
    
    final success = await _service.registerDeviceFingerprint(widget.licenseId);
    
    setState(() => _isRegistering = false);

    if (success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('device_registered_successfully'.tr())),
        );
        context.go('/dashboard');
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('failed_to_register_device'.tr())),
        );
      }
    }
  }
}

