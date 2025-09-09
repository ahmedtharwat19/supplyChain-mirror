/* import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:puresip_purchasing/widgets/app_scaffold.dart';
import '../../utils/user_local_storage.dart';
import 'package:easy_localization/easy_localization.dart';

class ItemsPage extends StatefulWidget {
  const ItemsPage({super.key});

  @override
  State<ItemsPage> createState() => _ItemsPageState();
}

class _ItemsPageState extends State<ItemsPage> {
  String? userId;
  bool isLoading = true;

@override
void initState() {
  super.initState();
  safeDebugPrint("🚀 initState: Starting to load user...");
  _loadUser();
}

Future<void> _loadUser() async {
  final user = await UserLocalStorage.getUser();
  safeDebugPrint("👤 Loaded user: $user");

  if (!mounted) return;

  if (user == null) {
    safeDebugPrint("⚠️ No user found in local storage.");
    setState(() {
      isLoading = false;
    });
    return;
  }

  setState(() {
    userId = user['userId'];
    isLoading = false;
  });

  safeDebugPrint("✅ User ID set to: $userId");
}



Future<List<QueryDocumentSnapshot>> _fetchUserItems() async {
  if (userId == null) {
    safeDebugPrint("❌ Cannot fetch items: userId is null");
    return [];
  }

  try {
    safeDebugPrint("📦 Fetching items for user: $userId...");
    final snapshot = await FirebaseFirestore.instance
        .collection('items')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .get();

    safeDebugPrint("📦 Retrieved ${snapshot.docs.length} items for user: $userId");

    for (var doc in snapshot.docs) {
      safeDebugPrint("✅ Item: ${doc.data()}");
    }

    return snapshot.docs;
  } catch (e) {
    safeDebugPrint("❌ Error fetching items: $e");
    return [];
  }
}

Future<List<String>> _getSupplierNames(List<dynamic> supplierIds) async {
  try {
    if (supplierIds.isEmpty) {
      safeDebugPrint("ℹ️ No supplier IDs provided.");
      return [];
    }

    safeDebugPrint("🔍 Fetching supplier names for IDs: $supplierIds");

    final suppliersSnapshot = await FirebaseFirestore.instance
        .collection('vendors')
        .where(FieldPath.documentId, whereIn: supplierIds)
        .get();

    safeDebugPrint("✅ Fetched ${suppliersSnapshot.docs.length} suppliers.");

    return suppliersSnapshot.docs
        .map((doc) => doc.data()['name']?.toString() ?? 'N/A')
        .toList();
  } catch (e) {
    safeDebugPrint("❌ Error fetching supplier names: $e");
    return ['Error loading suppliers'];
  }
}


  String _typeName(String type) {
    return {
          'raw_material': tr('raw_material'),
          'packaging_material': tr('packaging_material'),
        }[type] ??
        type;
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return AppScaffold(
/*       appBar: AppBar(
        title: Text(tr('manage_items')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.go('/dashboard'), // العودة للصفحة الرئيسية باستخدام GoRouter
        ),
      ), */
      title: tr('manage_items'),
      body: FutureBuilder<List<QueryDocumentSnapshot>>(
        future: _fetchUserItems(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
             safeDebugPrint("⏳ Waiting for items to load...");
            return Center(child: Text(tr('loading_items')));
          }
          if (snapshot.hasError) {

            safeDebugPrint("❌ Error loading items: ${snapshot.error}");

            return Center(
              
                child: Text('${tr('error_occurred')}: ${snapshot.error}'));
          }
          final items = snapshot.data ?? [];
          safeDebugPrint("📋 Final item count in UI: ${items.length}");
          if (items.isEmpty) {
            return Center(child: Text(tr('no_items_found')));
          }

          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final doc = items[index];
              final data = doc.data() as Map<String, dynamic>;

              return FutureBuilder<List<String>>(
                future: _getSupplierNames(data['supplierIds'] ?? []),
                builder: (context, suppliersSnapshot) {
                  final supplierNames = suppliersSnapshot.data ?? [];

                  return Card(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: ListTile(
                      title: Text(data['name'] ?? tr('unnamed')),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              '${tr('unit_price')}: ${data['unitPrice']?.toStringAsFixed(2) ?? 'N/A'}'),
                          Text(
                              '${tr('item_type')}: ${_typeName(data['type'] ?? '')}'),
                          if (supplierNames.isNotEmpty)
                            Text(
                                '${tr('suppliers')}: ${supplierNames.join(', ')}'),
                        ],
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (action) => _onItemAction(action, doc),
                        itemBuilder: (ctx) => [
                          PopupMenuItem(value: 'edit', child: Text(tr('edit'))),
                          PopupMenuItem(
                              value: 'delete', child: Text(tr('delete'))),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () =>
            context.push('/items/add'), // فتح صفحة إضافة صنف جديدة (مثال)
        tooltip: tr('add_item'),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _onItemAction(String action, QueryDocumentSnapshot doc) {
    if (action == 'delete') {
      _deleteItem(doc);
    } else {
      context.push(
          '/items/edit/${doc.id}'); // فتح صفحة تعديل الصنف باستخدام GoRouter
    }
  }

  Future<void> _deleteItem(QueryDocumentSnapshot itemDoc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('confirm_delete')),
        content: Text(tr('delete_item_confirm')),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(tr('cancel'))),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child:
                Text(tr('delete'), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await itemDoc.reference.delete();
      if (!mounted) return;
      setState(() {});
    }
  }
}
 */

/* 
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/app_scaffold.dart';

class ItemsPage extends StatefulWidget {
  const ItemsPage({super.key});

  @override
  State<ItemsPage> createState() => _ItemsPageState();
}

class _ItemsPageState extends State<ItemsPage> {
  String searchQuery = '';
  bool isLoading = true;
  String? userId;
  List<Map<String, dynamic>> items = [];

  @override
  void initState() {
    super.initState();
    _loadUserAndItems();
  }

  Future<void> _loadUserAndItems() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) context.go('/login');
      return;
    }
    setState(() {
      userId = user.uid;
    });

    await _fetchUserItems();
  }

  Future<void> _fetchUserItems() async {
    if (userId == null) return;

    setState(() {
      isLoading = true;
    });

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('items')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      final loadedItems = querySnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();

      if (mounted) {
        setState(() {
          items = loadedItems;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${tr('error_occurred')}: $e')),
        );
      }
    }
  }

  Future<void> _confirmDeleteItem(String itemId) async {
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
        await FirebaseFirestore.instance.collection('items').doc(itemId).delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(tr('item_deleted'))),
          );
          await _fetchUserItems();
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

  Future<void> _editItem(Map<String, dynamic> itemData) async {
    await context.push('/edit-item/${itemData['id']}', extra: itemData);
    if (mounted) _fetchUserItems();
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = items.where((item) {
      final name = (item['nameAr'] ?? '').toString().toLowerCase();
      return name.contains(searchQuery.toLowerCase());
    }).toList();

    return AppScaffold(
      title: tr('items_list'),
      userName: userId, // ممكن تعدل لتحمل اسم المستخدم مثل companies page
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
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onChanged: (value) => setState(() => searchQuery = value),
                  ),
                ),
                Expanded(
                  child: filteredItems.isEmpty
                      ? Center(child: Text(tr('no_items_found')))
                      : ListView.builder(
                          itemCount: filteredItems.length,
                          itemBuilder: (context, index) {
                            final item = filteredItems[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              elevation: 2,
                              child: ListTile(
                                title: Text(item['nameAr'] ?? ''),
                                subtitle: Text('${tr('unit_price')}: ${item['unit_price'] ?? '-'}'),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit, color: Colors.blue),
                                      tooltip: tr('edit'),
                                      onPressed: () => _editItem(item),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      tooltip: tr('delete'),
                                      onPressed: () => _confirmDeleteItem(item['id']),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await context.push('/items/add');
          if (mounted) _fetchUserItems();
        },
        tooltip: tr('add_item'),
        child: const Icon(Icons.add),
      ),
    );
  }
}
 */

/* 
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/app_scaffold.dart';

class ItemsPage extends StatefulWidget {
  const ItemsPage({super.key});

  @override
  State<ItemsPage> createState() => _ItemsPageState();
}

class _ItemsPageState extends State<ItemsPage> {
  String searchQuery = '';
  bool isLoading = true;
  String? userId;
  List<Map<String, dynamic>> items = [];

  @override
  void initState() {
    super.initState();
    _loadUserAndItems();
  }

  Future<void> _loadUserAndItems() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) context.go('/login');
      return;
    }
    setState(() {
      userId = user.uid;
    });

    await _fetchUserItems();
  }

  Future<void> _fetchUserItems() async {
    if (userId == null) return;

    setState(() {
      isLoading = true;
    });

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('items')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      final loadedItems = querySnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();

      if (mounted) {
        setState(() {
          items = loadedItems;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${tr('error_occurred')}: $e')),
        );
      }
    }
  }

  Future<void> _confirmDeleteItem(String itemId) async {
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
        await FirebaseFirestore.instance.collection('items').doc(itemId).delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(tr('item_deleted'))),
          );
          await _fetchUserItems();
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

  Future<void> _editItem(Map<String, dynamic> itemData) async {
    await context.push('/edit-item/${itemData['id']}', extra: itemData);
    if (mounted) _fetchUserItems();
  }

  String _typeName(String type) {
    return {
      'raw_material': tr('raw_material'),
      'packaging_material': tr('packaging_material'),
    }[type] ?? type;
  }

  @override
  Widget build(BuildContext context) {
    final currentLocale = context.locale.languageCode;
    final filteredItems = items.where((item) {
      final name = (currentLocale == 'ar' ? item['nameAr'] ?? '' : item['nameEn'] ?? '').toString().toLowerCase();
      return name.contains(searchQuery.toLowerCase());
    }).toList();

    return AppScaffold(
      title: tr('items_list'),
      userName: userId, // ممكن تعدل لتحمل اسم المستخدم مثل companies page
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
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onChanged: (value) => setState(() => searchQuery = value),
                  ),
                ),
                Expanded(
                  child: filteredItems.isEmpty
                      ? Center(child: Text(tr('no_items_found')))
                      : ListView.builder(
                          itemCount: filteredItems.length,
                          itemBuilder: (context, index) {
                            final item = filteredItems[index];
                            final itemName = currentLocale == 'ar'
                                ? item['nameAr'] ?? ''
                                : item['nameEn'] ?? '';

                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              elevation: 2,
                              child: ListTile(
                                title: Text(itemName),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('${tr('unit_price')}: ${item['unit_price'] ?? '-'}'),
                                    if (item['unit'] != null)
                                      Text('${tr('unit')}: ${item['unit']}'),
                                    if (item['type'] != null)
                                      Text('${tr('item_type')}: ${_typeName(item['type'])}'),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit, color: Colors.blue),
                                      tooltip: tr('edit'),
                                      onPressed: () => _editItem(item),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      tooltip: tr('delete'),
                                      onPressed: () => _confirmDeleteItem(item['id']),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await context.push('/items/add');
          if (mounted) _fetchUserItems();
        },
        tooltip: tr('add_item'),
        child: const Icon(Icons.add),
      ),
    );
  }
}
 */

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/app_scaffold.dart';
import 'package:puresip_purchasing/debug_helper.dart';


class ItemsPage extends StatefulWidget {
  const ItemsPage({super.key});

  @override
  State<ItemsPage> createState() => _ItemsPageState();
}

class _ItemsPageState extends State<ItemsPage> {
  String searchQuery = '';
  bool isLoading = true;
  String? userId;
  String? userName;
  List<Map<String, dynamic>> items = [];

  @override
  void initState() {
    super.initState();
    _loadUserAndItems();
  }

  Future<void> _loadUserAndItems() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        userId = user.uid;
        // خذ الاسم من displayName لو موجود، وإذا ما موجود استخدم جزء من الإيميل
        userName = user.displayName != null && user.displayName!.isNotEmpty
            ? user.displayName
            : user.email?.split('@')[0];
      });

      await _fetchUserItems();
    } else {
      if (mounted) context.go('/login');
    }
  }

  Future<void> _fetchUserItems() async {
    if (userId == null) return;

    setState(() {
      isLoading = true;
    });

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('items')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      final loadedItems = querySnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();

      if (mounted) {
        setState(() {
          items = loadedItems;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${tr('error_occurred')}: $e')),
          
        );
        safeDebugPrint("❌ Error fetching items: $e");
      }
    }
  }

  Future<void> _confirmDeleteItem(String itemId) async {
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
        await FirebaseFirestore.instance
            .collection('items')
            .doc(itemId)
            .delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(tr('item_deleted'))),
          );
          await _fetchUserItems();
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

  Future<void> _editItem(Map<String, dynamic> itemData) async {
    await context.push('/edit-item/${itemData['id']}', extra: itemData);
    if (mounted) _fetchUserItems();
  }

  String _typeName(String type) {
    return {
          'raw_material': tr('raw_material'),
          'packaging_material': tr('packaging_material'),
        }[type] ??
        type;
  }

  String _categoryName(String category) {
    return {
          'raw_material': tr('raw_material'),
          'packaging': tr('packaging'),
          'finished_product': tr('finished_product'),
          'service': tr('service'),
          'accessory': tr('accessory'),
          'other': tr('other'),
        }[category] ??
        category;
  }

  @override
  Widget build(BuildContext context) {
    final currentLocale = context.locale.languageCode;
    final filteredItems = items.where((item) {
      final name = (currentLocale == 'ar'
              ? item['nameAr'] ?? ''
              : item['nameEn'] ?? '')
          .toString()
          .toLowerCase();
      return name.contains(searchQuery.toLowerCase());
    }).toList();

    return AppScaffold(
      title: tr('items_list'),
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
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onChanged: (value) => setState(() => searchQuery = value),
                  ),
                ),
                Expanded(
                  child: filteredItems.isEmpty
                      ? Center(child: Text(tr('no_items_found')))
                      : ListView.builder(
                          itemCount: filteredItems.length,
                          itemBuilder: (context, index) {
                            final item = filteredItems[index];
                            final itemName = currentLocale == 'ar'
                                ? item['nameAr'] ?? ''
                                : item['nameEn'] ?? '';

                            return Card(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              elevation: 2,
                              child: ListTile(
                                title: Text(itemName),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                        '${tr('unit_price')}: ${item['unitPrice'] ?? '-'}'),
                                    if (item['unit'] != null)
                                      Text('${tr('unit')}: ${item['unit']}'),
                                    if (item['type'] != null)
                                      Text(
                                          '${tr('item_type')}: ${_typeName(item['type'])}'),
                                    if (item['category'] != null)
                                      Text(
                                          '${tr('category')}: ${_categoryName(item['category'])}'),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit,
                                          color: Colors.blue),
                                      tooltip: tr('edit'),
                                      onPressed: () => _editItem(item),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete,
                                          color: Colors.red),
                                      tooltip: tr('delete'),
                                      onPressed: () =>
                                          _confirmDeleteItem(item['id']),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await context.push('/items/add');
          if (mounted) _fetchUserItems();
        },
        tooltip: tr('add_item'),
        child: const Icon(Icons.add),
      ),
    );
  }
}
