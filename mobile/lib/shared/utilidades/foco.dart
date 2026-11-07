import 'package:flutter/widgets.dart';

void soltarFoco() => FocusManager.instance.primaryFocus?.unfocus();

void enfocarAlDibujar(FocusNode foco) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (foco.context?.mounted ?? false) {
      foco.requestFocus();
    }
  });
}
