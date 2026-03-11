class Marca {
  final String id;
  final String nombre;
  final bool activo;

  Marca({
    required this.id,
    required this.nombre,
    this.activo = true,
  });

  factory Marca.fromJson(Map<String, dynamic> json) {
    return Marca(
      id: json['id'] as String,
      nombre: json['nombre'] as String,
      activo: json['activo'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nombre': nombre,
      'activo': activo,
    };
  }
}

class Modelo {
  final String id;
  final String marcaId;
  final String nombre;
  final bool activo;

  // Relación
  final Marca? marca;

  Modelo({
    required this.id,
    required this.marcaId,
    required this.nombre,
    this.activo = true,
    this.marca,
  });

  factory Modelo.fromJson(Map<String, dynamic> json) {
    return Modelo(
      id: json['id'] as String,
      marcaId: json['marca_id'] as String,
      nombre: json['nombre'] as String,
      activo: json['activo'] as bool? ?? true,
      marca: json['marcas'] != null
          ? Marca.fromJson(json['marcas'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'marca_id': marcaId,
      'nombre': nombre,
      'activo': activo,
    };
  }
}
