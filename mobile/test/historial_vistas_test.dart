import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:ubbike/core/modelos/rol_usuario.dart';
import 'package:ubbike/features/historial/presentation/vista_movimientos_central.dart';
import 'package:ubbike/features/historial/presentation/vista_movimientos_usuario.dart';
import 'package:ubbike/features/historial/presentation/vista_operaciones_guardias_central.dart';

import 'soporte_api_falsa.dart';

Map<String, dynamic> _movimiento(
  String id, {
  String tipo = 'INGRESO',
  String estado = 'CONFIRMADO',
  String guardia = 'Pedro Soto',
  String bicicletero = 'Biblioteca Central',
  String? motivo,
}) =>
    {
      'id': id,
      'tipo': tipo,
      'estado': estado,
      'origen': 'QR',
      'creadoEn': '2026-10-20T13:30:00.000Z',
      'motivoDenegacion': motivo,
      'usuario': {
        'id': 'u1',
        'nombre': 'Ana Rojas',
        'correo': 'ana@alumnos.ubiobio.cl',
        'rut': '11.111.111-1',
      },
      'bicicleta': {
        'id': 'b1',
        'descripcion': 'Urbana azul',
        'marca': 'Oxford'
      },
      'bicicletero': {'id': 'r1', 'nombre': bicicletero},
      'guardia': {
        'id': 'g1',
        'nombre': guardia,
        'correo': 'guardia@ubiobio.cl'
      },
    };

Map<String, dynamic> _pagina(
  List<Map<String, dynamic>> movimientos, {
  int pagina = 1,
  int totalPaginas = 1,
  int? total,
}) =>
    {
      'movimientos': movimientos,
      'metadatos': {
        'pagina': pagina,
        'totalPaginas': totalPaginas,
        'total': total ?? movimientos.length,
        'limite': 20,
      },
    };

const _opciones = {
  'bicicleteros': [
    {'id': 'r1', 'nombre': 'Biblioteca Central'},
  ],
  'guardias': [
    {'id': 'g1', 'nombre': 'Pedro Soto', 'rol': 'GUARDIA'},
  ],
};

Iterable<Map<String, String>> _consultas(ApiFalsa api) => api.peticiones
    .where((p) => p.method == 'GET' && p.url.path == '/historial')
    .map((p) => p.url.queryParameters);

Object? _porPagina(http.Request peticion) =>
    peticion.url.queryParameters['page'] == '2'
        ? _pagina([_movimiento('m2', tipo: 'RETIRO')],
            pagina: 2, totalPaginas: 2, total: 2)
        : _pagina([_movimiento('m1')], totalPaginas: 2, total: 2);

void main() {
  group('movimientos del usuario', () {
    Future<ApiFalsa> montar(WidgetTester tester, Object? historial) =>
        montarConApi(
          tester,
          const VistaMovimientosUsuario(),
          rutas: {'GET /historial': historial},
        );

    testWidgets('sin movimientos lo indica', (tester) async {
      await montar(tester, _pagina([]));

      expect(find.text('Mis movimientos'), findsOneWidget);
      expect(find.text('Sin movimientos'), findsOneWidget);
    });

    testWidgets('si falla la carga permite reintentar', (tester) async {
      final api = await montar(tester, const RespuestaFalsa(500));

      expect(find.text('No se pudieron cargar movimientos'), findsOneWidget);

      api.responder('GET /historial', _pagina([_movimiento('m1')]));
      await tocarTexto(tester, 'No se pudieron cargar movimientos');

      expect(find.text('Biblioteca Central'), findsWidgets);
    });

    testWidgets('muestra el detalle de un retiro denegado', (tester) async {
      await montar(
        tester,
        _pagina([
          _movimiento('m1',
              tipo: 'RETIRO',
              estado: 'DENEGADO',
              motivo: 'La bicicleta no coincide'),
        ]),
      );

      expect(find.text('Denegado'), findsWidgets);
      expect(find.textContaining('Retiro'), findsWidgets);
    });

    testWidgets('filtrar por tipo consulta solo ingresos', (tester) async {
      final api = await montar(tester, _pagina([_movimiento('m1')]));

      await tocarTexto(tester, 'Filtros');
      await tocarTexto(tester, 'Ingresos');

      expect(_consultas(api).last['tipo'], 'INGRESO');
    });

    testWidgets('carga la página siguiente', (tester) async {
      final api = await montar(tester, _porPagina);

      await tocarTexto(tester, 'Cargar más movimientos');

      expect(_consultas(api).last['page'], '2');
      expect(find.text('Cargar más movimientos'), findsNothing);
    });

    testWidgets('siempre pide solo los movimientos propios', (tester) async {
      final api = await montar(tester, _porPagina);

      await tocarTexto(tester, 'Cargar más movimientos');

      expect(_consultas(api).map((consulta) => consulta['alcance']),
          everyElement('PROPIO'));
    });
  });

  group('historial de central', () {
    Future<ApiFalsa> montar(WidgetTester tester, Object? historial) =>
        montarConApi(
          tester,
          const VistaMovimientosCentral(),
          rol: RolUsuario.adminCentral,
          rutas: {
            'GET /historial': historial,
            'GET /historial/opciones': _opciones,
          },
        );

    testWidgets('lista los movimientos con su detalle', (tester) async {
      await montar(tester, _pagina([_movimiento('m1')]));

      expect(find.text('Historial'), findsOneWidget);
      expect(find.text('Ingreso | Ana Rojas'), findsWidgets);
      expect(find.text('Pedro Soto'), findsWidgets);
      expect(find.text('Confirmado'), findsWidgets);
    });

    testWidgets('sin coincidencias muestra el estado vacío', (tester) async {
      await montar(tester, _pagina([]));

      expect(find.text('Sin movimientos'), findsOneWidget);
    });

    testWidgets('si falla la carga lo informa', (tester) async {
      await montar(tester, const RespuestaFalsa(500));

      expect(find.text('No se pudieron cargar movimientos'), findsOneWidget);
    });

    testWidgets('usa la semana como período por defecto', (tester) async {
      final api = await montar(tester, _pagina([_movimiento('m1')]));

      expect(_consultas(api).first['periodo'], 'SEMANA');
      expect(_consultas(api).first.containsKey('alcance'), isFalse);
    });

    testWidgets('buscar envía el texto al backend', (tester) async {
      final api = await montar(tester, _pagina([_movimiento('m1')]));

      await tester.enterText(
        find.widgetWithText(
            TextField, 'Buscar por bicicleta, bicicletero o guardia'),
        'oxford',
      );
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      expect(_consultas(api).last['q'], 'oxford');
    });

    testWidgets('los filtros cambian la consulta y se pueden quitar',
        (tester) async {
      final api = await montar(tester, _pagina([_movimiento('m1')]));

      await tocarTexto(tester, 'Filtros');
      await tocarTexto(tester, 'Mes');
      expect(_consultas(api).last['periodo'], 'MES');

      await tocarTexto(tester, 'Retiros');
      expect(_consultas(api).last['tipo'], 'RETIRO');

      await tocarTexto(tester, 'Denegados');
      expect(_consultas(api).last['estado'], 'DENEGADO');

      await tocarTexto(tester, 'Manual');
      expect(_consultas(api).last['origen'], 'MANUAL');

      await tocarTexto(tester, 'Restablecer filtros');
      final consulta = _consultas(api).last;
      expect(consulta['periodo'], 'SEMANA');
      expect(consulta.containsKey('tipo'), isFalse);
    });

    testWidgets('carga más movimientos por página', (tester) async {
      final api = await montar(tester, _porPagina);

      expect(find.text('Mostrando 1 de 2 movimientos'), findsOneWidget);
      await tocarTexto(tester, 'Cargar más');

      expect(_consultas(api).last['page'], '2');
      expect(
          find.text('Mostrando los 2 movimientos del filtro'), findsOneWidget);
    });
  });

  group('operaciones por guardia', () {
    Future<ApiFalsa> montar(WidgetTester tester, Object? historial) =>
        montarConApi(
          tester,
          const VistaOperacionesGuardiasCentral(),
          rol: RolUsuario.adminCentral,
          rutas: {
            'GET /historial': historial,
            'GET /historial/opciones': _opciones,
            'GET /bicicleteros': {
              'bicicleteros': _opciones['bicicleteros'],
            },
          },
        );

    testWidgets('agrupa las validaciones de cada guardia', (tester) async {
      await montar(tester, {
        'movimientos': [
          _movimiento('m1'),
          _movimiento('m2', estado: 'DENEGADO'),
          _movimiento('m3', guardia: 'Rosa Díaz'),
        ],
      });

      expect(find.text('Operaciones por guardia'), findsOneWidget);
      expect(find.text('Pedro Soto'), findsOneWidget);
      expect(find.text('Rosa Díaz'), findsOneWidget);
      expect(find.textContaining('2 validaciones'), findsOneWidget);
      expect(find.textContaining('1 denegaciones'), findsOneWidget);
    });

    testWidgets('abrir un guardia muestra sus movimientos', (tester) async {
      await montar(tester, {
        'movimientos': [_movimiento('m1')],
      });

      await tocarTexto(tester, 'Pedro Soto');

      expect(find.text('Ingreso | Ana Rojas'), findsWidgets);
    });

    testWidgets('sin validaciones en el período lo indica', (tester) async {
      final api = await montar(tester, {'movimientos': []});

      expect(find.text('Sin operaciones'), findsOneWidget);
      expect(_consultas(api).first['periodo'], 'DIA');
    });

    testWidgets('si falla la carga lo informa', (tester) async {
      await montar(tester, const RespuestaFalsa(500));

      expect(find.text('No se pudieron cargar operaciones'), findsOneWidget);
    });
  });
}
