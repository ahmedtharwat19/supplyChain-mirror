// widgets/receiving_dialog.dart
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class ReceivingDialog extends StatefulWidget {
  final List<Map<String, dynamic>> items;
  final String orderNumber;

  const ReceivingDialog({
    super.key,
    required this.items,
    required this.orderNumber,
  });

  @override
  State<ReceivingDialog> createState() => _ReceivingDialogState();
}

class _ReceivingDialogState extends State<ReceivingDialog> {
  late List<TextEditingController> _controllers;
  late List<Map<String, dynamic>> _items;

  @override
  void initState() {
    super.initState();
    _items = widget.items.map((item) {
      final qty = (item['quantity'] as num?)?.toDouble() ?? 0;
      return {
        ...item,
        'receivedQuantity': qty,
      };
    }).toList();
    _controllers = _items.map((item) {
      return TextEditingController(
        text: (item['receivedQuantity'] as double).toString(),
      );
    }).toList();
  }

  @override
  void dispose() {
    for (var c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _updateQuantity(int index, String value) {
    final qty = double.tryParse(value) ?? 0;
    setState(() {
      _items[index]['receivedQuantity'] = qty;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = context.locale.languageCode == 'ar';

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.inventory, color: Colors.teal),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'receiving_dialog_title'.tr(args: [widget.orderNumber]),
              style: const TextStyle(fontSize: 18),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: MediaQuery.of(context).size.height * 0.5,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      isArabic ? 'الصنف' : 'Item',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'ordered_quantity_short'.tr(),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'received_quantity_short'.tr(),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Items List
            Expanded(
              child: ListView.builder(
                itemCount: _items.length,
                itemBuilder: (ctx, index) {
                  final item = _items[index];
                  final name = isArabic
                      ? (item['nameAr'] ?? item['itemName'] ?? '')
                      : (item['nameEn'] ?? item['itemName'] ?? '');
                  final orderedQty = (item['quantity'] as num?)?.toDouble() ?? 0;

                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Colors.grey.shade200),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(
                            name,
                            style: const TextStyle(fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            orderedQty.toString(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _controllers[index],
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 4,
                              ),
                            ),
                            onChanged: (value) => _updateQuantity(index, value),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('cancel'.tr()),
        ),
        ElevatedButton.icon(
          onPressed: () {
            final result = _items.map((item) {
              return {
                'itemId': item['itemId'],
                'orderedQuantity': (item['quantity'] as num?)?.toDouble() ?? 0,
                'receivedQuantity': (item['receivedQuantity'] as num?)?.toDouble() ?? 0,
                'unitPrice': (item['unitPrice'] as num?)?.toDouble() ?? 0,
                'totalAmount': ((item['receivedQuantity'] as num?)?.toDouble() ?? 0) *
                    ((item['unitPrice'] as num?)?.toDouble() ?? 0),
              };
            }).toList();
            final total = result.fold(0.0, (sum, item) => sum + (item['totalAmount'] as double));
            Navigator.pop(context, {
              'items': result,
              'totalAmount': total,
            });
          },
          icon: const Icon(Icons.check),
          label: Text('confirm'.tr()),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
        ),
      ],
    );
  }
}