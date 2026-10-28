import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubbike/core/modelos/rol_usuario.dart';
import 'package:ubbike/features/admin/presentation/vista_gestion_bicicleteros.dart';
import 'package:ubbike/features/notificaciones/presentation/pantalla_notificaciones.dart';
import 'package:ubbike/shared/modelos/notificacion_app.dart';

import 'soporte_api_falsa.dart';

Map<String, dynamic> _notificacion(
  String id, {
  String titulo = 'Guardia en camino',
  String tipo = 'SOLICITUD_GUARDIA',
  bool leida = false,
  Duration hace = const Duration(minutes: 5),
}) =>
    {
      'id': id,
      'titulo': titulo,
      'mensaje': 'El guardia va en camino a Biblioteca.',
      'tipo': tipo,
      'leida': leida,
      'creadaEn': DateTime.now().subtract(hace).toUtc().toIso8601String(),
    };

class _Lanzador extends StatefulWidget {
  const _Lanzador();

  @override
  State<_Lanzador> createState() => _LanzadorState();
}

class _LanzadorState extends State<_Lanzador> {
  String resultado = 'sin abrir';

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(resultado),
        ElevatedButton(
          onPressed: () async {
            final abierta = await Navigator.of(context).push<NotificacionApp>(
              MaterialPageRoute(builder: (_) => const PantallaNotificaciones()),
            );
            setState(() => resultado = 'abierta ${abierta?.id}');
          },
          child: const Text('ver avisos'),
        ),
      ],
    );
  }
}

Map<String, dynamic> _rack(String id, String nombre, {int ocupados = 3}) => {
      'id': id,
      'nombre': nombre,
      'ubicacion': 'Campus Concepción',
      'capacidad': 20,
      'ocupados': ocupados,
      'cuposDisponibles': 20 - ocupados,
      'porcentajeUso': ocupados * 5,
    };

void main() {
  group('notificaciones', () {
    Future<ApiFalsa> abrir(WidgetTester tester, Object? respuesta,
        {Map<String, Object?> extra = const {}}) async {
      final api = await montarConApi(
        tester,
        const _Lanzador(),
        rutas: {'GET /notificaciones': respuesta, ...extra},
      );
      await tocarTexto(tester, 'ver avisos');
      return api;
    }

    testWidgets('sin avisos lo indica', (tester) async {
      await abrir(tester, {'notificaciones': [], 'nextCursor': null});

      expect(find.text('Sin notificaciones'), findsOneWidget);
    });

    testWidgets('sin conexión permite actualizar', (tester) async {
      final api = await abrir(tester, const RespuestaFalsa(503));

      expect(find.text('No se pudo actualizar. Revisa tu conexión.'),
          findsOneWidget);

      api.responder('GET /notificaciones', {
        'notificaciones': [_notificacion('n1')],
        'nextCursor': null,
      });
      await tocarTexto(tester, 'Actualizar');

      expect(find.text('Guardia en camino'), findsOneWidget);
    });

    testWidgets('ordena primero las no leídas y muestra la antigüedad',
        (tester) async {
      await abrir(tester, {
        'notificaciones': [
          _notificacion('n1',
              titulo: 'Cuenta activada', tipo: 'CUENTA', leida: true),
          _notificacion('n2',
              titulo: 'Incidencia actualizada',
              tipo: 'INCIDENCIA',
              hace: const Duration(hours: 3)),
        ],
        'nextCursor': null,
      });

      final y1 = tester.getTopLeft(find.text('Incidencia actualizada')).dy;
      final y2 = tester.getTopLeft(find.text('Cuenta activada')).dy;
      expect(y1, lessThan(y2));
      expect(find.text('Hace 3 horas'), findsOneWidget);
      expect(find.text('Hace 5 min'), findsOneWidget);
    });

    testWidgets('carga más páginas con el cursor', (tester) async {
      final api = await abrir(
        tester,
        (dynamic peticion) => peticion.url.queryParameters['cursor'] == 'c2'
            ? {
                'notificaciones': [_notificacion('n2', titulo: 'Segunda')],
                'nextCursor': null,
              }
            : {
                'notificaciones': [_notificacion('n1', titulo: 'Primera')],
                'nextCursor': 'c2',
              },
      );

      await tocarTexto(tester, 'Cargar más notificaciones');

      expect(find.text('Primera'), findsOneWidget);
      expect(find.text('Segunda'), findsOneWidget);
      expect(find.text('Cargar más notificaciones'), findsNothing);
      expect(
        api.peticiones.last.url.queryParameters['cursor'],
        'c2',
      );
    });

    testWidgets('abrir un aviso lo marca leído y lo devuelve', (tester) async {
      final api = await abrir(
        tester,
        {
          'notificaciones': [_notificacion('n1')],
          'nextCursor': null,
        },
        extra: {'PATCH /notificaciones/n1/leida': const {}},
      );

      await tocarTexto(tester, 'Guardia en camino');

      expect(api.llamadas, contains('PATCH /notificaciones/n1/leida'));
      expect(find.text('abierta n1'), findsOneWidget);
    });

    testWidgets('un aviso ya leído no se vuelve a marcar', (tester) async {
      final api = await abrir(tester, {
        'notificaciones': [_notificacion('n1', leida: true)],
        'nextCursor': null,
      });

      await tocarTexto(tester, 'Guardia en camino');

      expect(api.llamadas, isNot(contains('PATCH /notificaciones/n1/leida')));
      expect(find.text('abierta n1'), findsOneWidget);
    });
  });

  group('gestión de bicicleteros', () {
    Future<ApiFalsa> montar(WidgetTester tester, Object? respuesta,
            {Map<String, Object?> extra = const {}}) =>
        montarConApi(
          tester,
          const VistaGestionBicicleteros(),
          rol: RolUsuario.administrador,
          rutas: {'GET /bicicleteros': respuesta, ...extra},
        );

    testWidgets('lista los bicicleteros habilitados', (tester) async {
      await montar(tester, {
        'bicicleteros': [
          _rack('r1', 'Biblioteca Central'),
          _rack('r2', 'Facultad de Ingeniería'),
        ],
      });

      expect(find.text('Bicicleteros'), findsOneWidget);
      expect(find.text('Biblioteca Central'), findsOneWidget);
      expect(find.text('Facultad de Ingeniería'), findsOneWidget);
    });

    testWidgets('sin bicicleteros muestra el estado vacío', (tester) async {
      await montar(tester, {'bicicleteros': []});

      expect(find.text('Sin bicicleteros'), findsOneWidget);
    });

    testWidgets('si falla la carga permite reintentar', (tester) async {
      final api = await montar(tester, const RespuestaFalsa(500));

      expect(find.text('No se pudieron cargar bicicleteros'), findsOneWidget);

      api.responder('GET /bicicleteros', {
        'bicicleteros': [_rack('r1', 'Biblioteca Central')],
      });
      await tocarTexto(tester, 'No se pudieron cargar bicicleteros');

      expect(find.text('Biblioteca Central'), findsOneWidget);
    });

    testWidgets('eliminar pide confirmación y desactiva el bicicletero',
        (tester) async {
      final api = await montar(
        tester,
        {
          'bicicleteros': [_rack('r1', 'Biblioteca Central', ocupados: 0)],
        },
        extra: {'DELETE /bicicleteros/r1': const {}},
      );

      await tocarTexto(tester, 'Gestionar bicicletero');
      await tocarTexto(tester, 'Eliminar');
      expect(find.text('Eliminar bicicletero'), findsOneWidget);

      await tester.tap(find.byKey(const Key('eliminar-confirmar')));
      await tester.pumpAndSettle();

      expect(api.llamadas, contains('DELETE /bicicleteros/r1'));
      expect(find.text('Bicicletero eliminado'), findsOneWidget);
    });

    testWidgets('no elimina un bicicletero con bicicletas dentro',
        (tester) async {
      await montar(
        tester,
        {
          'bicicleteros': [_rack('r1', 'Biblioteca Central')],
        },
        extra: {
          'DELETE /bicicleteros/r1': const RespuestaFalsa(409, {
            'message': 'El bicicletero todavía tiene bicicletas dentro',
          }),
        },
      );

      await tocarTexto(tester, 'Gestionar bicicletero');
      await tocarTexto(tester, 'Eliminar');
      await tester.tap(find.byKey(const Key('eliminar-confirmar')));
      await tester.pumpAndSettle();

      expect(find.text('El bicicletero todavía tiene bicicletas dentro'),
          findsOneWidget);
    });
  });
}
