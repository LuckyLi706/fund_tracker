import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/fund_model.dart';
import '../services/fund_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FundProvider with ChangeNotifier {
  final FundService _service = FundService();
  final List<String> _codes = [];
  final Map<String, FundEstimate> _estimates = {};
  bool _isLoading = false;
  Timer? _timer;
  FundDataSource _currentSource = FundDataSource.tiantian;
  
  SharedPreferences? _prefs;
  bool _isStorageReady = false;
  
  static const String _storageKey = 'tracked_fund_codes';
  static const String _sourceKey = 'data_source_index';

  FundProvider({SharedPreferences? prefs}) : _prefs = prefs {
    _isStorageReady = _prefs != null;
    if (_isStorageReady) {
      _loadFromInitialPrefs();
    }
    _initTimer();
  }

  void _loadFromInitialPrefs() {
    final savedCodes = _prefs!.getStringList(_storageKey) ?? [];
    _codes.clear();
    _codes.addAll(savedCodes);
    
    final sourceIndex = _prefs!.getInt(_sourceKey) ?? 0;
    if (sourceIndex < FundDataSource.values.length) {
      _currentSource = FundDataSource.values[sourceIndex];
    }
  }

  void _initTimer() {
    // Initial fetch
    refreshAll();
    
    // Setup periodic timer
    _timer = Timer.periodic(const Duration(seconds: 10), (timer) {
      refreshAll();
    });
  }

  bool get isStorageReady => _isStorageReady;

  String? _lastStorageError;
  String? get lastStorageError => _lastStorageError;

  Future<bool> _saveToPrefs() async {
    try {
      if (_prefs == null) {
        _prefs = await SharedPreferences.getInstance();
        _isStorageReady = true;
        _lastStorageError = null;
        notifyListeners();
      }
      
      if (_prefs == null) {
        _lastStorageError = "无法获取 SharedPreferences 实例";
        return false;
      }

      // 使用副本进行保存，防止并发修改
      final codesToSave = List<String>.from(_codes);
      final success1 = await _prefs!.setStringList(_storageKey, codesToSave);
      final success2 = await _prefs!.setInt(_sourceKey, _currentSource.index);
      
      final success = success1 && success2;
      
      if (!success && _isStorageReady) {
        _isStorageReady = false;
        _lastStorageError = "底层写入操作返回 false (可能空间不足或文件被锁定)";
        notifyListeners();
      } else if (success) {
        if (!_isStorageReady) {
          _isStorageReady = true;
          notifyListeners();
        }
        _lastStorageError = null;
      }
      
      return success;
    } catch (e) {
      _lastStorageError = e.toString();
      debugPrint('SharedPreferences Error: $e');
      if (_isStorageReady) {
        _isStorageReady = false;
        notifyListeners();
      }
      return false;
    }
  }

  List<String> get codes => List<String>.from(_codes);
  FundEstimate? getEstimate(String code) => _estimates[code];
  bool get isLoading => _isLoading;
  FundDataSource get currentSource => _currentSource;

  void setDataSource(FundDataSource source) {
    if (_currentSource != source) {
      _currentSource = source;
      notifyListeners(); 
      _saveToPrefs();
      refreshAll();
    }
  }

  Future<void> refreshAll() async {
    if (_codes.isEmpty) {
      if (_isLoading) {
        _isLoading = false;
        notifyListeners();
      }
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final currentCodes = List<String>.from(_codes);
      final futures = currentCodes.map((code) => _service.fetchEstimate(code, _currentSource));
      final results = await Future.wait(futures);

      for (int i = 0; i < currentCodes.length; i++) {
        final estimate = results[i];
        if (estimate != null) {
          _estimates[currentCodes[i]] = estimate;
        }
      }
    } catch (e) {
      print('Error during refreshAll: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void addFund(String code, {Function(bool)? onResult}) async {
    final cleanCode = code.trim();
    if (cleanCode.isEmpty) return;
    
    if (!_codes.contains(cleanCode)) {
      _codes.add(cleanCode);
      notifyListeners(); 
      final success = await _saveToPrefs();
      if (onResult != null) onResult(success);
      
      _fetchSingleEstimate(cleanCode);
    }
  }

  Future<void> _fetchSingleEstimate(String code) async {
    try {
      final estimate = await _service.fetchEstimate(code, _currentSource);
      if (estimate != null) {
        _estimates[code] = estimate;
      }
    } catch (e) {
      print('Error fetching estimate for $code: $e');
    } finally {
      notifyListeners();
    }
  }

  void removeFund(String code) {
    if (_codes.contains(code)) {
      _codes.remove(code);
      _estimates.remove(code);
      notifyListeners(); 
      _saveToPrefs();
    }
  }

  Future<void> reconnectStorage() async {
    await _saveToPrefs();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
