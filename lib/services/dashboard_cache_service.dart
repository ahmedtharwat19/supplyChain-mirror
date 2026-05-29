// services/dashboard_cache_service.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';


class DashboardCacheService {
  static const String _keyStats = 'dashboard_stats_cache';
  static const String _keyView = 'dashboard_view';
  static const String _keyCards = 'dashboard_cards';
  static const String _keyUserName = 'user_name';
  static const String _keyUserData = 'user_data_cache';
  
  static Future<void> cacheStats(Map<String, dynamic> stats) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyStats, json.encode(stats));
  }
  
  static Future<Map<String, dynamic>?> getCachedStats() async {
    final prefs = await SharedPreferences.getInstance();
    final statsStr = prefs.getString(_keyStats);
    if (statsStr != null) {
      return json.decode(statsStr) as Map<String, dynamic>;
    }
    return null;
  }
  
  static Future<void> cacheView(String view) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyView, view);
  }
  
  static Future<String?> getCachedView() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyView);
  }
  
  static Future<void> cacheCards(List<String> cards) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCards, json.encode(cards));
  }
  
  static Future<List<String>?> getCachedCards() async {
    final prefs = await SharedPreferences.getInstance();
    final cardsStr = prefs.getString(_keyCards);
    if (cardsStr != null) {
      return List<String>.from(json.decode(cardsStr));
    }
    return null;
  }
  
  static Future<void> cacheUserName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserName, name);
  }
  
  static Future<String?> getCachedUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserName);
  }
  
  static Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyStats);
    await prefs.remove(_keyUserData);
  }
}