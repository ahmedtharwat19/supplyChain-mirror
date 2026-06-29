/* /* import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:puresip_purchasing/widgets/app_scaffold.dart';

class EditFactoryPage extends StatelessWidget {
  final String factoryId;

  const EditFactoryPage({super.key, required this.factoryId});

  @override
  Widget build(BuildContext context) {
    // Here you would typically fetch the factory details using the factoryId
    // and display them in a form for editing.
    return AppScaffold(
      
        title: tr('edit_factory'),
     
      body: Center(
        child: Text(tr('edit_factory_details', namedArgs: {'id': factoryId})),
      ),
    );
  }
}
 */

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';

class EditFactoryPage extends StatefulWidget {
  final String factoryId;
  const EditFactoryPage({super.key, required this.factoryId});

  @override
  State<EditFactoryPage> createState() => _EditFactoryPageState();
}

class _EditFactoryPageState extends State<EditFactoryPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameArController = TextEditingController();
  final _nameEnController = TextEditingController();
  final _locationController = TextEditingController();
  final _managerController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;

  @override void initState() {
    super.initState();
    _loadFactory();
  }

  Future<void> _loadFactory() async {
    try {
      final doc = await FirebaseFirestore.instance
        .collection('factories')
        .doc(widget.factoryId)
        .get();

      if (!doc.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(tr('factory_not_found'))));
          context.pop();
        }
        return;
      }

      final data = doc.data()!;
      _nameArController.text = data['nameAr'] ?? '';
      _nameEnController.text = data['nameEn'] ?? '';
      _locationController.text = data['location'] ?? '';
      _managerController.text = data['managerName'] ?? '';
      _phoneController.text = data['managerPhone'] ?? '';
    } catch (e) {
      safeDebugPrint('Error loading factory: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('${tr('error_occurred')}: $e')));
        context.pop();
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateFactory() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final updateData = {
        'nameAr': _nameArController.text.trim(),
        'nameEn': _nameEnController.text.trim(),
        'location': _locationController.text.trim(),
        'managerName': _managerController.text.trim(),
        'managerPhone': _phoneController.text.trim(),
      };
      await FirebaseFirestore.instance
        .collection('factories')
        .doc(widget.factoryId)
        .update(updateData);

      if (mounted) {
        ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(tr('factory_updated_successfully'))));
        context.pop();
      }
    } catch (e) {
      safeDebugPrint('Error updating factory: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${tr('error_occurred')}: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override void dispose() {
    _nameArController.dispose();
    _nameEnController.dispose();
    _locationController.dispose();
    _managerController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(tr('edit_factory'))),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(tr('edit_factory'))),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(children: [
            TextFormField(
              controller: _nameArController,
              decoration: InputDecoration(labelText: tr('nameArabic')),
              validator: (v) => v == null || v.isEmpty ? tr('required_field') : null,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameEnController,
              decoration: InputDecoration(labelText: tr('nameEnglish')),
              validator: (v) => v == null || v.isEmpty ? tr('required_field') : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _locationController,
              decoration: InputDecoration(labelText: tr('location')),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _managerController,
              decoration: InputDecoration(labelText: tr('managerName')),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _phoneController,
              decoration: InputDecoration(labelText: tr('managerPhone')),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isSaving ? null : _updateFactory,
              child: Text(tr('update')),
            ),
          ]),
        ),
      ),
    );
  }
}
 */

/* 
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:puresip_purchasing/debug_helper.dart';

class EditFactoryPage extends StatefulWidget {
  final String factoryId;
  const EditFactoryPage({super.key, required this.factoryId});

  @override
  State<EditFactoryPage> createState() => _EditFactoryPageState();
}

class _EditFactoryPageState extends State<EditFactoryPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameArController = TextEditingController();
  final _nameEnController = TextEditingController();
  final _locationController = TextEditingController();
  final _managerController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;

  List<Map<String, dynamic>> _companies = [];
  List<String> _selectedCompanyIds = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCompanies();
      _loadFactory();
    });
  }

  Future<void> _loadCompanies() async {
    try {
      final isArabic = Localizations.localeOf(context).languageCode == 'ar';

      final querySnapshot = await FirebaseFirestore.instance.collection('companies').get();

      final loaded = querySnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': isArabic ? (data['nameAr'] ?? '') : (data['nameEn'] ?? ''),
        };
      }).toList();

      setState(() {
        _companies = loaded;
      });
    } catch (e) {
      safeDebugPrint('Error loading companies: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${tr('error_occurred')}: $e')),
        );
      }
    }
  }

  Future<void> _loadFactory() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('factories')
          .doc(widget.factoryId)
          .get();

      if (!doc.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(tr('factory_not_found'))));
          context.pop();
        }
        return;
      }

      final data = doc.data()!;
      _nameArController.text = data['nameAr'] ?? '';
      _nameEnController.text = data['nameEn'] ?? '';
      _locationController.text = data['location'] ?? '';
      _managerController.text = data['managerName'] ?? '';
      _phoneController.text = data['managerPhone'] ?? '';

      final List<dynamic> companyIdsFromDb = data['companyIds'] ?? [];
      setState(() {
        _selectedCompanyIds = companyIdsFromDb.map((e) => e.toString()).toList();
        _isLoading = false;
      });
    } catch (e) {
      safeDebugPrint('Error loading factory: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${tr('error_occurred')}: $e')));
        context.pop();
      }
    }
  }

  Future<void> _updateFactory() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final updateData = {
        'nameAr': _nameArController.text.trim(),
        'nameEn': _nameEnController.text.trim(),
        'location': _locationController.text.trim(),
        'managerName': _managerController.text.trim(),
        'managerPhone': _phoneController.text.trim(),
        'companyIds': _selectedCompanyIds,
      };

      await FirebaseFirestore.instance
          .collection('factories')
          .doc(widget.factoryId)
          .update(updateData);

      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(tr('factory_updated_successfully'))));
        context.pop();
      }
    } catch (e) {
      safeDebugPrint('Error updating factory: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${tr('error_occurred')}: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _nameArController.dispose();
    _nameEnController.dispose();
    _locationController.dispose();
    _managerController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(tr('edit_factory'))),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(tr('edit_factory'))),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameArController,
                decoration: InputDecoration(labelText: tr('nameArabic')),
                validator: (v) =>
                    v == null || v.isEmpty ? tr('required_field') : null,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameEnController,
                decoration: InputDecoration(labelText: tr('nameEnglish')),
                validator: (v) =>
                    v == null || v.isEmpty ? tr('required_field') : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _locationController,
                decoration: InputDecoration(labelText: tr('location')),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _managerController,
                decoration: InputDecoration(labelText: tr('managerName')),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _phoneController,
                decoration: InputDecoration(labelText: tr('managerPhone')),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 24),

              Text(tr('select_companies'), style: Theme.of(context).textTheme.titleMedium),

              ..._companies.map((company) {
                final id = company['id'] as String;
                final name = company['name'] as String;
                return CheckboxListTile(
                  title: Text(name),
                  value: _selectedCompanyIds.contains(id),
                  onChanged: (bool? checked) {
                    setState(() {
                      if (checked == true) {
                        if (!_selectedCompanyIds.contains(id)) {
                          _selectedCompanyIds.add(id);
                        }
                      } else {
                        _selectedCompanyIds.remove(id);
                      }
                    });
                  },
                );
              }),

              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isSaving ? null : _updateFactory,
                child: Text(tr('update')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
 */


/* 
// lib/pages/factories/edit_factory_page.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:puresip_purchasing/debug_helper.dart';
import 'package:puresip_purchasing/services/hive_service.dart';

class EditFactoryPage extends StatefulWidget {
  final String factoryId;
  const EditFactoryPage({super.key, required this.factoryId});

  @override
  State<EditFactoryPage> createState() => _EditFactoryPageState();
}

class _EditFactoryPageState extends State<EditFactoryPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameArController = TextEditingController();
  final _nameEnController = TextEditingController();
  final _locationController = TextEditingController();
  final _managerController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;

  List<Map<String, dynamic>> _companies = [];
  List<String> _selectedCompanyIds = [];

  // شركات المستخدم (لتحديد المسموح بها)
  List<String> _userCompanyIds = [];

  @override
  void initState() {
    super.initState();
    _loadUserAndData();
  }

  Future<void> _loadUserAndData() async {
    await _loadUserCompanies();     // تحميل شركات المستخدم فقط
    await _loadCompanies();         // تحميل تفاصيل هذه الشركات (من Hive أو Firestore)
    await _loadFactory();           // تحميل بيانات المصنع
  }

  /// جلب معرفات الشركات من المستخدم الحالي (من Hive أولاً، ثم Firestore)
  Future<void> _loadUserCompanies() async {
    try {
      // 1. حاول من Hive
      Map<String, dynamic>? userData = await HiveService.getUserData();
      if (userData != null && userData['companyIds'] != null) {
        _userCompanyIds = List<String>.from(userData['companyIds']);
        safeDebugPrint('User companies from Hive: $_userCompanyIds');
        return;
      }

      // 2. إذا لم يجد، جلب من Firestore
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (userDoc.exists) {
        _userCompanyIds = List<String>.from(userDoc.data()?['companyIds'] ?? []);
        // حفظ في Hive للمرة القادمة
        await HiveService.updateUserData('companyIds', _userCompanyIds);
        safeDebugPrint('User companies from Firestore: $_userCompanyIds');
      }
    } catch (e) {
      safeDebugPrint('Error loading user companies: $e');
    }
  }

  /// تحميل تفاصيل الشركات (من Hive أولاً، ثم Firestore إذا لزم الأمر)
  Future<void> _loadCompanies() async {
    if (_userCompanyIds.isEmpty) {
      setState(() => _companies = []);
      return;
    }

    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    // 1. محاولة تحميل من Hive (cache)
    final cached = await HiveService.getCachedData('companies_list');
    if (cached != null && cached is List) {
      final allCompanies = List<Map<String, dynamic>>.from(cached);
      // تصفية حسب شركات المستخدم فقط
      final filtered = allCompanies.where((c) => _userCompanyIds.contains(c['id'])).toList();
      if (filtered.isNotEmpty) {
        setState(() {
          _companies = filtered;
        });
        safeDebugPrint('Companies loaded from Hive: ${_companies.length}');
        return;
      }
    }

    // 2. جلب من Firestore (مرة واحدة فقط)
    try {
      final List<Map<String, dynamic>> loaded = [];
      for (final companyId in _userCompanyIds) {
        final doc = await FirebaseFirestore.instance
            .collection('companies')
            .doc(companyId)
            .get();
        if (doc.exists) {
          final data = doc.data()!;
          loaded.add({
            'id': doc.id,
            'name': isArabic ? (data['nameAr'] ?? '') : (data['nameEn'] ?? ''),
          });
        }
      }
      // حفظ في Hive
      await HiveService.cacheData('companies_list', loaded);
      setState(() {
        _companies = loaded;
      });
      safeDebugPrint('Companies loaded from Firestore: ${_companies.length}');
    } catch (e) {
      safeDebugPrint('Error loading companies from Firestore: $e');
    }
  }

  /// تحميل بيانات المصنع من Firestore (مع التحقق من صحة الشركات المرتبطة)
  Future<void> _loadFactory() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('factories')
          .doc(widget.factoryId)
          .get();

      if (!doc.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(tr('factory_not_found'))));
          context.pop();
        }
        return;
      }

      final data = doc.data()!;
      _nameArController.text = data['nameAr'] ?? '';
      _nameEnController.text = data['nameEn'] ?? '';
      _locationController.text = data['location'] ?? '';
      _managerController.text = data['managerName'] ?? '';
      _phoneController.text = data['managerPhone'] ?? '';

      final List<dynamic> companyIdsFromDb = data['companyIds'] ?? [];
      final List<String> allSelected = companyIdsFromDb.map((e) => e.toString()).toList();

      // فلترة الشركات المختارة بحيث تكون فقط ضمن الشركات المسموح بها للمستخدم
      setState(() {
        _selectedCompanyIds = allSelected.where((id) => _userCompanyIds.contains(id)).toList();
        _isLoading = false;
      });
    } catch (e) {
      safeDebugPrint('Error loading factory: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${tr('error_occurred')}: $e')));
        context.pop();
      }
    }
  }

  /// حفظ التغييرات في Firestore ثم تحديث Hive محلياً
  Future<void> _updateFactory() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final updateData = {
        'nameAr': _nameArController.text.trim(),
        'nameEn': _nameEnController.text.trim(),
        'location': _locationController.text.trim(),
        'managerName': _managerController.text.trim(),
        'managerPhone': _phoneController.text.trim(),
        'companyIds': _selectedCompanyIds,
      };

      // 1. تحديث Firestore
      await FirebaseFirestore.instance
          .collection('factories')
          .doc(widget.factoryId)
          .update(updateData);

      // 2. تحديث Hive (حذف الكاش القديم للمصانع ليتم تحديثه لاحقاً)
      await HiveService.cacheData('factories_${widget.factoryId}', null); // إبطال الكاش
      // أيضاً إبطال كاش المصانع لكل شركة (اختياري)
      for (final companyId in _selectedCompanyIds) {
        await HiveService.cacheData('factories_$companyId', null);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('factory_updated_successfully'))));
        context.pop();
      }
    } catch (e) {
      safeDebugPrint('Error updating factory: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${tr('error_occurred')}: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _nameArController.dispose();
    _nameEnController.dispose();
    _locationController.dispose();
    _managerController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(tr('edit_factory'))),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(tr('edit_factory'))),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameArController,
                decoration: InputDecoration(labelText: tr('nameArabic')),
                validator: (v) => (v == null || v.isEmpty) ? tr('required_field') : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameEnController,
                decoration: InputDecoration(labelText: tr('nameEnglish')),
                validator: (v) => (v == null || v.isEmpty) ? tr('required_field') : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _locationController,
                decoration: InputDecoration(labelText: tr('location')),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _managerController,
                decoration: InputDecoration(labelText: tr('managerName')),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _phoneController,
                decoration: InputDecoration(labelText: tr('managerPhone')),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 24),
              Text(tr('select_companies'), style: Theme.of(context).textTheme.titleMedium),
              ..._companies.map((company) {
                final id = company['id'] as String;
                final name = company['name'] as String;
                return CheckboxListTile(
                  title: Text(name),
                  value: _selectedCompanyIds.contains(id),
                  onChanged: (bool? checked) {
                    setState(() {
                      if (checked == true) {
                        if (!_selectedCompanyIds.contains(id)) {
                          _selectedCompanyIds.add(id);
                        }
                      } else {
                        _selectedCompanyIds.remove(id);
                      }
                    });
                  },
                );
              }),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isSaving ? null : _updateFactory,
                child: Text(tr('update')),
              ),
            ],
          ),
        ),
      ),
    );
  }
} */

// lib/pages/factories/edit_factory_page.dart - بدون Hive
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:puresip_purchasing/debug_helper.dart';

class EditFactoryPage extends StatefulWidget {
  final String factoryId;
  const EditFactoryPage({super.key, required this.factoryId});

  @override
  State<EditFactoryPage> createState() => _EditFactoryPageState();
}

class _EditFactoryPageState extends State<EditFactoryPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameArController = TextEditingController();
  final _nameEnController = TextEditingController();
  final _locationController = TextEditingController();
  final _managerController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;

  List<Map<String, dynamic>> _companies = [];
  List<String> _selectedCompanyIds = [];

  // شركات المستخدم (لتحديد المسموح بها)
  List<String> _userCompanyIds = [];
  
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // ✅ مفاتيح التخزين
  static const String _keyUserData = 'user_data';
  static const String _keyCompaniesCache = 'companies_list_cache';
  static const String _keyFactoriesPrefix = 'factories_';

  @override
  void initState() {
    super.initState();
    _loadUserAndData();
  }

  Future<void> _loadUserAndData() async {
    await _loadUserCompanies();
    await _loadCompanies();
    await _loadFactory();
  }

  /// جلب معرفات الشركات من المستخدم الحالي (من SecureStorage أولاً، ثم Firestore)
  Future<void> _loadUserCompanies() async {
    try {
      // 1. حاول من SecureStorage
      final userDataJson = await _secureStorage.read(key: _keyUserData);
      if (userDataJson != null) {
        final userData = json.decode(userDataJson) as Map<String, dynamic>;
        if (userData['companyIds'] != null) {
          _userCompanyIds = List<String>.from(userData['companyIds']);
          safeDebugPrint('User companies from SecureStorage: $_userCompanyIds');
          return;
        }
      }

      // 2. إذا لم يجد، جلب من Firestore
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
          
      if (userDoc.exists) {
        _userCompanyIds = List<String>.from(userDoc.data()?['companyIds'] ?? []);
        
        // حفظ في SecureStorage للمرة القادمة
        if (userDataJson != null) {
          final updatedUserData = json.decode(userDataJson) as Map<String, dynamic>;
          updatedUserData['companyIds'] = _userCompanyIds;
          await _secureStorage.write(key: _keyUserData, value: json.encode(updatedUserData));
        }
        
        safeDebugPrint('User companies from Firestore: $_userCompanyIds');
      }
    } catch (e) {
      safeDebugPrint('Error loading user companies: $e');
    }
  }

  /// تحميل تفاصيل الشركات (من SharedPreferences أولاً، ثم Firestore إذا لزم الأمر)
  Future<void> _loadCompanies() async {
    if (_userCompanyIds.isEmpty) {
      setState(() => _companies = []);
      return;
    }

    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    // 1. محاولة تحميل من SharedPreferences (cache)
    final prefs = await SharedPreferences.getInstance();
    final cachedJson = prefs.getString(_keyCompaniesCache);
    
    if (cachedJson != null) {
      final allCompanies = List<Map<String, dynamic>>.from(json.decode(cachedJson));
      // تصفية حسب شركات المستخدم فقط
      final filtered = allCompanies.where((c) => _userCompanyIds.contains(c['id'])).toList();
      if (filtered.isNotEmpty) {
        setState(() {
          _companies = filtered;
        });
        safeDebugPrint('Companies loaded from cache: ${_companies.length}');
        return;
      }
    }

    // 2. جلب من Firestore (مرة واحدة فقط)
    try {
      final List<Map<String, dynamic>> loaded = [];
      for (final companyId in _userCompanyIds) {
        final doc = await FirebaseFirestore.instance
            .collection('companies')
            .doc(companyId)
            .get();
        if (doc.exists) {
          final data = doc.data()!;
          loaded.add({
            'id': doc.id,
            'name': isArabic ? (data['nameAr'] ?? '') : (data['nameEn'] ?? ''),
          });
        }
      }
      // حفظ في SharedPreferences
      await prefs.setString(_keyCompaniesCache, json.encode(loaded));
      setState(() {
        _companies = loaded;
      });
      safeDebugPrint('Companies loaded from Firestore: ${_companies.length}');
    } catch (e) {
      safeDebugPrint('Error loading companies from Firestore: $e');
    }
  }

  /// تحميل بيانات المصنع من Firestore
  Future<void> _loadFactory() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('factories')
          .doc(widget.factoryId)
          .get();

      if (!doc.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(tr('factory_not_found'))));
          context.pop();
        }
        return;
      }

      final data = doc.data()!;
      _nameArController.text = data['nameAr'] ?? '';
      _nameEnController.text = data['nameEn'] ?? '';
      _locationController.text = data['location'] ?? '';
      _managerController.text = data['managerName'] ?? '';
      _phoneController.text = data['managerPhone'] ?? '';

      final List<dynamic> companyIdsFromDb = data['companyIds'] ?? [];
      final List<String> allSelected = companyIdsFromDb.map((e) => e.toString()).toList();

      // فلترة الشركات المختارة بحيث تكون فقط ضمن الشركات المسموح بها للمستخدم
      setState(() {
        _selectedCompanyIds = allSelected.where((id) => _userCompanyIds.contains(id)).toList();
        _isLoading = false;
      });
    } catch (e) {
      safeDebugPrint('Error loading factory: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${tr('error_occurred')}: $e')));
        context.pop();
      }
    }
  }

  /// إبطال الكاش للمصنع المحدد
  Future<void> _invalidateFactoryCache(String factoryId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_keyFactoriesPrefix$factoryId');
      safeDebugPrint('Factory cache invalidated for: $factoryId');
    } catch (e) {
      safeDebugPrint('Error invalidating cache: $e');
    }
  }

  /// حفظ التغييرات في Firestore ثم تحديث الكاش محلياً
  Future<void> _updateFactory() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final updateData = {
        'nameAr': _nameArController.text.trim(),
        'nameEn': _nameEnController.text.trim(),
        'location': _locationController.text.trim(),
        'managerName': _managerController.text.trim(),
        'managerPhone': _phoneController.text.trim(),
        'companyIds': _selectedCompanyIds,
      };

      // 1. تحديث Firestore
      await FirebaseFirestore.instance
          .collection('factories')
          .doc(widget.factoryId)
          .update(updateData);

      // 2. إبطال الكاش القديم للمصنع
      await _invalidateFactoryCache(widget.factoryId);
      
      // 3. إبطال كاش المصانع لكل شركة مرتبطة
      final prefs = await SharedPreferences.getInstance();
      for (final companyId in _selectedCompanyIds) {
        await prefs.remove('${_keyFactoriesPrefix}company_$companyId');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('factory_updated_successfully'))));
        context.pop(true); // إرجاع true لتحديث الصفحة السابقة
      }
    } catch (e) {
      safeDebugPrint('Error updating factory: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${tr('error_occurred')}: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _nameArController.dispose();
    _nameEnController.dispose();
    _locationController.dispose();
    _managerController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(tr('edit_factory'))),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(tr('edit_factory'))),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameArController,
                decoration: InputDecoration(labelText: tr('nameArabic')),
                validator: (v) => (v == null || v.isEmpty) ? tr('required_field') : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameEnController,
                decoration: InputDecoration(labelText: tr('nameEnglish')),
                validator: (v) => (v == null || v.isEmpty) ? tr('required_field') : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _locationController,
                decoration: InputDecoration(labelText: tr('location')),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _managerController,
                decoration: InputDecoration(labelText: tr('managerName')),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _phoneController,
                decoration: InputDecoration(labelText: tr('managerPhone')),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 24),
              Text(tr('select_companies'), style: Theme.of(context).textTheme.titleMedium),
              ..._companies.map((company) {
                final id = company['id'] as String;
                final name = company['name'] as String;
                return CheckboxListTile(
                  title: Text(name),
                  value: _selectedCompanyIds.contains(id),
                  onChanged: (bool? checked) {
                    setState(() {
                      if (checked == true) {
                        if (!_selectedCompanyIds.contains(id)) {
                          _selectedCompanyIds.add(id);
                        }
                      } else {
                        _selectedCompanyIds.remove(id);
                      }
                    });
                  },
                );
              }),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isSaving ? null : _updateFactory,
                child: Text(tr('update')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}