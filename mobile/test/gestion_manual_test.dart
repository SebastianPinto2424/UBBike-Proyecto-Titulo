import 'package:flutter_test/flutter_test.dart';
import 'package:ubbike/features/acceso/data/acceso_modelos.dart';
import 'package:ubbike/features/acceso/presentation/campos_gestion_manual.dart';
import 'package:ubbike/shared/modelos/bicicleta_app.dart';

void main() {
  group('SolicitudRegistroManual.aJson', () {
    test('omite los textos vacíos y siempre envía los datos obligatorios', () {
      const solicitud = SolicitudRegistroManual(
        tipo: 'INGRESO',
        correo: 'ana@alumnos.ubiobio.cl',
        rut: '',
        comentario: '',
        bicicletaDescripcion: 'Bici azul',
      );

      expect(solicitud.aJson(), {
        'correo': 'ana@alumnos.ubiobio.cl',
        'bicicletaDescripcion': 'Bici azul',
        'tipo': 'INGRESO',
        'denegar': false,
        'motivo': null,
        'crearBicicletaNueva': false,
      });
    });

    test('incluye el motivo al rechazar', () {
      const solicitud = SolicitudRegistroManual(
        tipo: 'RETIRO',
        bicicletaId: 'bici-1',
        denegar: true,
        motivo: 'No coincide la bicicleta',
      );

      final json = solicitud.aJson();

      expect(json['denegar'], isTrue);
      expect(json['motivo'], 'No coincide la bicicleta');
      expect(json['bicicletaId'], 'bici-1');
    });
  });

  group('CamposGestionManual', () {
    late CamposGestionManual campos;

    setUp(() => campos = CamposGestionManual());
    tearDown(() => campos.dispose());

    test('arma la solicitud con los textos recortados y normalizados', () {
      campos.nombre.text = '  Ana Pérez ';
      campos.correo.text = ' ana@alumnos.ubiobio.cl ';
      campos.rut.text = '11.111.111-1';
      campos.descripcion.text = ' Bici azul ';
      campos.aro.text = ' 29 ';

      final solicitud = campos.solicitud(
        tipo: 'INGRESO',
        bicicletaId: null,
        bicicleteroId: 'bicicletero-1',
        fotoUrl: 'data:image/png;base64,AAAA',
        denegar: false,
      );

      expect(solicitud.nombre, 'Ana Pérez');
      expect(solicitud.correo, 'ana@alumnos.ubiobio.cl');
      expect(solicitud.bicicletaDescripcion, 'Bici azul');
      expect(solicitud.bicicletaAro, '29');
      expect(solicitud.bicicleteroId, 'bicicletero-1');
      expect(solicitud.crearBicicletaNueva, isTrue);
    });

    test('con una bicicleta registrada no pide crear otra', () {
      final solicitud = campos.solicitud(
        tipo: 'RETIRO',
        bicicletaId: 'bici-1',
        bicicleteroId: null,
        fotoUrl: null,
        denegar: false,
      );

      expect(solicitud.crearBicicletaNueva, isFalse);
    });

    test('carga una bicicleta registrada y la limpia sin tocar al usuario', () {
      campos.correo.text = 'ana@alumnos.ubiobio.cl';
      campos.cargarBicicleta(
        const BicicletaApp(
          id: 'bici-1',
          descripcion: 'Bici roja',
          activa: true,
          dentroBicicletero: false,
          marca: 'Trek',
          aro: '29',
          numeroSerie: 'ABC123',
        ),
      );

      expect(campos.descripcion.text, 'Bici roja');
      expect(campos.marca.text, 'Trek');
      expect(campos.aro.text, '29');
      expect(campos.numeroSerie.text, 'ABC123');

      campos.limpiarBicicleta();

      expect(campos.descripcion.text, isEmpty);
      expect(campos.numeroSerie.text, isEmpty);
      expect(campos.correo.text, 'ana@alumnos.ubiobio.cl');
    });

    test('limpia todos los campos', () {
      campos.nombre.text = 'Ana';
      campos.comentario.text = 'Trae candado';
      campos.descripcion.text = 'Bici';

      campos.limpiarTodo();

      expect(campos.nombre.text, isEmpty);
      expect(campos.comentario.text, isEmpty);
      expect(campos.descripcion.text, isEmpty);
    });
  });
}
