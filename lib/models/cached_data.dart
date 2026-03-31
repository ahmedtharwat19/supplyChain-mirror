import 'package:hive/hive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

part 'cached_data.g.dart';

@HiveType(typeId: 1)
class CachedData {
  @HiveField(0)
  final String key;
  
  @HiveField(1)
  final dynamic data;
  
  @HiveField(2)
  final DateTime lastUpdated;
  
  @HiveField(3)
  final String dataType; // 'companies', 'factories', 'items', 'movements'

  CachedData({
    required this.key,
    required this.data,
    required this.lastUpdated,
    required this.dataType,
  });

  // دالة لتحويل البيانات إلى Map للتخزين
  Map<String, dynamic> toMap() {
    return {
      'key': key,
      'data': data,
      'lastUpdated': lastUpdated,
      'dataType': dataType,
    };
  }

  factory CachedData.fromMap(Map<String, dynamic> map) {
    return CachedData(
      key: map['key'] ?? '',
      data: map['data'],
      lastUpdated: (map['lastUpdated'] is Timestamp) 
          ? (map['lastUpdated'] as Timestamp).toDate() 
          : DateTime.now(),
      dataType: map['dataType'] ?? '',
    );
  }
}