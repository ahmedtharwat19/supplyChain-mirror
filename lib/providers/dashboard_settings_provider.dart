/* // providers/dashboard_settings_provider.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DashboardSettingsProvider extends ChangeNotifier {
  String _dashboardView = 'short';
  Set<String> _selectedCards = {};

  String get dashboardView => _dashboardView;
  Set<String> get selectedCards => _selectedCards;

  DashboardSettingsProvider() {
    _loadFromStorage();
  }

  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _dashboardView = prefs.getString('dashboard_view') ?? 'short';
      
      final cardsString = prefs.getString('selected_cards');
      if (cardsString != null && cardsString.isNotEmpty) {
        final List<dynamic> decoded = json.decode(cardsString);
        _selectedCards = decoded.map((e) => e.toString()).toSet();
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading settings: $e');
    }
  }

  void updateSettings(String view, Set<String> cards) async {
    _dashboardView = view;
    _selectedCards = cards;
    
    // حفظ في SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('dashboard_view', view);
    await prefs.setString('selected_cards', json.encode(cards.toList()));
    
    notifyListeners();
  }

  void resetToDefault() {
    _dashboardView = 'short';
    _selectedCards = {'totalCompanies', 'totalSuppliers', 'totalOrders', 'totalFinishedProducts'};
    updateSettings(_dashboardView, _selectedCards);
  }
} */
// providers/dashboard_settings_provider.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DashboardSettingsProvider extends ChangeNotifier {
  String _dashboardView = 'short'; // 'short' or 'long'
  Set<String> _selectedCards = {};
  String _displayMode = 'cards'; // 'cards' or 'logo'

  String get dashboardView => _dashboardView;
  Set<String> get selectedCards => _selectedCards;
  String get displayMode => _displayMode;

  // تحميل الإعدادات من SharedPreferences
  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _dashboardView = prefs.getString('dashboard_view') ?? 'short';
    
    final cardsString = prefs.getString('selected_cards');
    if (cardsString != null && cardsString.isNotEmpty) {
      try {
        final List<dynamic> decoded = json.decode(cardsString);
        _selectedCards = decoded.map((e) => e.toString()).toSet();
      } catch (_) {
        _selectedCards = {};
      }
    } else {
      _selectedCards = {};
    }
    
    _displayMode = prefs.getString('display_mode') ?? 'cards';
    notifyListeners();
  }

  // تحديث نوع العرض (Short / Long)
  void updateView(String view) {
    if (_dashboardView != view) {
      _dashboardView = view;
      _saveSettings();
    }
  }

  // تحديث الكروت المختارة
  void updateCards(Set<String> cards) {
    _selectedCards = cards;
    _saveSettings();
  }

  // تحديث وضع الشاشة (كروت / شعار)
  void updateDisplayMode(String mode) {
    if (_displayMode != mode) {
      _displayMode = mode;
      _saveSettings();
    }
  }

  // حفظ كل الإعدادات في SharedPreferences
  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('dashboard_view', _dashboardView);
    await prefs.setString('selected_cards', json.encode(_selectedCards.toList()));
    await prefs.setString('display_mode', _displayMode);
    notifyListeners();
  }
}