import 'package:flutter/widgets.dart';

SpellCheckConfiguration? revisionOrtografica() {
  final disponible =
      WidgetsBinding.instance.platformDispatcher.nativeSpellCheckServiceDefined;
  return disponible ? const SpellCheckConfiguration() : null;
}
