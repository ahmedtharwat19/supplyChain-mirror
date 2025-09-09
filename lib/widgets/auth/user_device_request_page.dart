// صفحة جديدة لطلب أجهزة
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:puresip_purchasing/services/user_subscription_service.dart';

class DeviceRequestPage extends StatelessWidget {
  const DeviceRequestPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('request_device_button'.tr())),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text('max_devices_reached'.tr(namedArgs: {'max': '2'})),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _requestNewDevice(context),
              child: Text('request_device_button'.tr()),
            ),
          ],
        ),
      ),
    );
  }

  void _requestNewDevice(BuildContext context) async {
    final service = UserSubscriptionService();
    // احصل على licenseId من somewhere
    await service.requestNewDeviceSlot('license-id', 'Need new device access');
    if(!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('request_sent_to_admin'.tr())),
    );
  }
}