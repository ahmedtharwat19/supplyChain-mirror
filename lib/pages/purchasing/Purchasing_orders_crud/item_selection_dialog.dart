import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:puresip_purchasing/models/item.dart';

class ItemSelectionDialog extends StatefulWidget {
  final List<Item> allItems;
  final List<String> preSelectedItems;

  const ItemSelectionDialog({
    super.key,
    required this.allItems,
    required this.preSelectedItems,
  });

  @override
  State<ItemSelectionDialog> createState() => _ItemSelectionDialogState();
}

class _ItemSelectionDialogState extends State<ItemSelectionDialog> {
  final _searchController = TextEditingController();
  List<Item> _filteredItems = [];
  final Set<String> _selectedItems = {};

  @override
  void initState() {
    super.initState();
    _filteredItems = widget.allItems;
    _selectedItems.addAll(widget.preSelectedItems);
    _searchController.addListener(_filterItems);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterItems() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredItems = widget.allItems.where((item) {
        return item.nameAr.toLowerCase().contains(query) ||
            item.nameEn.toLowerCase().contains(query);
      }).toList();
    });
  }

/* 
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Items'),
      content: SizedBox(
        width: 400, // يمكن تعديله حسب الحاجة
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search Items',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 300, // ارتفاع مخصص للقائمة
              child: ListView.builder(
                itemCount: _filteredItems.length,
                itemBuilder: (context, index) {
                  final item = _filteredItems[index];
                  return CheckboxListTile(
                    title: Text('${item.nameAr} (${item.unit})'),
                    subtitle: Text(
                      '${item.unitPrice.toStringAsFixed(2)} ${'currency'.tr()}',
                    ),
                    value: _selectedItems.contains(item.itemId),
                    onChanged: (selected) {
                      setState(() {
                        if (selected == true) {
                          _selectedItems.add(item.itemId);
                        } else {
                          _selectedItems.remove(item.itemId);
                        }
                      });
                    },
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
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final selected = widget.allItems
                .where((item) => _selectedItems.contains(item.itemId))
                .toList();
            Navigator.pop(context, selected);
          },
          child: const Text('Confirm'),
        ),
      ],
    );
  }
 */
/*   @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Items'),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
          maxWidth: 400,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  labelText: 'Search Items',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              const SizedBox(height: 16),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _filteredItems.length,
                itemBuilder: (context, index) {
                  final item = _filteredItems[index];
                  return CheckboxListTile(
                    title: Text('${item.nameAr} (${item.unit})'),
                    subtitle: Text(
                      '${item.unitPrice.toStringAsFixed(2)} ${'currency'.tr()}',
                    ),
                    value: _selectedItems.contains(item.itemId),
                    onChanged: (selected) {
                      setState(() {
                        if (selected == true) {
                          _selectedItems.add(item.itemId);
                        } else {
                          _selectedItems.remove(item.itemId);
                        }
                      });
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final selected = widget.allItems
                .where((item) => _selectedItems.contains(item.itemId))
                .toList();
            Navigator.pop(context, selected);
          },
          child: const Text('Confirm'),
        ),
      ],
    );
  }
 */
@override
Widget build(BuildContext context) {
  return AlertDialog(
    title: const Text('Select Items'),
    content: SizedBox(
      width: 400,
      height: MediaQuery.of(context).size.height * 0.6,  // تحديد ارتفاع واضح
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              labelText: 'Search Items',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(  // هنا Expanded مهم جداً ليستغل المساحة المتبقية
            child: ListView.builder(
              itemCount: _filteredItems.length,
              itemBuilder: (context, index) {
                final item = _filteredItems[index];
                return CheckboxListTile(
                  title: Text('${item.nameAr} (${item.unit})'),
                  subtitle: Text(
                    '${item.unitPrice.toStringAsFixed(2)} ${'currency'.tr()}',
                  ),
                  value: _selectedItems.contains(item.itemId),
                  onChanged: (selected) {
                    setState(() {
                      if (selected == true) {
                        _selectedItems.add(item.itemId);
                      } else {
                        _selectedItems.remove(item.itemId);
                      }
                    });
                  },
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
        child: const Text('Cancel'),
      ),
      ElevatedButton(
        onPressed: () {
          final selected = widget.allItems
              .where((item) => _selectedItems.contains(item.itemId))
              .toList();
          Navigator.pop(context, selected);
        },
        child: const Text('Confirm'),
      ),
    ],
  );
}

}
