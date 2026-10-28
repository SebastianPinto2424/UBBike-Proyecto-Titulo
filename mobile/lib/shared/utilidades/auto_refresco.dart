import 'package:flutter/widgets.dart';

import 'package:ubbike/shared/utilidades/refresco_coalescido.dart';

mixin AutoRefrescoMixin<T extends StatefulWidget> on State<T> {
  RefrescoCoalescido? _refresco;

  Duration get intervaloAutoRefresco => const Duration(seconds: 30);

  Future<void> refrescar();

  bool get datosDesactualizados => false;

  void solicitarRefresco() => _refresco?.solicitar();

  void iniciarAutoRefresco() {
    _refresco?.detener();
    _refresco = RefrescoCoalescido(
      alRefrescar: () async {
        if (mounted) {
          await refrescar();
        }
      },
      intervaloRespaldo: intervaloAutoRefresco,
      detectarFallo: () => datosDesactualizados,
    )..iniciarRespaldo();
  }

  void detenerAutoRefresco() {
    _refresco?.detener();
    _refresco = null;
  }

  @override
  void dispose() {
    _refresco?.detener();
    super.dispose();
  }
}
