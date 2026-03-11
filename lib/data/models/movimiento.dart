class Movimiento {
  final String id;
  final String repuestoId;
  final String tipo; // ingreso_vehiculo, ingreso_externo, venta, intercambio, traslado, descarte
  final DateTime fecha;
  final String usuarioId;
  final String? ubicacionOrigenId;
  final String? ubicacionDestinoId;
  final String? ventaId;
  final String? intercambioId;
  final String? notas;
  final DateTime createdAt;

  // Relaciones
  final String? usuarioNombre;
  final String? repuestoNombre;
  final String? ubicacionOrigenNombre;
  final String? ubicacionDestinoNombre;

  Movimiento({
    required this.id,
    required this.repuestoId,
    required this.tipo,
    required this.fecha,
    required this.usuarioId,
    this.ubicacionOrigenId,
    this.ubicacionDestinoId,
    this.ventaId,
    this.intercambioId,
    this.notas,
    required this.createdAt,
    this.usuarioNombre,
    this.repuestoNombre,
    this.ubicacionOrigenNombre,
    this.ubicacionDestinoNombre,
  });

  factory Movimiento.fromJson(Map<String, dynamic> json) {
    return Movimiento(
      id: json['id'] as String,
      repuestoId: json['repuesto_id'] as String,
      tipo: json['tipo'] as String,
      fecha: DateTime.parse(json['fecha'] as String),
      usuarioId: json['usuario_id'] as String,
      ubicacionOrigenId: json['ubicacion_origen_id'] as String?,
      ubicacionDestinoId: json['ubicacion_destino_id'] as String?,
      ventaId: json['venta_id'] as String?,
      intercambioId: json['intercambio_id'] as String?,
      notas: json['notas'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      usuarioNombre: json['perfiles'] != null
          ? (json['perfiles'] as Map<String, dynamic>)['nombre'] as String?
          : null,
      repuestoNombre: json['repuestos'] != null
          ? _extractRepuestoNombre(json['repuestos'] as Map<String, dynamic>)
          : null,
    );
  }

  static String? _extractRepuestoNombre(Map<String, dynamic> repuesto) {
    final catalogo = repuesto['catalogo_partes'] as Map<String, dynamic>?;
    return catalogo?['nombre'] as String?;
  }

  Map<String, dynamic> toJson() {
    return {
      'repuesto_id': repuestoId,
      'tipo': tipo,
      'fecha': fecha.toIso8601String(),
      'usuario_id': usuarioId,
      'ubicacion_origen_id': ubicacionOrigenId,
      'ubicacion_destino_id': ubicacionDestinoId,
      'venta_id': ventaId,
      'intercambio_id': intercambioId,
      'notas': notas,
    };
  }
}

class Intercambio {
  final String id;
  final String movimientoSalidaId;
  final String movimientoEntradaId;
  final String? notas;
  final DateTime createdAt;

  Intercambio({
    required this.id,
    required this.movimientoSalidaId,
    required this.movimientoEntradaId,
    this.notas,
    required this.createdAt,
  });

  factory Intercambio.fromJson(Map<String, dynamic> json) {
    return Intercambio(
      id: json['id'] as String,
      movimientoSalidaId: json['movimiento_salida_id'] as String,
      movimientoEntradaId: json['movimiento_entrada_id'] as String,
      notas: json['notas'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'movimiento_salida_id': movimientoSalidaId,
      'movimiento_entrada_id': movimientoEntradaId,
      'notas': notas,
    };
  }
}
