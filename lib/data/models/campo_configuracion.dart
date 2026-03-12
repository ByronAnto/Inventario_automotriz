class CampoConfiguracion {
  final String id;
  final String nombreCampo;
  final String tabla;
  final String etiqueta;
  final bool obligatorio;
  final bool activo;

  CampoConfiguracion({
    required this.id,
    required this.nombreCampo,
    required this.tabla,
    required this.etiqueta,
    this.obligatorio = false,
    this.activo = true,
  });

  factory CampoConfiguracion.fromJson(Map<String, dynamic> json) {
    return CampoConfiguracion(
      id: json['id'] as String,
      nombreCampo: json['nombre_campo'] as String,
      tabla: json['tabla'] as String,
      etiqueta: json['etiqueta'] as String,
      obligatorio: json['obligatorio'] as bool? ?? false,
      activo: json['activo'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nombre_campo': nombreCampo,
      'tabla': tabla,
      'etiqueta': etiqueta,
      'obligatorio': obligatorio,
      'activo': activo,
    };
  }
}
