import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:puresip_purchasing/models/additional_item.dart';
import 'package:puresip_purchasing/widgets/app_scaffold.dart';

class AdditionalItemsPage extends StatefulWidget {
  const AdditionalItemsPage({super.key});

  @override
  State<AdditionalItemsPage> createState() => _AdditionalItemsPageState();
}

class _AdditionalItemsPageState extends State<AdditionalItemsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isInitializing = false;
  bool _isLoading = true;

  // تخزين البيانات
  List<AdditionalItem> _conditions = [];
  List<AdditionalItem> _documents = [];
  List<AdditionalItem> _notes = [];

  String get _userId => _auth.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initializePage();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initializePage() async {
    if (_userId.isEmpty) return;
    await _loadAllData();
    setState(() => _isLoading = false);
  }

  Future<void> _loadAllData() async {
    await Future.wait([
      _loadItemsByType(AdditionalItemType.condition),
      _loadItemsByType(AdditionalItemType.document),
      _loadItemsByType(AdditionalItemType.note),
    ]);
  }

// في دالة _loadItemsByType
  Future<void> _loadItemsByType(AdditionalItemType type) async {
    try {
      final snapshot = await _firestore
          .collection('additional_items')
          .where('userId', isEqualTo: _userId)
          .where('type', isEqualTo: type.asString) // ✅ استخدام asString
          .orderBy('order')
          .get();

      final items = snapshot.docs
          .map((doc) => AdditionalItem.fromMap(doc.data(), doc.id))
          .toList();

      setState(() {
        switch (type) {
          case AdditionalItemType.condition:
            _conditions = items;
            break;
          case AdditionalItemType.document:
            _documents = items;
            break;
          case AdditionalItemType.note:
            _notes = items;
            break;
        }
      });
    } catch (e) {
      debugPrint('Error loading items for $type: $e');
    }
  }

// يمكن حذف دالة _getTypeString لأننا نستخدم asString
/*   String _getTypeString(AdditionalItemType type) {
    switch (type) {
      case AdditionalItemType.condition:
        return 'condition';
      case AdditionalItemType.document:
        return 'document';
      case AdditionalItemType.note:
        return 'note';
    }
  }
 */

  Future<bool> _checkIfAnyDataExists() async {
    final snapshot = await _firestore
        .collection('additional_items')
        .where('userId', isEqualTo: _userId)
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  Future<void> _initializeDefaultItems() async {
    if (_userId.isEmpty) return;
    if (_isInitializing) return;

    final hasData = await _checkIfAnyDataExists();
    if (hasData) {
      await _loadAllData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Data already exists')),
        );
      }
      return;
    }

    setState(() => _isInitializing = true);
    try {
      await _createDefaultItems();
      await _loadAllData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Default items initialized successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isInitializing = false);
    }
  }

  Future<void> _createDefaultItems() async {
    final List<Map<String, String>> defaultItems = [
      {
        'titleAr': 'شروط إضافية 1',
        'titleEn': 'Additional Condition 1',
        'type': 'condition'
      },
      {
        'titleAr': 'شروط إضافية 2',
        'titleEn': 'Additional Condition 2',
        'type': 'condition'
      },
      {
        'titleAr': 'شروط إضافية 3',
        'titleEn': 'Additional Condition 3',
        'type': 'condition'
      },
      {
        'titleAr': 'فاتورة أصلية',
        'titleEn': 'Original Invoice',
        'type': 'document'
      },
      {
        'titleAr': 'شهادة تحليل',
        'titleEn': 'Certificate of Analysis',
        'type': 'document'
      },
      {'titleAr': 'رقم الدفعة', 'titleEn': 'Batch Number', 'type': 'document'},
      {
        'titleAr': 'تاريخ الصلاحية',
        'titleEn': 'Expiry Date',
        'type': 'document'
      },
      {
        'titleAr': 'قائمة التعبئة',
        'titleEn': 'Packing List',
        'type': 'document'
      },
      {'titleAr': 'ملاحظة 1', 'titleEn': 'Note 1', 'type': 'note'},
      {'titleAr': 'ملاحظة 2', 'titleEn': 'Note 2', 'type': 'note'},
      {'titleAr': 'ملاحظة 3', 'titleEn': 'Note 3', 'type': 'note'},
    ];

    final batch = _firestore.batch();
    for (int i = 0; i < defaultItems.length; i++) {
      final item = defaultItems[i];
      final docRef = _firestore.collection('additional_items').doc();
      batch.set(docRef, {
        'userId': _userId,
        'titleAr': item['titleAr'],
        'titleEn': item['titleEn'],
        'descriptionAr': '',
        'descriptionEn': '',
        'type': item['type'],
        'isActive': true,
        'order': i,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'manage_conditions_documents'.tr(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildMainContent(),
      floatingActionButton: _isInitializing
          ? null
          : FloatingActionButton(
              onPressed: () => _showAddDialog(_getCurrentType()),
              child: const Icon(Icons.add),
            ),
    );
  }

  Widget _buildMainContent() {
    // عرض زر التهيئة إذا كانت جميع القوائم فارغة
    if (_conditions.isEmpty &&
        _documents.isEmpty &&
        _notes.isEmpty &&
        !_isInitializing) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('no_items_available'.tr(),
                style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _initializeDefaultItems,
              icon: const Icon(Icons.download),
              label: Text('load_default_items'.tr()),
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'conditions'.tr()),
            Tab(text: 'required_documents'.tr()),
            Tab(text: 'notes'.tr()),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildItemsList(_conditions, AdditionalItemType.condition),
              _buildItemsList(_documents, AdditionalItemType.document),
              _buildItemsList(_notes, AdditionalItemType.note),
            ],
          ),
        ),
      ],
    );
  }

  AdditionalItemType _getCurrentType() {
    switch (_tabController.index) {
      case 0:
        return AdditionalItemType.condition;
      case 1:
        return AdditionalItemType.document;
      case 2:
        return AdditionalItemType.note;
      default:
        return AdditionalItemType.condition;
    }
  }

  Widget _buildItemsList(List<AdditionalItem> items, AdditionalItemType type) {
    final isArabic = context.locale.languageCode == 'ar';

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.list_alt, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('no_items'.tr(), style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _showAddDialog(type),
              icon: const Icon(Icons.add),
              label: Text('add_item'.tr()),
            ),
          ],
        ),
      );
    }

    return ReorderableListView.builder(
      onReorderItem: (oldIndex, newIndex) =>
          _reorderItems(items, oldIndex, newIndex, type),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Card(
          key: ValueKey(item.id),
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: ListTile(
            title: Text(isArabic ? item.titleAr : item.titleEn),
            subtitle: item.getDescription(isArabic) != null
                ? Text(item.getDescription(isArabic)!)
                : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () => _showEditDialog(item, type),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteItem(item, type),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _reorderItems(List<AdditionalItem> items, int oldIndex,
      int newIndex, AdditionalItemType type) async {
    if (oldIndex < newIndex) newIndex -= 1;
    final item = items.removeAt(oldIndex);
    items.insert(newIndex, item);

    final batch = _firestore.batch();
    for (int i = 0; i < items.length; i++) {
      final docRef = _firestore.collection('additional_items').doc(items[i].id);
      batch.update(docRef, {'order': i});
    }
    await batch.commit();
    await _loadItemsByType(type);
  }

Future<void> _showAddDialog(AdditionalItemType type) async {
  final titleArController = TextEditingController();
  final titleEnController = TextEditingController();
  final descArController = TextEditingController();
  final descEnController = TextEditingController();

  await showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('add_item'.tr()),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleArController, decoration: InputDecoration(labelText: 'title_ar'.tr())),
            const SizedBox(height: 8),
            TextField(controller: titleEnController, decoration: InputDecoration(labelText: 'title_en'.tr())),
            const SizedBox(height: 8),
            TextField(controller: descArController, maxLines: 2, decoration: InputDecoration(labelText: 'description_ar_optional'.tr())),
            const SizedBox(height: 8),
            TextField(controller: descEnController, maxLines: 2, decoration: InputDecoration(labelText: 'description_en_optional'.tr())),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text('cancel'.tr())),
        ElevatedButton(
          onPressed: () async {
            if (titleArController.text.trim().isEmpty) return;
            await _firestore.collection('additional_items').add({
              'userId': _userId,
              'titleAr': titleArController.text.trim(),
              'titleEn': titleEnController.text.trim(),
              'descriptionAr': descArController.text.trim(),
              'descriptionEn': descEnController.text.trim(),
              'type': type.asString,  // ✅ استخدام asString بدلاً من _getTypeString
              'isActive': true,
              'order': DateTime.now().millisecondsSinceEpoch,
              'createdAt': FieldValue.serverTimestamp(),
            });
            await _loadItemsByType(type);
            if (dialogContext.mounted) Navigator.pop(dialogContext);
          },
          child: Text('save'.tr()),
        ),
      ],
    ),
  );
}
  Future<void> _showEditDialog(
      AdditionalItem item, AdditionalItemType type) async {
    final titleArController = TextEditingController(text: item.titleAr);
    final titleEnController = TextEditingController(text: item.titleEn);
    final descArController =
        TextEditingController(text: item.descriptionAr ?? '');
    final descEnController =
        TextEditingController(text: item.descriptionEn ?? '');
    bool isActive = item.isActive;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: Text('edit_item'.tr()),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: titleArController,
                    decoration: InputDecoration(labelText: 'title_ar'.tr())),
                const SizedBox(height: 8),
                TextField(
                    controller: titleEnController,
                    decoration: InputDecoration(labelText: 'title_en'.tr())),
                const SizedBox(height: 8),
                TextField(
                    controller: descArController,
                    maxLines: 2,
                    decoration: InputDecoration(
                        labelText: 'description_ar_optional'.tr())),
                const SizedBox(height: 8),
                TextField(
                    controller: descEnController,
                    maxLines: 2,
                    decoration: InputDecoration(
                        labelText: 'description_en_optional'.tr())),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: Text('active'.tr()),
                  value: isActive,
                  onChanged: (value) => setStateDialog(() => isActive = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text('cancel'.tr())),
            ElevatedButton(
              onPressed: () async {
                await _firestore
                    .collection('additional_items')
                    .doc(item.id)
                    .update({
                  'titleAr': titleArController.text.trim(),
                  'titleEn': titleEnController.text.trim(),
                  'descriptionAr': descArController.text.trim(),
                  'descriptionEn': descEnController.text.trim(),
                  'isActive': isActive,
                });
                await _loadItemsByType(type);
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: Text('save'.tr()),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteItem(AdditionalItem item, AdditionalItemType type) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('confirm_delete'.tr()),
        content: Text('delete_item_confirm'.tr()),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text('cancel'.tr())),
          ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text('delete'.tr())),
        ],
      ),
    );
    if (confirmed == true) {
      await _firestore.collection('additional_items').doc(item.id).delete();
      await _loadItemsByType(type);
    }
  }
}
