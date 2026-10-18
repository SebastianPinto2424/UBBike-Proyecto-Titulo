class BicicleteroApp {
  const BicicleteroApp({
    required this.id,
    required this.nombre,
    required this.ubicacion,
    this.latitud,
    this.longitud,
    required this.capacidad,
    required this.ocupados,
    required this.cuposDisponibles,
    required this.porcentajeUso,
  });

  final String id;
  final String nombre;
  final String ubicacion;
  final double? latitud;
  final double? longitud;
  final int capacidad;
  final int ocupados;
  final int cuposDisponibles;
  final int porcentajeUso;

  bool get tieneCoordenadas => latitud != null && longitud != null;

  factory BicicleteroApp.desdeJson(Map<String, dynamic> json) {
    return BicicleteroApp(
      id: json['id'] as String,
      nombre: json['nombre'] as String,
      ubicacion: json['ubicacion'] as String? ?? 'Ubicación no informada',
      latitud: (json['latitud'] as num?)?.toDouble(),
      longitud: (json['longitud'] as num?)?.toDouble(),
      capacidad: json['capacidad'] as int? ?? 0,
      ocupados: json['ocupados'] as int? ?? 0,
      cuposDisponibles: json['cuposDisponibles'] as int? ?? 0,
      porcentajeUso: json['porcentajeUso'] as int? ?? 0,
    );
  }
}
