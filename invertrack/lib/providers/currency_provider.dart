import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/market_service.dart';

class CurrencyProvider extends ChangeNotifier {
  final supabase = Supabase.instance.client;

  String _currency = 'USD';
  double _rate     = 1.0;
  bool   _loading  = false;

  String get currency => _currency;
  double get rate     => _rate;
  bool   get loading  => _loading;

  static const Map<String, String> symbols = {
    'USD': '\$',
    'EUR': '€',
  };

  String get symbol => symbols[_currency] ?? '\$';

  // Convierte un valor en USD a la moneda seleccionada
  double convert(double usdValue) => usdValue * _rate;

  // Formatea ya convertido con símbolo
  String format(double usdValue, {int decimals = 2}) {
    final converted = convert(usdValue);
    return '$symbol${converted.toStringAsFixed(decimals)}';
  }

  // Carga moneda desde Supabase y obtiene tipo de cambio
  Future<void> load() async {
    try {
      _loading = true;
      notifyListeners();

      final uid  = supabase.auth.currentUser?.id;
      if (uid == null) return;

      final data = await supabase
          .from('profiles')
          .select('currency')
          .eq('id', uid)
          .maybeSingle();

      final savedCurrency = data?['currency'] as String? ?? 'USD';
      await _setCurrencyInternal(savedCurrency, saveToDb: false);
    } catch (_) {
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // Cambia moneda, actualiza tipo de cambio y guarda en Supabase
  Future<void> setCurrency(String currency) async {
    await _setCurrencyInternal(currency, saveToDb: true);
  }

  Future<void> _setCurrencyInternal(String currency,
      {required bool saveToDb}) async {
    _currency = currency;

    // Obtener tipo de cambio desde la API
    if (currency == 'USD') {
      _rate = 1.0;
    } else {
      _rate = await MarketService.fetchExchangeRate(currency) ?? 1.0;
    }

    if (saveToDb) {
      try {
        final uid = supabase.auth.currentUser?.id;
        if (uid != null) {
          await supabase.from('profiles').update({
            'currency': currency,
          }).eq('id', uid);
        }
      } catch (_) {}
    }

    notifyListeners();
  }

  /// Resetea a USD sin tocar la BD (para cuando se cierra sesión)
  void reset() {
    _currency = 'USD';
    _rate     = 1.0;
    notifyListeners();
  }
}