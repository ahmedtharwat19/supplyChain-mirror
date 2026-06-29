// providers/dashboard_settings_provider.dart
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
}