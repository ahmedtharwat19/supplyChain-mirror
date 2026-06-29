import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class CompanyAddedPage extends StatelessWidget {
  final String nameEn;
  final String docId;

  const CompanyAddedPage({
    super.key,
    required this.nameEn,
    required this.docId,
  });

  @override
  Widget build(BuildContext context) {
    // فك ترميز الاسم العربي في حال احتوى على رموز خاصة
    final decodednameEn = Uri.decodeComponent(nameEn);

    return Scaffold(
      appBar: AppBar(title: Text('company_added'.tr())),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                child: Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 100,
                ),
              ),
              const SizedBox(height: 30),
              Text(
                '✅ ${'company_added_successfully'.tr()}',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Text(
                '🧾 ${tr('company_name')} : $decodednameEn',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 10),
              Text(
                '🆔 ${tr('companyId')}: $docId',
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 40),
              Center(
                child: ElevatedButton.icon(
                  onPressed: () {
                    context.go('/companies');
                  },
                  icon: const Icon(Icons.home),
                  label: Text('back_to_home'.tr()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
