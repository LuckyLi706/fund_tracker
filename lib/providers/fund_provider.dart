import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/fund_model.dart';
import '../services/fund_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FundProvider with ChangeNotifier {
  final FundService _service = FundService();
  List<String> _codes = [];
  static const String _storageKey = 'tracked_fund_codes';
  static const String _sourceKey = 'data_source_index';
  Map<String, FundEstimate> _estimates = {};
  bool _isLoading = false;
  Timer? _timer;
  
  // Current data source
  FundDataSource _currentSource = FundDataSource.tiantian;

  FundProvider() {
    _init();
  }

  Future<void> _init() async {
    await _loadFromPrefs();
    refreshAll();
    _timer = Timer.periodic(const Duration(seconds: 10), (timer) {
      refreshAll();
    });
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _codes = prefs.getStringList(_storageKey) ?? [];
    
    final sourceIndex = prefs.getInt(_sourceKey) ?? 0;
    if (sourceIndex < FundDataSource.values.length) {
      _currentSource = FundDataSource.values[sourceIndex];
    }
    
    notifyListeners();
  }

  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_storageKey, _codes);
    await prefs.setInt(_sourceKey, _currentSource.index);
  }

  List<FundEstimate> get funds => _estimates.values.toList();
  bool get isLoading => _isLoading;
  FundDataSource get currentSource => _currentSource;

  void setDataSource(FundDataSource source) async {
    if (_currentSource != source) {
      _currentSource = source;
      await _saveToPrefs();
      refreshAll();
      notifyListeners();
    }
  }

  Future<void> refreshAll() async {
    print('Refreshing fund data from ${_currentSource.label} at ${DateTime.now()}');
    _isLoading = true;
    notifyListeners();

    for (var code in _codes) {
      final estimate = await _service.fetchEstimate(code, _currentSource);
      if (estimate != null) {
        _estimates[code] = estimate;
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  void addFund(String code) async {
    if (!_codes.contains(code)) {
      _codes.add(code);
      await _saveToPrefs();
      final estimate = await _service.fetchEstimate(code, _currentSource);
      if (estimate != null) {
        _estimates[code] = estimate;
        notifyListeners();
      }
    }
  }

  void removeFund(String code) async {
    _codes.remove(code);
    _estimates.remove(code);
    await _saveToPrefs();
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
