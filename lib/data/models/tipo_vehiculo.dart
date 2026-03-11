class TipoVehiculo {
  final String id;
  final String nombre;
  final String? descripcion;
  final String? icono;
  final bool activo;

  TipoVehiculo({
    required this.id,
    required this.nombre,
    this.descripcion,
    this.icono,
    this.activo = true,
  });

  factory TipoVehiculo.fromJson(Map<String, dynamic> json) {
    return TipoVehiculo(
      id: json['id'] as String,
      nombre: json['nombre'] as String,
      descripcion: json['descripcion'] as String?,
      icono: json['icono'] as String?,
      activo: json['activo'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nombre': nombre,
      'descripcion': descripcion,
      'icono': icono,
      'activo': activo,
    };
  }
}
