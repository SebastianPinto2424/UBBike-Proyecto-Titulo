import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:ubbike/core/modelos/rol_usuario.dart';
import 'package:ubbike/core/providers/sesion_provider.dart';
import 'package:ubbike/core/providers/versiones_provider.dart';
import 'package:ubbike/features/acceso/presentation/selector_bicicletero_guardia.dart';
import 'package:ubbike/features/acceso/presentation/hoja_cancelar_solicitud.dart';
import 'package:ubbike/features/acceso/presentation/vista_alertas_guardia.dart';
import 'package:ubbike/features/acceso/presentation/vista_inicio_guardia.dart';
import 'package:ubbike/features/acceso/presentation/vista_solicitar_guardia.dart';
import 'package:ubbike/features/acceso/presentation/vista_solicitudes_central.dart';

import 'soporte_api_falsa.dart';
import 'package:ubbike/core/servicios/excepcion_api.dart';

Map<String, dynamic> _rack(String id, String nombre, {int cupos = 12}) => {
      'id': id,
      'nombre': nombre,
      'ubicacion': 'Campus',
      'capacidad': 20,
      'ocupados': 20 - cupos,
      'cuposDisponibles': cupos,
      'porcentajeUso': (20 - cupos) * 5,
    };

Map<String, dynamic> _solicitud({
  String id = 's1',
  String estado = 'NOTIFICADA',
  String bicicletero = 'Biblioteca Central',
  String solicitante = 'Ana Rojas',
  bool puedeNotificar = true,
}) =>
    {
      'id': id,
      'tipo': 'REQUIERE_SERVICIO',
      'estado': estado,
      'mensaje': 'Necesito retirar mi bicicleta',
      'bicicletero': {'id': 'r1', 'nombre': bicicletero},
      'solicitante': {
        'id': 'u1',
        'nombre': solicitante,
        'correo': 'ana@alumnos.ubiobio.cl',
        'rol': 'ESTUDIANTE',
      },
      'guardiaAsignado': {'id': 'g1', 'nombre': 'Pedro Soto', 'rol': 'GUARDIA'},
      'guardiasAsignados': const [],
      'creadaEn': '2026-10-20T13:30:00.000Z',
      'notificadaGuardiaEn': '2026-10-20T13:30:00.000Z',
      'notificacionesGuardia': 1,
      'puedeNotificarGuardia': puedeNotificar,
      'segundosParaNotificarGuardia': puedeNotificar ? 0 : 40,
    };

Future<void> _recargarSolicitudes(WidgetTester tester, Type vista) async {
  ProviderScope.containerOf(tester.element(find.byType(vista)))
      .read(solicitudesGuardiaVersionProvider.notifier)
      .state++;
  await tester.pumpAndSettle();
}

Iterable<Map<String, String>> _consultas(ApiFalsa api) => api.peticiones
    .where((p) => p.method == 'GET' && p.url.path == '/solicitudes-guardia')
    .map((p) => p.url.queryParameters);

void main() {
  group('usuario solicita atención', () {
    Future<ApiFalsa> montar(WidgetTester tester, Object? solicitudes,
            {Map<String, Object?> extra = const {}}) =>
        montarConApi(
          tester,
          const VistaSolicitarGuardia(),
          rutas: {
            'GET /solicitudes-guardia': solicitudes,
            'GET /bicicleteros': {
              'bicicleteros': [_rack('r1', 'Biblioteca Central')],
            },
            ...extra,
          },
        );

    testWidgets('sin solicitudes lo indica', (tester) async {
      final api = await montar(tester, {'solicitudes': []});

      expect(find.text('Atención del guardia'), findsOneWidget);
      expect(find.text('Sin solicitudes recientes'), findsOneWidget);
      expect(_consultas(api).map((consulta) => consulta['alcance']),
          everyElement('PROPIO'));
    });

    testWidgets('el guardia no pide atención en el bicicletero que gestiona',
        (tester) async {
      await montarConApi(
        tester,
        const VistaSolicitarGuardia(),
        rol: RolUsuario.guardia,
        rutas: {
          'GET /solicitudes-guardia': {'solicitudes': []},
          'GET /bicicleteros': {
            'bicicleteros': [
              {
                ..._rack('r1', 'Rack propio'),
                'guardiaActivo': {'id': 'yo', 'nombre': 'Persona de Prueba'},
              },
              _rack('r2', 'Rack de otro sector'),
            ],
          },
        },
      );
      await ProviderScope.containerOf(
        tester.element(find.byType(VistaSolicitarGuardia)),
      ).read(sesionProvider.future);

      await tocarTexto(tester, 'Solicitar atención');

      expect(find.text('Rack de otro sector'), findsWidgets);
      expect(find.text('Rack propio'), findsNothing);
    });

    testWidgets('si los bicicleteros no cargaron, al tocar reintenta',
        (tester) async {
      var intentos = 0;
      await montar(
        tester,
        {'solicitudes': []},
        extra: {
          'GET /bicicleteros': (http.Request _) => ++intentos == 1
              ? const RespuestaFalsa(500)
              : {
                  'bicicleteros': [_rack('r1', 'Biblioteca Central')],
                },
        },
      );

      expect(find.text('Cargando bicicleteros'), findsNothing);
      await tocarTexto(tester, 'Solicitar atención');

      expect(intentos, greaterThanOrEqualTo(2));
      expect(find.widgetWithText(TextFormField, 'Mensaje (opcional)'),
          findsOneWidget);
    });

    testWidgets('si los bicicleteros siguen sin cargar avisa el motivo real',
        (tester) async {
      await montar(
        tester,
        {'solicitudes': []},
        extra: {'GET /bicicleteros': const RespuestaFalsa(500)},
      );

      await tocarTexto(tester, 'Solicitar atención');

      expect(find.text(mensajeServidorNoDisponible), findsOneWidget);
      expect(find.text('No hay bicicleteros disponibles por ahora.'),
          findsNothing);
      expect(find.widgetWithText(ElevatedButton, 'Solicitar atención'),
          findsOneWidget);
    });

    testWidgets('si falla la carga lo informa', (tester) async {
      await montar(tester, const RespuestaFalsa(500));

      expect(
          find.text('No se pudieron cargar tus solicitudes'), findsOneWidget);
    });

    testWidgets('envía una solicitud con el mensaje', (tester) async {
      final api = await montar(
        tester,
        {'solicitudes': []},
        extra: {
          'POST /solicitudes-guardia': {'solicitud': _solicitud()}
        },
      );

      await tocarTexto(tester, 'Solicitar atención');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Mensaje (opcional)'),
        'Necesito retirar mi bicicleta',
      );
      await tocar(tester, find.text('Solicitar atención').last);

      final cuerpo = api.cuerpoDe('POST /solicitudes-guardia');
      expect(cuerpo['bicicleteroId'], 'r1');
      expect(cuerpo['tipo'], 'REQUIERE_SERVICIO');
      expect(cuerpo['mensaje'], 'Necesito retirar mi bicicleta');
      expect(find.text('Solicitud enviada al guardia con copia a central'),
          findsOneWidget);
    });

    testWidgets('si nadie gestiona el bicicletero lo explica al enviar',
        (tester) async {
      await montar(
        tester,
        {'solicitudes': []},
        extra: {
          'POST /solicitudes-guardia': {
            'solicitud': {
              ..._solicitud(estado: 'PENDIENTE'),
              'guardiaAsignado': null,
              'guardiasAsignados': [],
            },
          },
        },
      );

      await tocarTexto(tester, 'Solicitar atención');
      await tocar(tester, find.text('Solicitar atención').last);

      expect(
        find.text(
          'Por ahora nadie gestiona este bicicletero. Avisamos a central y tu solicitud llegará al guardia en cuanto tome el turno.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('se actualiza sola aunque se pierda un aviso en tiempo real',
        (tester) async {
      final api = await montar(tester, {
        'solicitudes': [_solicitud()],
      });
      expect(find.text('Guardia en camino'), findsNothing);

      api.responder('GET /solicitudes-guardia', {
        'solicitudes': [_solicitud(estado: 'EN_CAMINO')],
      });
      await tester.pump(const Duration(seconds: 31));
      await tester.pumpAndSettle();

      expect(find.text('Guardia en camino'), findsWidgets);
    });

    testWidgets('si una recarga falla conserva las solicitudes',
        (tester) async {
      final api = await montar(tester, {
        'solicitudes': [_solicitud()],
      });

      api.responder('GET /solicitudes-guardia', const RespuestaFalsa(500));
      await _recargarSolicitudes(tester, VistaSolicitarGuardia);

      expect(find.text('Necesito retirar mi bicicleta'), findsOneWidget);
      expect(find.text('No se pudieron cargar tus solicitudes'), findsNothing);
    });

    testWidgets('puede volver a avisar al guardia', (tester) async {
      final api = await montar(
        tester,
        {
          'solicitudes': [_solicitud()],
        },
        extra: {
          'POST /solicitudes-guardia/s1/notificar-guardia': {
            'solicitud': _solicitud(puedeNotificar: false),
          },
        },
      );

      await tocarTexto(tester, 'Recordar al guardia');

      expect(api.llamadas,
          contains('POST /solicitudes-guardia/s1/notificar-guardia'));
      expect(find.text('Guardia notificado nuevamente'), findsOneWidget);
    });

    group('cancelar', () {
      const ruta = 'POST /solicitudes-guardia/s1/cancelar';

      Future<ApiFalsa> montarCancelable(
        WidgetTester tester, {
        String estado = 'NOTIFICADA',
        Object? respuesta,
      }) =>
          montar(
            tester,
            {
              'solicitudes': [_solicitud(estado: estado)],
            },
            extra: {
              ruta: respuesta ?? {'solicitud': _solicitud(estado: 'CANCELADA')},
            },
          );

      Future<void> elegirMotivo(WidgetTester tester, String motivo) async {
        await tocar(tester, find.byType(DropdownButton<String>));
        await tocar(tester, find.text(motivo));
      }

      Future<void> confirmar(WidgetTester tester) =>
          tocar(tester, find.text('Cancelar solicitud'));

      testWidgets('cancela eligiendo un motivo', (tester) async {
        final api = await montarCancelable(tester);

        await tocarTexto(tester, 'Cancelar solicitud');
        expect(find.textContaining('el guardia ya no la verá pendiente'),
            findsOneWidget);
        await elegirMotivo(tester, 'Ya no necesito ayuda');
        await confirmar(tester);

        expect(api.cuerpoDe(ruta), {'motivo': 'Ya no necesito ayuda'});
        expect(find.text('Solicitud cancelada'), findsOneWidget);
        expect(find.byType(HojaCancelarSolicitud), findsNothing);
      });

      testWidgets('el motivo es obligatorio', (tester) async {
        final api = await montarCancelable(tester);

        await tocarTexto(tester, 'Cancelar solicitud');
        await confirmar(tester);

        expect(find.text('Elige un motivo.'), findsOneWidget);
        expect(api.llamadas, isNot(contains(ruta)));

        await elegirMotivo(tester, 'Ya lo resolví');
        expect(find.text('Elige un motivo.'), findsNothing);
        await confirmar(tester);

        expect(api.cuerpoDe(ruta), {'motivo': 'Ya lo resolví'});
      });

      testWidgets('otro motivo exige escribirlo', (tester) async {
        final api = await montarCancelable(tester);

        await tocarTexto(tester, 'Cancelar solicitud');
        await elegirMotivo(tester, 'Otro motivo');
        await confirmar(tester);

        expect(find.text('Escribe el motivo.'), findsOneWidget);
        expect(api.llamadas, isNot(contains(ruta)));

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Cuéntanos el motivo'),
          'no',
        );
        await confirmar(tester);

        expect(find.text('Debe tener al menos 3 caracteres.'), findsOneWidget);
        expect(api.llamadas, isNot(contains(ruta)));

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Cuéntanos el motivo'),
          'Llegó el guardia',
        );
        await confirmar(tester);

        expect(api.cuerpoDe(ruta), {'motivo': 'Llegó el guardia'});
      });

      testWidgets('advierte que el guardia en camino recibirá el aviso',
          (tester) async {
        await montarCancelable(tester, estado: 'EN_CAMINO');

        await tocarTexto(tester, 'Cancelar solicitud');

        expect(find.textContaining('El guardia va en camino'), findsOneWidget);
      });

      testWidgets('si el servidor la rechaza lo muestra en el formulario',
          (tester) async {
        await montarCancelable(
          tester,
          respuesta: const RespuestaFalsa(
            409,
            {'message': 'La solicitud ya está cerrada'},
          ),
        );

        await tocarTexto(tester, 'Cancelar solicitud');
        await elegirMotivo(tester, 'Ya lo resolví');
        await confirmar(tester);

        expect(find.text('La solicitud ya está cerrada'), findsOneWidget);
        expect(find.byType(HojaCancelarSolicitud), findsOneWidget);
      });

      testWidgets('la hoja muestra en vivo que el guardia va en camino',
          (tester) async {
        final api = await montarCancelable(tester);

        await tocarTexto(tester, 'Cancelar solicitud');
        expect(find.textContaining('el guardia ya no la verá pendiente'),
            findsOneWidget);

        api.responder('GET /solicitudes-guardia', {
          'solicitudes': [_solicitud(estado: 'EN_CAMINO')],
        });
        await _recargarSolicitudes(tester, VistaSolicitarGuardia);

        expect(find.textContaining('El guardia va en camino'), findsOneWidget);
        expect(find.text('Biblioteca Central · Guardia en camino'),
            findsOneWidget);
      });

      testWidgets('si el guardia la resuelve con la hoja abierta no la cancela',
          (tester) async {
        final api = await montarCancelable(tester);

        await tocarTexto(tester, 'Cancelar solicitud');
        await elegirMotivo(tester, 'Ya lo resolví');
        api.responder('GET /solicitudes-guardia', {
          'solicitudes': [
            {..._solicitud(estado: 'RESUELTA'), 'cerradaPor': 'GUARDIA'},
          ],
        });
        await _recargarSolicitudes(tester, VistaSolicitarGuardia);

        expect(
          find.text(
              'El guardia ya resolvió esta solicitud. No es necesario cancelarla.'),
          findsOneWidget,
        );
        expect(find.byType(DropdownButton<String>), findsNothing);

        await tocarTexto(tester, 'Entendido');

        expect(find.byType(HojaCancelarSolicitud), findsNothing);
        expect(api.llamadas, isNot(contains(ruta)));
      });

      testWidgets('si central la cierra con la hoja abierta lo indica',
          (tester) async {
        final api = await montarCancelable(tester);

        await tocarTexto(tester, 'Cancelar solicitud');
        api.responder('GET /solicitudes-guardia', {
          'solicitudes': [
            {..._solicitud(estado: 'CANCELADA'), 'cerradaPor': 'CENTRAL'},
          ],
        });
        await _recargarSolicitudes(tester, VistaSolicitarGuardia);

        expect(
          find.text(
              'Central cerró esta solicitud. No es necesario cancelarla.'),
          findsOneWidget,
        );
      });

      testWidgets(
          'se envía aunque la lista se recargue con el formulario abierto',
          (tester) async {
        final api = await montarCancelable(tester);

        await tocarTexto(tester, 'Cancelar solicitud');
        await _recargarSolicitudes(tester, VistaSolicitarGuardia);
        await elegirMotivo(tester, 'Ya lo resolví');
        await confirmar(tester);

        expect(api.cuerpoDe(ruta), {'motivo': 'Ya lo resolví'});
        expect(find.text('Solicitud cancelada'), findsOneWidget);
      });
    });
  });

  group('alertas del guardia', () {
    Future<ApiFalsa> montar(WidgetTester tester,
            {Map<String, Object?> extra = const {}}) =>
        montarConApi(
          tester,
          const VistaAlertasGuardia(),
          rol: RolUsuario.guardia,
          rutas: {
            'GET /solicitudes-guardia': {
              'solicitudes': [
                _solicitud(),
                _solicitud(
                  id: 's2',
                  estado: 'RESUELTA',
                  bicicletero: 'Facultad de Ingeniería',
                  solicitante: 'Luis Muñoz',
                ),
              ],
            },
            ...extra,
          },
        );

    testWidgets('muestra las alertas asignadas', (tester) async {
      await montar(tester);

      expect(find.text('Alertas'), findsOneWidget);
      expect(find.text('Ana Rojas'), findsOneWidget);
      expect(find.text('Luis Muñoz'), findsOneWidget);
    });

    testWidgets('buscar filtra en la lista', (tester) async {
      await montar(tester);

      await tester.enterText(
        find.widgetWithText(TextField, 'Buscar por bicicletero o solicitante'),
        'ingeniería',
      );
      await tester.pumpAndSettle();

      expect(find.text('Luis Muñoz'), findsOneWidget);
      expect(find.text('Ana Rojas'), findsNothing);
    });

    testWidgets('sin coincidencias lo indica', (tester) async {
      await montar(tester);

      await tester.enterText(
        find.widgetWithText(TextField, 'Buscar por bicicletero o solicitante'),
        'nadie',
      );
      await tester.pumpAndSettle();

      expect(find.text('Sin resultados'), findsOneWidget);
    });

    testWidgets('el guardia confirma que va en camino', (tester) async {
      final api = await montar(
        tester,
        extra: {
          'PATCH /solicitudes-guardia/s1/estado': {
            'solicitud': _solicitud(estado: 'EN_CAMINO'),
          },
        },
      );

      await tocarTexto(tester, 'Voy en camino');

      expect(api.cuerpoDe('PATCH /solicitudes-guardia/s1/estado')['estado'],
          'EN_CAMINO');
    });
  });

  group('central de solicitudes', () {
    Future<ApiFalsa> montar(WidgetTester tester,
            {Object? solicitudes, Map<String, Object?> extra = const {}}) =>
        montarConApi(
          tester,
          const VistaSolicitudesCentral(),
          rol: RolUsuario.adminCentral,
          rutas: {
            'GET /solicitudes-guardia': solicitudes ??
                {
                  'solicitudes': [_solicitud()],
                },
            ...extra,
          },
        );

    testWidgets('sin solicitudes lo indica', (tester) async {
      await montar(tester, solicitudes: {'solicitudes': []});

      expect(find.text('Sin solicitudes'), findsOneWidget);
    });

    testWidgets('filtrar por estado consulta al backend', (tester) async {
      final api = await montar(tester);

      await tocarTexto(tester, 'Filtros');
      await tocarTexto(tester, 'Guardia en camino');

      expect(_consultas(api).last['estado'], 'EN_CAMINO');
    });

    testWidgets('central no puede marcar una solicitud como resuelta',
        (tester) async {
      await montar(tester);

      expect(find.text('Cerrar sin resolver'), findsOneWidget);
      expect(find.text('Marcar resuelta'), findsNothing);
      expect(find.text('Voy en camino'), findsNothing);
    });

    testWidgets('cerrar sin resolver exige y envía el motivo', (tester) async {
      final api = await montar(
        tester,
        extra: {
          'PATCH /solicitudes-guardia/s1/estado': {
            'solicitud': _solicitud(estado: 'CANCELADA'),
          },
        },
      );

      await tocarTexto(tester, 'Cerrar sin resolver');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Motivo del cierre'),
        'El usuario ya retiró su bicicleta',
      );
      await tocarTexto(tester, 'Confirmar');

      final cuerpo = api.cuerpoDe('PATCH /solicitudes-guardia/s1/estado');
      expect(cuerpo['estado'], 'CANCELADA');
      expect(cuerpo['nota'], 'El usuario ya retiró su bicicleta');
      expect(find.text('Solicitud cerrada sin resolver'), findsOneWidget);
    });

    testWidgets('si central desiste no cierra nada', (tester) async {
      final api = await montar(tester);

      await tocarTexto(tester, 'Cerrar sin resolver');
      await tocarTexto(tester, 'Cancelar');

      expect(api.llamadas,
          isNot(contains('PATCH /solicitudes-guardia/s1/estado')));
    });

    testWidgets('el cierre se envía aunque la lista se recargue',
        (tester) async {
      final api = await montar(
        tester,
        extra: {
          'PATCH /solicitudes-guardia/s1/estado': {
            'solicitud': _solicitud(estado: 'CANCELADA'),
          },
        },
      );

      await tocarTexto(tester, 'Cerrar sin resolver');
      await _recargarSolicitudes(tester, VistaSolicitudesCentral);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Motivo del cierre'),
        'Solicitud duplicada',
      );
      await tocarTexto(tester, 'Confirmar');

      expect(api.cuerpoDe('PATCH /solicitudes-guardia/s1/estado')['nota'],
          'Solicitud duplicada');
    });
  });

  group('inicio del guardia', () {
    testWidgets('sin bicicletero asignado pide elegir uno', (tester) async {
      await montarConApi(
        tester,
        const VistaInicioGuardia(),
        rol: RolUsuario.guardia,
        rutas: {
          'GET /guardias/me/bicicletero': {'bicicletero': null},
          'GET /bicicleteros': {
            'bicicleteros': [_rack('r1', 'Biblioteca Central')],
          },
        },
      );

      expect(find.text('Turno sin iniciar'), findsOneWidget);
      expect(find.text('Selecciona un bicicletero para comenzar a validar.'),
          findsOneWidget);
      expect(find.text('Escanear QR temporal'), findsOneWidget);
      expect(find.text('Gestión manual'), findsOneWidget);
    });

    testWidgets('con turno activo muestra el bicicletero y sus cupos',
        (tester) async {
      await montarConApi(
        tester,
        const VistaInicioGuardia(),
        rol: RolUsuario.guardia,
        rutas: {
          'GET /guardias/me/bicicletero': {
            'bicicletero': _rack('r1', 'Biblioteca Central', cupos: 1),
          },
          'GET /bicicleteros': {
            'bicicleteros': [_rack('r1', 'Biblioteca Central', cupos: 1)],
          },
        },
      );

      expect(find.text('Turno activo'), findsOneWidget);
      expect(find.text('Gestionas Biblioteca Central · 1 cupo libre'),
          findsOneWidget);
    });

    testWidgets('si una recarga falla mantiene el turno y la lista',
        (tester) async {
      final api = await montarConApi(
        tester,
        const VistaInicioGuardia(),
        rol: RolUsuario.guardia,
        rutas: {
          'GET /guardias/me/bicicletero': {
            'bicicletero': _rack('r1', 'Biblioteca Central', cupos: 1),
          },
          'GET /bicicleteros': {
            'bicicleteros': [_rack('r1', 'Biblioteca Central', cupos: 1)],
          },
        },
      );

      api.responder('GET /guardias/me/bicicletero', const RespuestaFalsa(500));
      api.responder('GET /bicicleteros', const RespuestaFalsa(500));
      await tester.pump(const Duration(seconds: 31));
      await tester.pumpAndSettle();

      expect(find.text('Turno activo'), findsOneWidget);
      expect(find.text('No se pudieron cargar bicicleteros'), findsNothing);
      expect(find.text(mensajeSinConexion), findsNothing);
    });
  });

  group('bicicletero que gestiona el guardia', () {
    testWidgets('elegir un bicicletero lo asigna', (tester) async {
      final api = await montarConApi(
        tester,
        const SingleChildScrollView(child: SelectorBicicleteroGuardiaPerfil()),
        rol: RolUsuario.guardia,
        rutas: {
          'GET /guardias/me/bicicletero': {'bicicletero': null},
          'GET /bicicleteros': {
            'bicicleteros': [
              _rack('r1', 'Biblioteca Central'),
              _rack('r2', 'Facultad de Ingeniería'),
            ],
          },
          'PATCH /guardias/me/bicicletero': {
            'bicicletero': _rack('r2', 'Facultad de Ingeniería'),
          },
        },
      );

      await tocarTexto(tester, 'Selecciona un bicicletero');
      await tocarTexto(tester, 'Facultad de Ingeniería');

      expect(api.cuerpoDe('PATCH /guardias/me/bicicletero')['bicicleteroId'],
          'r2');
      expect(
          find.text('Ahora gestionas Facultad de Ingeniería'), findsOneWidget);
    });

    testWidgets('un bicicletero que gestiona otro guardia no se puede elegir',
        (tester) async {
      final api = await montarConApi(
        tester,
        const SingleChildScrollView(child: SelectorBicicleteroGuardiaPerfil()),
        rol: RolUsuario.guardia,
        rutas: {
          'GET /guardias/me/bicicletero': {'bicicletero': null},
          'GET /bicicleteros': {
            'bicicleteros': [
              {
                ..._rack('r1', 'Biblioteca Central'),
                'guardiaActivo': {'id': 'g9', 'nombre': 'Pedro Soto'},
              },
              _rack('r2', 'Facultad de Ingeniería'),
            ],
          },
        },
      );

      await tocarTexto(tester, 'Selecciona un bicicletero');
      expect(find.text('Lo gestiona Pedro Soto'), findsOneWidget);
      await tocarTexto(tester, 'Biblioteca Central');

      expect(api.llamadas, isNot(contains('PATCH /guardias/me/bicicletero')));
    });

    testWidgets('dejar de gestionar libera el bicicletero', (tester) async {
      final api = await montarConApi(
        tester,
        const SingleChildScrollView(child: SelectorBicicleteroGuardiaPerfil()),
        rol: RolUsuario.guardia,
        rutas: {
          'GET /guardias/me/bicicletero': {
            'bicicletero': _rack('r1', 'Biblioteca Central'),
          },
          'GET /bicicleteros': {
            'bicicleteros': [_rack('r1', 'Biblioteca Central')],
          },
          'DELETE /guardias/me/bicicletero': const {},
        },
      );

      await tocarTexto(tester, 'Biblioteca Central · 12 cupos libres');
      await tocarTexto(tester, 'Ninguno');

      expect(api.llamadas, contains('DELETE /guardias/me/bicicletero'));
      expect(find.text('Ya no gestionas un bicicletero'), findsOneWidget);
    });

    testWidgets(
        'al dejar de gestionar, su bicicletero queda libre y puede volver a elegirlo',
        (tester) async {
      final api = await montarConApi(
        tester,
        const SingleChildScrollView(child: SelectorBicicleteroGuardiaPerfil()),
        rol: RolUsuario.guardia,
        rutas: {
          'GET /guardias/me/bicicletero': {
            'bicicletero': _rack('r1', 'Biblioteca Central'),
          },
          'GET /bicicleteros': {
            'bicicleteros': [
              {
                ..._rack('r1', 'Biblioteca Central'),
                'guardiaActivo': {'id': 'yo', 'nombre': 'Guardia Prueba'},
              },
              _rack('r2', 'Facultad de Ingeniería'),
            ],
          },
          'DELETE /guardias/me/bicicletero': const {},
          'PATCH /guardias/me/bicicletero': {
            'bicicletero': _rack('r1', 'Biblioteca Central'),
          },
        },
      );
      api.responder('GET /guardias/me/bicicletero', {'bicicletero': null});

      await tocarTexto(tester, 'Biblioteca Central · 12 cupos libres');
      await tocarTexto(tester, 'Ninguno');
      await tocarTexto(tester, 'Selecciona un bicicletero');

      expect(find.textContaining('Lo gestiona'), findsNothing);
      expect(find.byIcon(Icons.lock_outline), findsNothing);

      await tocarTexto(tester, 'Biblioteca Central');

      expect(api.cuerpoDe('PATCH /guardias/me/bicicletero')['bicicleteroId'],
          'r1');
    });

    Future<ApiFalsa> montarSelectorLibre(WidgetTester tester) => montarConApi(
          tester,
          const SingleChildScrollView(
              child: SelectorBicicleteroGuardiaPerfil()),
          rol: RolUsuario.guardia,
          rutas: {
            'GET /guardias/me/bicicletero': {'bicicletero': null},
            'GET /bicicleteros': {
              'bicicleteros': [
                _rack('r1', 'Biblioteca Central'),
                _rack('r2', 'Facultad de Ingeniería'),
              ],
            },
          },
        );

    void otroGuardiaTomaBiblioteca(ApiFalsa api) =>
        api.responder('GET /bicicleteros', {
          'bicicleteros': [
            {
              ..._rack('r1', 'Biblioteca Central'),
              'guardiaActivo': {'id': 'g9', 'nombre': 'Pedro Soto'},
            },
            _rack('r2', 'Facultad de Ingeniería'),
          ],
        });

    testWidgets('con el desplegable abierto se actualiza en tiempo real',
        (tester) async {
      final api = await montarSelectorLibre(tester);
      await tocarTexto(tester, 'Selecciona un bicicletero');
      expect(find.text('Lo gestiona Pedro Soto'), findsNothing);

      otroGuardiaTomaBiblioteca(api);
      ProviderScope.containerOf(
              tester.element(find.byType(SelectorBicicleteroGuardiaPerfil)))
          .read(bicicleterosVersionProvider.notifier)
          .state++;
      await tester.pumpAndSettle();

      expect(find.text('Lo gestiona Pedro Soto'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    });

    testWidgets('se actualiza solo aunque se pierda un aviso', (tester) async {
      final api = await montarSelectorLibre(tester);
      await tocarTexto(tester, 'Selecciona un bicicletero');

      otroGuardiaTomaBiblioteca(api);
      await tester.pump(const Duration(seconds: 31));
      await tester.pumpAndSettle();

      expect(find.text('Lo gestiona Pedro Soto'), findsOneWidget);
    });

    testWidgets('si una recarga en segundo plano falla no muestra errores',
        (tester) async {
      final api = await montarSelectorLibre(tester);

      api.responder('GET /bicicleteros', const RespuestaFalsa(500));
      await tester.pump(const Duration(seconds: 31));
      await tester.pumpAndSettle();

      expect(find.text('Selecciona un bicicletero'), findsOneWidget);
      expect(find.text(mensajeSinConexion), findsNothing);
      expect(find.text('Error 500'), findsNothing);
    });

    testWidgets('si no hay bicicleteros activos lo explica', (tester) async {
      await montarConApi(
        tester,
        const SingleChildScrollView(child: SelectorBicicleteroGuardiaPerfil()),
        rol: RolUsuario.guardia,
        rutas: {
          'GET /guardias/me/bicicletero': {'bicicletero': null},
          'GET /bicicleteros': {'bicicleteros': []},
        },
      );

      expect(find.text('Sin bicicleteros activos'), findsOneWidget);
    });
  });
}
