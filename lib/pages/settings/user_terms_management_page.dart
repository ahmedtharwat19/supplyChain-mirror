import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:puresip_purchasing/models/user_payment_term.dart';
import 'package:puresip_purchasing/models/user_delivery_term.dart';
import 'package:puresip_purchasing/services/user_terms_service.dart';
import 'package:puresip_purchasing/widgets/app_scaffold.dart';

class UserTermsManagementPage extends StatefulWidget {
  const UserTermsManagementPage({super.key});

  @override
  State<UserTermsManagementPage> createState() =>
      _UserTermsManagementPageState();
}

class _UserTermsManagementPageState extends State<UserTermsManagementPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final UserTermsService _termsService = UserTermsService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  bool _isInitializing = false;
  bool _isLoading = true;
  
  // تخزين البيانات
  List<UserPaymentTerm> _paymentTerms = [];
  List<UserDeliveryTerm> _deliveryTerms = [];

  String get _userId => _auth.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
      _loadPaymentTerms(),
      _loadDeliveryTerms(),
    ]);
  }

  Future<void> _loadPaymentTerms() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('user_payment_terms')
          .where('userId', isEqualTo: _userId)
          .where('isActive', isEqualTo: true)
          .orderBy('order')
          .get();
      
      setState(() {
        _paymentTerms = snapshot.docs
            .map((doc) => UserPaymentTerm.fromMap(doc.data(), doc.id))
            .toList();
      });
    } catch (e) {
      debugPrint('Error loading payment terms: $e');
    }
  }

  Future<void> _loadDeliveryTerms() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('user_delivery_terms')
          .where('userId', isEqualTo: _userId)
          .where('isActive', isEqualTo: true)
          .orderBy('order')
          .get();
      
      setState(() {
        _deliveryTerms = snapshot.docs
            .map((doc) => UserDeliveryTerm.fromMap(doc.data(), doc.id))
            .toList();
      });
    } catch (e) {
      debugPrint('Error loading delivery terms: $e');
    }
  }

  Future<bool> _checkIfAnyDataExists() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('user_payment_terms')
        .where('userId', isEqualTo: _userId)
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  Future<void> _initializeDefaultTerms() async {
    if (_userId.isEmpty) return;
    if (_isInitializing) return;
    
    final hasData = await _checkIfAnyDataExists();
    if (hasData) {
      await _loadAllData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Terms already exist')),
        );
      }
      return;
    }
    
    setState(() => _isInitializing = true);
    try {
      await _termsService.initializeDefaultTerms(_userId);
      await _loadAllData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Default terms initialized successfully')),
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

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'manage_payment_delivery_terms'.tr(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildMainContent(),
      floatingActionButton: _isInitializing
          ? null
          : FloatingActionButton(
              onPressed: () => _showAddDialog(_tabController.index == 0),
              child: const Icon(Icons.add),
            ),
    );
  }

  Widget _buildMainContent() {
    // عرض زر التهيئة إذا كانت جميع القوائم فارغة
    if (_paymentTerms.isEmpty && _deliveryTerms.isEmpty && !_isInitializing) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('no_terms_available'.tr(), style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _initializeDefaultTerms,
              icon: const Icon(Icons.download),
              label: Text('load_default_terms'.tr()),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
            Tab(text: 'payment_terms'.tr()),
            Tab(text: 'delivery_terms'.tr()),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildPaymentTermsList(),
              _buildDeliveryTermsList(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentTermsList() {
    final isArabic = context.locale.languageCode == 'ar';
    
    if (_paymentTerms.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.payment, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('no_payment_terms'.tr(), style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _showAddDialog(true),
              icon: const Icon(Icons.add),
              label: Text('add_payment_term'.tr()),
            ),
          ],
        ),
      );
    }

    return ReorderableListView.builder(
      onReorderItem: (oldIndex, newIndex) => _reorderPaymentTerms(_paymentTerms, oldIndex, newIndex),
      itemCount: _paymentTerms.length,
      itemBuilder: (context, index) {
        final term = _paymentTerms[index];
        return Card(
          key: ValueKey(term.id),
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: ListTile(
            title: Text(term.getName(isArabic)),
            subtitle: Text(term.getDescription(isArabic)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () => _showEditPaymentDialog(term),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deletePaymentTerm(term),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDeliveryTermsList() {
    final isArabic = context.locale.languageCode == 'ar';
    
    if (_deliveryTerms.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_shipping, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('no_delivery_terms'.tr(), style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _showAddDialog(false),
              icon: const Icon(Icons.add),
              label: Text('add_delivery_term'.tr()),
            ),
          ],
        ),
      );
    }

    return ReorderableListView.builder(
      onReorderItem: (oldIndex, newIndex) => _reorderDeliveryTerms(_deliveryTerms, oldIndex, newIndex),
      itemCount: _deliveryTerms.length,
      itemBuilder: (context, index) {
        final term = _deliveryTerms[index];
        return Card(
          key: ValueKey(term.id),
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: ListTile(
            title: Text(term.getName(isArabic)),
            subtitle: Text(term.getDescription(isArabic)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () => _showEditDeliveryDialog(term),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteDeliveryTerm(term),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _reorderPaymentTerms(List<UserPaymentTerm> terms, int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) newIndex -= 1;
    final term = terms.removeAt(oldIndex);
    terms.insert(newIndex, term);

    final batch = FirebaseFirestore.instance.batch();
    for (int i = 0; i < terms.length; i++) {
      batch.update(
        FirebaseFirestore.instance.collection('user_payment_terms').doc(terms[i].id),
        {'order': i},
      );
    }
    await batch.commit();
    await _loadPaymentTerms();
  }

  Future<void> _reorderDeliveryTerms(List<UserDeliveryTerm> terms, int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) newIndex -= 1;
    final term = terms.removeAt(oldIndex);
    terms.insert(newIndex, term);

    final batch = FirebaseFirestore.instance.batch();
    for (int i = 0; i < terms.length; i++) {
      batch.update(
        FirebaseFirestore.instance.collection('user_delivery_terms').doc(terms[i].id),
        {'order': i},
      );
    }
    await batch.commit();
    await _loadDeliveryTerms();
  }

  Future<void> _showAddDialog(bool isPaymentTerm) async {
    final codeController = TextEditingController();
    final nameArController = TextEditingController();
    final nameEnController = TextEditingController();
    final descArController = TextEditingController();
    final descEnController = TextEditingController();
    final daysController = TextEditingController();

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isPaymentTerm ? 'add_payment_term'.tr() : 'add_delivery_term'.tr()),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: codeController, decoration: InputDecoration(labelText: 'code'.tr())),
              const SizedBox(height: 8),
              TextField(controller: nameArController, decoration: InputDecoration(labelText: 'name_ar'.tr())),
              const SizedBox(height: 8),
              TextField(controller: nameEnController, decoration: InputDecoration(labelText: 'name_en'.tr())),
              const SizedBox(height: 8),
              TextField(controller: descArController, maxLines: 2, decoration: InputDecoration(labelText: 'description_ar'.tr())),
              const SizedBox(height: 8),
              TextField(controller: descEnController, maxLines: 2, decoration: InputDecoration(labelText: 'description_en'.tr())),
              if (isPaymentTerm) ...[
                const SizedBox(height: 8),
                TextField(controller: daysController, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'payment_days'.tr(), suffixText: 'days'.tr())),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text('cancel'.tr())),
          ElevatedButton(
            onPressed: () async {
              if (isPaymentTerm) {
                await _termsService.addPaymentTerm(
                  _userId, codeController.text, nameArController.text, nameEnController.text,
                  descArController.text, descEnController.text, int.tryParse(daysController.text) ?? 0,
                );
              } else {
                await _termsService.addDeliveryTerm(
                  _userId, codeController.text, nameArController.text, nameEnController.text,
                  descArController.text, descEnController.text,
                );
              }
              await _loadAllData();
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: Text('save'.tr()),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditPaymentDialog(UserPaymentTerm term) async {
    final nameArController = TextEditingController(text: term.nameAr);
    final nameEnController = TextEditingController(text: term.nameEn);
    final descArController = TextEditingController(text: term.descriptionAr);
    final descEnController = TextEditingController(text: term.descriptionEn);
    final daysController = TextEditingController(text: term.days.toString());
    bool isActive = term.isActive;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: Text('edit_payment_term'.tr()),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameArController, decoration: InputDecoration(labelText: 'name_ar'.tr())),
                const SizedBox(height: 8),
                TextField(controller: nameEnController, decoration: InputDecoration(labelText: 'name_en'.tr())),
                const SizedBox(height: 8),
                TextField(controller: descArController, maxLines: 2, decoration: InputDecoration(labelText: 'description_ar'.tr())),
                const SizedBox(height: 8),
                TextField(controller: descEnController, maxLines: 2, decoration: InputDecoration(labelText: 'description_en'.tr())),
                const SizedBox(height: 8),
                TextField(controller: daysController, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'payment_days'.tr(), suffixText: 'days'.tr())),
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
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text('cancel'.tr())),
            ElevatedButton(
              onPressed: () async {
                final updatedTerm = UserPaymentTerm(
                  id: term.id, userId: term.userId, code: term.code,
                  nameAr: nameArController.text, nameEn: nameEnController.text,
                  descriptionAr: descArController.text, descriptionEn: descEnController.text,
                  days: int.tryParse(daysController.text) ?? 0, order: term.order,
                  isActive: isActive, createdAt: term.createdAt,
                );
                await _termsService.updatePaymentTerm(updatedTerm);
                await _loadPaymentTerms();
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: Text('save'.tr()),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditDeliveryDialog(UserDeliveryTerm term) async {
    final nameArController = TextEditingController(text: term.nameAr);
    final nameEnController = TextEditingController(text: term.nameEn);
    final descArController = TextEditingController(text: term.descriptionAr);
    final descEnController = TextEditingController(text: term.descriptionEn);
    bool isActive = term.isActive;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: Text('edit_delivery_term'.tr()),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameArController, decoration: InputDecoration(labelText: 'name_ar'.tr())),
                const SizedBox(height: 8),
                TextField(controller: nameEnController, decoration: InputDecoration(labelText: 'name_en'.tr())),
                const SizedBox(height: 8),
                TextField(controller: descArController, maxLines: 2, decoration: InputDecoration(labelText: 'description_ar'.tr())),
                const SizedBox(height: 8),
                TextField(controller: descEnController, maxLines: 2, decoration: InputDecoration(labelText: 'description_en'.tr())),
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
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text('cancel'.tr())),
            ElevatedButton(
              onPressed: () async {
                final updatedTerm = UserDeliveryTerm(
                  id: term.id, userId: term.userId, code: term.code,
                  nameAr: nameArController.text, nameEn: nameEnController.text,
                  descriptionAr: descArController.text, descriptionEn: descEnController.text,
                  order: term.order, isActive: isActive, createdAt: term.createdAt,
                );
                await _termsService.updateDeliveryTerm(updatedTerm);
                await _loadDeliveryTerms();
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: Text('save'.tr()),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deletePaymentTerm(UserPaymentTerm term) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('confirm_delete'.tr()),
        content: Text('delete_term_confirm'.tr()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text('cancel'.tr())),
          ElevatedButton(onPressed: () => Navigator.pop(dialogContext, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: Text('delete'.tr())),
        ],
      ),
    );
    if (confirmed == true) {
      await _termsService.deletePaymentTerm(term.id);
      await _loadPaymentTerms();
    }
  }

  Future<void> _deleteDeliveryTerm(UserDeliveryTerm term) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('confirm_delete'.tr()),
        content: Text('delete_term_confirm'.tr()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text('cancel'.tr())),
          ElevatedButton(onPressed: () => Navigator.pop(dialogContext, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: Text('delete'.tr())),
        ],
      ),
    );
    if (confirmed == true) {
      await _termsService.deleteDeliveryTerm(term.id);
      await _loadDeliveryTerms();
    }
  }
}