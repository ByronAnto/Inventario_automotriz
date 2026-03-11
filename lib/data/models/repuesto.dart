class Repuesto {
  final String id;
  final String? vehiculoId;
  final String catalogoParteId;
  final String estado; // disponible, vendido, faltante, dañado, intercambiado, descartado
  final String? ubicacionId;
  final double? precioSugerido;
  final String origen; // vehiculo, externo
  final String? proveedorExterno;
  final double? costoExterno;
  final String? notas;
  final List<String>? fotos;
  final DateTime createdAt;

  // Relaciones cargadas
  final String? parteNombre;
  final String? parteCategoria;
  final String? ubicacionNombre;
  final String? vehiculoNombre;
  final String? vehiculoMarca;
  final String? vehiculoModelo;
  final int? vehiculoAnio;

  Repuesto({
    required this.id,
    this.vehiculoId,
    required this.catalogoParteId,
    required this.estado,
    this.ubicacionId,
    this.precioSugerido,
    this.origen = 'vehiculo',
    this.proveedorExterno,
    this.costoExterno,
    this.notas,
    this.fotos,
    required this.createdAt,
    this.parteNombre,
    this.parteCategoria,
    this.ubicacionNombre,
    this.vehiculoNombre,
    this.vehiculoMarca,
    this.vehiculoModelo,
    this.vehiculoAnio,
  });

  factory Repuesto.fromJson(Map<String, dynamic> json) {
    // Extraer datos de relaciones
    final catalogo = json['catalogo_partes'] as Map<String, dynamic>?;
    final ubicacion = json['ubicaciones'] as Map<String, dynamic>?;
    final vehiculo = json['vehiculos'] as Map<String, dynamic>?;

    String? vMarca;
    String? vModelo;
    int? vAnio;
    if (vehiculo != null) {
      vAnio = vehiculo['anio'] as int?;
      final marcaData = vehiculo['marcas'] as Map<String, dynamic>?;
      final modeloData = vehiculo['modelos'] as Map<String, dynamic>?;
      vMarca = marcaData?['nombre'] as String?;
      vModelo = modeloData?['nombre'] as String?;
    }

    return Repuesto(
      id: json['id'] as String,
      vehiculoId: json['vehiculo_id'] as String?,
      catalogoParteId: json['catalogo_parte_id'] as String,
      estado: json['estado'] as String,
      ubicacionId: json['ubicacion_id'] as String?,
      precioSugerido: (json['precio_sugerido'] as num?)?.toDouble(),
      origen: json['origen'] as String? ?? 'vehiculo',
      proveedorExterno: json['proveedor_externo'] as String?,
      costoExterno: (json['costo_externo'] as num?)?.toDouble(),
      notas: json['notas'] as String?,
      fotos: (json['fotos'] as List<dynamic>?)?.map((e) => e as String).toList(),
      createdAt: DateTime.parse(json['created_at'] as String),
      parteNombre: catalogo?['nombre'] as String?,
      parteCategoria: catalogo?['categoria'] as String?,
      ubicacionNombre: ubicacion?['nombre'] as String?,
      vehiculoMarca: vMarca,
      vehiculoModelo: vModelo,
      vehiculoAnio: vAnio,
      vehiculoNombre: vMarca != null ? '$vMarca $vModelo $vAnio' : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'vehiculo_id': vehiculoId,
      'catalogo_parte_id': catalogoParteId,
      'estado': estado,
      'ubicacion_id': ubicacionId,
      'precio_sugerido': precioSugerido,
      'origen': origen,
      'proveedor_externo': proveedorExterno,
      'costo_externo': costoExterno,
      'notas': notas,
      'fotos': fotos,
    };
  }

  Repuesto copyWith({
    String? id,
    String? vehiculoId,
    String? catalogoParteId,
    String? estado,
    String? ubicacionId,
    double? precioSugerido,
    String? origen,
    String? proveedorExterno,
    double? costoExterno,
    String? notas,
    List<String>? fotos,
    DateTime? createdAt,
  }) {
    return Repuesto(
      id: id ?? this.id,
      vehiculoId: vehiculoId ?? this.vehiculoId,
      catalogoParteId: catalogoParteId ?? this.catalogoParteId,
      estado: estado ?? this.estado,
      ubicacionId: ubicacionId ?? this.ubicacionId,
      precioSugerido: precioSugerido ?? this.precioSugerido,
      origen: origen ?? this.origen,
      proveedorExterno: proveedorExterno ?? this.proveedorExterno,
      costoExterno: costoExterno ?? this.costoExterno,
      notas: notas ?? this.notas,
      fotos: fotos ?? this.fotos,
      createdAt: createdAt ?? this.createdAt,
      parteNombre: parteNombre,
      parteCategoria: parteCategoria,
      ubicacionNombre: ubicacionNombre,
      vehiculoMarca: vehiculoMarca,
      vehiculoModelo: vehiculoModelo,
      vehiculoAnio: vehiculoAnio,
      vehiculoNombre: vehiculoNombre,
    );
  }
}
