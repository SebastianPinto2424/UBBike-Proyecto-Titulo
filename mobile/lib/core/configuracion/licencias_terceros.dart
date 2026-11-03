import 'package:flutter/foundation.dart';

void registrarLicenciasDeTerceros() {
  LicenseRegistry.addLicense(
    () => Stream.value(
      const LicenseEntryWithLineBreaks(
        ['Lista de palabras en español'],
        'Derivada de FrequencyWords, de Hermit Dave '
        '(https://github.com/hermitdave/FrequencyWords), generada a partir de '
        'OpenSubtitles 2018. Licencia CC BY-SA 4.0 '
        '(https://creativecommons.org/licenses/by-sa/4.0/). Cambios: se '
        'dejaron solo palabras y se quitaron abreviaturas y formas sin tilde '
        'que casi siempre son errores. La lista adaptada se distribuye con la '
        'misma licencia.',
      ),
    ),
  );
}
