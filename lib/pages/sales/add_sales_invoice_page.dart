// pages/sales/add_sales_invoice_page.dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:puresip_purchasing/debug_helper.dart';
import 'package:puresip_purchasing/helpers/company_helper.dart';
import 'package:puresip_purchasing/services/accounting_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddSalesInvoicePage extends StatefulWidget {
  final String? initialCompanyId;
  const AddSalesInvoicePage({super.key, this.initialCompanyId});

  @override
  State<AddSalesInvoicePage> createState() => _AddSalesInvoicePageState();
}

class _AddSalesInvoicePageState extends State<AddSalesInvoicePage> {
  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _productNameController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _unitPriceController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  String? _paymentMethod = 'cash';
  String? _selectedCompanyId;
  final List<Map<String, dynamic>> _items = [];
  double _totalAmount = 0.0;

  @override
  void initState() {
    super.initState();
    _loadCompany();
  }

  Future<void> _loadCompany() async {
    final companies = await CompanyHelper.getUserCompanies();
    if (companies.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('no_companies_found'.tr()),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.pop(context);
      }
      return;
    }

    // ✅ استخدام الشركة الممررة إن وجدت
    String? selectedId = widget.initialCompanyId;
    if (selectedId == null || !companies.any((c) => c['id'] == selectedId)) {
      selectedId = await CompanyHelper.getSelectedCompanyId();
    }
    if (selectedId == null || !companies.any((c) => c['id'] == selectedId)) {
      selectedId = companies.first['id'];
    }
    setState(() {
      _selectedCompanyId = selectedId;
    });
  }

  void _addItem() {
    final productName = _productNameController.text.trim();
    final quantity = double.tryParse(_quantityController.text);
    final unitPrice = double.tryParse(_unitPriceController.text);

    if (productName.isEmpty || quantity == null || unitPrice == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء إدخال بيانات صحيحة'), backgroundColor: Colors.red),
      );
      return;
    }

    final total = quantity * unitPrice;
    setState(() {
      _items.add({
        'productName': productName,
        'quantity': quantity,
        'unitPrice': unitPrice,
        'total': total,
      });
      _totalAmount += total;
      _productNameController.clear();
      _quantityController.clear();
      _unitPriceController.clear();
    });
  }

  void _removeItem(int index) {
    setState(() {
      _totalAmount -= _items[index]['total'] as double;
      _items.removeAt(index);
    });
  }

  Future<void> _saveInvoice() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أضف منتجاً واحداً على الأقل'), backgroundColor: Colors.red),
      );
      return;
    }

    final customerName = _customerNameController.text.trim();
    if (customerName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء إدخال اسم العميل'), backgroundColor: Colors.red),
      );
      return;
    }

    if (_selectedCompanyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الشركة غير محددة'), backgroundColor: Colors.red),
      );
      return;
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');

      final accountingService = AccountingService();
      await accountingService.createSalesInvoiceJournalEntry(
        companyId: _selectedCompanyId!,
        customerId: 'CUST-${DateTime.now().millisecondsSinceEpoch}',
        customerName: customerName,
        totalAmount: _totalAmount,
        description: _descriptionController.text.isNotEmpty
            ? _descriptionController.text
            : 'فاتورة مبيعات للعميل $customerName',
        paymentMethod: _paymentMethod!,
        bankAccountId: null,
        items: _items,
        userId: user.uid,
        entryDate: DateTime.now(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ الفاتورة بنجاح'), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      safeDebugPrint('❌ Error saving invoice: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('add_sales_invoice'.tr()),
        backgroundColor: const Color.fromARGB(255, 69, 200, 218),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _customerNameController,
                decoration: InputDecoration(
                  labelText: 'customer_name'.tr(),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _productNameController,
                      decoration: InputDecoration(
                        labelText: 'product_name'.tr(),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 1,
                    child: TextField(
                      controller: _quantityController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'qty'.tr(),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 1,
                    child: TextField(
                      controller: _unitPriceController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'price'.tr(),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _addItem,
                    icon: const Icon(Icons.add_circle, color: Colors.green),
                    iconSize: 40,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_items.isNotEmpty)
                Card(
                  child: Column(
                    children: _items.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final item = entry.value;
                      return ListTile(
                        title: Text(item['productName']),
                        subtitle: Text('${item['quantity']} × ${item['unitPrice']} = ${item['total']} EGP'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _removeItem(idx),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'total_amount'.tr(),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${_totalAmount.toStringAsFixed(2)} EGP',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _paymentMethod,
                decoration: InputDecoration(labelText: 'payment_method'.tr()),
                items: const [
                  DropdownMenuItem(value: 'cash', child: Text('نقدي')),
                  DropdownMenuItem(value: 'credit', child: Text('آجل')),
                ],
                onChanged: (value) => setState(() => _paymentMethod = value),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'description'.tr(),
                  border: const OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveInvoice,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text('save_invoice'.tr()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}