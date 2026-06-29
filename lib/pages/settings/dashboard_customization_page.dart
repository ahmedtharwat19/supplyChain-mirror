/* import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:puresip_purchasing/services/hive_service.dart';
import 'package:puresip_purchasing/debug_helper.dart';

enum DashboardView { short, long }

class DashboardCustomizationPage extends StatefulWidget {
  const DashboardCustomizationPage({super.key});

  @override
  State<DashboardCustomizationPage> createState() => _DashboardCustomizationPageState();
}

class _DashboardCustomizationPageState extends State<DashboardCustomizationPage> {
  DashboardView _selectedView = DashboardView.short;
  Set<String> _selectedCards = {};

  // قائمة البطاقات المتاحة (كما طلبت)
  final List<Map<String, String>> _availableCards = [
    {'key': 'totalCompanies', 'title': 'Companies'},
    {'key': 'totalSuppliers', 'title': 'Suppliers'},
    {'key': 'totalOrders', 'title': 'Orders'},
    {'key': 'totalFinishedProducts', 'title': 'Finished'},
    {'key': 'totalAmount', 'title': 'Amounts'},
    {'key': 'totalItems', 'title': 'Items'},
    {'key': 'totalMovements', 'title': 'Stocks'},
    {'key': 'inventory_query', 'title': 'Inventory Query'},
    {'key': 'totalManufacturingOrders', 'title': 'Manufacturing'},
    {'key': 'totalFactories', 'title': 'Factories'},
    {'key': 'totalReports', 'title': 'Reports'},
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final viewString = await HiveService.getSetting<String>('dashboard_view');
      final savedCards = await HiveService.getSetting<List<dynamic>>('selected_cards');

      setState(() {
        _selectedView = (viewString == 'long') ? DashboardView.long : DashboardView.short;
        if (savedCards != null && savedCards.isNotEmpty) {
          _selectedCards = savedCards.map((e) => e.toString()).toSet();
        } else {
          _selectedCards = _getDefaultCardsForView(_selectedView);
        }
      });
    } catch (e) {
      debugPrint('Error loading dashboard settings: $e');
      _selectedCards = _getDefaultCardsForView(DashboardView.short);
    }
  }

  Set<String> _getDefaultCardsForView(DashboardView view) {
    if (view == DashboardView.long) {
      return _availableCards.map((c) => c['key']!).toSet();
    } else {
      return {'totalCompanies', 'totalSuppliers', 'totalOrders', 'totalAmount'};
    }
  }

  void _onViewChanged(DashboardView? value) {
    if (value == null) return;
    setState(() {
      _selectedView = value;
      _selectedCards = _getDefaultCardsForView(value);
    });
  }

  void _onCardToggled(String cardKey, bool selected) {
    setState(() {
      if (selected) {
        _selectedCards.add(cardKey);
      } else {
        _selectedCards.remove(cardKey);
      }
    });
  }

  void _resetToDefaults() {
    setState(() {
      _selectedView = DashboardView.short;
      _selectedCards = _getDefaultCardsForView(DashboardView.short);
    });
  }

  Future<void> _saveAndClose() async {
    try {
      await HiveService.saveSetting('dashboard_view', _selectedView == DashboardView.long ? 'long' : 'short');
      await HiveService.saveSetting('selected_cards', _selectedCards.toList());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('settings.saved_successfully')),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
        Navigator.pop(context, true); // إرجاع true لتحديث Dashboard
      }
    } catch (e) {
      safeDebugPrint('Save error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${tr('settings.save_error')}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('customize_dashboard')),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // اختيار العرض
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.view_quilt, color: Colors.purple),
                        const SizedBox(width: 12),
                        Text(tr('settings.choose_view'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SegmentedButton<DashboardView>(
                      segments: const [
                        ButtonSegment(value: DashboardView.short, label: Text('Short'), icon: Icon(Icons.view_compact)),
                        ButtonSegment(value: DashboardView.long, label: Text('Long'), icon: Icon(Icons.view_agenda)),
                      ],
                      selected: {_selectedView},
                      onSelectionChanged: (Set<DashboardView> set) {
                        if (set.isNotEmpty) _onViewChanged(set.first);
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // قائمة البطاقات
            Expanded(
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.dashboard, color: Colors.teal),
                          const SizedBox(width: 12),
                          Text(tr('settings.choose_cards'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: ListView.builder(
                          itemCount: _availableCards.length,
                          itemBuilder: (context, index) {
                            final card = _availableCards[index];
                            return CheckboxListTile(
                              title: Text(card['title']!.tr()),
                              value: _selectedCards.contains(card['key']),
                              onChanged: (val) => _onCardToggled(card['key']!, val ?? false),
                              activeColor: Colors.teal,
                              contentPadding: EdgeInsets.zero,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // أزرار Reset و Save & Close
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.restore),
                    label: Text(tr('settings.reset')),
                    onPressed: _resetToDefaults,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.save),
                    label: Text(tr('save_and_close')),
                    onPressed: _saveAndClose,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      backgroundColor: Colors.teal,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
} */

// dashboard_customization_page.dart - بدون Hive
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:puresip_purchasing/debug_helper.dart';

enum DashboardView { short, long }

class DashboardCustomizationPage extends StatefulWidget {
  const DashboardCustomizationPage({super.key});

  @override
  State<DashboardCustomizationPage> createState() => _DashboardCustomizationPageState();
}

class _DashboardCustomizationPageState extends State<DashboardCustomizationPage> {
  DashboardView _selectedView = DashboardView.short;
  Set<String> _selectedCards = {};

  // ✅ مفاتيح التخزين
  static const String _keyDashboardView = 'dashboard_view';
  static const String _keySelectedCards = 'selected_cards';

  // قائمة البطاقات المتاحة
  final List<Map<String, String>> _availableCards = [
    {'key': 'totalCompanies', 'title': 'Companies'},
    {'key': 'totalSuppliers', 'title': 'Suppliers'},
    {'key': 'totalOrders', 'title': 'Orders'},
    {'key': 'totalFinishedProducts', 'title': 'Finished'},
    {'key': 'totalAmount', 'title': 'Amounts'},
    {'key': 'totalItems', 'title': 'Items'},
    {'key': 'totalMovements', 'title': 'Stocks'},
    {'key': 'inventory_query', 'title': 'Inventory Query'},
    {'key': 'totalManufacturingOrders', 'title': 'Manufacturing'},
    {'key': 'totalFactories', 'title': 'Factories'},
    {'key': 'totalReports', 'title': 'Reports'},
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final viewString = prefs.getString(_keyDashboardView);
      final selectedCardsString = prefs.getString(_keySelectedCards);

      setState(() {
        _selectedView = (viewString == 'long') ? DashboardView.long : DashboardView.short;
        
        if (selectedCardsString != null && selectedCardsString.isNotEmpty) {
          final List<dynamic> decoded = json.decode(selectedCardsString);
          _selectedCards = decoded.map((e) => e.toString()).toSet();
        } else {
          _selectedCards = _getDefaultCardsForView(_selectedView);
        }
      });
    } catch (e) {
      debugPrint('Error loading dashboard settings: $e');
      setState(() {
        _selectedCards = _getDefaultCardsForView(DashboardView.short);
      });
    }
  }

  Set<String> _getDefaultCardsForView(DashboardView view) {
    if (view == DashboardView.long) {
      return _availableCards.map((c) => c['key']!).toSet();
    } else {
      return {'totalCompanies', 'totalSuppliers', 'totalOrders', 'totalAmount'};
    }
  }

  void _onViewChanged(DashboardView? value) {
    if (value == null) return;
    setState(() {
      _selectedView = value;
      _selectedCards = _getDefaultCardsForView(value);
    });
  }

  void _onCardToggled(String cardKey, bool selected) {
    setState(() {
      if (selected) {
        _selectedCards.add(cardKey);
      } else {
        _selectedCards.remove(cardKey);
      }
    });
  }

  void _resetToDefaults() {
    setState(() {
      _selectedView = DashboardView.short;
      _selectedCards = _getDefaultCardsForView(DashboardView.short);
    });
  }

  Future<void> _saveAndClose() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      await prefs.setString(_keyDashboardView, _selectedView == DashboardView.long ? 'long' : 'short');
      await prefs.setString(_keySelectedCards, json.encode(_selectedCards.toList()));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('settings.saved_successfully')),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
        Navigator.pop(context, true); // إرجاع true لتحديث Dashboard
      }
    } catch (e) {
      safeDebugPrint('Save error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${tr('settings.save_error')}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('customize_dashboard')),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // اختيار العرض
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.view_quilt, color: Colors.purple),
                        const SizedBox(width: 12),
                        Text(tr('settings.choose_view'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SegmentedButton<DashboardView>(
                      segments: const [
                        ButtonSegment(value: DashboardView.short, label: Text('Short'), icon: Icon(Icons.view_compact)),
                        ButtonSegment(value: DashboardView.long, label: Text('Long'), icon: Icon(Icons.view_agenda)),
                      ],
                      selected: {_selectedView},
                      onSelectionChanged: (Set<DashboardView> set) {
                        if (set.isNotEmpty) _onViewChanged(set.first);
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // قائمة البطاقات
            Expanded(
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.dashboard, color: Colors.teal),
                          const SizedBox(width: 12),
                          Text(tr('settings.choose_cards'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: ListView.builder(
                          itemCount: _availableCards.length,
                          itemBuilder: (context, index) {
                            final card = _availableCards[index];
                            return CheckboxListTile(
                              title: Text(card['title']!.tr()),
                              value: _selectedCards.contains(card['key']),
                              onChanged: (val) => _onCardToggled(card['key']!, val ?? false),
                              activeColor: Colors.teal,
                              contentPadding: EdgeInsets.zero,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // أزرار Reset و Save & Close
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.restore),
                    label: Text(tr('settings.reset')),
                    onPressed: _resetToDefaults,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.save),
                    label: Text(tr('save_and_close')),
                    onPressed: _saveAndClose,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      backgroundColor: Colors.teal,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}