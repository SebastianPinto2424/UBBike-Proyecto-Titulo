import 'package:web/web.dart' as web;

bool get requiereAlmacenNavegador => !web.window.isSecureContext;

String? leerAlmacenNavegador(String clave) =>
    web.window.sessionStorage.getItem(clave);

void escribirAlmacenNavegador(String clave, String valor) =>
    web.window.sessionStorage.setItem(clave, valor);

void borrarAlmacenNavegador(String clave) =>
    web.window.sessionStorage.removeItem(clave);
