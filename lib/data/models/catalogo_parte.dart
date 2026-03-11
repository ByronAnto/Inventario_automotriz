class CatalogoParte {
  final String id;
  final String nombre;
  final String categoria;
  final bool activoPorDefecto;
  final int orden;

  CatalogoParte({
    required this.id,
    required this.nombre,
    required this.categoria,
    this.activoPorDefecto = true,
    this.orden = 0,
  });

  factory CatalogoParte.fromJson(Map<String, dynamic> json) {
    return CatalogoParte(
      id: json['id'] as String,
      nombre: json['nombre'] as String,
      categoria: json['categoria'] as String,
      activoPorDefecto: json['activo_por_defecto'] as bool? ?? true,
      orden: json['orden'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nombre': nombre,
      'categoria': categoria,
      'activo_por_defecto': activoPorDefecto,
      'orden': orden,
    };
  }
}

class PlantillaTipoVehiculo {
  final String id;
  final String tipoVehiculoId;
  final String parteId;
  final bool activo;

  // Relaciones cargadas
  final CatalogoParte? parte;

  PlantillaTipoVehiculo({
    required this.id,
    required this.tipoVehiculoId,
    required this.parteId,
    this.activo = true,
    this.parte,
  });

  factory PlantillaTipoVehiculo.fromJson(Map<String, dynamic> json) {
    return PlantillaTipoVehiculo(
      id: json['id'] as String,
      tipoVehiculoId: json['tipo_vehiculo_id'] as String,
      parteId: json['parte_id'] as String,
      activo: json['activo'] as bool? ?? true,
      parte: json['catalogo_partes'] != null
          ? CatalogoParte.fromJson(json['catalogo_partes'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tipo_vehiculo_id': tipoVehiculoId,
      'parte_id': parteId,
      'activo': activo,
    };
  }
}
