// pages/settings/settings_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:puresip_purchasing/pages/dashboard/dashboard_metrics.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:puresip_purchasing/providers/dashboard_settings_provider.dart';
import 'package:puresip_purchasing/debug_helper.dart';

enum DashboardView { short, long }

class SettingsPage extends StatefulWidget {
  final List<String> allCards;

  const SettingsPage({super.key, required this.allCards});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  DashboardView? _selectedView;
  Set<String> _selectedCards = {};
  String _selectedDisplayMode = 'cards';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final viewString = prefs.getString('dashboard_view');
      final selectedCardsString = prefs.getString('selected_cards');
      final displayMode = prefs.getString('display_mode') ?? 'cards';

      Set<String> cardsSet = {};
      if (selectedCardsString != null && selectedCardsString.isNotEmpty) {
        try {
          final List<dynamic> decoded = json.decode(selectedCardsString);
          cardsSet = decoded.map((e) => e.toString()).toSet();
        } catch (_) {
          cardsSet = _getDefaultCardsForView(DashboardView.short);
        }
      } else {
        cardsSet = _getDefaultCardsForView(DashboardView.short);
      }

      setState(() {
        _selectedView =
            viewString == 'long' ? DashboardView.long : DashboardView.short;
        _selectedCards = cardsSet;
        _selectedDisplayMode = displayMode;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _selectedView = DashboardView.short;
        _selectedCards = _getDefaultCardsForView(DashboardView.short);
        _selectedDisplayMode = 'cards';
        _isLoading = false;
      });
    }
  }

  Set<String> _getDefaultCardsForView(DashboardView view) {
    if (view == DashboardView.long) {
      return dashboardMetrics
          .where((m) => m.defaultMenuType == 'long' || m.defaultMenuType == 'short')
          .map((m) => m.titleKey)
          .toSet();
    } else {
      return dashboardMetrics
          .where((m) => m.defaultMenuType == 'short')
          .map((m) => m.titleKey)
          .toSet();
    }
  }

  void _onCardToggle(String cardKey, bool selected) {
    setState(() {
      if (selected) {
        _selectedCards.add(cardKey);
      } else {
        _selectedCards.remove(cardKey);
      }
      _selectedView = null;
    });
    _saveSettings(shouldPop: false);
  }

  void _resetToDefaults() {
    setState(() {
      _selectedView = DashboardView.short;
      _selectedCards = _getDefaultCardsForView(DashboardView.short);
      _selectedDisplayMode = 'cards';
    });
    _saveSettings(shouldPop: false);
  }

  Future<void> _saveSettings({bool shouldPop = false}) async {
    try {
      final viewString = _selectedView == DashboardView.long ? 'long' : 'short';

      // تحديث Provider
      final settingsProvider =
          Provider.of<DashboardSettingsProvider>(context, listen: false);
      settingsProvider.updateView(viewString);
      settingsProvider.updateCards(_selectedCards);
      settingsProvider.updateDisplayMode(_selectedDisplayMode);

      safeDebugPrint('✅ Settings saved - View: $viewString, Cards: ${_selectedCards.length}, Mode: $_selectedDisplayMode');

      if (shouldPop && mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      safeDebugPrint('Save error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('settings.title')),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () => _saveSettings(shouldPop: true),
            tooltip: tr('save_and_close'),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ─── 1. بطاقة المستندات ──────────────────────────────
                _buildDocumentsCard(),
                const SizedBox(height: 16),

                // ─── 2. بطاقة اختيار العرض ────────────────────────────
                _buildViewCard(),
                const SizedBox(height: 16),

                // ─── 3. بطاقة اختيار الكروت ───────────────────────────
                _buildCardsCard(),
                const SizedBox(height: 16),

                // ─── 4. بطاقة وضع الشاشة (جديد) ──────────────────────
                _buildDisplayModeCard(),
              ],
            ),
          ),
          // ─── أزرار الإجراءات ──────────────────────────────────────
          _buildActionButtons(),
        ],
      ),
    );
  }

  // ─── مكونات البطاقات ──────────────────────────────────────────────

  Widget _buildDocumentsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          ListTile(
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.blue.withAlpha(26),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.description, color: Colors.blue),
            ),
            title: Text(tr('manage_conditions_documents'),
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(tr('manage_conditions_documents_desc')),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            onTap: () => context.push('/additional-items'),
          ),
          const Divider(height: 0, indent: 20, endIndent: 20),
          ListTile(
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.green.withAlpha(26),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.payment, color: Colors.green),
            ),
            title: Text(tr('manage_payment_delivery_terms'),
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(tr('manage_payment_delivery_terms_desc')),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            onTap: () => context.push('/user-terms'),
          ),
        ],
      ),
    );
  }

  Widget _buildViewCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.purple.withAlpha(26),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.view_quilt, color: Colors.purple),
                ),
                const SizedBox(width: 16),
                Text(tr('settings.choose_view'),
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 16),
            SegmentedButton<DashboardView>(
              segments: const [
                ButtonSegment(
                  value: DashboardView.short,
                  label: Text('Short'),
                  icon: Icon(Icons.view_compact),
                ),
                ButtonSegment(
                  value: DashboardView.long,
                  label: Text('Long'),
                  icon: Icon(Icons.view_agenda),
                ),
              ],
              selected: {_selectedView ?? DashboardView.short},
              onSelectionChanged: (Set<DashboardView> newSelection) {
                if (newSelection.isNotEmpty) {
                  final newView = newSelection.first;
                  setState(() {
                    _selectedView = newView;
                    _selectedCards = _getDefaultCardsForView(newView);
                  });
                  _saveSettings(shouldPop: false);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.teal.withAlpha(26),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.dashboard, color: Colors.teal),
                ),
                const SizedBox(width: 16),
                Text(tr('settings.choose_cards'),
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 400,
              child: ListView.builder(
                itemCount: widget.allCards.length,
                itemBuilder: (context, index) {
                  final cardKey = widget.allCards[index];
                  final isSelected = _selectedCards.contains(cardKey);
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    elevation: 0,
                    color: isSelected ? Colors.teal.withAlpha(13) : null,
                    child: CheckboxListTile(
                      title: Text(
                        cardKey.tr(),
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                      value: isSelected,
                      onChanged: (val) => _onCardToggle(cardKey, val ?? false),
                      activeColor: Colors.teal,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      secondary: Icon(
                        _getIconForCard(cardKey),
                        color: isSelected ? Colors.teal : Colors.grey.shade400,
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

  // ✅ بطاقة وضع الشاشة (جديدة)
  Widget _buildDisplayModeCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.indigo.withAlpha(26),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.dashboard_customize, color: Colors.indigo),
                ),
                const SizedBox(width: 16),
                Text(tr('display_mode'),
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'cards',
                  label: Text('Show Cards'),
                  icon: Icon(Icons.dashboard),
                ),
                ButtonSegment(
                  value: 'logo',
                  label: Text('Show Logo'),
                  icon: Icon(Icons.image),
                ),
              ],
              selected: {_selectedDisplayMode},
              onSelectionChanged: (Set<String> newSelection) {
                if (newSelection.isNotEmpty) {
                  final newMode = newSelection.first;
                  setState(() {
                    _selectedDisplayMode = newMode;
                  });
                  _saveSettings(shouldPop: false);
                }
              },
            ),
            const SizedBox(height: 8),
            Text(
              _selectedDisplayMode == 'cards'
                  ? tr('display_mode_cards_desc')
                  : tr('display_mode_logo_desc'),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: Colors.grey.shade300, width: 1)),
      ),
      child: Row(
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
              icon: const Icon(Icons.check),
              label: Text(tr('save_and_close')),
              onPressed: () => _saveSettings(shouldPop: true),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconForCard(String cardKey) {
    switch (cardKey) {
      case 'totalCompanies':       return Icons.business;
      case 'totalSuppliers':       return Icons.local_shipping;
      case 'totalOrders':          return Icons.shopping_cart;
      case 'totalFinishedProducts':return Icons.check_circle_outline;
      case 'totalAmount':          return Icons.attach_money;
      case 'totalItems':           return Icons.inventory_2;
      case 'totalStockMovements':  return Icons.move_to_inbox;
      case 'inventory_query':      return Icons.search;
      case 'totalManufacturingOrders': return Icons.precision_manufacturing;
      case 'totalFactories':       return Icons.factory;
      case 'reports':              return Icons.query_stats;
      default:                     return Icons.dashboard;
    }
  }
}