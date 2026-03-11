class Perfil {
  final String id;
  final String userId;
  final String nombre;
  final String? telefono;
  final String? email;
  final String rol; // administrador, vendedor, mecanico
  final double? comisionPorcentaje;
  final bool activo;
  final DateTime createdAt;

  Perfil({
    required this.id,
    required this.userId,
    required this.nombre,
    this.telefono,
    this.email,
    required this.rol,
    this.comisionPorcentaje,
    this.activo = true,
    required this.createdAt,
  });

  factory Perfil.fromJson(Map<String, dynamic> json) {
    return Perfil(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      nombre: json['nombre'] as String,
      telefono: json['telefono'] as String?,
      email: json['email'] as String?,
      rol: json['rol'] as String,
      comisionPorcentaje: (json['comision_porcentaje'] as num?)?.toDouble(),
      activo: json['activo'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'nombre': nombre,
      'telefono': telefono,
      'email': email,
      'rol': rol,
      'comision_porcentaje': comisionPorcentaje,
      'activo': activo,
    };
  }

  Perfil copyWith({
    String? id,
    String? userId,
    String? nombre,
    String? telefono,
    String? email,
    String? rol,
    double? comisionPorcentaje,
    bool? activo,
    DateTime? createdAt,
  }) {
    return Perfil(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      nombre: nombre ?? this.nombre,
      telefono: telefono ?? this.telefono,
      email: email ?? this.email,
      rol: rol ?? this.rol,
      comisionPorcentaje: comisionPorcentaje ?? this.comisionPorcentaje,
      activo: activo ?? this.activo,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
