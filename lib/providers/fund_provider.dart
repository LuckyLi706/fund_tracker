import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/fund_model.dart';
import '../services/fund_service.dart';

class FundProvider with ChangeNotifier {
  final FundService _service = FundService();
  final List<String> _codes = ['161725', '000001'];
  Map<String, FundEstimate> _estimates = {};
  bool _isLoading = false;
  Timer? _timer;
  
  // Current data source
  FundDataSource _currentSource = FundDataSource.tiantian;

  FundProvider() {
    refreshAll();
    _timer = Timer.periodic(const Duration(seconds: 10), (timer) {
      refreshAll();
    });
  }

  List<FundEstimate> get funds => _estimates.values.toList();
  bool get isLoading => _isLoading;
  FundDataSource get currentSource => _currentSource;

  void setDataSource(FundDataSource source) {
    if (_currentSource != source) {
      _currentSource = source;
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
      final estimate = await _service.fetchEstimate(code, _currentSource);
      if (estimate != null) {
        _estimates[code] = estimate;
        notifyListeners();
      }
    }
  }

  void removeFund(String code) {
    _codes.remove(code);
    _estimates.remove(code);
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
