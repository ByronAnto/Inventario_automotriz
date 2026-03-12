class EstadoVehiculo {
  final String id;
  final String nombre;
  final String valor;
  final String? descripcion;
  final String color;
  final bool activo;
  final int orden;

  EstadoVehiculo({
    required this.id,
    required this.nombre,
    required this.valor,
    this.descripcion,
    this.color = '#757575',
    this.activo = true,
    this.orden = 0,
  });

  factory EstadoVehiculo.fromJson(Map<String, dynamic> json) {
    return EstadoVehiculo(
      id: json['id'] as String,
      nombre: json['nombre'] as String,
      valor: json['valor'] as String,
      descripcion: json['descripcion'] as String?,
      color: json['color'] as String? ?? '#757575',
      activo: json['activo'] as bool? ?? true,
      orden: json['orden'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nombre': nombre,
      'valor': valor,
      'descripcion': descripcion,
      'color': color,
      'activo': activo,
      'orden': orden,
    };
  }
}
