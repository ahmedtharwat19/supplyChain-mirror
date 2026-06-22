/* // lib/widgets/reports_widgets.dart
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// شريط الفلاتر الأساسي
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class ReportFilterBar extends StatelessWidget {
  final List<Map<String, dynamic>> companies;
  final List<Map<String, dynamic>> factories;
  final String? selectedCompanyId;
  final String? selectedFactoryId;
  final ValueChanged<String?> onCompanyChanged;
  final ValueChanged<String?> onFactoryChanged;
  final bool isLoading;
  final Widget? extraFilters;

  const ReportFilterBar({
    super.key,
    required this.companies,
    required this.factories,
    required this.selectedCompanyId,
    required this.selectedFactoryId,
    required this.onCompanyChanged,
    required this.onFactoryChanged,
    required this.isLoading,
    this.extraFilters,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.grey[100],
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: selectedCompanyId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'company'.tr(),
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    isDense: true,
                  ),
                  items: companies.map((c) {
                    return DropdownMenuItem<String>(
                      value: c['id'],
                      child: Text(c['name'] ?? ''),
                    );
                  }).toList(),
                  onChanged: isLoading ? null : onCompanyChanged,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: selectedFactoryId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'factory'.tr(),
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    isDense: true,
                  ),
                  items: factories.map((f) {
                    return DropdownMenuItem<String>(
                      value: f['id'],
                      child: Text(f['name'] ?? ''),
                    );
                  }).toList(),
                  onChanged: isLoading || factories.isEmpty ? null : onFactoryChanged,
                ),
              ),
            ],
          ),
          if (extraFilters != null) ...[
            const SizedBox(height: 8),
            extraFilters!,
          ],
        ],
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// بطاقة إحصائية عامة
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final double? width;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width ?? (MediaQuery.of(context).size.width - 48) / 2,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(30)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  title,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// بطاقة KPI صغيرة
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final IconData icon;
  final String? subtitle;

  const KpiCard({
    super.key,
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withAlpha(25),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha(75)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            if (subtitle != null)
              Text(
                subtitle!,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
          ],
        ),
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// حالة عدم وجود بيانات
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class ReportEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;

  const ReportEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle!,
              style: TextStyle(color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// دالات مساعدة
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

String formatDate(DateTime? date) {
  if (date == null) return '-';
  return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
}

String formatDateTime(DateTime? date) {
  if (date == null) return '-';
  return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

Future<DateTimeRange?> showCustomDateRangePicker(
  BuildContext context, {
  DateTime? startDate,
  DateTime? endDate,
}) {
  return showDateRangePicker(
    context: context,
    firstDate: DateTime(2020),
    lastDate: DateTime.now(),
    initialDateRange: DateTimeRange(
      start: startDate ?? DateTime.now().subtract(const Duration(days: 30)),
      end: endDate ?? DateTime.now(),
    ),
    saveText: 'apply'.tr(),
    cancelText: 'cancel'.tr(),
  );
}

/// قائمة خيارات الفترات الزمنية (للDropdown) - بدون isArabic
List<DropdownMenuItem<String>> getPeriodOptions() {
  final periodKeys = ['weekly', 'monthly', 'quarterly', 'semi_annual', 'annual', 'all', 'custom'];
  return periodKeys.map((key) {
    return DropdownMenuItem<String>(
      value: key,
      child: Text(key.tr()),
    );
  }).toList();
}

/// قائمة خيارات أنواع الحركات (للDropdown) - بدون isArabic
List<DropdownMenuItem<String>> getMovementTypeOptions() {
  final typeKeys = ['all', 'purchase', 'manufacturing', 'sale', 'issue', 'return', 'adjustment'];
  return typeKeys.map((key) {
    return DropdownMenuItem<String>(
      value: key,
      child: Text(key.tr()),
    );
  }).toList();
}

/// دالة مساعدة للحصول على اسم الكيان حسب اللغة
String getLocalName(Map<String, dynamic> item, BuildContext context) {
  final isArabic = context.locale.languageCode == 'ar';
  return isArabic
      ? (item['nameAr'] ?? item['nameEn'] ?? item['id'] ?? '')
      : (item['nameEn'] ?? item['nameAr'] ?? item['id'] ?? '');
}

/// إظهار مؤشر تحميل في الزر
Widget buildLoadingButton({
  required bool isLoading,
  required VoidCallback? onPressed,
  required Widget icon,
  required String label,
}) {
  return ElevatedButton.icon(
    onPressed: isLoading ? null : onPressed,
    icon: isLoading
        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
        : icon,
    label: Text(label),
    style: ElevatedButton.styleFrom(
      minimumSize: const Size(0, 50),
    ),
  );
}

// lib/widgets/reports_widgets.dart

// ... الكود الموجود ...

/// عرض مؤشر تحميل صغير للاستخدام في الأزرار
Widget buildLoadingIndicator({double size = 20, double strokeWidth = 2}) {
  return SizedBox(
    width: size,
    height: size,
    child: CircularProgressIndicator(strokeWidth: strokeWidth),
  );
} */

// lib/widgets/reports_widgets.dart
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// شريط الفلاتر الأساسي
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class ReportFilterBar extends StatelessWidget {
  final List<Map<String, dynamic>> companies;
  final List<Map<String, dynamic>> factories;
  final String? selectedCompanyId;
  final String? selectedFactoryId;
  final ValueChanged<String?> onCompanyChanged;
  final ValueChanged<String?> onFactoryChanged;
  final bool isLoading;
  final Widget? extraFilters;

  const ReportFilterBar({
    super.key,
    required this.companies,
    required this.factories,
    required this.selectedCompanyId,
    required this.selectedFactoryId,
    required this.onCompanyChanged,
    required this.onFactoryChanged,
    required this.isLoading,
    this.extraFilters,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.grey[100],
      child: Column(
        children: [
          Row(
            children: [
              // ✅ Dropdown الشركات
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: selectedCompanyId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'company'.tr(),
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    isDense: true,
                  ),
                  items: companies.map((c) {
                    // ✅ استخدام الحقل name مباشرة (الذي تم تعبئته باللغة المناسبة)
                    return DropdownMenuItem<String>(
                      value: c['id'],
                      child: Text(
                        c['name'] ?? c['nameAr'] ?? c['nameEn'] ?? c['id'] ?? '',
                      ),
                    );
                  }).toList(),
                  onChanged: isLoading ? null : onCompanyChanged,
                ),
              ),
              const SizedBox(width: 8),
              // ✅ Dropdown المصانع
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: selectedFactoryId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'factory'.tr(),
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    isDense: true,
                  ),
                  items: factories.map((f) {
                    // ✅ استخدام الحقل name مباشرة
                    return DropdownMenuItem<String>(
                      value: f['id'],
                      child: Text(
                        f['name'] ?? f['nameAr'] ?? f['nameEn'] ?? f['id'] ?? '',
                      ),
                    );
                  }).toList(),
                  onChanged: isLoading || factories.isEmpty ? null : onFactoryChanged,
                ),
              ),
            ],
          ),
          if (extraFilters != null) ...[
            const SizedBox(height: 8),
            extraFilters!,
          ],
        ],
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// بطاقة إحصائية عامة
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final double? width;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width ?? (MediaQuery.of(context).size.width - 48) / 2,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(30)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  title.tr(), // ✅ استخدام الترجمة
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// بطاقة KPI صغيرة
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final IconData icon;
  final String? subtitle;

  const KpiCard({
    super.key,
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withAlpha(25),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha(75)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title.tr(), // ✅ استخدام الترجمة
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            if (subtitle != null)
              Text(
                subtitle!.tr(), // ✅ استخدام الترجمة
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
          ],
        ),
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// حالة عدم وجود بيانات
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class ReportEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;

  const ReportEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            title.tr(), // ✅ استخدام الترجمة
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle!.tr(), // ✅ استخدام الترجمة
              style: TextStyle(color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// دالات مساعدة - كلها تعتمد على easy_localization
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/// تنسيق التاريخ
String formatDate(DateTime? date) {
  if (date == null) return '-';
  return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
}

/// تنسيق التاريخ والوقت
String formatDateTime(DateTime? date) {
  if (date == null) return '-';
  return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

/// اختيار نطاق زمني مخصص
Future<DateTimeRange?> showCustomDateRangePicker(
  BuildContext context, {
  DateTime? startDate,
  DateTime? endDate,
}) {
  return showDateRangePicker(
    context: context,
    firstDate: DateTime(2020),
    lastDate: DateTime.now(),
    initialDateRange: DateTimeRange(
      start: startDate ?? DateTime.now().subtract(const Duration(days: 30)),
      end: endDate ?? DateTime.now(),
    ),
    saveText: 'apply'.tr(),
    cancelText: 'cancel'.tr(),
  );
}

/// قائمة خيارات الفترات الزمنية
List<DropdownMenuItem<String>> getPeriodOptions() {
  final periodKeys = ['weekly', 'monthly', 'quarterly', 'semi_annual', 'annual', 'all', 'custom'];
  return periodKeys.map((key) {
    return DropdownMenuItem<String>(
      value: key,
      child: Text(key.tr()), // ✅ استخدام الترجمة
    );
  }).toList();
}

/// قائمة خيارات أنواع الحركات
List<DropdownMenuItem<String>> getMovementTypeOptions() {
  final typeKeys = ['all', 'purchase', 'manufacturing', 'sale', 'issue', 'return', 'adjustment'];
  return typeKeys.map((key) {
    return DropdownMenuItem<String>(
      value: key,
      child: Text('movement_type_$key'.tr()), // ✅ استخدام الترجمة مع مفتاح مخصص
    );
  }).toList();
}

/// ✅ عرض مؤشر تحميل صغير للاستخدام في الأزرار
Widget buildLoadingIndicator({double size = 20, double strokeWidth = 2}) {
  return SizedBox(
    width: size,
    height: size,
    child: CircularProgressIndicator(strokeWidth: strokeWidth),
  );
}

/// ✅ زر مع مؤشر تحميل
Widget buildLoadingButton({
  required bool isLoading,
  required VoidCallback? onPressed,
  required Widget icon,
  required String label,
}) {
  return ElevatedButton.icon(
    onPressed: isLoading ? null : onPressed,
    icon: isLoading
        ? buildLoadingIndicator()
        : icon,
    label: Text(label.tr()), // ✅ استخدام الترجمة
    style: ElevatedButton.styleFrom(
      minimumSize: const Size(0, 50),
    ),
  );
}