String etiquetaPeriodoFiltro(String periodo) {
  return switch (periodo) {
    'DIA' => 'Día',
    'SEMANA' => 'Semana',
    'MES' => 'Mes',
    'ANIO' => 'Año',
    _ => periodo,
  };
}

String etiquetaTipoMovimientoFiltro(String tipo) {
  return switch (tipo) {
    'TODOS' => 'Todos los movimientos',
    'INGRESO' => 'Ingresos',
    'RETIRO' => 'Retiros',
    _ => tipo,
  };
}

String etiquetaEstadoMovimientoFiltro(String estado) {
  return switch (estado) {
    'TODOS' => 'Todos los resultados',
    'CONFIRMADO' => 'Confirmados',
    'DENEGADO' => 'Denegados',
    _ => estado,
  };
}

String etiquetaOrigenMovimientoFiltro(String origen) {
  return switch (origen) {
    'TODOS' => 'Todos los orígenes',
    'QR' => 'QR',
    'MANUAL' => 'Manual',
    _ => origen,
  };
}
