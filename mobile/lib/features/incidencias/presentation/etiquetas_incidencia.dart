import 'package:flutter/material.dart';

import 'package:ubbike/core/tema/colores_ubb.dart';

const List<String> tiposIncidencia = [
  'PROBLEMA_QR',
  'DANO_BICICLETA',
  'DANO_INFRAESTRUCTURA',
  'PROBLEMA_MOVIMIENTO',
  'USUARIO_DATOS',
  'OTRO',
];

String etiquetaTipoIncidencia(String tipo) {
  return switch (tipo) {
    'PROBLEMA_QR' => 'Problema con QR',
    'DANO_BICICLETA' => 'Daño de bicicleta',
    'DANO_INFRAESTRUCTURA' => 'Daño de infraestructura',
    'PROBLEMA_MOVIMIENTO' => 'Problema de movimiento',
    'USUARIO_DATOS' => 'Datos de usuario',
    'OTRO' => 'Otro',
    _ => tipo,
  };
}

String etiquetaEstadoIncidencia(String estado) {
  return switch (estado) {
    'TODOS' => 'Todos',
    'ABIERTAS' => 'Abiertas',
    'PENDIENTE' => 'Pendiente',
    'EN_REVISION' => 'En revisión',
    'RESUELTA' => 'Resuelta',
    'DESCARTADA' => 'Descartada',
    _ => estado,
  };
}

Color colorEstadoIncidencia(String estado) {
  return switch (estado) {
    'PENDIENTE' => ColoresUbb.rojoInstitucional,
    'EN_REVISION' => ColoresUbb.azulApp,
    'RESUELTA' => ColoresUbb.exito,
    'DESCARTADA' => ColoresUbb.textoSecundario,
    _ => ColoresUbb.azulApp,
  };
}
