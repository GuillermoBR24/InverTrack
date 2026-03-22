import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static Future<void> init() async {
    if (!_supported || _initialized) return;

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(settings);

    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          'price_alerts',
          'Alertas de precio',
          description: 'Notificaciones cuando un activo alcanza tu precio objetivo',
          importance: Importance.high,
          playSound: true,
        ));

    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          'bg_service',
          'Servicio de alertas',
          description: 'Monitorización de precios en segundo plano',
          importance: Importance.low,
        ));

    _initialized = true;
  }

  static Future<void> showPriceAlert({
    required int id,
    required String symbol,
    required String name,
    required String condition,
    required double targetPrice,
    required double currentPrice,
  }) async {
    if (!_supported) return;

    final conditionText = condition == 'above' ? 'superado' : 'bajado de';

    await _plugin.show(
      id,
      '🔔 Alerta: $symbol',
      '$name ha $conditionText \$${targetPrice.toStringAsFixed(2)}',
      NotificationDetails(
        android: AndroidNotificationDetails(
          'price_alerts',
          'Alertas de precio',
          channelDescription: 'Alerta de precio activada',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          styleInformation: BigTextStyleInformation(
            '$name ha $conditionText \$${targetPrice.toStringAsFixed(2)}. '
            'Precio actual: \$${currentPrice.toStringAsFixed(2)}',
          ),
        ),
      ),
    );
  }
}