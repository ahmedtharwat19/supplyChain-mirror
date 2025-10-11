/* // ignore_for_file: deprecated_member_use

/* import 'package:flutter/material.dart';
import 'package:puresip_purchasing/pages/dashboard/dashboard_metrics.dart';
import 'package:puresip_purchasing/widgets/app_scaffold.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';

const String prefDashboardView = 'dashboard_view';
const String prefSelectedCards = 'selected_cards';

enum DashboardView { short, long }

class SettingsPage extends StatefulWidget {
  final List<String> allCards;

  const SettingsPage({super.key, required this.allCards});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  DashboardView _selectedView = DashboardView.short;
  Set<String> _selectedCards = {};

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final viewString = prefs.getString(prefDashboardView) ?? 'short';
    final selectedCards = prefs.getStringList(prefSelectedCards) ?? [];

    setState(() {
      _selectedView =
          viewString == 'long' ? DashboardView.long : DashboardView.short;
      _selectedCards = selectedCards.toSet();
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefDashboardView,
        _selectedView == DashboardView.long ? 'long' : 'short');
    await prefs.setStringList(prefSelectedCards, _selectedCards.toList());

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('settings.saved_successfully'))),
      );
    }
  }

/*   void _onViewChanged(DashboardView? value) async {
    if (value == null) return;

    Set<String> selectedCards;
    if (value == DashboardView.long) {
      selectedCards = widget.allCards.toSet(); // اختيار الكل
    } else {
      selectedCards = {
        'total_companies',
        'total_orders',
        'total_amount',
        'total_suppliers',
      };
    }

    setState(() {
      _selectedView = value;
      _selectedCards = selectedCards;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        prefDashboardView, value == DashboardView.long ? 'long' : 'short');
    await prefs.setStringList(prefSelectedCards, selectedCards.toList());

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value == DashboardView.long
                ? tr('settings.long_selected')
                : tr('settings.short_selected'),
          ),
        ),
      );
    }
  } */

void _onViewChanged(DashboardView? value) async {
  if (value == null) return;

  // 🧠 استخدم defaultMenuType لتوليد البطاقات المختارة
  Set<String> selectedCards;
  if (value == DashboardView.long) {
    selectedCards = dashboardMetrics
        .where((metric) => metric.defaultMenuType == 'long')
        .map((metric) => metric.titleKey)
        .toSet();
  } else {
    selectedCards = dashboardMetrics
        .where((metric) => metric.defaultMenuType == 'short')
        .map((metric) => metric.titleKey)
        .toSet();
  }

  setState(() {
    _selectedView = value;
    _selectedCards = selectedCards;
  });

  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
      prefDashboardView, value == DashboardView.long ? 'long' : 'short');
  await prefs.setStringList(prefSelectedCards, selectedCards.toList());

  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          value == DashboardView.long
              ? tr('settings.long_selected')
              : tr('settings.short_selected'),
        ),
      ),
    );
  }
}




  void _onCardToggle(String cardKey, bool selected) {
    setState(() {
      if (selected) {
        _selectedCards.add(cardKey);
      } else {
        _selectedCards.remove(cardKey);
      }
    });
    _saveSettings();
  }

  void _resetToDefaults() async {
    setState(() {
      _selectedView = DashboardView.short;
      _selectedCards = {
        'totalCompanies',
        'totalOrders',
        'totalAmount',
        'totalSuppliers',
      };
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefDashboardView, 'short');
    await prefs.setStringList(prefSelectedCards, _selectedCards.toList());

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('settings.restored_defaults'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'settings.title'.tr(),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text('settings.choose_view',
                    style: Theme.of(context).textTheme.headlineMedium)
                .tr(),
            ListTile(
              title: Text('settings.short_view'.tr()),
              leading: Radio<DashboardView>(
                value: DashboardView.short,
                groupValue: _selectedView,
                onChanged: _onViewChanged,
              ),
            ),
            ListTile(
              title: Text('settings.long_view'.tr()),
              leading: Radio<DashboardView>(
                value: DashboardView.long,
                groupValue: _selectedView,
                onChanged: _onViewChanged,
              ),
            ),
            const Divider(height: 32),
            Text('settings.choose_cards',
                    style: Theme.of(context).textTheme.headlineSmall)
                .tr(),
            Expanded(
              child: ListView(
                children: widget.allCards.map((cardKey) {
                  return CheckboxListTile(
                    title: Text(cardKey).tr(),
                    value: _selectedCards.contains(cardKey),
                    onChanged: (val) {
                      if (val == null) return;
                      _onCardToggle(cardKey, val);
                    },
                  );
                }).toList(),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.save),
                    label: Text(tr('save')),
                    onPressed: () async {
                      await _saveSettings();
                      if (!context.mounted) return;
                      Navigator.pop(context, true); // عودة للـ dashboard
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.restore),
                    label: Text(tr('settings.reset')),
                    onPressed: _resetToDefaults,
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
 */

import 'package:flutter/material.dart';
import 'package:puresip_purchasing/pages/dashboard/dashboard_metrics.dart';
import 'package:puresip_purchasing/widgets/app_scaffold.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:puresip_purchasing/debug_helper.dart';

const String prefDashboardView = 'dashboard_view';
const String prefSelectedCards = 'selected_cards';

enum DashboardView { short, long }

class SettingsPage extends StatefulWidget {
  final List<String> allCards;

  const SettingsPage({super.key, required this.allCards});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  DashboardView? _selectedView; // يمكن يكون null لو يدوي
  Set<String> _selectedCards = {};

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final viewString = prefs.getString(prefDashboardView);
    final selectedCards = prefs.getStringList(prefSelectedCards) ?? [];

    Set<String> cardsSet = selectedCards.toSet();

    // تحديد view مع مراعاة التعديل اليدوي
    DashboardView? loadedView;

    if (viewString == 'short') {
      loadedView = DashboardView.short;
    } else if (viewString == 'long') {
      loadedView = DashboardView.long;
    } else {
      loadedView = null;
    }

    // تحقق هل الكروت المختارة تتطابق مع عرض short أو long + short
    bool matchesShort = cardsSet.length ==
            dashboardMetrics
                .where((m) => m.defaultMenuType == 'short')
                .map((m) => m.titleKey)
                .toSet()
                .length &&
        cardsSet.containsAll(dashboardMetrics
            .where((m) => m.defaultMenuType == 'short')
            .map((m) => m.titleKey));

    bool matchesLong = cardsSet.length ==
            dashboardMetrics
                .where((m) =>
                    m.defaultMenuType == 'long' || m.defaultMenuType == 'short')
                .map((m) => m.titleKey)
                .toSet()
                .length &&
        cardsSet.containsAll(dashboardMetrics
            .where((m) =>
                m.defaultMenuType == 'long' || m.defaultMenuType == 'short')
            .map((m) => m.titleKey));

    // لو الكروت المختارة ما تتطابق مع short ولا مع long => تعديل يدوي => نضع view null
    if (!(matchesShort && loadedView == DashboardView.short) &&
        !(matchesLong && loadedView == DashboardView.long)) {
      loadedView = null;
    }

    setState(() {
      _selectedView = loadedView;
      _selectedCards = cardsSet;
    });
  }

  Future<void> _saveSettings({bool showMessage = true}) async {
    final prefs = await SharedPreferences.getInstance();
    if (_selectedView != null) {
      await prefs.setString(prefDashboardView,
          _selectedView == DashboardView.long ? 'long' : 'short');
    } else {
      await prefs.remove(prefDashboardView); // حذف القيمة لو يدوي
    }
    await prefs.setStringList(prefSelectedCards, _selectedCards.toList());

    safeDebugPrint('Saving settings: view=$_selectedView, cards=$_selectedCards');

    if (mounted && showMessage) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('settings.saved_successfully')),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.only(bottom: 70, left: 16, right: 16),
        ),
      );
    }
  }

  void _onViewChanged(DashboardView? value) {
    if (value == null) return;

    Set<String> selectedCards;

    if (value == DashboardView.long) {
      selectedCards = dashboardMetrics
          .where((metric) =>
              metric.defaultMenuType == 'long' ||
              metric.defaultMenuType == 'short')
          .map((metric) => metric.titleKey)
          .toSet();
    } else {
      selectedCards = dashboardMetrics
          .where((metric) => metric.defaultMenuType == 'short')
          .map((metric) => metric.titleKey)
          .toSet();
    }

    setState(() {
      _selectedView = value;
      _selectedCards = selectedCards;
    });

    _saveSettings(showMessage: true);
  }

  void _onCardToggle(String cardKey, bool selected) {
    setState(() {
      if (selected) {
        _selectedCards.add(cardKey);
      } else {
        _selectedCards.remove(cardKey);
      }
      // لما يتم تعديل يدوي، نلغي تحديد العرض (null)
      _selectedView = null;
    });

    _saveSettings(showMessage: false);
  }

  void _resetToDefaults() async {
    setState(() {
      _selectedView = DashboardView.short;
      _selectedCards = dashboardMetrics
          .where((metric) => metric.defaultMenuType == 'short')
          .map((metric) => metric.titleKey)
          .toSet();
    });

    await _saveSettings();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('settings.restored_defaults')),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.only(bottom: 70, left: 16, right: 16),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'settings.title'.tr(),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text('settings.choose_view',
                    style: Theme.of(context).textTheme.headlineMedium)
                .tr(),
            ListTile(
              title: Text('settings.short_view'.tr()),
              leading: Radio<DashboardView>(
                value: DashboardView.short,
                groupValue: _selectedView,
                onChanged: _onViewChanged,
              ),
            ),
            ListTile(
              title: Text('settings.long_view'.tr()),
              leading: Radio<DashboardView>(
                value: DashboardView.long,
                groupValue: _selectedView,
                onChanged: _onViewChanged,
              ),
            ),
            if (_selectedView == null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  tr('settings.custom_selection_note'), // مثلا "Custom selection active"
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            const Divider(height: 32),
            Text('settings.choose_cards',
                    style: Theme.of(context).textTheme.headlineSmall)
                .tr(),
            Expanded(
              child: ListView(
                children: widget.allCards.map((cardKey) {
                  return CheckboxListTile(
                    title: Text(cardKey).tr(),
                    value: _selectedCards.contains(cardKey),
                    onChanged: (val) {
                      if (val == null) return;
                      _onCardToggle(cardKey, val);
                    },
                  );
                }).toList(),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.save),
                    label: Text(tr('save')),
                    onPressed: () async {
                      await _saveSettings();
                      if (!context.mounted) return;
                      Navigator.pop(context, true);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.restore),
                    label: Text(tr('settings.reset')),
                    onPressed: _resetToDefaults,
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
 */

import 'package:flutter/material.dart';
import 'package:puresip_purchasing/pages/dashboard/dashboard_metrics.dart';
import 'package:puresip_purchasing/widgets/app_scaffold.dart';
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

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

/*   Future<void> _loadSettings() async {
    try {
      // تحميل الإعدادات من Hive
      final viewString = await HiveService.getSetting<String>('dashboard_view');
      final selectedCards = await HiveService.getSetting<List<String>>(
          'selected_cards',
          defaultValue: []);

      Set<String> cardsSet = selectedCards!.toSet();

      // تحديد view مع مراعاة التعديل اليدوي
      DashboardView? loadedView;

      if (viewString == 'short') {
        loadedView = DashboardView.short;
      } else if (viewString == 'long') {
        loadedView = DashboardView.long;
      } else {
        loadedView = null;
      }

      // تحقق هل الكروت المختارة تتطابق مع عرض short أو long
      bool matchesShort = cardsSet.length ==
              dashboardMetrics
                  .where((m) => m.defaultMenuType == 'short')
                  .map((m) => m.titleKey)
                  .toSet()
                  .length &&
          cardsSet.containsAll(dashboardMetrics
              .where((m) => m.defaultMenuType == 'short')
              .map((m) => m.titleKey));

      bool matchesLong = cardsSet.length ==
              dashboardMetrics
                  .where((m) =>
                      m.defaultMenuType == 'long' ||
                      m.defaultMenuType == 'short')
                  .map((m) => m.titleKey)
                  .toSet()
                  .length &&
          cardsSet.containsAll(dashboardMetrics
              .where((m) =>
                  m.defaultMenuType == 'long' || m.defaultMenuType == 'short')
              .map((m) => m.titleKey));

      // لو الكروت المختارة ما تتطابق مع short ولا مع long => تعديل يدوي
      if (!(matchesShort && loadedView == DashboardView.short) &&
          !(matchesLong && loadedView == DashboardView.long)) {
        loadedView = null;
      }

      setState(() {
        _selectedView = loadedView;
        _selectedCards = cardsSet;
      });

      safeDebugPrint(
          'Settings loaded from Hive: view=$loadedView, cards=$cardsSet');
    } catch (e) {
      safeDebugPrint('❌ Error loading settings from Hive: $e');
      // القيم الافتراضية في حالة الخطأ
      setState(() {
        _selectedView = DashboardView.short;
        _selectedCards = dashboardMetrics
            .where((metric) => metric.defaultMenuType == 'short')
            .map((metric) => metric.titleKey)
            .toSet();
      });
    }
  }
 */

  Future<void> _loadSettings() async {
    try {
      safeDebugPrint('🔄 Starting to load settings from Hive...');

      // تحميل الإعدادات من Hive بطريقة أكثر أماناً
      final viewString = await HiveService.getSetting<String>('dashboard_view');
      final selectedCards =
          await HiveService.getSetting<List<dynamic>>('selected_cards');

      safeDebugPrint(
          '🔍 Raw Hive data - view: $viewString, cards: $selectedCards');

      // معالجة selected_cards بشكل آمن
      Set<String> cardsSet = {};
      if (selectedCards != null && selectedCards.isNotEmpty) {
        cardsSet = selectedCards.map((item) => item.toString()).toSet();
      } else {
        // إذا لم توجد كروت محفوظة، استخدم الافتراضية
        cardsSet = _getDefaultCardsForView(DashboardView.short);
        safeDebugPrint('🔄 No cards found, using defaults: $cardsSet');
      }

      safeDebugPrint('✅ Processed cards set: $cardsSet');

      // تحديد view
      DashboardView? loadedView;
      if (viewString == 'short') {
        loadedView = DashboardView.short;
      } else if (viewString == 'long') {
        loadedView = DashboardView.long;
      } else {
        loadedView = null;
        safeDebugPrint('🔄 No view found in Hive, will auto-detect');
      }

      // إذا كان view null، حاول اكتشافه تلقائياً من الكروت
      if (loadedView == null) {
        loadedView = _detectViewFromCards(cardsSet);
        safeDebugPrint('🔍 Auto-detected view: $loadedView');
      }

      // تحقق من صحة الكروت (إذا كانت هناك كروت غير موجودة في القائمة الأساسية)
      final validCards = _validateCards(cardsSet);
      if (validCards.length != cardsSet.length) {
        safeDebugPrint(
            '🔄 Filtered out invalid cards: ${cardsSet.length} -> ${validCards.length}');
        cardsSet = validCards;
      }

      setState(() {
        _selectedView = loadedView;
        _selectedCards = cardsSet;
      });

      safeDebugPrint(
          '✅ Settings loaded successfully: view=$loadedView, cards=$cardsSet');
    } catch (e) {
      safeDebugPrint('❌ Error loading settings from Hive: $e');
      // القيم الافتراضية في حالة الخطأ
      _setDefaultSettings();
    }
  }

// دالة مساعدة لاكتشاف العرض من الكروت
  DashboardView _detectViewFromCards(Set<String> cards) {
    final allShortCards = dashboardMetrics
        .where((m) => m.defaultMenuType == 'short')
        .map((m) => m.titleKey)
        .toSet();

    final allLongCards = dashboardMetrics
        .where(
            (m) => m.defaultMenuType == 'long' || m.defaultMenuType == 'short')
        .map((m) => m.titleKey)
        .toSet();

    // تحقق إذا كانت الكروت تطابق العرض القصير
    if (cards.length == allShortCards.length &&
        cards.containsAll(allShortCards)) {
      return DashboardView.short;
    }

    // تحقق إذا كانت الكروت تطابق العرض الطويل
    if (cards.length == allLongCards.length &&
        cards.containsAll(allLongCards)) {
      return DashboardView.long;
    }

    // إذا لم تطابق أي من النمطين، اعتبرها تعديل يدوي واستخدم العرض القصير كافتراضي
    return DashboardView.short;
  }

// دالة مساعدة للحصول على الكروت الافتراضية لكل عرض
  Set<String> _getDefaultCardsForView(DashboardView view) {
    if (view == DashboardView.long) {
      return dashboardMetrics
          .where((metric) =>
              metric.defaultMenuType == 'long' ||
              metric.defaultMenuType == 'short')
          .map((metric) => metric.titleKey)
          .toSet();
    } else {
      return dashboardMetrics
          .where((metric) => metric.defaultMenuType == 'short')
          .map((metric) => metric.titleKey)
          .toSet();
    }
  }

// دالة للتحقق من صحة الكروت (إزالة أي كروت غير موجودة في القائمة الأساسية)
  Set<String> _validateCards(Set<String> cards) {
    final allValidCards =
        dashboardMetrics.map((metric) => metric.titleKey).toSet();

    return cards.where((card) => allValidCards.contains(card)).toSet();
  }

// دالة للإعدادات الافتراضية
  void _setDefaultSettings() {
    final defaultView = DashboardView.short;
    final defaultCards = _getDefaultCardsForView(defaultView);

    setState(() {
      _selectedView = defaultView;
      _selectedCards = defaultCards;
    });

    safeDebugPrint(
        '🔄 Using default settings: view=$defaultView, cards=$defaultCards');
  }

  Future<void> _saveSettings({bool showMessage = true}) async {
    try {
      if (_selectedView != null) {
        await HiveService.saveSetting('dashboard_view',
            _selectedView == DashboardView.long ? 'long' : 'short');
      } else {
        await HiveService.saveSetting('dashboard_view', null);
      }

      await HiveService.saveSetting('selected_cards', _selectedCards.toList());

      safeDebugPrint(
          'Settings saved to Hive: view=$_selectedView, cards=$_selectedCards');

      if (mounted && showMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('settings.saved_successfully')),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.only(bottom: 70, left: 16, right: 16),
          ),
        );
      }
    } catch (e) {
      safeDebugPrint('❌ Error saving settings to Hive: $e');
      if (mounted && showMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('settings.save_error')),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _onViewChanged(DashboardView? value) {
    if (value == null) return;

    Set<String> selectedCards;

    if (value == DashboardView.long) {
      selectedCards = dashboardMetrics
          .where((metric) =>
              metric.defaultMenuType == 'long' ||
              metric.defaultMenuType == 'short')
          .map((metric) => metric.titleKey)
          .toSet();
    } else {
      selectedCards = dashboardMetrics
          .where((metric) => metric.defaultMenuType == 'short')
          .map((metric) => metric.titleKey)
          .toSet();
    }

    setState(() {
      _selectedView = value;
      _selectedCards = selectedCards;
    });

    _saveSettings(showMessage: true);
  }

  void _onCardToggle(String cardKey, bool selected) {
    setState(() {
      if (selected) {
        _selectedCards.add(cardKey);
      } else {
        _selectedCards.remove(cardKey);
      }
      // لما يتم تعديل يدوي، نلغي تحديد العرض (null)
      _selectedView = null;
    });

    _saveSettings(showMessage: false);
  }

  void _resetToDefaults() async {
    setState(() {
      _selectedView = DashboardView.short;
      _selectedCards = dashboardMetrics
          .where((metric) => metric.defaultMenuType == 'short')
          .map((metric) => metric.titleKey)
          .toSet();
    });

    await _saveSettings();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('settings.restored_defaults')),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.only(bottom: 70, left: 16, right: 16),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'settings.title'.tr(),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text('settings.choose_view',
                    style: Theme.of(context).textTheme.headlineMedium)
                .tr(),
            Column(
              children: [
                RadioMenuButton<DashboardView>(
                  value: DashboardView.short,
                  groupValue: _selectedView,
                  onChanged: _onViewChanged,
                  child: Text('settings.short_view'.tr()),
                ),
                RadioMenuButton<DashboardView>(
                  value: DashboardView.long,
                  groupValue: _selectedView,
                  onChanged: _onViewChanged,
                  child: Text('settings.long_view'.tr()),
                ),
              ],
            ),
            if (_selectedView == null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  tr('settings.custom_selection_note'),
                  style: const TextStyle(color: Colors.orange),
                ),
              ),
            const Divider(height: 32),
            Text('settings.choose_cards',
                    style: Theme.of(context).textTheme.headlineSmall)
                .tr(),
            Expanded(
              child: ListView(
                children: widget.allCards.map((cardKey) {
                  return CheckboxListTile(
                    title: Text(cardKey).tr(),
                    value: _selectedCards.contains(cardKey),
                    onChanged: (val) {
                      if (val == null) return;
                      _onCardToggle(cardKey, val);
                    },
                  );
                }).toList(),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.save),
                    label: Text(tr('save')),
                    onPressed: () async {
                      await _saveSettings();
                      if (!context.mounted) return;
                      Navigator.pop(context, true);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.restore),
                    label: Text(tr('settings.reset')),
                    onPressed: _resetToDefaults,
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
