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
