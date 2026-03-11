class Ubicacion {
  final String id;
  final String nombre;
  final String? direccion;
  final String? telefono;
  final bool activo;

  Ubicacion({
    required this.id,
    required this.nombre,
    this.direccion,
    this.telefono,
    this.activo = true,
  });

  factory Ubicacion.fromJson(Map<String, dynamic> json) {
    return Ubicacion(
      id: json['id'] as String,
      nombre: json['nombre'] as String,
      direccion: json['direccion'] as String?,
      telefono: json['telefono'] as String?,
      activo: json['activo'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nombre': nombre,
      'direccion': direccion,
      'telefono': telefono,
      'activo': activo,
    };
  }
}
