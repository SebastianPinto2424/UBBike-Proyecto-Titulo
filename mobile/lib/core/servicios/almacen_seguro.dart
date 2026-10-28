import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AlmacenSeguro {
  const AlmacenSeguro();

  static const _seguro = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<String?> leer({required String clave}) => _seguro.read(key: clave);

  Future<void> escribir({required String clave, required String? valor}) async {
    if (valor == null) {
      return borrar(clave: clave);
    }
    await _seguro.write(key: clave, value: valor);
  }

  Future<void> borrar({required String clave}) => _seguro.delete(key: clave);
}
