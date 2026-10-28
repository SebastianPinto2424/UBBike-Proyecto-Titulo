import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:ubbike/core/servicios/registro_dispositivo_push.dart';

@pragma('vm:entry-point')
Future<void> manejarMensajeSegundoPlano(RemoteMessage mensaje) async {}

class FcmServicio {
  FcmServicio._();
  static final FcmServicio instancia = FcmServicio._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _inicializado = false;
  String? _ultimoToken;
  StreamSubscription<String>? _renovacionToken;

  final ValueNotifier<Map<String, dynamic>?> notificacionTocada =
      ValueNotifier(null);

  static const AndroidNotificationChannel _canal = AndroidNotificationChannel(
    'ubbike_notificaciones',
    'Notificaciones UBBike',
    description: 'Solicitudes de guardia e incidencias',
    importance: Importance.high,
  );

  Future<void> inicializar() async {
    if (_inicializado) {
      return;
    }
    _inicializado = true;

    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: (respuesta) {
        final payload = respuesta.payload;
        if (payload != null && payload.isNotEmpty) {
          notificacionTocada.value = {'tipo': payload};
        }
      },
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_canal);

    await FirebaseMessaging.instance.requestPermission();

    FirebaseMessaging.onBackgroundMessage(manejarMensajeSegundoPlano);
    FirebaseMessaging.onMessage.listen(_mostrarEnPrimerPlano);
    FirebaseMessaging.onMessageOpenedApp.listen((mensaje) {
      notificacionTocada.value = mensaje.data;
    });

    final inicial = await FirebaseMessaging.instance.getInitialMessage();
    if (inicial != null) {
      notificacionTocada.value = inicial.data;
    }
  }

  void _mostrarEnPrimerPlano(RemoteMessage mensaje) {
    final notificacion = mensaje.notification;
    if (notificacion == null) {
      return;
    }

    _plugin.show(
      notificacion.hashCode,
      notificacion.title,
      notificacion.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _canal.id,
          _canal.name,
          channelDescription: _canal.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: mensaje.data['tipo'] as String?,
    );
  }

  Future<void> registrarToken(RegistroDispositivoPush repositorio) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) {
        return;
      }
      _ultimoToken = token;
      await repositorio.registrarDispositivo(token);

      await _renovacionToken?.cancel();
      _renovacionToken =
          FirebaseMessaging.instance.onTokenRefresh.listen((nuevoToken) async {
        _ultimoToken = nuevoToken;
        try {
          await repositorio.registrarDispositivo(nuevoToken);
        } catch (_) {}
      });
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[fcm] No se pudo registrar el token: $error');
      }
    }
  }

  Future<void> eliminarToken(RegistroDispositivoPush repositorio) async {
    try {
      final token = _ultimoToken ?? await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await repositorio.eliminarDispositivo(token);
      }
    } catch (_) {}
  }
}
