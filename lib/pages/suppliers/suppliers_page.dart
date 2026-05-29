// pages/suppliers/suppliers_page.dart - بدون UserLocalStorage
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/supplier.dart';
import '../../widgets/app_scaffold.dart';
import '../../debug_helper.dart';

class SuppliersPage extends StatefulWidget {
  const SuppliersPage({super.key});

  @override
  State<SuppliersPage> createState() => _SuppliersPageState();
}

class _SuppliersPageState extends State<SuppliersPage> {
  String searchQuery = '';
  String? userId;
  String? userName;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      // ✅ الحصول على userId من FirebaseAuth مباشرة
      final user = FirebaseAuth.instance.currentUser;
      
      if (user == null) {
        if (mounted) context.go('/login');
        return;
      }

      // ✅ الحصول على اسم المستخدم من SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final storedUserName = prefs.getString('userName');
      
      setState(() {
        userId = user.uid;
        userName = storedUserName ?? user.displayName ?? user.email?.split('@').first ?? 'User';
        isLoading = false;
      });
    } catch (e) {
      safeDebugPrint('Error loading user data: $e');
      setState(() => isLoading = false);
      if (mounted) context.go('/login');
    }
  }

  Future<void> _confirmDelete(DocumentSnapshot doc) async {
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
            child: Text(tr('delete'), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await doc.reference.delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(tr('supplier_deleted'))),
          );
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

  Future<void> _editSupplier(Supplier supplier) async {
    final result = await context.push('/edit-vendor/${supplier.id}');
    if (result == true && mounted) {
      // تحديث الصفحة بعد التعديل
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: tr('supplier_list'),
      userName: userName,
      body: isLoading || userId == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    decoration: InputDecoration(
                      labelText: tr('search'),
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onChanged: (value) => setState(() => searchQuery = value.toLowerCase()),
                  ),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('vendors')
                        .where(Supplier.fieldUserId, isEqualTo: userId)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(child: Text('${tr('error_occurred')}: ${snapshot.error}'));
                      }

                      final suppliers = snapshot.data!.docs
                          .map((doc) => Supplier.fromMap(doc.data() as Map<String, dynamic>, doc.id))
                          .where((supplier) => 
                              supplier.nameAr.toLowerCase().contains(searchQuery) ||
                              supplier.nameEn.toLowerCase().contains(searchQuery))
                          .toList();

                      if (suppliers.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.business_outlined, size: 64, color: Colors.grey),
                              const SizedBox(height: 16),
                              Text(tr('no_match_search'), style: const TextStyle(color: Colors.grey)),
                            ],
                          ),
                        );
                      }

                      return RefreshIndicator(
                        onRefresh: () async {
                          // تحديث البيانات
                          setState(() {});
                        },
                        child: ListView.builder(
                          itemCount: suppliers.length,
                          itemBuilder: (context, index) {
                            final supplier = suppliers[index];

                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 2,
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.blue.shade100,
                                  child: const Icon(Icons.person, color: Colors.blue),
                                ),
                                title: Text(
                                  supplier.nameAr,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (supplier.nameEn.isNotEmpty)
                                      Text('🏢 ${supplier.nameEn}', style: const TextStyle(fontSize: 12)),
                                    if (supplier.phone.isNotEmpty)
                                      Text('📞 ${supplier.phone}', style: const TextStyle(fontSize: 12)),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit, color: Colors.blue),
                                      tooltip: tr('edit'),
                                      onPressed: () => _editSupplier(supplier),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      tooltip: tr('delete'),
                                      onPressed: () => _confirmDelete(
                                        snapshot.data!.docs[index],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await context.push('/add-supplier');
          if (result == true && mounted) {
            // تحديث الصفحة بعد الإضافة
            setState(() {});
          }
        },
        tooltip: tr('add_supplier'),
        child: const Icon(Icons.add),
      ),
    );
  }
}