// ============================================
// Constantes de la aplicación
// ============================================

class AppConstants {
  static const String appName = 'AutoPartes Inventory';
  static const String appVersion = '1.0.0';

  // Roles de usuario
  static const String rolAdmin = 'administrador';
  static const String rolVendedor = 'vendedor';
  static const String rolMecanico = 'mecanico';

  // Estados de repuesto
  static const String estadoDisponible = 'disponible';
  static const String estadoVendido = 'vendido';
  static const String estadoFaltante = 'faltante';
  static const String estadoDanado = 'dañado';
  static const String estadoIntercambiado = 'intercambiado';
  static const String estadoDescartado = 'descartado';

  // Estados de vehículo
  static const String vehiculoSiniestrado = 'siniestrado';
  static const String vehiculoBaja = 'dado_de_baja';
  static const String vehiculoIncompleto = 'incompleto';

  // Tipos de movimiento
  static const String movIngresoVehiculo = 'ingreso_vehiculo';
  static const String movIngresoExterno = 'ingreso_externo';
  static const String movVenta = 'venta';
  static const String movIntercambio = 'intercambio';
  static const String movTraslado = 'traslado';
  static const String movDescarte = 'descarte';

  // Orígenes de repuesto
  static const String origenVehiculo = 'vehiculo';
  static const String origenExterno = 'externo';

  // Métodos de pago
  static const List<String> metodosPago = [
    'Efectivo',
    'Transferencia',
    'Tarjeta',
    'Cheque',
    'Crédito',
  ];

  // Categorías de partes
  static const List<String> categorias = [
    'Carrocería exterior',
    'Vidrios y espejos',
    'Iluminación',
    'Motor y mecánica',
    'Transmisión',
    'Suspensión y dirección',
    'Frenos',
    'Interior',
    'Sistema eléctrico',
    'Ruedas',
    'Otros',
  ];
}
