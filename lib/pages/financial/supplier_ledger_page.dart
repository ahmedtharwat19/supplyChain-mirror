// pages/financial/supplier_ledger_page.dart
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:puresip_purchasing/debug_helper.dart';
import 'package:puresip_purchasing/helpers/company_helper.dart';
import 'package:puresip_purchasing/models/journal_entry.dart';
import 'package:puresip_purchasing/models/supplier.dart';
import 'package:puresip_purchasing/widgets/app_scaffold.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SupplierLedgerPage extends StatefulWidget {
  const SupplierLedgerPage({super.key});

  @override
  State<SupplierLedgerPage> createState() => _SupplierLedgerPageState();
}

class _SupplierLedgerPageState extends State<SupplierLedgerPage> {
  String? _selectedSupplierId;
  List<Supplier> _suppliers = [];
  List<JournalEntry> _entries = [];
  double _totalBalance = 0.0;
  bool _isLoading = true;
  bool _isSyncing = false;

  // متغيرات اختيار الشركة
  String? _selectedCompanyId;
  List<Map<String, String>> _companies = [];
  String? supplierAccountId;

  static const String _keySuppliersCache = 'suppliers_cache';
  static const String _keyLedgerCachePrefix = 'supplier_ledger_';

  @override
  void initState() {
    super.initState();
    _loadCompaniesAndData();
  }

  Future<void> _loadCompaniesAndData() async {
    try {
      final companies = await CompanyHelper.getUserCompanies();
      if (companies.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('no_companies_found'.tr()),
                backgroundColor: Colors.red),
          );
          setState(() => _isLoading = false);
        }
        return;
      }

      String? selectedId = await CompanyHelper.getSelectedCompanyId();
      if (selectedId == null || !companies.any((c) => c['id'] == selectedId)) {
        selectedId = companies.first['id'];
      }

      setState(() {
        _companies = companies;
        _selectedCompanyId = selectedId;
      });

      await _loadCompanySettings();
      await _loadFromCache();
      if (mounted) setState(() => _isLoading = false);
      _syncFromFirestoreInBackground();
    } catch (e) {
      safeDebugPrint('❌ Error loading companies: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadCompanySettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      supplierAccountId =
          prefs.getString('supplier_account_id_$_selectedCompanyId');
      safeDebugPrint('📦 Loaded supplierAccountId: $supplierAccountId');
    } catch (e) {
      safeDebugPrint('❌ Error loading settings: $e');
    }
  }

  Future<void> _loadFromCache() async {
    if (_selectedCompanyId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final suppliersJson = prefs.getString(_keySuppliersCache);
      if (suppliersJson != null) {
        final List<dynamic> decoded = json.decode(suppliersJson);
        List<Supplier> loadedSuppliers = [];
        for (var item in decoded) {
          try {
            final id = item['id']?.toString() ?? '';
            if (id.isEmpty) continue;
            item['createdAt'] = item['createdAt'] is DateTime
                ? Timestamp.fromDate(item['createdAt'] as DateTime)
                : item['createdAt'];
            item['nameAr'] = item['nameAr']?.toString() ?? '';
            item['nameEn'] = item['nameEn']?.toString() ?? '';
            item['userId'] = item['userId']?.toString() ?? '';
            // فلتر حسب الشركة
            if (item['companyId'] != _selectedCompanyId) continue;
            loadedSuppliers.add(Supplier.fromMap(item, id));
          } catch (e) {
            safeDebugPrint('⚠️ Error decoding supplier: $e');
          }
        }
        _suppliers = loadedSuppliers;
        safeDebugPrint('📦 Loaded ${_suppliers.length} suppliers from cache');
        if (_suppliers.isNotEmpty && _selectedSupplierId == null) {
          _selectedSupplierId = _suppliers.first.id;
        }
      }

      if (_selectedSupplierId != null) {
        final ledgerJson =
            prefs.getString('$_keyLedgerCachePrefix$_selectedSupplierId');
        if (ledgerJson != null) {
          final List<dynamic> decoded = json.decode(ledgerJson);
          List<JournalEntry> loadedEntries = [];
          for (var item in decoded) {
            try {
              final entry = _journalEntryFromJson(item);
              if (entry.companyId == _selectedCompanyId) {
                loadedEntries.add(entry);
              }
            } catch (e) {
              safeDebugPrint('⚠️ Error decoding entry: $e');
            }
          }
          _entries = loadedEntries;
          _calculateBalance();
          safeDebugPrint('📦 Loaded ${_entries.length} entries from cache');
        }
      }
    } catch (e) {
      safeDebugPrint('⚠️ Cache load error: $e');
    }
  }

  JournalEntry _journalEntryFromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic dateValue) {
      if (dateValue == null) return DateTime.now();
      if (dateValue is DateTime) return dateValue;
      if (dateValue is Timestamp) return dateValue.toDate();
      if (dateValue is String && dateValue.isNotEmpty) {
        try {
          return DateTime.parse(dateValue);
        } catch (_) {
          return DateTime.now();
        }
      }
      return DateTime.now();
    }

    final lines = (json['lines'] as List?)
            ?.map((line) => JournalEntryLine(
                  accountId: line['accountId']?.toString() ?? '',
                  debit: (line['debit'] as num?)?.toDouble() ?? 0.0,
                  credit: (line['credit'] as num?)?.toDouble() ?? 0.0,
                  description: line['description']?.toString() ?? '',
                ))
            .toList() ??
        [];

    return JournalEntry(
      id: json['id']?.toString() ?? '',
      companyId: json['companyId']?.toString() ?? '',
      entryDate: parseDate(json['entryDate']),
      description: json['description']?.toString() ?? '',
      referenceId: json['referenceId']?.toString() ?? '',
      referenceType: json['referenceType']?.toString() ?? '',
      lines: lines,
      createdAt: parseDate(json['createdAt']),
      createdBy: json['createdBy']?.toString() ?? '',
    );
  }

  Future<void> _syncFromFirestoreInBackground() async {
    if (_selectedCompanyId == null) return;
    if (mounted) setState(() => _isSyncing = true);
    await _fetchFromFirestore();
    if (mounted) setState(() => _isSyncing = false);
  }

  Future<void> _fetchFromFirestore() async {
    if (_selectedCompanyId == null) return;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // جلب الموردين حسب الشركة المختارة
      final snapshot = await FirebaseFirestore.instance
          .collection('vendors')
          .where('userId', isEqualTo: user.uid)
          .where('companyId', isEqualTo: _selectedCompanyId)
          .get();

      final List<Supplier> loadedSuppliers = snapshot.docs
          .map((doc) => Supplier.fromMap(doc.data(), doc.id))
          .toList();

      safeDebugPrint(
          '✅ Loaded ${loadedSuppliers.length} suppliers from Firestore');
      await _saveSuppliersToCache(loadedSuppliers);

      if (mounted) {
        setState(() {
          _suppliers = loadedSuppliers;
          if (_suppliers.isNotEmpty && _selectedSupplierId == null) {
            _selectedSupplierId = _suppliers.first.id;
          }
        });
      }

      if (_suppliers.isEmpty) {
        if (mounted) {
          setState(() {
            _entries = [];
            _totalBalance = 0.0;
          });
        }
        return;
      }

      if (_selectedSupplierId != null) {
        final ledgerSnapshot = await FirebaseFirestore.instance
            .collection('journal_entries')
            .where('supplierId', isEqualTo: _selectedSupplierId)
            .where('companyId', isEqualTo: _selectedCompanyId)
            .orderBy('entryDate', descending: false)
            .get();

        final List<JournalEntry> loadedEntries = [];
        for (var doc in ledgerSnapshot.docs) {
          final entry = JournalEntry.fromMap(doc.data(), doc.id);
          loadedEntries.add(entry);
        }

        await _saveLedgerToCache(_selectedSupplierId!, loadedEntries);

        if (mounted) {
          setState(() {
            _entries = loadedEntries;
            _calculateBalance();
          });
        }
        safeDebugPrint('✅ Synced ${_entries.length} entries from Firestore');
      }
    } catch (e) {
      safeDebugPrint('❌ Firestore sync error: $e');
    }
  }

  void _calculateBalance() {
    _totalBalance = 0.0;
    final purchaseTypes = [
      'purchase_order',
      'goods_received',
      'purchase',
      'stock_receipt'
    ];
    final paymentTypes = ['supplier_payment', 'payment'];

    for (var entry in _entries) {
      double change = 0.0;
      if (supplierAccountId != null && supplierAccountId!.isNotEmpty) {
        for (var line in entry.lines) {
          if (line.accountId == supplierAccountId) {
            if (line.credit > 0) {
              change = -line.credit;
            } else if (line.debit > 0) {
              change = line.debit;
            }
            break;
          }
        }
      }
      if (change == 0.0) {
        if (purchaseTypes.contains(entry.referenceType)) {
          for (var line in entry.lines) {
            if (line.credit > 0) {
              change = -line.credit;
              break;
            }
          }
        } else if (paymentTypes.contains(entry.referenceType)) {
          for (var line in entry.lines) {
            if (line.debit > 0) {
              change = line.debit;
              break;
            }
          }
        } else {
          for (var line in entry.lines) {
            if (line.credit > 0) {
              change = -line.credit;
              break;
            } else if (line.debit > 0) {
              change = line.debit;
              break;
            }
          }
        }
      }
      _totalBalance += change;
    }
    safeDebugPrint('💰 Total balance: $_totalBalance');
  }

  Future<void> _saveSuppliersToCache(List<Supplier> suppliers) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final suppliersJson = suppliers.map((supplier) {
        final map = supplier.toMap();
        if (map['createdAt'] is Timestamp) {
          map['createdAt'] =
              (map['createdAt'] as Timestamp).toDate().toIso8601String();
        }
        return map;
      }).toList();
      await prefs.setString(_keySuppliersCache, json.encode(suppliersJson));
    } catch (e) {
      safeDebugPrint('❌ Error caching suppliers: $e');
    }
  }

  Future<void> _saveLedgerToCache(
      String supplierId, List<JournalEntry> entries) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final entriesJson = entries.map((entry) {
        final map = entry.toMap();
        map['entryDate'] = entry.entryDate.toIso8601String();
        map['createdAt'] = entry.createdAt.toIso8601String();
        return map;
      }).toList();
      await prefs.setString(
          '$_keyLedgerCachePrefix$supplierId', json.encode(entriesJson));
    } catch (e) {
      safeDebugPrint('❌ Error caching ledger: $e');
    }
  }

  void _onSupplierChanged(String? supplierId) {
    if (supplierId == null || supplierId == _selectedSupplierId) return;
    setState(() {
      _selectedSupplierId = supplierId;
      _entries = [];
      _isSyncing = true;
    });
    _loadFromCache().then((_) {
      if (mounted) setState(() {});
    });
    _fetchFromFirestore().then((_) {
      if (mounted) setState(() => _isSyncing = false);
    });
  }

  Future<void> _onCompanyChanged(String? newCompanyId) async {
    if (newCompanyId == null || newCompanyId == _selectedCompanyId) return;
    await CompanyHelper.setSelectedCompanyId(newCompanyId);
    setState(() {
      _selectedCompanyId = newCompanyId;
      _selectedSupplierId = null;
      _suppliers.clear();
      _entries.clear();
      _totalBalance = 0.0;
      _isLoading = true;
    });
    await _loadCompanySettings();
    await _loadFromCache();
    await _syncFromFirestoreInBackground();
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = context.locale.languageCode == 'ar';
    final actions = <Widget>[];
    if (_companies.length > 1 && _selectedCompanyId != null) {
      actions.add(
        CompanyHelper.buildCompanyDropdown(
          companies: _companies,
          selectedCompanyId: _selectedCompanyId,
          onChanged: _onCompanyChanged,
          languageCode: context.locale.languageCode,
          dropdownColor: Colors.white,
          textColor: Colors.black,
          iconColor: Colors.black,
        ),
      );
    }

    return AppScaffold(
      title: 'supplier_ledger'.tr(),
      actions: actions,
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() => _isSyncing = true);
          await _fetchFromFirestore();
          if (mounted) setState(() => _isSyncing = false);
        },
        child: Column(
          children: [
            if (_suppliers.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(12),
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedSupplierId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'supplier'.tr(),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  items: _suppliers.map((supplier) {
                    return DropdownMenuItem<String>(
                      value: supplier.id,
                      child: Text(
                        isArabic
                            ? supplier.nameAr
                            : (supplier.nameEn.isNotEmpty
                                ? supplier.nameEn
                                : supplier.nameAr),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: _onSupplierChanged,
                ),
              )
            else if (!_isLoading)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Center(
                    child: Text('no_suppliers_found'.tr(),
                        style: const TextStyle(color: Colors.grey))),
              ),
            if (!_isLoading && _entries.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.teal.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('total_balance_due'.tr(),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    Row(
                      children: [
                        if (_isSyncing)
                          const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2)),
                        const SizedBox(width: 8),
                        Text(
                          '${_totalBalance.toStringAsFixed(2)} EGP',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color:
                                _totalBalance < 0 ? Colors.red : Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _entries.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.receipt_long,
                                  size: 64, color: Colors.grey),
                              const SizedBox(height: 12),
                              Text(
                                _suppliers.isEmpty
                                    ? 'no_suppliers_found'.tr()
                                    : 'no_transactions_found'.tr(),
                                style: const TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _entries.length,
                          itemBuilder: (context, index) {
                            final entry = _entries[index];
                            double change = 0.0;
                            final purchaseTypes = [
                              'purchase_order',
                              'goods_received',
                              'purchase',
                              'stock_receipt'
                            ];
                            final paymentTypes = [
                              'supplier_payment',
                              'payment'
                            ];

                            if (supplierAccountId != null &&
                                supplierAccountId!.isNotEmpty) {
                              for (var line in entry.lines) {
                                if (line.accountId == supplierAccountId) {
                                  if (line.credit > 0) {
                                    change = -line.credit;
                                  } else if (line.debit > 0) {
                                    change = line.debit;
                                  }
                                  break;
                                }
                              }
                            }
                            if (change == 0.0) {
                              if (purchaseTypes.contains(entry.referenceType)) {
                                for (var line in entry.lines) {
                                  if (line.credit > 0) {
                                    change = -line.credit;
                                    break;
                                  }
                                }
                              } else if (paymentTypes
                                  .contains(entry.referenceType)) {
                                for (var line in entry.lines) {
                                  if (line.debit > 0) {
                                    change = line.debit;
                                    break;
                                  }
                                }
                              } else {
                                for (var line in entry.lines) {
                                  if (line.credit > 0) {
                                    change = -line.credit;
                                    break;
                                  } else if (line.debit > 0) {
                                    change = line.debit;
                                    break;
                                  }
                                }
                              }
                            }

                            final isNegative = change < 0;
                            final color =
                                isNegative ? Colors.red : Colors.green;
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: color,
                                  child: Text(isNegative ? '-' : '+',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold)),
                                ),
                                title: Text(entry.description,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis),
                                subtitle: Text(
                                    '${DateFormat('dd/MM/yyyy').format(entry.entryDate)} | ${entry.referenceType}'),
                                trailing: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${isNegative ? '' : '+'}${change.toStringAsFixed(2)} EGP',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: color),
                                    ),
                                    if (entry.lines.isNotEmpty)
                                      Text(
                                        '(${entry.lines.length} ${entry.lines.length == 1 ? 'line'.tr() : 'lines'.tr()})',
                                        style: const TextStyle(
                                            fontSize: 10, color: Colors.grey),
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
      ),
    );
  }
}
