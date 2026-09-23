import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:ubbike/shared/utils/refresco_coalescido.dart';

void main() {
  setUp(() {
    RefrescoCoalescido.aplicacionActiva = true;
    RefrescoCoalescido.socketConectado = true;
  });

  group('RefrescoCoalescido en segundo plano', () {
    test('no consulta mientras la app no esta visible', () async {
      var ejecuciones = 0;

      final refresco = RefrescoCoalescido(
        alRefrescar: () async => ejecuciones++,
        intervaloRespaldo: const Duration(milliseconds: 30),
      )..iniciarRespaldo();

      RefrescoCoalescido.aplicacionActiva = false;
      await Future<void>.delayed(const Duration(milliseconds: 120));

      expect(ejecuciones, 0);
      refresco.detener();
    });

    test('recupera de inmediato al volver la app, sin esperar el respaldo',
        () async {
      var ejecuciones = 0;

      final refresco = RefrescoCoalescido(
        alRefrescar: () async => ejecuciones++,
        intervaloRespaldo: const Duration(seconds: 30),
      )..iniciarRespaldo();

      RefrescoCoalescido.aplicacionActiva = false;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(ejecuciones, 0);

      RefrescoCoalescido.aplicacionActiva = true;
      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(ejecuciones, greaterThanOrEqualTo(0));
      refresco.detener();
    });

    test('detener lo saca del registro: no revive al reactivarse la app',
        () async {
      var ejecuciones = 0;

      final refresco = RefrescoCoalescido(
        alRefrescar: () async => ejecuciones++,
        intervaloRespaldo: const Duration(milliseconds: 20),
      )..iniciarRespaldo();

      RefrescoCoalescido.aplicacionActiva = false;
      refresco.detener();
      RefrescoCoalescido.aplicacionActiva = true;
      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(ejecuciones, 0);
    });
  });

  group('RefrescoCoalescido ante fallos', () {
    test('reintenta rapido tras un fallo en vez de esperar el respaldo largo',
        () async {
      var ejecuciones = 0;

      final refresco = RefrescoCoalescido(
        alRefrescar: () async => ejecuciones++,
        intervaloRespaldo: const Duration(seconds: 30),
        detectarFallo: () => true,
      );

      await refresco.solicitar();
      expect(ejecuciones, 1);

      await Future<void>.delayed(const Duration(milliseconds: 2400));

      expect(ejecuciones, greaterThanOrEqualTo(2));
      refresco.detener();
    });

    test('vuelve al respaldo largo cuando el refresco sale bien', () async {
      var fallando = true;
      var ejecuciones = 0;

      final refresco = RefrescoCoalescido(
        alRefrescar: () async => ejecuciones++,
        intervaloRespaldo: const Duration(seconds: 30),
        detectarFallo: () => fallando,
      );

      await refresco.solicitar();
      fallando = false;
      await refresco.solicitar();
      final tras2 = ejecuciones;

      await Future<void>.delayed(const Duration(milliseconds: 2400));

      expect(ejecuciones, tras2);
      refresco.detener();
    });
  });

  group('RefrescoCoalescido', () {
    test('no lanza un refresco nuevo mientras otro sigue en vuelo', () async {
      var enCurso = 0;
      var maximoSimultaneo = 0;
      final completer = Completer<void>();

      final refresco = RefrescoCoalescido(
        alRefrescar: () async {
          enCurso += 1;
          maximoSimultaneo =
              enCurso > maximoSimultaneo ? enCurso : maximoSimultaneo;
          await completer.future;
          enCurso -= 1;
        },
      );

      final primera = refresco.solicitar();
      await refresco.solicitar();
      await refresco.solicitar();

      expect(refresco.enVuelo, isTrue);
      expect(maximoSimultaneo, 1);

      completer.complete();
      await primera;
      refresco.detener();

      expect(maximoSimultaneo, 1);
    });

    test('agrupa las solicitudes acumuladas en un solo refresco posterior',
        () async {
      var ejecuciones = 0;
      var permitir = Completer<void>();

      final refresco = RefrescoCoalescido(
        alRefrescar: () async {
          ejecuciones += 1;
          await permitir.future;
        },
      );

      final primera = refresco.solicitar();
      await refresco.solicitar();
      await refresco.solicitar();
      await refresco.solicitar();

      expect(ejecuciones, 1);

      final anterior = permitir;
      permitir = Completer<void>()..complete();
      anterior.complete();
      await primera;
      await Future<void>.delayed(Duration.zero);

      expect(ejecuciones, 2);
      refresco.detener();
    });

    test('el respaldo se reprograma desde el fin del refresco anterior',
        () async {
      var ejecuciones = 0;

      final refresco = RefrescoCoalescido(
        alRefrescar: () async {
          ejecuciones += 1;
          await Future<void>.delayed(const Duration(milliseconds: 60));
        },
        intervaloRespaldo: const Duration(milliseconds: 40),
      )..iniciarRespaldo();

      await Future<void>.delayed(const Duration(milliseconds: 150));
      refresco.detener();

      expect(ejecuciones, lessThanOrEqualTo(2));
      expect(ejecuciones, greaterThanOrEqualTo(1));
    });

    test('detener cancela el respaldo y rechaza solicitudes nuevas', () async {
      var ejecuciones = 0;

      final refresco = RefrescoCoalescido(
        alRefrescar: () async {
          ejecuciones += 1;
        },
        intervaloRespaldo: const Duration(milliseconds: 20),
      )..iniciarRespaldo();

      refresco.detener();
      await refresco.solicitar();
      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(ejecuciones, 0);
    });
  });
}
