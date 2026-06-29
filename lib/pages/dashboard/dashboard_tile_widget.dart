/* import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import 'dashboard_metrics.dart';

class DashboardTileWidget extends StatelessWidget {
  final DashboardMetric metric;
  final Map<String, dynamic> data;
  final bool highlight;

  const DashboardTileWidget({
    super.key,
    required this.metric,
    required this.data,
    this.highlight = false,
  });

  Color _withOpacity(Color color, double opacity) {
    return color.withAlpha((opacity * 255).round());
  }

  @override
  Widget build(BuildContext context) {
    final value = metric.valueBuilder(data);
    final progress = metric.progressBuilder(data).clamp(0.0, 1.0);
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: highlight
            ? BorderSide(color: _withOpacity(Colors.orange, 0.8), width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: () => context.go(metric.route),
        /*  child: Container(
          width: isMobile ? 120 : 160,   // 160 : 200
          padding: const EdgeInsets.all(4),

          // استخدم Expanded أو Flexible داخل العمود لمنع overflow
          child: Column(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: _withOpacity(metric.color, 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  metric.icon,
                  size: isMobile ? 24 : 28,  // 28 : 32
                  color: metric.color,
                ),
              ),
              const SizedBox(height: 2),
              // FittedBox لمنع النص من التمدد الزائد
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value.isNotEmpty ? value : 'no_data'.tr(),
                  style: TextStyle(
                    fontSize: isMobile ? 18 : 22,  //20 : 26
                    fontWeight: FontWeight.bold,
                    color: metric.color,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                ),
              ),
              const SizedBox(height: 1),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  tr(metric.titleKey),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: isMobile ? 16 : 20,  //  16 : 18
                        height: 1.1,//1.3,
                      ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                ),
              ),
         //     const SizedBox(height: 8),
              // المساحة المرنة لدفع شريط التقدم لأسفل
              Expanded(
                // التغيير الرئيسي هنا
                child: Container(), // حاوية فارغة تأخذ المساحة المتبقية
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: _withOpacity(Colors.grey, 0.2),
                    color: metric.color,
                    minHeight: 8,
                  ),
                ),
              ),
            ],
          ),
        ), */
        child: Container(
          //height: 300, // اضبط هذا حسب التصميم العام
           width: isMobile ? 120 : 160,   // 160 : 200
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
          //  crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: _withOpacity(metric.color, 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      metric.icon,
                      size: isMobile ? 24 : 28,
                      color: metric.color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      value.isNotEmpty ? value : 'no_data'.tr(),
                      style: TextStyle(
                        fontSize: isMobile ? 18 : 22,
                        fontWeight: FontWeight.bold,
                        color: metric.color,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      tr(metric.titleKey),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontSize: isMobile ? 16 : 20,
                            height: 1.1,
                          ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                    ),
                  ),
                ],
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: _withOpacity(Colors.grey, 0.2),
                  color: metric.color,
                  minHeight: 8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
 */

// dashboard_tile_widget.dart - نسخة سريعة
// dashboard_tile_widget.dart
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:puresip_purchasing/services/navigation_service.dart';
import 'dashboard_metrics.dart';

class DashboardTileWidget extends StatelessWidget {
  final DashboardMetric metric;
  final Map<String, dynamic> data;
  final bool highlight;

  const DashboardTileWidget({
    super.key,
    required this.metric,
    required this.data,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final value = metric.valueBuilder(data);
    final progress = metric.progressBuilder(data).clamp(0.0, 1.0);
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Card(
      elevation: highlight ? 6 : 2,
      margin: const EdgeInsets.all(8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: highlight
            ? BorderSide(color: Colors.orange.withAlpha(204), width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: () {
          NavigationService().navigateTo(context, metric.route);
        },
        child: Container(
          width: isMobile ? 120 : 160,
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: metric.color.withAlpha(26),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      metric.icon,
                      size: isMobile ? 24 : 28,
                      color: metric.color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      value.isNotEmpty ? value : 'no_data'.tr(),
                      style: TextStyle(
                        fontSize: isMobile ? 18 : 22,
                        fontWeight: FontWeight.bold,
                        color: metric.color,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      tr(metric.titleKey),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: isMobile ? 14 : 16,
                        height: 1.1,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                    ),
                  ),
                ],
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.grey.withAlpha(51),
                  color: metric.color,
                  minHeight: 6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}