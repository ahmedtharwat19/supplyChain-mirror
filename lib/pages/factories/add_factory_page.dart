/* import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:puresip_purchasing/widgets/app_scaffold.dart';
import '../../../utils/user_local_storage.dart';

class AddFactoryPage extends StatefulWidget {
  const AddFactoryPage({super.key});

  @override
  State<AddFactoryPage> createState() => _AddFactoryPageState();
}

class _AddFactoryPageState extends State<AddFactoryPage> {
  final _formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final addressController = TextEditingController();
  final phoneController = TextEditingController();

  bool isSubmitting = false;

  Future<void> addFactory() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isSubmitting = true);

    final user = await UserLocalStorage.getUser();
    final companyId = await UserLocalStorage.getCurrentCompanyId();

    if (!mounted) return; // ⛑️ حماية قبل استخدام context

    if (user == null || companyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('no_user_or_company'.tr())),
      );
      return;
    }

    await FirebaseFirestore.instance.collection('factories').add({
      'name': nameController.text.trim(),
      'address': addressController.text.trim(),
      'phone': phoneController.text.trim(),
      'companyId': companyId,
      'userId': user['userId'],
      'createdAt': Timestamp.now(),
    });

    if (!mounted) return;
    setState(() => isSubmitting = false);
    Navigator.pop(context); // العودة بعد الإضافة
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'add_factory'.tr(),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: nameController,
                decoration: InputDecoration(labelText: 'factory_name'.tr()),
                validator: (value) => value!.isEmpty ? 'requierd'.tr() : null,
              ),
              TextFormField(
                controller: addressController,
                decoration: InputDecoration(labelText: 'address'.tr()),
              ),
              TextFormField(
                controller: phoneController,
                decoration: InputDecoration(labelText: 'phone'.tr()),
              ),
              const SizedBox(height: 20),
              isSubmitting
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: addFactory,
                      child: Text('add_factory'.tr()),
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

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';

class AddFactoryPage extends StatefulWidget {
  const AddFactoryPage({super.key});
  @override
  State<AddFactoryPage> createState() => _AddFactoryPageState();
}

class _AddFactoryPageState extends State<AddFactoryPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameArController = TextEditingController();
  final _nameEnController = TextEditingController();
  final _locationController = TextEditingController();
  final _managerController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isLoading = false;

  @override void dispose() {
    _nameArController.dispose();
    _nameEnController.dispose();
    _locationController.dispose();
    _managerController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _addFactory() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final data = {
      'nameAr': _nameArController.text.trim(),
      'nameEn': _nameEnController.text.trim(),
      'location': _locationController.text.trim(),
      'managerName': _managerController.text.trim(),
      'managerPhone': _phoneController.text.trim(),
      //'companyId': user.uid, // أو أي منطق للمفتاح
      'createdAt': FieldValue.serverTimestamp(),
      'userId': user.uid,
    };

    try {
      final docRef = await FirebaseFirestore.instance
          .collection('factories')
          .add(data);

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'factoryIds': FieldValue.arrayUnion([docRef.id]),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(tr('factory_added_successfully'))));
      context.pop();
    } catch (e) {
      safeDebugPrint('Error adding factory: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${tr('error_occurred')}: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('add_factory'))),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
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
                onPressed: _isLoading ? null : _addFactory,
                child: Text(tr('add')),
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
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:puresip_purchasing/utils/user_local_storage.dart';

class AddFactoryPage extends StatefulWidget {
  const AddFactoryPage({super.key});
  @override
  State<AddFactoryPage> createState() => _AddFactoryPageState();
}

class _AddFactoryPageState extends State<AddFactoryPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameArController = TextEditingController();
  final _nameEnController = TextEditingController();
  final _locationController = TextEditingController();
  final _managerController = TextEditingController();
  final _phoneController = TextEditingController();

  final _nameArFocus = FocusNode();
  final _nameEnFocus = FocusNode();
  final _locationFocus = FocusNode();
  final _managerFocus = FocusNode();
  final _phoneFocus = FocusNode();

  bool _isLoading = false;
  bool _isArabicWarningShown = false;
  bool _isEnglishWarningShown = false;
  bool _isPhoneWarningShown = false;

  @override
  void dispose() {
    _nameArController.dispose();
    _nameEnController.dispose();
    _locationController.dispose();
    _managerController.dispose();
    _phoneController.dispose();

    _nameArFocus.dispose();
    _nameEnFocus.dispose();
    _locationFocus.dispose();
    _managerFocus.dispose();
    _phoneFocus.dispose();

    super.dispose();
  }

  TextInputFormatter getInputFormatter(String lang) {
    if (lang == 'arabic') {
      return FilteringTextInputFormatter.allow(RegExp(r'[\u0600-\u06FF\s]'));
    } else if (lang == 'english') {
      return FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]'));
    } else if (lang == 'digits') {
      return FilteringTextInputFormatter.digitsOnly;
    }
    return FilteringTextInputFormatter.allow(RegExp('.*'));
  }

  Function(String) getOnChanged(String lang) {
    return (String value) {
      bool hasInvalid = false;
      if (lang == 'arabic') {
        hasInvalid = RegExp(r'[^\u0600-\u06FF\s]').hasMatch(value);
        setState(() => _isArabicWarningShown = hasInvalid);
      } else if (lang == 'english') {
        hasInvalid = RegExp(r'[^a-zA-Z\s]').hasMatch(value);
        setState(() => _isEnglishWarningShown = hasInvalid);
      } else if (lang == 'digits') {
        hasInvalid = RegExp(r'[^\d]').hasMatch(value);
        setState(() => _isPhoneWarningShown = hasInvalid);
      }
    };
  }

  String? _validateArabicName(String? value) {
    if (value == null || value.isEmpty) {
      return tr('required_field');
    }
    final arabicRegex = RegExp(r'^[\u0600-\u06FF\s]+$');
    if (!arabicRegex.hasMatch(value)) {
      return tr('only_arabic_letters_allowed');
    }
    return null;
  }

  String? _validateEnglishName(String? value) {
    if (value == null || value.isEmpty) {
      return tr('required_field');
    }
    final englishRegex = RegExp(r'^[a-zA-Z\s]+$');
    if (!englishRegex.hasMatch(value)) {
      return tr('only_english_letters_allowed');
    }
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return null; // رقم التليفون اختياري
    }
    final phoneRegex = RegExp(r'^\d+$');
    if (!phoneRegex.hasMatch(value)) {
      return tr('only_numbers_allowed');
    }
    return null;
  }

  Future<void> _addFactory() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final data = {
      'nameAr': _nameArController.text.trim(),
      'nameEn': _nameEnController.text.trim(),
      'location': _locationController.text.trim(),
      'managerName': _managerController.text.trim(),
      'managerPhone': _phoneController.text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'userId': user.uid,
      'companyIds': [], // حدث حسب متطلباتك
    };

    try {
      final docRef =
          await FirebaseFirestore.instance.collection('factories').add(data);

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'factoryIds': FieldValue.arrayUnion([docRef.id]),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('factory_added_successfully'))));
      context.pop();
    } catch (e) {
      safeDebugPrint('Error adding factory: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${tr('error_occurred')}: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  } */

//import 'user_local_storage.dart'; // تأكد من استيراد الملف الصحيح

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:puresip_purchasing/utils/user_local_storage.dart';
import 'package:puresip_purchasing/debug_helper.dart';

class AddFactoryPage extends StatefulWidget {
  const AddFactoryPage({super.key});

  @override
  State<AddFactoryPage> createState() => _AddFactoryPageState();
}

class _AddFactoryPageState extends State<AddFactoryPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameAr = TextEditingController();
  final TextEditingController _nameEn = TextEditingController();
  final TextEditingController _location = TextEditingController();
  final TextEditingController _manager = TextEditingController();
  final TextEditingController _phone = TextEditingController();

  bool _isLoading = false;
  bool _warnAr = false, _warnEn = false, _warnPhone = false;

  List<Map<String, dynamic>> _companies = [];
  final List<String> _selectedCompanyIds = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCompanies();
    });
  }

/*   Future<void> _loadCompanies() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userData = await UserLocalStorage.getUser();
    final ids = List<String>.from(userData?['companyIds'] ?? []);
    safeDebugPrint('📦 companyIds from local: $ids'); // ✅ للتأكد
    if (ids.isEmpty) return;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('companies')
          .where(FieldPath.documentId, whereIn: ids)
          .get();
      final loadedCompanies = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'] ?? 'No Name',
        };
      }).toList();

      safeDebugPrint('✅ Loaded companies: $loadedCompanies'); // ✅ للتأكد

      setState(() {
        _companies.clear();
        _companies.addAll(loadedCompanies);
      });
    } catch (e) {
      safeDebugPrint('❌ Error loading companies: $e');
    }
  }
 */

  Future<void> _loadCompanies() async {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final List<String> ids =
        List<String>.from(userDoc.data()?['companyIds'] ?? []);
    safeDebugPrint('📦 companyIds from Firestore user doc: $ids');

    if (ids.isEmpty) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('companies')
        .where(FieldPath.documentId, whereIn: ids)
        .get();

    final loaded = snapshot.docs
        .map((doc) => {
              'id': doc.id,
              'name': isArabic
                  ? doc.data()['nameAr'] ?? ''
                  : doc.data()['nameEn'] ?? '',
            })
        .toList();

    safeDebugPrint('✅ Loaded companies count: ${loaded.length}');
    setState(() => _companies = loaded);
  }

  Future<void> _addFactory() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCompanyIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('please_select_at_least_one_company'))),
      );
      return;
    }

    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser!;
    final data = {
      'nameAr': _nameAr.text.trim(),
      'nameEn': _nameEn.text.trim(),
      'location': _location.text.trim(),
      'managerName': _manager.text.trim(),
      'managerPhone': _phone.text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'userId': user.uid,
      'companyIds': _selectedCompanyIds,
    };

    try {
      final doc =
          await FirebaseFirestore.instance.collection('factories').add(data);

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'factoryIds': FieldValue.arrayUnion([doc.id]),
      });

      final userData = await UserLocalStorage.getUser();
      if (userData != null) {
        final List<String> existing =
            List<String>.from(userData['factoryIds'] ?? []);
        if (!existing.contains(doc.id)) {
          existing.add(doc.id);
          await UserLocalStorage.saveUser(
            userId: user.uid,
            email: userData['email'] ?? '',
            displayName: userData['displayName'] ?? '',
            companyIds: List<String>.from(userData['companyIds'] ?? []),
            factoryIds: existing,
            supplierIds: List<String>.from(userData['supplierIds'] ?? []),
          );
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('factory_added_successfully'))),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${tr('error_occurred')}: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  TextInputFormatter _getFmt(String lang) {
    switch (lang) {
      case 'arabic':
        return FilteringTextInputFormatter.allow(RegExp(r'[\u0600-\u06FF\s]'));
      case 'english':
        return FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]'));
      case 'digits':
        return FilteringTextInputFormatter.digitsOnly;
      default:
        return FilteringTextInputFormatter.allow(RegExp('.*'));
    }
  }

  Function(String) _onChangeWarn(String lang) => (value) {
        final invalid = lang == 'arabic'
            ? RegExp(r'[^\u0600-\u06FF\s]').hasMatch(value)
            : lang == 'english'
                ? RegExp(r'[^a-zA-Z\s]').hasMatch(value)
                : RegExp(r'[^\d]').hasMatch(value);
        setState(() {
          if (lang == 'arabic') _warnAr = invalid;
          if (lang == 'english') _warnEn = invalid;
          if (lang == 'digits') _warnPhone = invalid;
        });
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('add_factory'))),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameAr,
                decoration: InputDecoration(labelText: tr('factory_nameAr')),
                inputFormatters: [_getFmt('arabic')],
                onChanged: _onChangeWarn('arabic'),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return tr('field_required');
                  }
                  if (_warnAr) return tr('only_arabic_allowed');
                  return null;
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameEn,
                decoration: InputDecoration(labelText: tr('factory_nameEn')),
                inputFormatters: [_getFmt('english')],
                onChanged: _onChangeWarn('english'),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return tr('field_required');
                  }
                  if (_warnEn) return tr('only_english_allowed');
                  return null;
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _location,
                decoration: InputDecoration(labelText: tr('location')),
                validator: (v) =>
                    (v?.trim().isEmpty ?? true) ? tr('field_required') : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _manager,
                decoration: InputDecoration(labelText: tr('managerName')),
                validator: (v) =>
                    (v?.trim().isEmpty ?? true) ? tr('field_required') : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _phone,
                decoration: InputDecoration(labelText: tr('managerPhone')),
                keyboardType: TextInputType.phone,
                inputFormatters: [_getFmt('digits')],
                onChanged: _onChangeWarn('digits'),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return tr('field_required');
                  }
                  if (_warnPhone) return tr('only_digits_allowed');
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Text(tr('select_companies'),
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              _companies.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        tr('no_companies_found'),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    )
                  : Column(
                      children: _companies.map((company) {
                        final companyId = company['id'] as String;
                        final companyName = company['name'] ?? 'Unnamed';

                        return CheckboxListTile(
                          title: Text(companyName),
                          value: _selectedCompanyIds.contains(companyId),
                          onChanged: (selected) {
                            setState(() {
                              if (selected == true) {
                                _selectedCompanyIds.add(companyId);
                              } else {
                                _selectedCompanyIds.remove(companyId);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _addFactory,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(tr('save')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
