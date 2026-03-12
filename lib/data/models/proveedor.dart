class Proveedor {
  final String id;
  final String nombre;
  final String? telefono;
  final String? direccion;
  final String? notas;
  final bool activo;
  final DateTime createdAt;

  Proveedor({
    required this.id,
    required this.nombre,
    this.telefono,
    this.direccion,
    this.notas,
    this.activo = true,
    required this.createdAt,
  });

  factory Proveedor.fromJson(Map<String, dynamic> json) {
    return Proveedor(
      id: json['id'] as String,
      nombre: json['nombre'] as String,
      telefono: json['telefono'] as String?,
      direccion: json['direccion'] as String?,
      notas: json['notas'] as String?,
      activo: json['activo'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nombre': nombre,
      'telefono': telefono,
      'direccion': direccion,
      'notas': notas,
      'activo': activo,
    };
  }
}
