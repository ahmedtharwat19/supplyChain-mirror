/* 
// pages/admin/admin_users_page.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:puresip_purchasing/debug_helper.dart';
import 'package:puresip_purchasing/widgets/app_scaffold.dart';

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════
  // حذف المستخدم عبر Cloud Function
  // ══════════════════════════════════════════════
  Future<void> _deleteUser(Map<String, dynamic> userData) async {
    final userId = userData['userId'] as String? ?? '';
    final name = userData['displayName'] as String? ??
        userData['email'] as String? ??
        'this_user'.tr();

    // ── تأكيد الحذف ──
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('delete_confirm_title'.tr()),
        content: Text('delete_confirm_message'.tr(args: [name])),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('cancel'.tr()),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('delete'.tr(), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // ── Loading dialog ──
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final db = FirebaseFirestore.instance;
      final batch = db.batch();

      // أ) تعطيل الحساب + تمييزه كمحذوف
      batch.update(db.collection('users').doc(userId), {
        'isActive': false,
        'isDeleted': true,
        'deletedAt': FieldValue.serverTimestamp(),
      });

      // ب) حذف الترخيص
      final licenseKey = userData['licenseKey'] as String?;
      if (licenseKey != null && licenseKey.isNotEmpty) {
        batch.delete(db.collection('licenses').doc(licenseKey));
      }

      // ج) حذف طلبات الترخيص
      final licenseRequests = await db
          .collection('license_requests')
          .where('userId', isEqualTo: userId)
          .get();
      for (final doc in licenseRequests.docs) {
        batch.delete(doc.reference);
      }

      // د) حذف الشركات
      final companyIds = List<String>.from(userData['companyIds'] ?? []);
      for (final id in companyIds) {
        batch.delete(db.collection('companies').doc(id));
      }

      // هـ) حذف المصانع
      final factoryIds = List<String>.from(userData['factoryIds'] ?? []);
      for (final id in factoryIds) {
        batch.delete(db.collection('factories').doc(id));
      }

      // و) حذف user_stats
      final statsDoc = await db.collection('user_stats').doc(userId).get();
      if (statsDoc.exists) batch.delete(statsDoc.reference);

      // ز) حذف user document نفسه
      batch.delete(db.collection('users').doc(userId));

      await batch.commit();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('delete_success0'.tr(args: [name])),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      safeDebugPrint('❌ Delete user error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('delete_error'.tr()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ══════════════════════════════════════════════
  // بناء كارت المستخدم
  // ══════════════════════════════════════════════
  Widget _buildUserCard(Map<String, dynamic> data) {
    final name = data['displayName'] as String? ?? '';
    final email = data['email'] as String? ?? '';
    final phone = data['phoneNumber'] as String? ?? '';
    final isActive = data['isActive'] as bool? ?? false;
    final isAdmin = data['isAdmin'] as bool? ?? false;
    final licenseType = data['licenseType'] as String? ?? '';
    final licenseKey = data['licenseKey'] as String? ?? '';

    Timestamp? expiry;
    try {
      expiry = data['license_expiry'] as Timestamp?;
    } catch (_) {}

    final expiryDate = expiry?.toDate();
    final isExpired =
        expiryDate != null && expiryDate.isBefore(DateTime.now());

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── الصف الأول: الاسم + الحالة + زر الحذف ──
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: isAdmin
                      ? Colors.amber.shade100
                      : Colors.blue.shade50,
                  child: Icon(
                    isAdmin ? Icons.admin_panel_settings : Icons.person,
                    color: isAdmin ? Colors.amber.shade800 : Colors.blue,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name.isEmpty ? email : name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isAdmin)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text('admin_label'.tr(),
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.amber.shade800,
                                      fontWeight: FontWeight.bold)),
                            ),
                        ],
                      ),
                      Text(email,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                // ── زر الحذف (مخفي للأدمن) ──
                if (!isAdmin)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    tooltip: 'delete_user'.tr(),
                    onPressed: () => _deleteUser(data),
                  ),
              ],
            ),
            const Divider(height: 16),
            // ── الصف الثاني: التفاصيل ──
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _chip(
                  icon: isActive ? Icons.check_circle : Icons.cancel,
                  label: isActive ? 'active'.tr() : 'inactive'.tr(),
                  color: isActive ? Colors.green : Colors.grey,
                ),
                if (licenseType.isNotEmpty)
                  _chip(
                    icon: Icons.key,
                    label: licenseType == 'trial' ? 'trial'.tr() : 'licensed'.tr(),
                    color:
                        licenseType == 'trial' ? Colors.orange : Colors.blue,
                  ),
                if (expiryDate != null)
                  _chip(
                    icon: isExpired ? Icons.timer_off : Icons.timer,
                    label: isExpired
                        ? 'expired_on'.tr(args: [_formatDate(expiryDate)])
                        : 'expires_on0'.tr(args: [_formatDate(expiryDate)]),
                    color: isExpired ? Colors.red : Colors.teal,
                  ),
                if (phone.isNotEmpty)
                  _chip(
                    icon: Icons.phone,
                    label: phone,
                    color: Colors.blueGrey,
                  ),
              ],
            ),
            if (licenseKey.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'License: $licenseKey',
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _chip(
      {required IconData icon,
      required String label,
      required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11, color: color, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  // ══════════════════════════════════════════════
  // Build
  // ══════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'admin_users_title'.tr(),
      body: Column(
        children: [
          // ── شريط البحث ──
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'search_users_hint'.tr(),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
            ),
          ),

          // ── قائمة المستخدمين ──
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('load_error'.tr(args: [snapshot.error.toString()])),
                  );
                }

                final allDocs = snapshot.data?.docs ?? [];

                // ── فلترة البحث ──
                final filtered = _searchQuery.isEmpty
                    ? allDocs
                    : allDocs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final name = (data['displayName'] ?? '').toString().toLowerCase();
                        final email = (data['email'] ?? '').toString().toLowerCase();
                        return name.contains(_searchQuery) ||
                            email.contains(_searchQuery);
                      }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.people_outline,
                            size: 64, color: Colors.grey),
                        const SizedBox(height: 12),
                        Text(
                          _searchQuery.isEmpty
                              ? 'no_users'.tr()
                              : 'no_search_results'.tr(args: [_searchQuery]),
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  children: [
                    // ── عدد المستخدمين ──
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      child: Row(
                        children: [
                          Text(
                            'users_count'.tr(args: [filtered.length.toString()]),
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 13),
                          ),
                          if (_searchQuery.isNotEmpty)
                            Text(
                              ' (${'out_of'.tr()} ${allDocs.length})',
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 13),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final data = filtered[index].data()
                              as Map<String, dynamic>;
                          return _buildUserCard(data);
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
} */

// pages/admin/admin_users_page.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:puresip_purchasing/debug_helper.dart';
import 'package:puresip_purchasing/widgets/app_scaffold.dart';

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════
  // حذف المستخدم مع Retry + Backoff
  // ══════════════════════════════════════════════
  Future<void> _deleteUser(Map<String, dynamic> userData) async {
    final userId = userData['userId'] as String? ?? '';
    final name = userData['displayName'] as String? ??
        userData['email'] as String? ??
        'this_user'.tr();

    // ── تأكيد الحذف ──
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('delete_confirm_title'.tr()),
        content: Text('delete_confirm_message'.tr(args: [name])),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('cancel'.tr()),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('delete'.tr(),
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // ── Loading dialog ──
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    // ── Retry مع Exponential Backoff ──
    const maxRetries = 3;
    Object? lastError;

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        safeDebugPrint('🗑️ Delete attempt $attempt/$maxRetries for: $userId');

        final db = FirebaseFirestore.instance;
        final batch = db.batch();

        // أ) تعطيل الحساب + تمييزه كمحذوف
        batch.update(db.collection('users').doc(userId), {
          'isActive': false,
          'isDeleted': true,
          'deletedAt': FieldValue.serverTimestamp(),
        });

        // ب) حذف الترخيص
        final licenseKey = userData['licenseKey'] as String?;
        if (licenseKey != null && licenseKey.isNotEmpty) {
          batch.delete(db.collection('licenses').doc(licenseKey));
        }

        // ج) حذف طلبات الترخيص
        final licenseRequests = await db
            .collection('license_requests')
            .where('userId', isEqualTo: userId)
            .get();
        for (final doc in licenseRequests.docs) {
          batch.delete(doc.reference);
        }

        // د) حذف طلبات الأجهزة ✅ جديد
        final deviceRequests = await db
            .collection('device_requests')
            .where('userId', isEqualTo: userId)
            .get();
        for (final doc in deviceRequests.docs) {
          batch.delete(doc.reference);
        }

        // هـ) حذف الشركات
        final companyIds =
            List<String>.from(userData['companyIds'] ?? []);
        for (final id in companyIds) {
          batch.delete(db.collection('companies').doc(id));
        }

        // و) حذف المصانع
        final factoryIds =
            List<String>.from(userData['factoryIds'] ?? []);
        for (final id in factoryIds) {
          batch.delete(db.collection('factories').doc(id));
        }

        // ز) حذف user_stats
        final statsDoc =
            await db.collection('user_stats').doc(userId).get();
        if (statsDoc.exists) batch.delete(statsDoc.reference);

        // ح) حذف user document نفسه
        batch.delete(db.collection('users').doc(userId));

        await batch.commit();

        safeDebugPrint('✅ User deleted successfully: $userId');

        if (mounted) {
          Navigator.pop(context); // أغلق loading
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('delete_success0'.tr(args: [name])),
              backgroundColor: Colors.green,
            ),
          );
        }
        return; // ✅ نجح

      } catch (e) {
        lastError = e;
        safeDebugPrint('❌ Delete attempt $attempt failed: $e');

        final isUnavailable = e.toString().contains('unavailable') ||
            e.toString().contains('UNAVAILABLE');

        if (isUnavailable && attempt < maxRetries) {
          // Exponential backoff: 1s → 2s → 4s
          final delay = Duration(seconds: 1 << (attempt - 1));
          safeDebugPrint('⏳ Retrying in ${delay.inSeconds}s...');
          await Future.delayed(delay);
          continue;
        }

        break; // خطأ غير قابل للـ retry
      }
    }

    // ── فشل بعد كل المحاولات ──
    if (mounted) Navigator.pop(context);
    safeDebugPrint(
        '❌ Delete user failed after $maxRetries attempts: $lastError');

    if (mounted) {
      final isNetworkError = lastError.toString().contains('unavailable') ||
          lastError.toString().contains('UNAVAILABLE');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isNetworkError ? 'delete_error_network'.tr() : 'delete_error'.tr(),
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
          action: isNetworkError
              ? SnackBarAction(
                  label: 'retry'.tr(),
                  textColor: Colors.white,
                  onPressed: () => _deleteUser(userData), // ✅ retry يدوي
                )
              : null,
        ),
      );
    }
  }

  // ══════════════════════════════════════════════
  // بناء كارت المستخدم
  // ══════════════════════════════════════════════
  Widget _buildUserCard(Map<String, dynamic> data) {
    final name = data['displayName'] as String? ?? '';
    final email = data['email'] as String? ?? '';
    final phone = data['phoneNumber'] as String? ?? '';
    final isActive = data['isActive'] as bool? ?? false;
    final isAdmin = data['isAdmin'] as bool? ?? false;
    final licenseType = data['licenseType'] as String? ?? '';
    final licenseKey = data['licenseKey'] as String? ?? '';

    Timestamp? expiry;
    try {
      expiry = data['license_expiry'] as Timestamp?;
    } catch (_) {}

    final expiryDate = expiry?.toDate();
    final isExpired =
        expiryDate != null && expiryDate.isBefore(DateTime.now());

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── الصف الأول: الاسم + الحالة + زر الحذف ──
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: isAdmin
                      ? Colors.amber.shade100
                      : Colors.blue.shade50,
                  child: Icon(
                    isAdmin ? Icons.admin_panel_settings : Icons.person,
                    color: isAdmin ? Colors.amber.shade800 : Colors.blue,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name.isEmpty ? email : name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isAdmin)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text('admin_label'.tr(),
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.amber.shade800,
                                      fontWeight: FontWeight.bold)),
                            ),
                        ],
                      ),
                      Text(email,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                // ── زر الحذف (مخفي للأدمن) ──
                if (!isAdmin)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    tooltip: 'delete_user'.tr(),
                    onPressed: () => _deleteUser(data),
                  ),
              ],
            ),
            const Divider(height: 16),
            // ── الصف الثاني: التفاصيل ──
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _chip(
                  icon: isActive ? Icons.check_circle : Icons.cancel,
                  label: isActive ? 'active'.tr() : 'inactive'.tr(),
                  color: isActive ? Colors.green : Colors.grey,
                ),
                if (licenseType.isNotEmpty)
                  _chip(
                    icon: licenseType == 'trial'
                        ? Icons.science_outlined
                        : Icons.verified,
                    label: licenseType == 'trial'
                        ? 'trial'.tr()
                        : 'licensed'.tr(),
                    color: licenseType == 'trial'
                        ? Colors.orange
                        : Colors.blue,
                  ),
                if (expiryDate != null)
                  _chip(
                    icon: isExpired ? Icons.timer_off : Icons.timer,
                    label: isExpired
                        ? 'expired_on'.tr(args: [_formatDate(expiryDate)])
                        : 'expires_on0'
                            .tr(args: [_formatDate(expiryDate)]),
                    color: isExpired ? Colors.red : Colors.teal,
                  ),
                if (phone.isNotEmpty)
                  _chip(
                    icon: Icons.phone,
                    label: phone,
                    color: Colors.blueGrey,
                  ),
              ],
            ),
            if (licenseKey.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'License: $licenseKey',
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _chip(
      {required IconData icon,
      required String label,
      required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  // ══════════════════════════════════════════════
  // Build
  // ══════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'admin_users_title'.tr(),
      body: Column(
        children: [
          // ── شريط البحث ──
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'search_users_hint'.tr(),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: (v) =>
                  setState(() => _searchQuery = v.toLowerCase()),
            ),
          ),

          // ── قائمة المستخدمين ──
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('load_error'
                        .tr(args: [snapshot.error.toString()])),
                  );
                }

                final allDocs = snapshot.data?.docs ?? [];

                // ── فلترة البحث ──
                final filtered = _searchQuery.isEmpty
                    ? allDocs
                    : allDocs.where((doc) {
                        final data =
                            doc.data() as Map<String, dynamic>;
                        final name = (data['displayName'] ?? '')
                            .toString()
                            .toLowerCase();
                        final email = (data['email'] ?? '')
                            .toString()
                            .toLowerCase();
                        return name.contains(_searchQuery) ||
                            email.contains(_searchQuery);
                      }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.people_outline,
                            size: 64, color: Colors.grey),
                        const SizedBox(height: 12),
                        Text(
                          _searchQuery.isEmpty
                              ? 'no_users'.tr()
                              : 'no_search_results'
                                  .tr(args: [_searchQuery]),
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  children: [
                    // ── عدد المستخدمين ──
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      child: Row(
                        children: [
                          Text(
                            'users_count'.tr(
                                args: [filtered.length.toString()]),
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 13),
                          ),
                          if (_searchQuery.isNotEmpty)
                            Text(
                              ' (${'out_of'.tr()} ${allDocs.length})',
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 13),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final data = filtered[index].data()
                              as Map<String, dynamic>;
                          return _buildUserCard(data);
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}