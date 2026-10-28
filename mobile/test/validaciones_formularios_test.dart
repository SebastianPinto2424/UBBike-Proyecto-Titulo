import 'package:flutter_test/flutter_test.dart';
import 'package:ubbike/shared/utilidades/identidad.dart';
import 'package:ubbike/shared/utilidades/opciones_bicicleta.dart';
import 'package:flutter/foundation.dart';
import 'package:ubbike/features/acceso/presentation/dialogo_nota_cierre.dart';
import 'package:ubbike/features/acceso/presentation/validaciones_gestion_manual.dart';
import 'package:ubbike/features/notificaciones/data/notificacion_api.dart';

void main() {
  group('validaciones de registro', () {
    test('valida RUT chileno con guion y digito verificador', () {
      expect(rutValido('12.345.678-5'), isTrue);
      expect(rutValido('12345678-5'), isTrue);
      expect(rutValido('12.345.670-K'), isTrue);
      expect(rutValido('12.345.678-9'), isFalse);
      expect(rutValido('123456785'), isFalse);
    });

    test('exige dos nombres y dos apellidos', () {
      expect(nombreCompletoValido('Juan Carlos Perez Soto'), isTrue);
      expect(nombreCompletoValido('Juan Carlos Pérez Soto'), isTrue);
      expect(nombreCompletoValido('Juan Perez'), isFalse);
      expect(nombreCompletoValido('Juan Carlos Perez'), isFalse);
      expect(nombreCompletoValido('Juan 123 Perez Soto'), isFalse);
    });

    test('obtiene nombre corto para saludos', () {
      expect(nombreCorto('Juan Carlos Perez Soto'), 'Juan Perez');
      expect(nombreCorto('Juan Perez'), 'Juan Perez');
      expect(nombreCorto('Juan'), 'Juan');
    });
  });

  group('validaciones de bicicleta', () {
    test('normaliza aros permitidos y rechaza valores desconocidos', () {
      expect(normalizarAroBicicleta('29'), '29');
      expect(normalizarAroBicicleta('700C'), '29');
      expect(normalizarAroBicicleta('27.5 / 650B (ISO 584)'), '27.5');
      expect(normalizarAroBicicleta('R26'), isNull);
    });

    test('normaliza colores y combinaciones validas', () {
      expect(normalizarColorBicicleta('plomo'), 'Gris');
      expect(normalizarColorBicicleta('negro / rojo / plateado'),
          'Negro / Rojo / Plateado');
      expect(normalizarColorBicicleta('negro/rojo/azul/verde'), isNull);
      expect(normalizarColorBicicleta('negro/inventado'), isNull);
    });

    test('sugiere colores por catalogo y alias', () {
      expect(sugerirColoresBicicleta('plo'), contains('Gris'));
      expect(sugerirColoresBicicleta('marino'), contains('Azul marino'));
      expect(sugerirColoresBicicleta(''), contains('Negro'));
    });

    test('valida descripcion marca modelo color y serie', () {
      expect(validarDescripcionBicicleta('Bici urbana'), isNull);
      expect(validarDescripcionBicicleta('--'), isNotNull);
      expect(validarMarcaBicicleta('Oxford'), isNull);
      expect(validarMarcaBicicleta('A'), isNotNull);
      expect(validarModeloBicicleta('ATX 720'), isNull);
      expect(validarColorBicicleta('azul marino'), isNull);
      expect(validarColorBicicleta('azul123'), isNotNull);
      expect(validarNumeroSerieBicicleta('AB-1234'), isNull);
      expect(validarNumeroSerieBicicleta('AB 1234'), isNotNull);
    });
  });

  group('validaciones alineadas con el backend', () {
    test('la gestion manual exige RUT con digito verificador correcto', () {
      expect(validarRutGestionManual('12.345.678-5'), isNull);
      expect(validarRutGestionManual('12.345.678-9'), isNotNull);
      expect(validarRutGestionManual('12.345.678'), isNotNull);
      expect(validarRutGestionManual(''), isNull);
      expect(validarRutGestionManual('', requerido: true), isNotNull);
    });

    test('un registro parcial nuevo exige correo institucional', () {
      expect(validarCorreoGestionManual('ana@gmail.com', ''), isNull);
      expect(
        validarCorreoGestionManual('ana@gmail.com', '', requiereCorreo: true),
        'Usa un correo @ubiobio.cl o @alumnos.ubiobio.cl.',
      );
      expect(
        validarCorreoGestionManual('ana@alumnos.ubiobio.cl', '',
            requiereCorreo: true),
        isNull,
      );
    });

    test('la descripcion manual usa el mismo limite que la bicicleta', () {
      expect(validarDescripcionBicicletaManual('Bici roja', true), isNull);
      expect(validarDescripcionBicicletaManual('x' * 101, true), isNotNull);
      expect(validarDescripcionBicicletaManual('123', true), isNotNull);
      expect(validarDescripcionBicicletaManual('', false), isNull);
    });

    test('el motivo de cierre de central tiene entre 3 y 600 caracteres', () {
      expect(validarNotaCierre(''), isNotNull);
      expect(validarNotaCierre('ok'), 'Debe tener al menos 3 caracteres.');
      expect(validarNotaCierre('Duplicada'), isNull);
      expect(validarNotaCierre('x' * 601), 'Máximo 600 caracteres.');
    });

    test('el token push se registra con la plataforma real', () {
      expect(plataformaPush(TargetPlatform.iOS), 'ios');
      expect(plataformaPush(TargetPlatform.android), 'android');
    });
  });
}
