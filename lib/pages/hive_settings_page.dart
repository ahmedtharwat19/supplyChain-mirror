import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:puresip_purchasing/services/hive_service.dart';
import 'package:puresip_purchasing/debug_helper.dart';

class HiveSettingsPage extends StatefulWidget {
  const HiveSettingsPage({super.key});

  @override
  State<HiveSettingsPage> createState() => _HiveSettingsPageState();
}

class _HiveSettingsPageState extends State<HiveSettingsPage> {
  int _cacheSize = 0;
  int _authDataSize = 0;
  int _userDataSize = 0;
  int _settingsSize = 0;
  int _licenseSize = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHiveStats();
  }

  Future<void> _loadHiveStats() async {
    setState(() => _isLoading = true);
    try {
      final stats = await HiveService.getStorageStats();
      
      setState(() {
        _cacheSize = stats['cache'] ?? 0;
        _authDataSize = stats['auth'] ?? 0;
        _userDataSize = stats['user'] ?? 0;
        _settingsSize = stats['settings'] ?? 0;
        _licenseSize = stats['license'] ?? 0;
        _isLoading = false;
      });
    } catch (e) {
      safeDebugPrint('Error loading Hive stats: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _clearAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('confirm_clear_data'.tr()),
        content: Text('clear_data_warning'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('clear'.tr()),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await HiveService.clearAllData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('data_cleared'.tr())),
      );
      _loadHiveStats();
    }
  }

  Future<void> _clearCache() async {
    await HiveService.clearCache();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('cache_cleared'.tr())),
    );
    _loadHiveStats();
  }

  Future<void> _compactDatabase() async {
    await HiveService.compactDatabase();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('database_compacted'.tr())),
    );
    _loadHiveStats();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('hive_settings'.tr()),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildStorageCard(),
                const SizedBox(height: 20),
                _buildActionButtons(),
              ],
            ),
    );
  }

  Widget _buildStorageCard() {
    final totalSize = _cacheSize + _authDataSize + _userDataSize + _settingsSize + _licenseSize;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'storage_usage'.tr(),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            _buildStorageItem('cache_data'.tr(), _cacheSize),
            _buildStorageItem('auth_data'.tr(), _authDataSize),
            _buildStorageItem('user_data'.tr(), _userDataSize),
            _buildStorageItem('settings_title'.tr(), _settingsSize),
            _buildStorageItem('license'.tr(), _licenseSize),
            const Divider(),
            _buildStorageItem('total'.tr(), totalSize, isTotal: true),
          ],
        ),
      ),
    );
  }

  Widget _buildStorageItem(String title, int size, {bool isTotal = false}) {
    final sizeKB = size / 1024;
    final displaySize = sizeKB > 1024 
        ? '${(sizeKB / 1024).toStringAsFixed(2)} MB' 
        : '${sizeKB.toStringAsFixed(2)} KB';
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: isTotal
                ? Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    )
                : Theme.of(context).textTheme.bodyMedium,
          ),
          Text(
            displaySize,
            style: isTotal
                ? Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    )
                : Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        // زر ضغط قاعدة البيانات
        ElevatedButton(
          onPressed: _compactDatabase,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
          ),
          child: Text('compact_database'.tr()),
        ),
        const SizedBox(height: 12),
        
        // زر مسح الذاكرة المؤقتة
        ElevatedButton(
          onPressed: _clearCache,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
          ),
          child: Text('clear_cache'.tr()),
        ),
        const SizedBox(height: 12),
        
        // زر مسح جميع البيانات
        ElevatedButton(
          onPressed: _clearAllData,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
          ),
          child: Text('clear_all_data'.tr()),
        ),
      ],
    );
  }
}