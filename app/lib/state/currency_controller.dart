import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/config.dart';

class CurrencyController extends ChangeNotifier {
  CurrencyController() {
    // Controller yaratilishi bilan internetdan yangi kursni oladi
    fetchLiveRate();
  }

  double _usdRate = 12023.0; // Standart boshlang'ich kurs
  double _cbuRate = 12023.0; // Markaziy bank kursi
  String _cbuDiff = '0.00';
  String _cbuDate = '';
  DateTime? _lastUpdated;
  bool _isLoading = false;
  bool _isCustom = false;
  String? _errorMessage;

  double get usdRate => _usdRate;
  double get cbuRate => _cbuRate;
  String get cbuDiff => _cbuDiff;
  String get cbuDate => _cbuDate;
  DateTime? get lastUpdated => _lastUpdated;
  bool get isLoading => _isLoading;
  bool get isCustom => _isCustom;
  String? get errorMessage => _errorMessage;

  /// So'mdan AQSH dollariga hisoblash
  double toUsd(double uzs) {
    if (_usdRate <= 0) return 0.0;
    return uzs / _usdRate;
  }

  /// AQSH dollaridan so'mga hisoblash
  double toUzs(double usd) {
    return usd * _usdRate;
  }

  /// Do'kon o'zining tijoriy kursini belgilashi (masalan $1 = 12 100 so'm)
  void setCustomRate(double customRate) {
    if (customRate <= 0) return;
    _usdRate = customRate;
    _isCustom = true;
    _lastUpdated = DateTime.now();
    notifyListeners();
  }

  /// Do'kon kursini yana Markaziy Bank kursiga tenglashtirish
  void resetToCbuRate() {
    _usdRate = _cbuRate;
    _isCustom = false;
    notifyListeners();
  }

  /// Markaziy Bankdan yoki server keshidan oxirgi kursni yangilash
  Future<void> fetchLiveRate() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    bool success = false;

    // 1. Birinchi navbatda backend server orqali tekshirish
    try {
      final backendUrl = Uri.parse('${AppConfig.apiBaseUrl}/finance/currency-rate');
      final resp = await http.get(backendUrl).timeout(const Duration(seconds: 4));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final rateVal = (data['rate'] as num?)?.toDouble();
        if (rateVal != null && rateVal > 0) {
          _cbuRate = rateVal;
          _cbuDiff = (data['diff'] ?? '').toString();
          _cbuDate = (data['date'] ?? '').toString();
          if (!_isCustom) {
            _usdRate = rateVal;
          }
          _lastUpdated = DateTime.now();
          success = true;
        }
      }
    } catch (_) {
      // Backend mavjud bo'lmasa yoki timeout bo'lsa, to'g'ridan-to'g'ri CBU ochiq API sidan olamiz
    }

    // 2. Agar backend orqali olinmagan bo'lsa, CBU ochiq API sidan to'g'ridan-to'g'ri olish
    if (!success) {
      try {
        final cbuUrl = Uri.parse('https://cbu.uz/uz/arkhiv-kursov-valyut/json/');
        final resp = await http.get(cbuUrl).timeout(const Duration(seconds: 5));
        if (resp.statusCode == 200) {
          final list = jsonDecode(resp.body) as List<dynamic>;
          for (final item in list) {
            if (item is Map<String, dynamic> && item['Ccy'] == 'USD') {
              final rateVal = double.tryParse((item['Rate'] ?? '').toString()) ?? 12023.0;
              _cbuRate = rateVal;
              _cbuDiff = (item['Diff'] ?? '0.00').toString();
              _cbuDate = (item['Date'] ?? '').toString();
              if (!_isCustom) {
                _usdRate = rateVal;
              }
              _lastUpdated = DateTime.now();
              success = true;
              break;
            }
          }
        }
      } catch (e) {
        _errorMessage = 'Internetdan kursni yangilab bo‘lmadi';
      }
    }

    _isLoading = false;
    notifyListeners();
  }
}

