import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SelectSupplierDialog extends StatefulWidget {
  final String companyId;

  const SelectSupplierDialog({super.key, required this.companyId});

  @override
  State<SelectSupplierDialog> createState() => _SelectSupplierDialogState();
}

class _SelectSupplierDialogState extends State<SelectSupplierDialog> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final suppliersStream = FirebaseFirestore.instance
        .collection('companies/${widget.companyId}/suppliers')
        .orderBy('name')
        .snapshots();

    return AlertDialog(
      title: const Text('اختر المورد'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'ابحث عن مورد',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.trim().toLowerCase();
                });
              },
            ),
            const SizedBox(height: 10),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: suppliersStream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('حدث خطأ: ${snapshot.error}'));
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snapshot.data?.docs ?? [];

                  // فلترة الموردين بناءً على البحث
                  final filteredSuppliers = docs.where((doc) {
                    final name = (doc['name'] ?? '').toString().toLowerCase();
                    return name.contains(_searchQuery);
                  }).toList();

                  if (filteredSuppliers.isEmpty) {
                    return const Center(child: Text('لا يوجد موردون مطابقون'));
                  }

                  return ListView.builder(
                    itemCount: filteredSuppliers.length,
                    itemBuilder: (context, index) {
                      final supplierDoc = filteredSuppliers[index];
                      final supplierData = supplierDoc.data() as Map<String, dynamic>;

                      return ListTile(
                        title: Text(supplierData['name'] ?? 'بدون اسم'),
                        subtitle: Text(supplierData['contact'] ?? ''),
                        onTap: () {
                          Navigator.of(context).pop({
                            'id': supplierDoc.id,
                            'name': supplierData['name'],
                          });
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          child: const Text('إلغاء'),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}
