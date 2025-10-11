import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/app_scaffold.dart';
import 'package:puresip_purchasing/debug_helper.dart';
import 'package:puresip_purchasing/services/hive_service.dart';

class CompaniesPage extends StatefulWidget {
  const CompaniesPage({super.key});

  @override
  State<CompaniesPage> createState() => _CompaniesPageState();
}

class _CompaniesPageState extends State<CompaniesPage> {
  String searchQuery = '';
  List<String> userCompanyIds = [];
  List<Map<String, dynamic>> _companies = [];
  bool _isInitialLoading = true;
  bool _isDataLoading = false;
  String? userName;

  @override
  void initState() {
    super.initState();
    safeDebugPrint('🚀 CompaniesPage initState called');

    _initializeFromHiveFirst();
    _debugHiveContents();
    // 🔥 Fail-safe timer لمنع التحميل اللانهائي
    Timer(const Duration(seconds: 3), () {
      if (mounted && _isInitialLoading) {
        setState(() {
          _isInitialLoading = false;
        });
        safeDebugPrint('⏰ FAIL-SAFE TIMER: _isInitialLoading forced to false');
      }
    });
  }

  Future<void> _initializeFromHiveFirst() async {
    safeDebugPrint('📦 Loading data from Hive first...');

    try {
      // تحميل البيانات الأساسية من Hive
      await _loadUserInfoFromHive();
      await _loadCompaniesFromHive();

      safeDebugPrint('✅ Hive initialization completed');
    } catch (e) {
      safeDebugPrint('❌ Error in initial Hive load: $e');
    } finally {
      // 🔥 هذا هو المهم: تحديث _isInitialLoading في النهاية بغض النظر عما حدث
      if (mounted) {
        setState(() {
          _isInitialLoading = false;
        });
        safeDebugPrint('✅ FINALLY: _isInitialLoading set to false');
      }
    }

    // بدء تحميل البيانات الخلفية بعد عرض الصفحة
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startBackgroundUpdates();
      });
    }
  }

  Future<void> _loadUserInfoFromHive() async {
    try {
      final userData = await HiveService.getUserData();
      if (userData != null) {
        final email = userData['email'] ?? '';
        final name = userData['displayName'] ?? '';
        setState(() {
          userName = name.isNotEmpty ? name : email.split('@')[0];
        });
      }
    } catch (e) {
      safeDebugPrint('❌ Error loading user info from Hive: $e');
    }
  }

  Future<void> _loadCompaniesFromHive() async {
    try {
      safeDebugPrint('🔍 Loading companies from Hive...');

      final cachedCompanies = await HiveService.getCachedData('companies');
      final cachedCompanyIds =
          await HiveService.getCachedData('user_company_ids');

      // إذا كانت البيانات موجودة، استخدمها
      if (cachedCompanies != null &&
          cachedCompanies is List &&
          cachedCompanies.isNotEmpty) {
        // التحويل الآمن للبيانات
        final List<Map<String, dynamic>> convertedCompanies = [];

        for (var company in cachedCompanies) {
          if (company is Map) {
            final Map<String, dynamic> convertedCompany = {};
            company.forEach((key, value) {
              convertedCompany[key.toString()] = value;
            });
            convertedCompanies.add(convertedCompany);
          }
        }

        if (mounted) {
          setState(() {
            _companies = convertedCompanies;
            userCompanyIds = cachedCompanyIds is List
                ? cachedCompanyIds
                    .map((id) => id.toString())
                    .toList()
                    .cast<String>()
                : [];
          });
        }

        safeDebugPrint('✅ Companies loaded from Hive: ${_companies.length}');
        return;
      }

      safeDebugPrint('🔄 No companies found in Hive');
    } catch (e) {
      safeDebugPrint('❌ Error loading from Hive: $e');
    }
  }

  void _startBackgroundUpdates() {
    if (mounted) {
      setState(() => _isDataLoading = true);
    }

    safeDebugPrint('🔄 Starting background updates from Firestore...');

    Future.wait([
      _syncUserDataWithFirestore(),
      _loadCompaniesFromFirestore(),
    ]).then((_) {
      if (mounted) {
        setState(() => _isDataLoading = false);
      }
      safeDebugPrint('✅ All background updates completed');
    }).catchError((error) {
      safeDebugPrint('❌ Error in background updates: $error');
      if (mounted) {
        setState(() => _isDataLoading = false);
      }
    });
  }

  Future<void> _syncUserDataWithFirestore() async {
    safeDebugPrint('🔄 Syncing user data with Firestore...');

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) context.go('/login');
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!mounted) return;

      final data = doc.data();
      if (data != null) {
        final firestoreCompanyIds =
            (data['companyIds'] as List?)?.cast<String>() ?? [];

        // حفظ في Hive
        await HiveService.cacheData('user_company_ids', firestoreCompanyIds);

        setState(() {
          userCompanyIds = firestoreCompanyIds;
        });

        safeDebugPrint(
            '✅ User data synced with Firestore: $firestoreCompanyIds');
      }
    } catch (e) {
      safeDebugPrint('❌ Error syncing user data: $e');
    }
  }

  Future<void> _loadCompaniesFromFirestore() async {
    // إذا لم توجد companyIds، حاول الحصول عليها من بيانات المستخدم أولاً
    if (userCompanyIds.isEmpty) {
      safeDebugPrint('🔄 No company IDs in state, checking user data...');
      final userData = await HiveService.getUserData();
      if (userData != null && userData['companyIds'] is List) {
        setState(() {
          userCompanyIds = (userData['companyIds'] as List).cast<String>();
        });
        safeDebugPrint('🔄 Got company IDs from user data: $userCompanyIds');
      }
    }

    if (userCompanyIds.isEmpty) {
      safeDebugPrint('🔄 No company IDs to load from Firestore');
      return;
    }

    safeDebugPrint(
        '🔄 Loading companies from Firestore for IDs: $userCompanyIds');

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('companies')
          .where(FieldPath.documentId, whereIn: userCompanyIds)
          .get();

      final companies = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();

      safeDebugPrint('✅ Firestore returned ${companies.length} companies');

      // 🔥 هذا هو الجزء المهم: حفظ البيانات في Hive بشكل صحيح
      await _saveCompaniesToHive(companies, userCompanyIds);

      if (mounted) {
        setState(() {
          _companies = companies.cast<Map<String, dynamic>>();
        });
        safeDebugPrint('✅ State updated with ${_companies.length} companies');
      }
    } catch (e) {
      safeDebugPrint('❌ Error loading companies from Firestore: $e');
    }
  }

// 🔥 دالة جديدة لحفظ البيانات في Hive بشكل منفصل
  Future<void> _saveCompaniesToHive(
      List<Map<String, dynamic>> companies, List<String> companyIds) async {
    try {
      safeDebugPrint('💾 ENHANCED: Starting enhanced Hive save...');

      // استخدام HiveService المحسّن
      await HiveService.cacheData('companies', companies);
      await HiveService.cacheData('user_company_ids', companyIds);

      safeDebugPrint('💾 ENHANCED: Save completed');

      // تصحيح شامل للصندوق
      await HiveService.debugHiveBox();
    } catch (e) {
      safeDebugPrint('❌ ENHANCED Hive save error: $e');
    }
  }

  Future<void> _debugHiveContents() async {
    try {
      safeDebugPrint('=== HIVE CONTENTS DEBUG ===');

      // فحص جميع المفاتيح في Hive
      final userData = await HiveService.getUserData();
      safeDebugPrint(
          'User data in Hive: ${userData != null ? "EXISTS" : "NULL"}');

      final companies = await HiveService.getCachedData('companies');
      safeDebugPrint(
          'Companies in Hive: ${companies != null ? (companies is List ? "${companies.length} items" : "EXISTS") : "NULL"}');

      final companyIds = await HiveService.getCachedData('user_company_ids');
      safeDebugPrint('Company IDs in Hive: $companyIds');

      // فحص المفاتيح الأخرى
      final allCachedData = await HiveService.getAllCachedData();
      safeDebugPrint('All keys in Hive: ${allCachedData.keys}');

      safeDebugPrint('=== END HIVE DEBUG ===');
    } catch (e) {
      safeDebugPrint('❌ Error debugging Hive: $e');
    }
  }

  Future<void> _refreshData() async {
    if (mounted) {
      setState(() => _isDataLoading = true);
    }

    try {
      await _syncUserDataWithFirestore();
      await _loadCompaniesFromFirestore();
    } catch (e) {
      safeDebugPrint('❌ Error refreshing data: $e');
    } finally {
      if (mounted) {
        setState(() => _isDataLoading = false);
      }
    }
  }

  Future<void> _confirmDeleteCompany(
      String companyId, Map<String, dynamic> companyData) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('confirm_delete_title')),
        content: Text(tr('confirm_delete_message')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child:
                Text(tr('delete'), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // حذف من Firestore
        await FirebaseFirestore.instance
            .collection('companies')
            .doc(companyId)
            .delete();

        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .update({
            'companyIds': FieldValue.arrayRemove([companyId]),
          });
        }

        // تحديث البيانات المحلية
        _removeCompanyFromLocal(companyId);

        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(tr('company_deleted'))));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${tr('delete_error')}: $e')),
          );
        }
      }
    }
  }

  void _removeCompanyFromLocal(String companyId) {
    setState(() {
      _companies.removeWhere((company) => company['id'] == companyId);
      userCompanyIds.remove(companyId);
    });

    // تحديث Hive
    HiveService.cacheData('companies', _companies);
    HiveService.cacheData('user_company_ids', userCompanyIds);
  }

  Future<void> _editCompany(String companyId) async {
    final company = _companies.firstWhere((c) => c['id'] == companyId);
    await context.push('/edit-company/$companyId', extra: company);
    // إعادة تحميل البيانات بعد التعديل
    _refreshData();
  }

  List<Map<String, dynamic>> get _filteredCompanies {
    safeDebugPrint(
        '🔍 Filtering companies - Total: ${_companies.length}, Query: "$searchQuery"');

    if (searchQuery.isEmpty) {
      safeDebugPrint(
          '🔍 No search query, returning all companies: ${_companies.length}');
      return _companies;
    }

    final filtered = _companies.where((company) {
      final nameAr = (company['nameAr'] ?? '').toString().toLowerCase();
      final nameEn = (company['nameEn'] ?? '').toString().toLowerCase();
      final matches =
          nameAr.contains(searchQuery) || nameEn.contains(searchQuery);

      if (matches) {
        safeDebugPrint('🔍 Company matches search: $nameAr - $nameEn');
      }

      return matches;
    }).toList();

    safeDebugPrint('🔍 Filtered result: ${filtered.length} companies');
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    safeDebugPrint(
        '🎯 BUILD CALLED - _isInitialLoading: $_isInitialLoading, Companies: ${_companies.length}, IDs: $userCompanyIds');

    if (_isInitialLoading) {
      safeDebugPrint('⏳ Showing loading screen...');
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    safeDebugPrint(
        '🎉 Showing companies list with ${_companies.length} companies');

    return AppScaffold(
      title: tr('company_list'),
      userName: userName,
      body: Stack(
        children: [
          Column(
            children: [
              // شريط البحث
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  decoration: InputDecoration(
                    labelText: tr('search'),
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onChanged: (value) =>
                      setState(() => searchQuery = value.toLowerCase()),
                ),
              ),

              // قائمة الشركات
              Expanded(
                child: _buildCompaniesList(),
              ),
            ],
          ),

          // مؤشر تحميل للبيانات الخلفية
          if (_isDataLoading) _buildDataLoadingOverlay(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await context.push('/add-company');
          _refreshData();
        },
        tooltip: tr('add_company'),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildCompaniesList() {
    safeDebugPrint(
        '🔍 Building companies list - Companies: ${_companies.length}, IDs: $userCompanyIds, Loading: $_isInitialLoading');

    if (_isInitialLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // إذا لم توجد شركات ولكن هناك company IDs
    if (_companies.isEmpty && userCompanyIds.isNotEmpty) {
      safeDebugPrint(
          '🔄 Companies array is empty but we have company IDs: $userCompanyIds');
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(tr('no_companies_found')),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _refreshData,
              child: Text(tr('retry')),
            ),
          ],
        ),
      );
    }

    if (userCompanyIds.isEmpty) {
      safeDebugPrint('🔄 No company IDs linked to user');
      return Center(child: Text(tr('no_companies_linked')));
    }

    // استخدام _filteredCompanies هنا
    final filtered = _filteredCompanies;
    safeDebugPrint('🔍 Filtered companies: ${filtered.length}');

    if (filtered.isEmpty) {
      return Center(child: Text(tr('no_match_search')));
    }

    return RefreshIndicator(
      onRefresh: _refreshData,
      child: ListView.builder(
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final company = filtered[index];
          safeDebugPrint(
              '🔍 Building company card: ${company['nameAr']} - ${company['nameEn']}');
          // استخدام _buildCompanyCard هنا
          return _buildCompanyCard(company);
        },
      ),
    );
  }

  Widget _buildCompanyCard(Map<String, dynamic> company) {
    safeDebugPrint('🔍 Building card for company: ${company['id']}');
    safeDebugPrint(
        '🔍 Company data: ${company['nameAr']} - ${company['nameEn']}');

    Uint8List? imageBytes;
    try {
      if (company['logoBase64'] != null &&
          company['logoBase64'].toString().isNotEmpty) {
        safeDebugPrint('🔍 Has logoBase64 data');
        imageBytes = base64Decode(company['logoBase64']);
      } else {
        safeDebugPrint('🔍 No logoBase64 data');
      }
    } catch (e) {
      safeDebugPrint('❌ Error decoding logo: $e');
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 2,
      child: ListTile(
        leading: SizedBox(
          width: 60,
          height: 60,
          child: imageBytes != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(imageBytes, fit: BoxFit.contain),
                )
              : const Icon(Icons.business, size: 40),
        ),
        title: Text(
          '${company['nameAr'] ?? ''} - ${company['nameEn'] ?? ''}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (company['address'] != null &&
                company['address'].toString().isNotEmpty)
              Text('📍 ${company['address']}'),
            if (company['managerName'] != null &&
                company['managerName'].toString().isNotEmpty)
              Text('👤 ${company['managerName']}'),
            if (company['managerPhone'] != null &&
                company['managerPhone'].toString().isNotEmpty)
              Text('📞 ${company['managerPhone']}'),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue),
              tooltip: tr('edit'),
              onPressed: () => _editCompany(company['id']),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              tooltip: tr('delete'),
              onPressed: () => _confirmDeleteCompany(company['id'], company),
            ),
          ],
        ),
        onTap: () {
          safeDebugPrint('🔍 Company tapped: ${company['id']}');
        },
      ),
    );
  }

  Widget _buildDataLoadingOverlay() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(12),
        color: Colors.blue.withAlpha(25),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text(
              tr('updating_data'),
              style: const TextStyle(
                fontSize: 14,
                color: Colors.blue,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* import 'dart:typed_data';
import 'dart:convert';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/app_scaffold.dart';
import 'package:puresip_purchasing/debug_helper.dart';

class CompaniesPage extends StatefulWidget {
  const CompaniesPage({super.key});

  @override
  State<CompaniesPage> createState() => _CompaniesPageState();
}

class _CompaniesPageState extends State<CompaniesPage> {
  String searchQuery = '';
  List<String> userCompanyIds = [];
  bool isLoading = true;
  String? userName;

  @override
  void initState() {
    super.initState();
    loadUserInfo();
    loadUserCompanies();
  }

  Future<void> loadUserInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final email = user.email ?? '';
      final name = user.displayName ?? '';
      setState(() {
        userName = name.isNotEmpty ? name : email.split('@')[0];
      });
    }
  }

  Future<void> loadUserCompanies() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) context.go('/login');
      return;
    }

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (!mounted) return;

    final data = doc.data();
    setState(() {
      userCompanyIds = (data?['companyIds'] as List?)?.cast<String>() ?? [];
      isLoading = false;
    });

    safeDebugPrint('🔹 Loaded company IDs: $userCompanyIds');
  }

  Future<void> _confirmDeleteCompany(DocumentSnapshot company) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('confirm_delete_title')),
        content: Text(tr('confirm_delete_message')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child:
                Text(tr('delete'), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await company.reference.delete();
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .update({
            'companyIds': FieldValue.arrayRemove([company.id]),
          });
        }
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(tr('company_deleted'))));
          await loadUserCompanies();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${tr('delete_error')}: $e')),
          );
        }
      }
    }
  }

  Future<void> _editCompany(DocumentSnapshot company) async {
    final data = company.data() as Map<String, dynamic>;
    await context.push('/edit-company/${company.id}', extra: data);
    if (mounted) loadUserCompanies();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: tr('company_list'),
      userName: userName,
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    decoration: InputDecoration(
                      labelText: tr('search'),
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onChanged: (value) =>
                        setState(() => searchQuery = value.toLowerCase()),
                  ),
                ),
                Expanded(
                  child: userCompanyIds.isEmpty
                      ? Center(child: Text(tr('no_companies_linked')))
                      : StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('companies')
                              .where(FieldPath.documentId,
                                  whereIn: userCompanyIds.isEmpty
                                      ? ['dummy']
                                      : userCompanyIds)
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                  child: CircularProgressIndicator());
                            }

                            if (snapshot.hasError) {
                              return Center(
                                child: Text(
                                    '${tr('error_occurred')}: ${snapshot.error}'),
                              );
                            }

                            final companies = snapshot.data?.docs ?? [];

                            final filtered = companies.where((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              final nameAr = (data['nameAr'] ?? '')
                                  .toString()
                                  .toLowerCase();
                              final nameEn = (data['nameEn'] ?? '')
                                  .toString()
                                  .toLowerCase();
                              return nameAr.contains(searchQuery) ||
                                  nameEn.contains(searchQuery);
                            }).toList();

                            if (filtered.isEmpty) {
                              return Center(child: Text(tr('no_match_search')));
                            }

                            return ListView.builder(
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final company = filtered[index];
                                final data =
                                    company.data() as Map<String, dynamic>;

                                Uint8List? imageBytes;
                                try {
                                  if (data['logoBase64'] != null &&
                                      data['logoBase64']
                                          .toString()
                                          .isNotEmpty) {
                                    imageBytes =
                                        base64Decode(data['logoBase64']);
                                  }
                                } catch (_) {}

                                return Card(
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  elevation: 2,
                                  child: ListTile(
                                    leading: SizedBox(
                                      width: 60,
                                      height: 60,
                                      child: imageBytes != null
                                          ? ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: Image.memory(imageBytes,
                                                  fit: BoxFit.contain),
                                            )
                                          : const Icon(Icons.business,
                                              size: 40),
                                    ),
                                    title: Text(
                                        '${data['nameAr'] ?? ''} - ${data['nameEn'] ?? ''}'),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (data['address'] != null)
                                          Text('📍 ${data['address']}'),
                                        if (data['managerName'] != null)
                                          Text('👤 ${data['managerName']}'),
                                        if (data['managerPhone'] != null)
                                          Text('📞 ${data['managerPhone']}'),
                                      ],
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit,
                                              color: Colors.blue),
                                          tooltip: tr('edit'),
                                          onPressed: () =>
                                              _editCompany(company),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete,
                                              color: Colors.red),
                                          tooltip: tr('delete'),
                                          onPressed: () =>
                                              _confirmDeleteCompany(company),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await context.push('/add-company');
          if (mounted) loadUserCompanies();
        },
        tooltip: tr('add_company'),
        child: const Icon(Icons.add),
      ),
    );
  }
}
 */
