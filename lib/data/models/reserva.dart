class Reserva {
  final String id;
  final String repuestoId;
  final String clienteNombre;
  final String? clienteTelefono;
  final double montoAbono;
  final DateTime fechaReserva;
  final DateTime fechaExpiracion;
  final String estado; // activa, completada, expirada, cancelada
  final String vendedorId;
  final String? notas;
  final DateTime createdAt;

  // Relaciones
  final String? repuestoNombre;
  final String? repuestoCategoria;
  final double? repuestoPrecio;
  final String? vendedorNombre;
  final String? vehiculoInfo;

  Reserva({
    required this.id,
    required this.repuestoId,
    required this.clienteNombre,
    this.clienteTelefono,
    required this.montoAbono,
    required this.fechaReserva,
    required this.fechaExpiracion,
    required this.estado,
    required this.vendedorId,
    this.notas,
    required this.createdAt,
    this.repuestoNombre,
    this.repuestoCategoria,
    this.repuestoPrecio,
    this.vendedorNombre,
    this.vehiculoInfo,
  });

  bool get estaActiva => estado == 'activa';
  bool get estaExpirada =>
      estado == 'activa' && DateTime.now().isAfter(fechaExpiracion);

  int get diasRestantes {
    final diff = fechaExpiracion.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff;
  }

  factory Reserva.fromJson(Map<String, dynamic> json) {
    // Parse nested relations
    final repuesto = json['repuestos'];
    String? repNombre;
    String? repCategoria;
    double? repPrecio;
    String? vehiculoInfo;

    if (repuesto != null) {
      repPrecio = (repuesto['precio_sugerido'] as num?)?.toDouble();

      final parte = repuesto['catalogo_partes'];
      if (parte != null) {
        repNombre = parte['nombre'] as String?;
        repCategoria = parte['categoria'] as String?;
      }

      final vehiculo = repuesto['vehiculos'];
      if (vehiculo != null) {
        final marca = vehiculo['marcas']?['nombre'] ?? '';
        final modelo = vehiculo['modelos']?['nombre'] ?? '';
        final anio = vehiculo['anio'] ?? '';
        vehiculoInfo = '$marca $modelo $anio'.trim();
      }
    }

    final perfil = json['perfiles'];
    String? vendedorNombre;
    if (perfil != null) {
      vendedorNombre = perfil['nombre'] as String?;
    }

    return Reserva(
      id: json['id'] as String,
      repuestoId: json['repuesto_id'] as String,
      clienteNombre: json['cliente_nombre'] as String,
      clienteTelefono: json['cliente_telefono'] as String?,
      montoAbono: (json['monto_abono'] as num).toDouble(),
      fechaReserva: DateTime.parse(json['fecha_reserva'] as String),
      fechaExpiracion: DateTime.parse(json['fecha_expiracion'] as String),
      estado: json['estado'] as String,
      vendedorId: json['vendedor_id'] as String,
      notas: json['notas'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      repuestoNombre: repNombre,
      repuestoCategoria: repCategoria,
      repuestoPrecio: repPrecio,
      vendedorNombre: vendedorNombre,
      vehiculoInfo: vehiculoInfo,
    );
  }
}
