import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class FilterBar extends StatelessWidget {
  final List<Map<String, dynamic>> allCompanies;
  final List<String> allSuppliers;
  final List<String> allItems;
  final List<Map<String, dynamic>> allFactories;

  final String? selectedCompany;
  final String? selectedSupplier;
  final String? selectedItem;
  final List<String> selectedFactories;
  final DateTime? startDate;
  final DateTime? endDate;

  final void Function(String?) onCompanyChanged;
  final void Function(String?) onSupplierChanged;
  final void Function(String?) onItemChanged;
  final void Function(List<String>) onFactoriesChanged;
  final void Function(DateTime?, DateTime?) onDateRangePick;
  final VoidCallback onClearFilters;

  const FilterBar({
    super.key,
    required this.allCompanies,
    required this.allSuppliers,
    required this.allItems,
    required this.allFactories,
    required this.selectedCompany,
    required this.selectedSupplier,
    required this.selectedItem,
    required this.selectedFactories,
    required this.startDate,
    required this.endDate,
    required this.onCompanyChanged,
    required this.onSupplierChanged,
    required this.onItemChanged,
    required this.onFactoriesChanged,
    required this.onDateRangePick,
    required this.onClearFilters,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildPopupButton(
          context: context,
          label: 'select_company'.tr(),
          selectedValue: selectedCompany != null
              ? allCompanies.firstWhere(
                  (e) => e['id'] == selectedCompany,
                  orElse: () => {'nameEn': ''},
                )['nameEn']
              : null,
          items: allCompanies
              .map((c) => PopupMenuItem<String>(
                    value: c['id'],
                    child: Text(c['nameEn']),
                  ))
              .toList(),
          onSelected: onCompanyChanged,
        ),
        _buildPopupButton(
          context: context,
          label: 'supplier'.tr(),
          selectedValue: selectedSupplier,
          items: allSuppliers
              .map((s) => PopupMenuItem<String>(
                    value: s,
                    child: Text(s),
                  ))
              .toList(),
          onSelected: onSupplierChanged,
        ),
        _buildPopupButton(
          context: context,
          label: 'item'.tr(),
          selectedValue: selectedItem,
          items: allItems
              .map((i) => PopupMenuItem<String>(
                    value: i,
                    child: Text(i),
                  ))
              .toList(),
          onSelected: onItemChanged,
        ),
        _buildPopupButton(
          context: context,
          label: 'factory'.tr(),
          selectedValue: selectedFactories.isNotEmpty
              ? selectedFactories.map((id) {
                  final factory = allFactories.firstWhere(
                    (f) => f['id'] == id,
                    orElse: () => {'nameEn': ''},
                  );
                  return factory['nameEn'];
                }).join(', ')
              : null,
          items: allFactories
              .map((f) => PopupMenuItem<String>(
                    value: f['id'],
                    child: Text(f['nameEn']),
                  ))
              .toList(),
          onSelected: (val) {
            if (val != null && !selectedFactories.contains(val)) {
              final updated = [...selectedFactories, val];
              onFactoriesChanged(updated);
            }
          },
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.date_range),
          label: Text(
            startDate == null
                ? 'dateRange'.tr()
                : '${DateFormat('dd/MM/yyyy').format(startDate!)} - ${DateFormat('dd/MM/yyyy').format(endDate!)}',
          ),
          onPressed: () async {
            final range = await showDateRangePicker(
              context: context,
              firstDate: DateTime(2023),
              lastDate: DateTime.now(),
            );
            if (range != null) {
              onDateRangePick(range.start, range.end);
            }
          },
        ),
        TextButton.icon(
          onPressed: onClearFilters,
          icon: const Icon(Icons.clear),
          label: Text('clear_filters'.tr()),
        ),
      ],
    );
  }

  Widget _buildPopupButton({
    required BuildContext context,
    required String label,
    required String? selectedValue,
    required List<PopupMenuEntry<String>> items,
    required void Function(String?) onSelected,
  }) {
    final hasItems = items.isNotEmpty;

    return ElevatedButton(
      onPressed: hasItems
          ? () async {
              final RenderBox button = context.findRenderObject() as RenderBox;
              final RenderBox overlay =
                  Overlay.of(context).context.findRenderObject() as RenderBox;
              final RelativeRect position = RelativeRect.fromRect(
                Rect.fromPoints(
                  button.localToGlobal(Offset.zero, ancestor: overlay),
                  button.localToGlobal(button.size.bottomRight(Offset.zero),
                      ancestor: overlay),
                ),
                Offset.zero & overlay.size,
              );

              final selected = await showMenu<String>(
                context: context,
                position: position,
                items: items,
              );

              if (selected != null) onSelected(selected);
            }
          : null,
      child: Text(
        selectedValue != null ? '$label: $selectedValue' : label,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
