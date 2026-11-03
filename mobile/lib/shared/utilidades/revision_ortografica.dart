import 'package:flutter/widgets.dart';

import 'package:ubbike/core/servicios/corrector_ortografico_servicio.dart';

SpellCheckConfiguration revisionOrtografica() {
  final correctorDelTelefono =
      WidgetsBinding.instance.platformDispatcher.nativeSpellCheckServiceDefined;
  return correctorDelTelefono
      ? const SpellCheckConfiguration()
      : SpellCheckConfiguration(
          spellCheckService: CorrectorOrtograficoServicio.instancia,
        );
}
