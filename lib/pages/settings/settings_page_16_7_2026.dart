/* /* /* /* import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:puresip_purchasing/pages/dashboard/dashboard_metrics.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:puresip_purchasing/debug_helper.dart';
import 'package:puresip_purchasing/services/hive_service.dart';

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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final viewString = await HiveService.getSetting<String>('dashboard_view');
      final selectedCards = await HiveService.getSetting<List<dynamic>>('selected_cards');

      Set<String> cardsSet = {};
      if (selectedCards != null && selectedCards.isNotEmpty) {
        cardsSet = selectedCards.map((e) => e.toString()).toSet();
      } else {
        cardsSet = _getDefaultCardsForView(DashboardView.short);
      }

      DashboardView loadedView;
      if (viewString == 'long') {
        loadedView = DashboardView.long;
      } else if (viewString == 'short') {
        loadedView = DashboardView.short;
      } else {
        loadedView = _detectViewFromCards(cardsSet);
      }

      setState(() {
        _selectedView = loadedView;
        _selectedCards = cardsSet;
        _isLoading = false;
      });
    } catch (e) {
      _setDefaultSettings();
    }
  }

  DashboardView _detectViewFromCards(Set<String> cards) {
    final shortSet = _getDefaultCardsForView(DashboardView.short);
    final longSet = _getDefaultCardsForView(DashboardView.long);
    if (cards.length == longSet.length && cards.containsAll(longSet)) {
      return DashboardView.long;
    }
    if (cards.length == shortSet.length && cards.containsAll(shortSet)) {
      return DashboardView.short;
    }
    return DashboardView.short;
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

  void _setDefaultSettings() {
    setState(() {
      _selectedView = DashboardView.short;
      _selectedCards = _getDefaultCardsForView(DashboardView.short);
      _isLoading = false;
    });
  }

  Future<void> _saveSettings({bool shouldPop = false}) async {
    try {
      if (_selectedView != null) {
        await HiveService.saveSetting('dashboard_view', _selectedView == DashboardView.long ? 'long' : 'short');
      } else {
        await HiveService.saveSetting('dashboard_view', null);
      }
      await HiveService.saveSetting('selected_cards', _selectedCards.toList());

/*       if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('settings.saved_successfully')),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      } */
      if (shouldPop && mounted) {
        Navigator.pop(context, true);
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

/*   void _showViewSelectionDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr('settings.choose_view')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SegmentedButton<DashboardView>(
              segments: const [
                ButtonSegment(value: DashboardView.short, label: Text('short'), icon: Icon(Icons.view_compact)),
                ButtonSegment(value: DashboardView.long, label: Text('long'), icon: Icon(Icons.view_agenda)),
              ],
              selected: {_selectedView ?? DashboardView.short},
              onSelectionChanged: (Set<DashboardView> newSelection) {
                if (newSelection.isNotEmpty) {
                  final newView = newSelection.first;
                  setState(() {
                    _selectedView = newView;
                    _selectedCards = _getDefaultCardsForView(newView);
                  });
                  Navigator.pop(dialogContext);
                  _saveSettings(shouldPop: false);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(tr('cancel')),
          ),
        ],
      ),
    );
  }
 */
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
    });
    _saveSettings(shouldPop: false);
/*     if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('settings.restored_defaults')),
          duration: const Duration(seconds: 2),
        ),
      );
    } */
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
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () => _saveSettings(shouldPop: true),
            tooltip: tr('save_and_close'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Column(
                children: [
                  _buildListTile(
                    icon: Icons.description,
                    iconColor: Colors.blue,
                    title: tr('manage_conditions_documents'),
                    subtitle: tr('manage_conditions_documents_desc'),
                    onTap: () => context.push('/additional-items'),
                  ),
                  const Divider(height: 0, indent: 20, endIndent: 20),
                  _buildListTile(
                    icon: Icons.payment,
                    iconColor: Colors.green,
                    title: tr('manage_payment_delivery_terms'),
                    subtitle: tr('manage_payment_delivery_terms_desc'),
                    onTap: () => context.push('/user-terms'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Column(
                children: [
/*                   _buildListTile(
                    icon: Icons.view_quilt,
                    iconColor: Colors.purple,
                    title: tr('settings.choose_view'),
                    subtitle: _selectedView == DashboardView.short
                        ? tr('settings.short_view')
                        : (_selectedView == DashboardView.long ? tr('settings.long_view') : tr('settings.custom_selection_note')),
                    onTap: _showViewSelectionDialog,
                    trailing: const Icon(Icons.arrow_drop_down, color: Colors.grey),
                  ), */
                  Padding(
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
            child: const Icon(Icons.view_quilt, color: Colors.purple, size: 26),
          ),
          const SizedBox(width: 16),
          Text(tr('settings.choose_view'), style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
      const SizedBox(height: 12),
      SegmentedButton<DashboardView>(
        segments: const [
          ButtonSegment(value: DashboardView.short, label: Text('Short'), icon: Icon(Icons.view_compact)),
          ButtonSegment(value: DashboardView.long, label: Text('Long'), icon: Icon(Icons.view_agenda)),
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
                  const Divider(height: 0, indent: 20, endIndent: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.dashboard, color: Colors.teal),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(tr('settings.choose_cards'), style: const TextStyle(fontWeight: FontWeight.w600)),
                              const SizedBox(height: 8),
                              ...widget.allCards.map((cardKey) {
                                return SwitchListTile(
                                  title: Text(cardKey.tr()),
                                  value: _selectedCards.contains(cardKey),
                                  onChanged: (val) => _onCardToggle(cardKey, val),
                                  activeThumbColor: Colors.teal,
                                  contentPadding: EdgeInsets.zero,
                                  dense: true,
                                );
                              }),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
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
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return ListTile(
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: iconColor.withAlpha(26),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(icon, color: iconColor, size: 26),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: trailing ?? const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
  }
} */

// settings_page.dart - بدون Hive
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:puresip_purchasing/pages/dashboard/dashboard_metrics.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  bool _isLoading = true;

  // ✅ مفاتيح التخزين
  static const String _keyDashboardView = 'dashboard_view';
  static const String _keySelectedCards = 'selected_cards';

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

      Set<String> cardsSet = {};
      if (selectedCardsString != null && selectedCardsString.isNotEmpty) {
        final List<dynamic> decoded = json.decode(selectedCardsString);
        cardsSet = decoded.map((e) => e.toString()).toSet();
      } else {
        cardsSet = _getDefaultCardsForView(DashboardView.short);
      }

      DashboardView loadedView;
      if (viewString == 'long') {
        loadedView = DashboardView.long;
      } else if (viewString == 'short') {
        loadedView = DashboardView.short;
      } else {
        loadedView = _detectViewFromCards(cardsSet);
      }

      setState(() {
        _selectedView = loadedView;
        _selectedCards = cardsSet;
        _isLoading = false;
      });
    } catch (e) {
      safeDebugPrint('Error loading settings: $e');
      _setDefaultSettings();
    }
  }

  DashboardView _detectViewFromCards(Set<String> cards) {
    final shortSet = _getDefaultCardsForView(DashboardView.short);
    final longSet = _getDefaultCardsForView(DashboardView.long);
    if (cards.length == longSet.length && cards.containsAll(longSet)) {
      return DashboardView.long;
    }
    if (cards.length == shortSet.length && cards.containsAll(shortSet)) {
      return DashboardView.short;
    }
    return DashboardView.short;
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

  void _setDefaultSettings() {
    setState(() {
      _selectedView = DashboardView.short;
      _selectedCards = _getDefaultCardsForView(DashboardView.short);
      _isLoading = false;
    });
  }

  Future<void> _saveSettings({bool shouldPop = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      if (_selectedView != null) {
        await prefs.setString(_keyDashboardView, _selectedView == DashboardView.long ? 'long' : 'short');
      }
      
      await prefs.setString(_keySelectedCards, json.encode(_selectedCards.toList()));

      if (shouldPop && mounted) {
        Navigator.pop(context, true);
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
    });
    _saveSettings(shouldPop: false);
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
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () => _saveSettings(shouldPop: true),
            tooltip: tr('save_and_close'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Column(
                children: [
                  _buildListTile(
                    icon: Icons.description,
                    iconColor: Colors.blue,
                    title: tr('manage_conditions_documents'),
                    subtitle: tr('manage_conditions_documents_desc'),
                    onTap: () => context.push('/additional-items'),
                  ),
                  const Divider(height: 0, indent: 20, endIndent: 20),
                  _buildListTile(
                    icon: Icons.payment,
                    iconColor: Colors.green,
                    title: tr('manage_payment_delivery_terms'),
                    subtitle: tr('manage_payment_delivery_terms_desc'),
                    onTap: () => context.push('/user-terms'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                              child: const Icon(Icons.view_quilt, color: Colors.purple, size: 26),
                            ),
                            const SizedBox(width: 16),
                            Text(tr('settings.choose_view'), style: const TextStyle(fontWeight: FontWeight.w600)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SegmentedButton<DashboardView>(
                          segments: const [
                            ButtonSegment(value: DashboardView.short, label: Text('Short'), icon: Icon(Icons.view_compact)),
                            ButtonSegment(value: DashboardView.long, label: Text('Long'), icon: Icon(Icons.view_agenda)),
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
                  const Divider(height: 0, indent: 20, endIndent: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.dashboard, color: Colors.teal),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(tr('settings.choose_cards'), style: const TextStyle(fontWeight: FontWeight.w600)),
                              const SizedBox(height: 8),
                              ...widget.allCards.map((cardKey) {
                                return SwitchListTile(
                                  title: Text(cardKey.tr()),
                                  value: _selectedCards.contains(cardKey),
                                  onChanged: (val) => _onCardToggle(cardKey, val),
                                  activeThumbColor: Colors.teal,
                                  contentPadding: EdgeInsets.zero,
                                  dense: true,
                                );
                              }),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
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
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return ListTile(
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: iconColor.withAlpha(26),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(icon, color: iconColor, size: 26),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: trailing ?? const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
  }
} */

// lib/pages/settings/settings_page.dart - النسخة الكاملة المحسنة
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:puresip_purchasing/pages/dashboard/dashboard_metrics.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  bool _isLoading = true;

  // ✅ مفاتيح التخزين
  static const String _keyDashboardView = 'dashboard_view';
  static const String _keySelectedCards = 'selected_cards';

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

      Set<String> cardsSet = {};
      if (selectedCardsString != null && selectedCardsString.isNotEmpty) {
        try {
          final List<dynamic> decoded = json.decode(selectedCardsString);
          cardsSet = decoded.map((e) => e.toString()).toSet();
        } catch (e) {
          safeDebugPrint('Error parsing selected cards: $e');
          cardsSet = _getDefaultCardsForView(DashboardView.short);
        }
      } else {
        cardsSet = _getDefaultCardsForView(DashboardView.short);
      }

      DashboardView loadedView;
      if (viewString == 'long') {
        loadedView = DashboardView.long;
      } else if (viewString == 'short') {
        loadedView = DashboardView.short;
      } else {
        loadedView = _detectViewFromCards(cardsSet);
      }

      setState(() {
        _selectedView = loadedView;
        _selectedCards = cardsSet;
        _isLoading = false;
      });
      
      safeDebugPrint('Settings loaded - View: $loadedView, Cards: ${cardsSet.length}');
    } catch (e) {
      safeDebugPrint('Error loading settings: $e');
      _setDefaultSettings();
    }
  }

  DashboardView _detectViewFromCards(Set<String> cards) {
    final shortSet = _getDefaultCardsForView(DashboardView.short);
    final longSet = _getDefaultCardsForView(DashboardView.long);
    
    if (cards.length == longSet.length && cards.containsAll(longSet)) {
      return DashboardView.long;
    }
    if (cards.length == shortSet.length && cards.containsAll(shortSet)) {
      return DashboardView.short;
    }
    return DashboardView.short;
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

  void _setDefaultSettings() {
    setState(() {
      _selectedView = DashboardView.short;
      _selectedCards = _getDefaultCardsForView(DashboardView.short);
      _isLoading = false;
    });
  }

/*   Future<void> _saveSettings({bool shouldPop = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      if (_selectedView != null) {
        await prefs.setString(_keyDashboardView, 
            _selectedView == DashboardView.long ? 'long' : 'short');
      }
      
      final cardsList = _selectedCards.toList();
      await prefs.setString(_keySelectedCards, json.encode(cardsList));
      
      safeDebugPrint('✅ Settings saved - View: $_selectedView, Cards: ${cardsList.length}');

      if (shouldPop && mounted) {
        Navigator.pop(context, true);
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
 */
  
  // settings_page.dart - في دالة _saveSettings

Future<void> _saveSettings({bool shouldPop = false}) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    
    if (_selectedView != null) {
      await prefs.setString(_keyDashboardView, 
          _selectedView == DashboardView.long ? 'long' : 'short');
      safeDebugPrint('✅ View saved: ${_selectedView == DashboardView.long ? 'long' : 'short'}');
    }
    
    final cardsList = _selectedCards.toList();
    await prefs.setString(_keySelectedCards, json.encode(cardsList));
    safeDebugPrint('✅ Cards saved: ${cardsList.length} cards');

    if (shouldPop && mounted) {
      // ✅ إرجاع true لتحديث Dashboard
      Navigator.pop(context, true);
    }
  } catch (e) {
    safeDebugPrint('Save error: $e');
    if (shouldPop && mounted) {
      Navigator.pop(context, false);
    }
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
    });
    _saveSettings(shouldPop: false);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('settings.restored_defaults')),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('settings.title')),
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                // ==================== بطاقة الإعدادات الرئيسية ====================
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      // ✅ اختيار نوع العرض
                      _buildViewSelector(),
                      const Divider(height: 0, indent: 20, endIndent: 20),
                      // ✅ اختيار الكروت
                      _buildCardsSelector(),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // ==================== بطاقة المستندات ====================
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      _buildListTile(
                        icon: Icons.description,
                        iconColor: Colors.blue,
                        title: tr('manage_conditions_documents'),
                        subtitle: tr('manage_conditions_documents_desc'),
                        onTap: () => context.push('/additional-items'),
                      ),
                      const Divider(height: 0, indent: 20, endIndent: 20),
                      _buildListTile(
                        icon: Icons.payment,
                        iconColor: Colors.green,
                        title: tr('manage_payment_delivery_terms'),
                        subtitle: tr('manage_payment_delivery_terms_desc'),
                        onTap: () => context.push('/user-terms'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // ==================== أزرار الإجراءات ====================
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              border: Border(
                top: BorderSide(
                  color: Colors.grey.shade300,
                  width: 1,
                ),
              ),
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
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// ✅ مكون اختيار نوع العرض
  Widget _buildViewSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                child: const Icon(Icons.view_quilt, color: Colors.purple, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  tr('settings.choose_view'),
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
              ),
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
    );
  }

  /// ✅ مكون اختيار الكروت (محسن للأداء)
  Widget _buildCardsSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                child: const Icon(Icons.dashboard, color: Colors.teal, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  tr('settings.choose_cards'),
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // ✅ استخدام ListView.builder لتحسين الأداء
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.4,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: widget.allCards.length,
              itemBuilder: (context, index) {
                final cardKey = widget.allCards[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  elevation: 0,
                  color: _selectedCards.contains(cardKey) 
                      ? Colors.teal.withAlpha(13) 
                      : null,
                  child: CheckboxListTile(
                    title: Text(
                      cardKey.tr(),
                      style: TextStyle(
                        fontWeight: _selectedCards.contains(cardKey) 
                            ? FontWeight.w600 
                            : FontWeight.normal,
                      ),
                    ),
                    value: _selectedCards.contains(cardKey),
                    onChanged: (val) => _onCardToggle(cardKey, val ?? false),
                    activeColor: Colors.teal,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    secondary: Icon(
                      _getIconForCard(cardKey),
                      color: _selectedCards.contains(cardKey) 
                          ? Colors.teal 
                          : Colors.grey.shade400,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// ✅ الحصول على الأيقونة المناسبة لكل كرت
  IconData _getIconForCard(String cardKey) {
    switch (cardKey) {
      case 'totalCompanies':
        return Icons.business;
      case 'totalSuppliers':
        return Icons.local_shipping;
      case 'totalOrders':
        return Icons.shopping_cart;
      case 'totalFinishedProducts':
        return Icons.check_circle_outline;
      case 'totalAmount':
        return Icons.attach_money;
      case 'totalItems':
        return Icons.inventory_2;
      case 'totalMovements':
        return Icons.move_to_inbox;
      case 'inventory_query':
        return Icons.search;
      case 'totalManufacturingOrders':
        return Icons.precision_manufacturing;
      case 'totalFactories':
        return Icons.factory;
      case 'totalReports':
        return Icons.query_stats;
      default:
        return Icons.dashboard;
    }
  }

  /// ✅ مكون القائمة المنسق
  Widget _buildListTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return ListTile(
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: iconColor.withAlpha(26),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(icon, color: iconColor, size: 26),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        subtitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
      ),
      trailing: trailing ?? const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
  }
} */
// lib/pages/settings/settings_page.dart - النسخة النهائية المحسنة
/* 
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:puresip_purchasing/pages/dashboard/dashboard_metrics.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  bool _isLoading = true;

  // مفاتيح التخزين
  static const String _keyDashboardView = 'dashboard_view';
  static const String _keySelectedCards = 'selected_cards';

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

      Set<String> cardsSet = {};
      if (selectedCardsString != null && selectedCardsString.isNotEmpty) {
        try {
          final List<dynamic> decoded = json.decode(selectedCardsString);
          cardsSet = decoded.map((e) => e.toString()).toSet();
        } catch (e) {
          safeDebugPrint('Error parsing selected cards: $e');
          cardsSet = _getDefaultCardsForView(DashboardView.short);
        }
      } else {
        cardsSet = _getDefaultCardsForView(DashboardView.short);
      }

      DashboardView loadedView;
      if (viewString == 'long') {
        loadedView = DashboardView.long;
      } else if (viewString == 'short') {
        loadedView = DashboardView.short;
      } else {
        loadedView = _detectViewFromCards(cardsSet);
      }

      setState(() {
        _selectedView = loadedView;
        _selectedCards = cardsSet;
        _isLoading = false;
      });
      
      safeDebugPrint('Settings loaded - View: $loadedView, Cards: ${cardsSet.length}');
    } catch (e) {
      safeDebugPrint('Error loading settings: $e');
      _setDefaultSettings();
    }
  }

  DashboardView _detectViewFromCards(Set<String> cards) {
    final shortSet = _getDefaultCardsForView(DashboardView.short);
    final longSet = _getDefaultCardsForView(DashboardView.long);
    
    if (cards.length == longSet.length && cards.containsAll(longSet)) {
      return DashboardView.long;
    }
    if (cards.length == shortSet.length && cards.containsAll(shortSet)) {
      return DashboardView.short;
    }
    return DashboardView.short;
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

  void _setDefaultSettings() {
    setState(() {
      _selectedView = DashboardView.short;
      _selectedCards = _getDefaultCardsForView(DashboardView.short);
      _isLoading = false;
    });
  }

  Future<void> _saveSettings({bool shouldPop = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      if (_selectedView != null) {
        await prefs.setString(_keyDashboardView, 
            _selectedView == DashboardView.long ? 'long' : 'short');
        safeDebugPrint('✅ View saved: ${_selectedView == DashboardView.long ? 'long' : 'short'}');
      }
      
      final cardsList = _selectedCards.toList();
      await prefs.setString(_keySelectedCards, json.encode(cardsList));
      safeDebugPrint('✅ Cards saved: ${cardsList.length} cards');

      if (shouldPop && mounted) {
        Navigator.pop(context, true);
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
      if (shouldPop && mounted) {
        Navigator.pop(context, false);
      }
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
    });
    _saveSettings(shouldPop: false);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('settings.restored_defaults')),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('settings.title')),
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                // ==================== بطاقة اختيار العرض ====================
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                              child: const Icon(Icons.view_quilt, color: Colors.purple, size: 26),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                tr('settings.choose_view'),
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                              ),
                            ),
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
                ),
                
                const SizedBox(height: 20),
                
                // ==================== بطاقة اختيار الكروت ====================
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                              child: const Icon(Icons.dashboard, color: Colors.teal, size: 26),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                tr('settings.choose_cards'),
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // ✅ استخدام ListView.builder لتحسين الأداء
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.4,
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: widget.allCards.length,
                            itemBuilder: (context, index) {
                              final cardKey = widget.allCards[index];
                              final isSelected = _selectedCards.contains(cardKey);
                              final cardMetric = dashboardMetrics.firstWhere(
                                (m) => m.titleKey == cardKey,
                                orElse: () => dashboardMetrics.first,
                              );
                              
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                elevation: 0,
                                color: isSelected 
                                    ? Colors.teal.withAlpha(13) 
                                    : null,
                                child: CheckboxListTile(
                                  title: Text(
                                    cardKey.tr(),
                                    style: TextStyle(
                                      fontWeight: isSelected 
                                          ? FontWeight.w600 
                                          : FontWeight.normal,
                                    ),
                                  ),
                                  value: isSelected,
                                  onChanged: (val) => _onCardToggle(cardKey, val ?? false),
                                  activeColor: Colors.teal,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                                  secondary: Icon(
                                    cardMetric.icon,
                                    color: isSelected 
                                        ? Colors.teal 
                                        : Colors.grey.shade400,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // ==================== بطاقة المستندات ====================
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      _buildListTile(
                        icon: Icons.description,
                        iconColor: Colors.blue,
                        title: tr('manage_conditions_documents'),
                        subtitle: tr('manage_conditions_documents_desc'),
                        onTap: () => context.push('/additional-items'),
                      ),
                      const Divider(height: 0, indent: 20, endIndent: 20),
                      _buildListTile(
                        icon: Icons.payment,
                        iconColor: Colors.green,
                        title: tr('manage_payment_delivery_terms'),
                        subtitle: tr('manage_payment_delivery_terms_desc'),
                        onTap: () => context.push('/user-terms'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // ==================== أزرار الإجراءات ====================
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              border: Border(
                top: BorderSide(
                  color: Colors.grey.shade300,
                  width: 1,
                ),
              ),
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
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return ListTile(
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: iconColor.withAlpha(26),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(icon, color: iconColor, size: 26),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        subtitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
      ),
      trailing: trailing ?? const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
  }
} */

// settings_page.dart - نسخة سريعة جداً

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

      Set<String> cardsSet = {};
      if (selectedCardsString != null && selectedCardsString.isNotEmpty) {
        try {
          final List<dynamic> decoded = json.decode(selectedCardsString);
          cardsSet = decoded.map((e) => e.toString()).toSet();
        } catch (e) {
          cardsSet = _getDefaultCardsForView(DashboardView.short);
        }
      } else {
        cardsSet = _getDefaultCardsForView(DashboardView.short);
      }

      setState(() {
        _selectedView =
            viewString == 'long' ? DashboardView.long : DashboardView.short;
        _selectedCards = cardsSet;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _selectedView = DashboardView.short;
        _selectedCards = _getDefaultCardsForView(DashboardView.short);
        _isLoading = false;
      });
    }
  }

  Set<String> _getDefaultCardsForView(DashboardView view) {
    if (view == DashboardView.long) {
      return dashboardMetrics
          .where((m) =>
              m.defaultMenuType == 'long' || m.defaultMenuType == 'short')
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
    });
    _saveSettings(shouldPop: false);
  }

  Future<void> _saveSettings({bool shouldPop = false}) async {
    try {
      final viewString = _selectedView == DashboardView.long ? 'long' : 'short';

      // ✅ تحديث Provider
      final settingsProvider =
          Provider.of<DashboardSettingsProvider>(context, listen: false);
      settingsProvider.updateSettings(viewString, _selectedCards);

      safeDebugPrint(
          '✅ Settings saved - View: $viewString, Cards: ${_selectedCards.length}');

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
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
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
                // ==================== ✅ 1. بطاقة المستندات (في الأعلى) ====================
                _buildDocumentsCard(),
                const SizedBox(height: 16),
                // ==================== 2. بطاقة اختيار العرض ====================
                _buildViewCard(),
                const SizedBox(height: 16),
                // ==================== 3. بطاقة اختيار الكروت ====================
                _buildCardsCard(),
              ],
            ),
          ),
          // ✅ أزرار الإجراءات
          _buildActionButtons(),
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
                Text(
                  tr('settings.choose_view'),
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 16),
                ),
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
                Text(
                  tr('settings.choose_cards'),
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // ✅ استخدام ListView.builder مع ارتفاع محدد
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
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.normal,
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
            title: Text(
              tr('manage_conditions_documents'),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(tr('manage_conditions_documents_desc')),
            trailing: const Icon(Icons.arrow_forward_ios,
                size: 16, color: Colors.grey),
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
            title: Text(
              tr('manage_payment_delivery_terms'),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(tr('manage_payment_delivery_terms_desc')),
            trailing: const Icon(Icons.arrow_forward_ios,
                size: 16, color: Colors.grey),
            onTap: () => context.push('/user-terms'),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
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
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
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
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconForCard(String cardKey) {
    switch (cardKey) {
      case 'totalCompanies':
        return Icons.business;
      case 'totalSuppliers':
        return Icons.local_shipping;
      case 'totalOrders':
        return Icons.shopping_cart;
      case 'totalFinishedProducts':
        return Icons.check_circle_outline;
      case 'totalAmount':
        return Icons.attach_money;
      case 'totalItems':
        return Icons.inventory_2;
      case 'totalStockMovements':
        return Icons.move_to_inbox;
      case 'inventory_query':
        return Icons.search;
      case 'totalManufacturingOrders':
        return Icons.precision_manufacturing;
      case 'totalFactories':
        return Icons.factory;
      case 'reports':
        return Icons.query_stats;
      default:
        return Icons.dashboard;
    }
  }
}
 */