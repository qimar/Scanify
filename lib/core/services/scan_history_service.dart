import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/scan_record.dart';

class ScanHistoryService {
  ScanHistoryService._();
  static final ScanHistoryService instance = ScanHistoryService._();

  static const String _storageKey = 'scan_history';
  SharedPreferences? _prefs;

  Future<SharedPreferences> get _preferences async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  Future<List<ScanRecord>> _loadRecords() async {
    final prefs = await _preferences;
    final jsonString = prefs.getString(_storageKey);
    if (jsonString == null) return [];
    try {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      final list = jsonList
          .map((json) => ScanRecord.fromJson(json as Map<String, dynamic>))
          .toList();
      // Sort newest first
      list.sort((a, b) => b.scannedAt.compareTo(a.scannedAt));
      return list;
    } catch (e) {
      return [];
    }
  }

  Future<void> _saveRecords(List<ScanRecord> records) async {
    final prefs = await _preferences;
    final jsonList = records.map((record) => record.toJson()).toList();
    await prefs.setString(_storageKey, jsonEncode(jsonList));
  }

  Future<void> addRecord(ScanRecord record) async {
    final records = await _loadRecords();
    
    // Check if the record already exists (e.g. prevent duplicate saves if any)
    records.removeWhere((r) => r.id == record.id);
    
    records.insert(0, record);

    // Keep max 500 records, drop oldest non-favorites first
    while (records.length > 500) {
      int indexToRemove = -1;
      for (int i = records.length - 1; i >= 0; i--) {
        if (!records[i].isFavourite) {
          indexToRemove = i;
          break;
        }
      }
      if (indexToRemove == -1) {
        indexToRemove = records.length - 1;
      }
      records.removeAt(indexToRemove);
    }

    await _saveRecords(records);
  }

  Future<List<ScanRecord>> getHistory() async {
    return _loadRecords();
  }

  Future<List<ScanRecord>> getFavourites() async {
    final records = await _loadRecords();
    return records.where((r) => r.isFavourite).toList();
  }

  Future<void> toggleFavourite(String id) async {
    final records = await _loadRecords();
    final index = records.indexWhere((r) => r.id == id);
    if (index != -1) {
      records[index] = records[index].copyWith(isFavourite: !records[index].isFavourite);
      await _saveRecords(records);
    }
  }

  Future<void> deleteRecord(String id) async {
    final records = await _loadRecords();
    records.removeWhere((r) => r.id == id);
    await _saveRecords(records);
  }

  Future<void> clearHistory({bool keepFavourites = true}) async {
    if (keepFavourites) {
      final records = await _loadRecords();
      records.removeWhere((r) => !r.isFavourite);
      await _saveRecords(records);
    } else {
      final prefs = await _preferences;
      await prefs.remove(_storageKey);
    }
  }
}
