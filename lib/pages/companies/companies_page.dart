import 'dart:typed_data';
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
