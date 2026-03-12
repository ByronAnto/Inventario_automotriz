class Vehiculo {
  final String id;
  final String marcaId;
  final String modeloId;
  final String tipoVehiculoId;
  final int anio;
  final String? color;
  final String? vin;
  final String? placa;
  final String estado; // dinámico desde estados_vehiculo
  final String completitud; // completo, incompleto
  final double costoCompra;
  final String? proveedor;
  final String? proveedorId;
  final double? valorGrua;
  final double? comisionViaje;
  final String? compradorId;
  final DateTime fechaIngreso;
  final String? notas;
  final List<String>? fotos;
  final String? ubicacionId;
  final bool condicionesRegistradas;
  final String? registradoPor;
  final DateTime createdAt;

  // Relaciones cargadas
  final String? marcaNombre;
  final String? modeloNombre;
  final String? tipoVehiculoNombre;
  final String? ubicacionNombre;
  final String? proveedorNombre;
  final String? compradorNombre;

  Vehiculo({
    required this.id,
    required this.marcaId,
    required this.modeloId,
    required this.tipoVehiculoId,
    required this.anio,
    this.color,
    this.vin,
    this.placa,
    required this.estado,
    this.completitud = 'completo',
    required this.costoCompra,
    this.proveedor,
    this.proveedorId,
    this.valorGrua,
    this.comisionViaje,
    this.compradorId,
    required this.fechaIngreso,
    this.notas,
    this.fotos,
    this.ubicacionId,
    this.condicionesRegistradas = false,
    this.registradoPor,
    required this.createdAt,
    this.marcaNombre,
    this.modeloNombre,
    this.tipoVehiculoNombre,
    this.ubicacionNombre,
    this.proveedorNombre,
    this.compradorNombre,
  });

  factory Vehiculo.fromJson(Map<String, dynamic> json) {
    return Vehiculo(
      id: json['id'] as String,
      marcaId: json['marca_id'] as String,
      modeloId: json['modelo_id'] as String,
      tipoVehiculoId: json['tipo_vehiculo_id'] as String,
      anio: json['anio'] as int,
      color: json['color'] as String?,
      vin: json['vin'] as String?,
      placa: json['placa'] as String?,
      estado: json['estado'] as String,
      completitud: json['completitud'] as String? ?? 'completo',
      costoCompra: (json['costo_compra'] as num).toDouble(),
      proveedor: json['proveedor'] as String?,
      proveedorId: json['proveedor_id'] as String?,
      valorGrua: (json['valor_grua'] as num?)?.toDouble(),
      comisionViaje: (json['comision_viaje'] as num?)?.toDouble(),
      compradorId: json['comprador_id'] as String?,
      fechaIngreso: DateTime.parse(json['fecha_ingreso'] as String),
      notas: json['notas'] as String?,
      fotos: (json['fotos'] as List<dynamic>?)?.map((e) => e as String).toList(),
      ubicacionId: json['ubicacion_id'] as String?,
      condicionesRegistradas: json['condiciones_registradas'] as bool? ?? false,
      registradoPor: json['registrado_por'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      marcaNombre: json['marcas'] != null
          ? (json['marcas'] as Map<String, dynamic>)['nombre'] as String?
          : null,
      modeloNombre: json['modelos'] != null
          ? (json['modelos'] as Map<String, dynamic>)['nombre'] as String?
          : null,
      tipoVehiculoNombre: json['tipos_vehiculo'] != null
          ? (json['tipos_vehiculo'] as Map<String, dynamic>)['nombre'] as String?
          : null,
      ubicacionNombre: json['ubicaciones'] != null
          ? (json['ubicaciones'] as Map<String, dynamic>)['nombre'] as String?
          : null,
      proveedorNombre: json['proveedores'] != null
          ? (json['proveedores'] as Map<String, dynamic>)['nombre'] as String?
          : null,
      compradorNombre: json['comprador:perfiles'] != null
          ? (json['comprador:perfiles'] as Map<String, dynamic>)['nombre'] as String?
          : (json['comprador_perfil'] != null
              ? (json['comprador_perfil'] as Map<String, dynamic>)['nombre'] as String?
              : null),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'marca_id': marcaId,
      'modelo_id': modeloId,
      'tipo_vehiculo_id': tipoVehiculoId,
      'anio': anio,
      'color': color,
      'vin': vin,
      'placa': placa,
      'estado': estado,
      'completitud': completitud,
      'costo_compra': costoCompra,
      'proveedor': proveedor,
      'proveedor_id': proveedorId,
      'valor_grua': valorGrua,
      'comision_viaje': comisionViaje,
      'comprador_id': compradorId,
      'fecha_ingreso': fechaIngreso.toIso8601String(),
      'notas': notas,
      'fotos': fotos,
      'ubicacion_id': ubicacionId,
      'condiciones_registradas': condicionesRegistradas,
      'registrado_por': registradoPor,
    };
  }

  String get nombreCompleto => '${marcaNombre ?? ''} ${modeloNombre ?? ''} $anio'.trim();

  Vehiculo copyWith({
    String? id,
    String? marcaId,
    String? modeloId,
    String? tipoVehiculoId,
    int? anio,
    String? color,
    String? vin,
    String? placa,
    String? estado,
    String? completitud,
    double? costoCompra,
    String? proveedor,
    String? proveedorId,
    double? valorGrua,
    double? comisionViaje,
    String? compradorId,
    DateTime? fechaIngreso,
    String? notas,
    List<String>? fotos,
    String? ubicacionId,
    bool? condicionesRegistradas,
    String? registradoPor,
    DateTime? createdAt,
  }) {
    return Vehiculo(
      id: id ?? this.id,
      marcaId: marcaId ?? this.marcaId,
      modeloId: modeloId ?? this.modeloId,
      tipoVehiculoId: tipoVehiculoId ?? this.tipoVehiculoId,
      anio: anio ?? this.anio,
      color: color ?? this.color,
      vin: vin ?? this.vin,
      placa: placa ?? this.placa,
      estado: estado ?? this.estado,
      completitud: completitud ?? this.completitud,
      costoCompra: costoCompra ?? this.costoCompra,
      proveedor: proveedor ?? this.proveedor,
      proveedorId: proveedorId ?? this.proveedorId,
      valorGrua: valorGrua ?? this.valorGrua,
      comisionViaje: comisionViaje ?? this.comisionViaje,
      compradorId: compradorId ?? this.compradorId,
      fechaIngreso: fechaIngreso ?? this.fechaIngreso,
      notas: notas ?? this.notas,
      fotos: fotos ?? this.fotos,
      ubicacionId: ubicacionId ?? this.ubicacionId,
      condicionesRegistradas: condicionesRegistradas ?? this.condicionesRegistradas,
      registradoPor: registradoPor ?? this.registradoPor,
      createdAt: createdAt ?? this.createdAt,
      marcaNombre: marcaNombre,
      modeloNombre: modeloNombre,
      tipoVehiculoNombre: tipoVehiculoNombre,
      ubicacionNombre: ubicacionNombre,
      proveedorNombre: proveedorNombre,
      compradorNombre: compradorNombre,
    );
  }
}
