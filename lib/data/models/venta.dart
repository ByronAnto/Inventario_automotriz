class Venta {
  final String id;
  final DateTime fecha;
  final String vendedorId;
  final String? clienteNombre;
  final String? clienteTelefono;
  final String metodoPago;
  final double total;
  final String? notas;
  final DateTime createdAt;

  // Relaciones
  final String? vendedorNombre;
  final List<VentaDetalle>? detalles;

  Venta({
    required this.id,
    required this.fecha,
    required this.vendedorId,
    this.clienteNombre,
    this.clienteTelefono,
    required this.metodoPago,
    required this.total,
    this.notas,
    required this.createdAt,
    this.vendedorNombre,
    this.detalles,
  });

  factory Venta.fromJson(Map<String, dynamic> json) {
    final perfil = json['perfiles'] as Map<String, dynamic>?;
    final detallesJson = json['venta_detalle'] as List<dynamic>?;

    return Venta(
      id: json['id'] as String,
      fecha: DateTime.parse(json['fecha'] as String),
      vendedorId: json['vendedor_id'] as String,
      clienteNombre: json['cliente_nombre'] as String?,
      clienteTelefono: json['cliente_telefono'] as String?,
      metodoPago: json['metodo_pago'] as String,
      total: (json['total'] as num).toDouble(),
      notas: json['notas'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      vendedorNombre: perfil?['nombre'] as String?,
      detalles: detallesJson
          ?.map((e) => VentaDetalle.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fecha': fecha.toIso8601String(),
      'vendedor_id': vendedorId,
      'cliente_nombre': clienteNombre,
      'cliente_telefono': clienteTelefono,
      'metodo_pago': metodoPago,
      'total': total,
      'notas': notas,
    };
  }
}

class VentaDetalle {
  final String id;
  final String ventaId;
  final String repuestoId;
  final double precio;

  // Relaciones
  final String? repuestoNombre;
  final String? vehiculoInfo;

  VentaDetalle({
    required this.id,
    required this.ventaId,
    required this.repuestoId,
    required this.precio,
    this.repuestoNombre,
    this.vehiculoInfo,
  });

  factory VentaDetalle.fromJson(Map<String, dynamic> json) {
    final repuesto = json['repuestos'] as Map<String, dynamic>?;
    String? nombre;
    String? vehiculoInfo;
    if (repuesto != null) {
      final catalogo = repuesto['catalogo_partes'] as Map<String, dynamic>?;
      nombre = catalogo?['nombre'] as String?;

      final vehiculo = repuesto['vehiculos'] as Map<String, dynamic>?;
      if (vehiculo != null) {
        final marca = vehiculo['marcas'] as Map<String, dynamic>?;
        final modelo = vehiculo['modelos'] as Map<String, dynamic>?;
        final parts = <String>[
          if (marca != null) marca['nombre'] as String? ?? '',
          if (modelo != null) modelo['nombre'] as String? ?? '',
          if (vehiculo['anio'] != null) vehiculo['anio'].toString(),
        ].where((s) => s.isNotEmpty).toList();
        if (parts.isNotEmpty) vehiculoInfo = parts.join(' ');
      }
    }

    return VentaDetalle(
      id: json['id'] as String,
      ventaId: json['venta_id'] as String,
      repuestoId: json['repuesto_id'] as String,
      precio: (json['precio'] as num).toDouble(),
      repuestoNombre: nombre,
      vehiculoInfo: vehiculoInfo,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'venta_id': ventaId,
      'repuesto_id': repuestoId,
      'precio': precio,
    };
  }
}
