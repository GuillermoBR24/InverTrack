import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'market_service.dart';
import 'notification_service.dart';

class AlertBackgroundService {
  static bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static Future<void> initialize() async {
    if (!_supported) return;

    await FlutterBackgroundService().configure(
      androidConfiguration: AndroidConfiguration(
        onStart: _onStart,
        autoStart: true,
        isForegroundMode: true,
        notificationChannelId: 'bg_service',
        initialNotificationTitle: 'InverTrack',
        initialNotificationContent: 'Monitorizando alertas...',
        foregroundServiceNotificationId: 999,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: _onStart,
      ),
    );
  }

  static Future<void> startService() async {
    if (!_supported) return;
    final service = FlutterBackgroundService();
    final isRunning = await service.isRunning();
    if (!isRunning) await service.startService();
  }

  static Future<void> stopService() async {
    if (!_supported) return;
    FlutterBackgroundService().invoke('stop');
  }
}

@pragma('vm:entry-point')
void _onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  await NotificationService.init();

  await Supabase.initialize(
    url: 'TU_SUPABASE_URL',
    anonKey: 'TU_SUPABASE_ANON_KEY',
  );

  service.on('stop').listen((_) => service.stopSelf());

  Timer.periodic(const Duration(seconds: 60), (_) async {
    await _checkAlerts();
  });

  await _checkAlerts();
}

Future<void> _checkAlerts() async {
  try {
    final supabase = Supabase.instance.client;
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;

    final alerts = await supabase
        .from('price_alerts')
        .select()
        .eq('user_id', uid);

    if (alerts.isEmpty) return;

    final Map<String, List<Map<String, dynamic>>> bySymbol = {};
    for (final alert in alerts) {
      bySymbol
          .putIfAbsent(alert['symbol'] as String, () => [])
          .add(alert);
    }

    for (final entry in bySymbol.entries) {
      final symbol = entry.key;
      final aList  = entry.value;
      final type   = aList.first['type'] as String;

      try {
        final live = await MarketService.fetchAsset(symbol, type);
        if (live == null) continue;

        final currentPrice = (live['price'] as num?)?.toDouble() ?? 0;
        if (currentPrice <= 0) continue;

        for (final alert in aList) {
          final targetPrice = (alert['target_price'] as num).toDouble();
          final condition   = alert['condition'] as String;
          final alertId     = alert['id'] as String;

          final triggered = condition == 'above'
              ? currentPrice >= targetPrice
              : currentPrice <= targetPrice;

          if (triggered) {
            await NotificationService.showPriceAlert(
              id: alertId.hashCode,
              symbol: symbol,
              name: alert['name'] as String,
              condition: condition,
              targetPrice: targetPrice,
              currentPrice: currentPrice,
            );

            await supabase
                .from('price_alerts')
                .delete()
                .eq('id', alertId);
          }
        }
      } catch (_) {
        continue;
      }
    }
  } catch (_) {}
}