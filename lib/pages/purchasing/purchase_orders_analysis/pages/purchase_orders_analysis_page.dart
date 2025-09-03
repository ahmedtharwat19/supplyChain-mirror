import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:puresip_purchasing/utils/user_local_storage.dart';
import 'package:puresip_purchasing/widgets/app_scaffold.dart';

class PurchaseOrdersAnalysisPage extends StatefulWidget {
  const PurchaseOrdersAnalysisPage({super.key});

  @override
  State<PurchaseOrdersAnalysisPage> createState() =>
      _PurchaseOrdersAnalysisPageState();
}

class _PurchaseOrdersAnalysisPageState extends State<PurchaseOrdersAnalysisPage> {
  String selectedPeriod = 'monthly';
  String selectedCompany = 'all';
  String? userId;
  bool get _isArabic => context.locale.languageCode == 'ar';
  List<Map<String, String>> userCompanies = [];
  final NumberFormat _currencyFormat = NumberFormat.currency(symbol: '');

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    try {
      final uid = await UserLocalStorage.getUserId();
      if (uid == null) return;

      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      
      if (!userDoc.exists) {
        debugPrint('User document does not exist');
        return;
      }

      final companyIds = List<String>.from(userDoc.data()?['companyIds'] ?? []);
      debugPrint('User companies: $companyIds');

      List<Map<String, String>> companies = [];

      if (companyIds.isNotEmpty) {
        final snapshot = await FirebaseFirestore.instance
            .collection('companies')
            .where(FieldPath.documentId, whereIn: companyIds)
            .get();

        companies = snapshot.docs.map((doc) {
          final data = doc.data();
          final name = _isArabic ? (data['nameAr'] ?? '') : (data['nameEn'] ?? '');
          return {
            'id': doc.id,
            'name': name.toString(),
          };
        }).toList();
      }

      setState(() {
        userId = uid;
        userCompanies = companies;
        selectedCompany = 'all';
      });
    } catch (e) {
      debugPrint('Error loading user info: $e');
    }
  }

  Future<Map<String, String>> _getSupplierNames(Set<String> supplierIds) async {
    if (supplierIds.isEmpty) return {};

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('vendors')
          .where(FieldPath.documentId, whereIn: supplierIds.toList())
          .get();

      final Map<String, String> supplierNames = {};
      for (var doc in snapshot.docs) {
        supplierNames[doc.id] = _isArabic ? doc['nameAr'] : doc['nameEn'];
      }

      return supplierNames;
    } catch (e) {
      debugPrint('Error loading supplier names: $e');
      return {};
    }
  }

  Stream<QuerySnapshot> _getOrdersStream() {
    if (userId == null) {
      return const Stream.empty();
    }

    final now = DateTime.now();
    DateTime startDate;

    switch (selectedPeriod) {
      case 'daily':
        startDate = DateTime(now.year, now.month, now.day);
        break;
      case 'weekly':
        startDate = now.subtract(Duration(days: now.weekday - 1));
        break;
      case 'quarterly':
        final currentQuarter = ((now.month - 1) ~/ 3) + 1;
        final quarterStartMonth = (currentQuarter - 1) * 3 + 1;
        startDate = DateTime(now.year, quarterStartMonth, 1);
        break;
      case 'yearly':
        startDate = DateTime(now.year, 1, 1);
        break;
      default: // monthly
        startDate = DateTime(now.year, now.month, 1);
    }

    Query query = FirebaseFirestore.instance
        .collection('purchase_orders')
        .where('userId', isEqualTo: userId)
        .where('orderDate', isGreaterThanOrEqualTo: startDate);

    if (selectedCompany != 'all') {
      query = query.where('companyId', isEqualTo: selectedCompany);
    }

    return query.snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'purchase_orders_analysis'.tr(),
      body: userId == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Filter Cards
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'filters'.tr(),
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'period'.tr(),
                                      style: Theme.of(context).textTheme.bodySmall,
                                    ),
                                    DropdownButton<String>(
                                      value: selectedPeriod,
                                      isExpanded: true,
                                      items: [
                                        'daily',
                                        'weekly',
                                        'monthly',
                                        'quarterly',
                                        'yearly'
                                      ]
                                          .map((e) => DropdownMenuItem(
                                                value: e,
                                                child: Text(e.tr()),
                                              ))
                                          .toList(),
                                      onChanged: (value) {
                                        if (value != null) {
                                          setState(() {
                                            selectedPeriod = value;
                                          });
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'company'.tr(),
                                      style: Theme.of(context).textTheme.bodySmall,
                                    ),
                                    DropdownButton<String>(
                                      value: selectedCompany,
                                      isExpanded: true,
                                      items: [
                                        DropdownMenuItem(
                                          value: 'all',
                                          child: Text('all_companies'.tr()),
                                        ),
                                        ...userCompanies.map((c) => DropdownMenuItem(
                                              value: c['id'],
                                              child: Text(
                                                c['name']!,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            )),
                                      ],
                                      onChanged: (value) {
                                        if (value != null) {
                                          setState(() {
                                            selectedCompany = value;
                                          });
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _getOrdersStream(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      
                      if (snapshot.hasError) {
                        debugPrint('Stream error: ${snapshot.error}');
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 48,
                                color: Theme.of(context).colorScheme.error,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'error_loading_data'.tr(),
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                            ],
                          ),
                        );
                      }

                      final docs = snapshot.data!.docs;
                      final totalOrders = docs.length;

                      if (totalOrders == 0) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.shopping_cart_outlined,
                                size: 64,
                                color: Theme.of(context).colorScheme.secondary,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'no_orders_found'.tr(),
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                            ],
                          ),
                        );
                      }

                      final completedOrders =
                          docs.where((d) => d['status'] == 'completed').length;
                      final openOrders =
                          docs.where((d) => d['status'] == 'pending').length;
                      final cancelledOrders =
                          docs.where((d) => d['status'] == 'cancelled').length;

                      final totalValue = docs.fold<double>(0, (sTotal, d) {
                        final amount = d['totalAmount'];
                        if (amount is int) {
                          return sTotal + amount.toDouble();
                        } else if (amount is double) {
                          return sTotal + amount;
                        } else if (amount is String) {
                          return sTotal + (double.tryParse(amount) ?? 0);
                        }
                        return sTotal;
                      });

                      final avgOrderValue =
                          totalOrders > 0 ? totalValue / totalOrders : 0;

                      final suppliers = <String>{};
                      final supplierTotals = <String, double>{};

                      for (var doc in docs) {
                        final supplierId = doc['supplierId'].toString();
                        suppliers.add(supplierId);

                        final amount = doc['totalAmount'];
                        double amountValue = 0;
                        
                        if (amount is int) {
                          amountValue = amount.toDouble();
                        } else if (amount is double) {
                          amountValue = amount;
                        } else if (amount is String) {
                          amountValue = double.tryParse(amount) ?? 0;
                        }
                        
                        supplierTotals[supplierId] =
                            (supplierTotals[supplierId] ?? 0) + amountValue;
                      }

                      return FutureBuilder<Map<String, String>>(
                        future: _getSupplierNames(suppliers),
                        builder: (context, supplierSnapshot) {
                          if (supplierSnapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          
                          if (supplierSnapshot.hasError) {
                            debugPrint('Supplier error: ${supplierSnapshot.error}');
                            return Center(
                              child: Text('error_loading_suppliers'.tr()),
                            );
                          }

                          final supplierNames = supplierSnapshot.data ?? {};
                          final totalSuppliers = suppliers.length;

                          return ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              // Summary Cards
                              GridView(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  childAspectRatio: 1.4,
                                ),
                                children: [
                                  _buildSummaryCard(
                                    context,
                                    'total_orders'.tr(),
                                    totalOrders.toString(),
                                    Icons.shopping_cart,
                                    Colors.blue,
                                  ),
                                  _buildSummaryCard(
                                    context,
                                    'total_value'.tr(),
                                    _currencyFormat.format(totalValue),
                                    Icons.attach_money,
                                    Colors.green,
                                  ),
                                  _buildSummaryCard(
                                    context,
                                    'avg_order_value'.tr(),
                                    _currencyFormat.format(avgOrderValue),
                                    Icons.analytics,
                                    Colors.orange,
                                  ),
                                  _buildSummaryCard(
                                    context,
                                    'suppliers'.tr(),
                                    totalSuppliers.toString(),
                                    Icons.business,
                                    Colors.purple,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              
                              // Status Distribution
                              Card(
                                elevation: 4,
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'order_status_distribution'.tr(),
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                      const SizedBox(height: 16),
                                      Container(
                                        height: 200,
                                        padding: const EdgeInsets.all(8),
                                        child: PieChart(
                                          PieChartData(
                                            sectionsSpace: 2,
                                            centerSpaceRadius: 40,
                                            sections: [
                                              PieChartSectionData(
                                                value: completedOrders.toDouble(),
                                                title: '${((completedOrders / totalOrders) * 100).toStringAsFixed(1)}%',
                                                color: Colors.green,
                                                radius: 60,
                                                titleStyle: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                              ),
                                              PieChartSectionData(
                                                value: openOrders.toDouble(),
                                                title: '${((openOrders / totalOrders) * 100).toStringAsFixed(1)}%',
                                                color: Colors.blue,
                                                radius: 60,
                                                titleStyle: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                              ),
                                              PieChartSectionData(
                                                value: cancelledOrders.toDouble(),
                                                title: '${((cancelledOrders / totalOrders) * 100).toStringAsFixed(1)}%',
                                                color: Colors.red,
                                                radius: 60,
                                                titleStyle: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                                        children: [
                                          _buildLegendItem(Colors.green, 'completed'.tr()),
                                          _buildLegendItem(Colors.blue, 'open'.tr()),
                                          _buildLegendItem(Colors.red, 'cancelled'.tr()),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              
                              // Supplier Breakdown
                              Card(
                                elevation: 4,
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'supplier_breakdown'.tr(),
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                      const SizedBox(height: 16),
                                      ...supplierTotals.entries.map((entry) {
                                        final name = supplierNames[entry.key] ?? entry.key;
                                        final percentage = (entry.value / totalValue * 100).toStringAsFixed(1);
                                        return _buildSupplierCard(
                                          context,
                                          name,
                                          entry.value,
                                          totalValue,
                                          percentage,
                                        );
                                      }),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      child: Container(
        constraints: const BoxConstraints(
          minHeight: 100,
          maxHeight: 120,
        ),
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 28, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildSupplierCard(BuildContext context, String name, double value, double totalValue, String percentage) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    name,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _currencyFormat.format(value),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.end,
                      ),
                      Text(
                        '$percentage%',
                        style: const TextStyle(fontSize: 11),
                        textAlign: TextAlign.end,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: value / totalValue,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}