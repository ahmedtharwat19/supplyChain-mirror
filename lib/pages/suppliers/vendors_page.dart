import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class VendorsPage extends StatefulWidget {
  const VendorsPage({super.key});

  @override
  State<VendorsPage> createState() => _VendorsPageState();
}

class _VendorsPageState extends State<VendorsPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _companyController = TextEditingController();
  bool _isLoading = false;

  Future<void> _addVendor() async {
    final name = _nameController.text.trim();
    final company = _companyController.text.trim();

    if (name.isEmpty || company.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance.collection('vendors').add({
        'name': name,
        'company': company,
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تمت إضافة المورد بنجاح')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        _nameController.clear();
        _companyController.clear();
      }
    }
  }

  void _showAddVendorDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة مورد جديد'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'اسم المورد'),
            ),
            TextField(
              controller: _companyController,
              decoration: const InputDecoration(labelText: 'الشركة'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
          _isLoading
              ? const CircularProgressIndicator()
              : ElevatedButton(
                  onPressed: _addVendor,
                  child: const Text('حفظ'),
                ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الموردين')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('vendors')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text('حدث خطأ'));
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final vendors = snapshot.data!.docs;

          return ListView.builder(
            itemCount: vendors.length,
            itemBuilder: (context, index) {
              final vendor = vendors[index];
              return ListTile(
                title: Text(vendor['name']),
                subtitle: Text(vendor['company']),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddVendorDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
