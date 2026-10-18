import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:ubbike/core/servicios/almacen_navegador.dart';

class AlmacenSeguro {
  const AlmacenSeguro();

  static const _seguro = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<String?> read({required String key}) async => requiereAlmacenNavegador
      ? leerAlmacenNavegador(key)
      : _seguro.read(key: key);

  Future<void> write({required String key, required String? value}) async {
    if (value == null) {
      return delete(key: key);
    }
    if (requiereAlmacenNavegador) {
      escribirAlmacenNavegador(key, value);
    } else {
      await _seguro.write(key: key, value: value);
    }
  }

  Future<void> delete({required String key}) async {
    if (requiereAlmacenNavegador) {
      borrarAlmacenNavegador(key);
    } else {
      await _seguro.delete(key: key);
    }
  }
}
