-- ============================================
-- AutoPartes Inventory - Supabase Schema
-- Ejecutar en el SQL Editor de Supabase
-- ============================================

-- Extensiones
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================
-- 1. PERFILES (vinculado a auth.users)
-- ============================================
CREATE TABLE IF NOT EXISTS perfiles (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  nombre TEXT NOT NULL,
  telefono TEXT,
  email TEXT,
  rol TEXT NOT NULL DEFAULT 'vendedor' CHECK (rol IN ('administrador', 'vendedor', 'mecanico')),
  comision_porcentaje NUMERIC(5,2),
  activo BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(user_id)
);

-- ============================================
-- 2. TIPOS DE VEHÍCULO
-- ============================================
CREATE TABLE IF NOT EXISTS tipos_vehiculo (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  nombre TEXT NOT NULL UNIQUE,
  descripcion TEXT,
  icono TEXT,
  activo BOOLEAN NOT NULL DEFAULT true
);

-- ============================================
-- 3. CATÁLOGO DE PARTES (catálogo maestro)
-- ============================================
CREATE TABLE IF NOT EXISTS catalogo_partes (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  nombre TEXT NOT NULL,
  categoria TEXT NOT NULL,
  activo_por_defecto BOOLEAN NOT NULL DEFAULT true,
  orden INT NOT NULL DEFAULT 0,
  UNIQUE(nombre, categoria)
);

-- ============================================
-- 4. PLANTILLA TIPO VEHÍCULO (partes por tipo)
-- ============================================
CREATE TABLE IF NOT EXISTS plantilla_tipo_vehiculo (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  tipo_vehiculo_id UUID NOT NULL REFERENCES tipos_vehiculo(id) ON DELETE CASCADE,
  parte_id UUID NOT NULL REFERENCES catalogo_partes(id) ON DELETE CASCADE,
  activo BOOLEAN NOT NULL DEFAULT true,
  UNIQUE(tipo_vehiculo_id, parte_id)
);

-- ============================================
-- 5. MARCAS
-- ============================================
CREATE TABLE IF NOT EXISTS marcas (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  nombre TEXT NOT NULL UNIQUE,
  activo BOOLEAN NOT NULL DEFAULT true
);

-- ============================================
-- 6. MODELOS
-- ============================================
CREATE TABLE IF NOT EXISTS modelos (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  marca_id UUID NOT NULL REFERENCES marcas(id) ON DELETE CASCADE,
  nombre TEXT NOT NULL,
  activo BOOLEAN NOT NULL DEFAULT true,
  UNIQUE(marca_id, nombre)
);

-- ============================================
-- 7. UBICACIONES
-- ============================================
CREATE TABLE IF NOT EXISTS ubicaciones (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  nombre TEXT NOT NULL UNIQUE,
  direccion TEXT,
  telefono TEXT,
  activo BOOLEAN NOT NULL DEFAULT true
);

-- ============================================
-- 8. PROVEEDORES
-- ============================================
CREATE TABLE IF NOT EXISTS proveedores (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  nombre TEXT NOT NULL UNIQUE,
  telefono TEXT,
  direccion TEXT,
  notas TEXT,
  activo BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================
-- 9. ESTADOS DE VEHÍCULO (dinámico)
-- ============================================
CREATE TABLE IF NOT EXISTS estados_vehiculo (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  nombre TEXT NOT NULL UNIQUE,
  valor TEXT NOT NULL UNIQUE,
  descripcion TEXT,
  color TEXT DEFAULT '#757575',
  activo BOOLEAN NOT NULL DEFAULT true,
  orden INT NOT NULL DEFAULT 0
);

-- ============================================
-- 10. CONFIGURACIÓN DE CAMPOS (obligatorio/opcional)
-- ============================================
CREATE TABLE IF NOT EXISTS campo_configuracion (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  nombre_campo TEXT NOT NULL,
  tabla TEXT NOT NULL,
  etiqueta TEXT NOT NULL,
  obligatorio BOOLEAN NOT NULL DEFAULT false,
  activo BOOLEAN NOT NULL DEFAULT true,
  UNIQUE(nombre_campo, tabla)
);

-- ============================================
-- 11. VEHÍCULOS
-- ============================================
CREATE TABLE IF NOT EXISTS vehiculos (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  marca_id UUID NOT NULL REFERENCES marcas(id),
  modelo_id UUID NOT NULL REFERENCES modelos(id),
  tipo_vehiculo_id UUID NOT NULL REFERENCES tipos_vehiculo(id),
  anio INT NOT NULL CHECK (anio >= 1900 AND anio <= 2100),
  color TEXT,
  vin TEXT,
  placa TEXT,
  estado TEXT NOT NULL DEFAULT 'incompleto',
  completitud TEXT NOT NULL DEFAULT 'completo' CHECK (completitud IN ('completo', 'incompleto')),
  costo_compra NUMERIC(12,2) NOT NULL DEFAULT 0,
  proveedor TEXT,
  proveedor_id UUID REFERENCES proveedores(id),
  valor_grua NUMERIC(12,2),
  comision_viaje NUMERIC(12,2),
  comprador_id UUID REFERENCES perfiles(id),
  fecha_ingreso DATE NOT NULL DEFAULT CURRENT_DATE,
  notas TEXT,
  fotos TEXT[],
  ubicacion_id UUID REFERENCES ubicaciones(id),
  condiciones_registradas BOOLEAN NOT NULL DEFAULT false,
  registrado_por UUID REFERENCES perfiles(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================
-- 12. REPUESTOS (inventario de partes)
-- ============================================
CREATE TABLE IF NOT EXISTS repuestos (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  vehiculo_id UUID REFERENCES vehiculos(id) ON DELETE SET NULL,
  catalogo_parte_id UUID NOT NULL REFERENCES catalogo_partes(id),
  estado TEXT NOT NULL DEFAULT 'disponible' CHECK (estado IN ('disponible', 'vendido', 'faltante', 'dañado', 'intercambiado', 'descartado', 'reservado')),
  ubicacion_id UUID REFERENCES ubicaciones(id),
  precio_sugerido NUMERIC(12,2),
  origen TEXT NOT NULL DEFAULT 'vehiculo' CHECK (origen IN ('vehiculo', 'externo')),
  proveedor_externo TEXT,
  costo_externo NUMERIC(12,2),
  -- Info del vehículo de origen para repuestos externos
  ext_marca_id UUID REFERENCES marcas(id),
  ext_modelo_id UUID REFERENCES modelos(id),
  ext_anio INT,
  notas TEXT,
  fotos TEXT[],
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================
-- 10. VENTAS
-- ============================================
CREATE TABLE IF NOT EXISTS ventas (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  fecha TIMESTAMPTZ NOT NULL DEFAULT now(),
  vendedor_id UUID NOT NULL REFERENCES perfiles(id),
  cliente_nombre TEXT,
  cliente_telefono TEXT,
  metodo_pago TEXT NOT NULL DEFAULT 'Efectivo' CHECK (metodo_pago IN ('Efectivo', 'Transferencia', 'Tarjeta', 'Cheque', 'Crédito')),
  total NUMERIC(12,2) NOT NULL DEFAULT 0,
  notas TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================
-- 11. DETALLE DE VENTA
-- ============================================
CREATE TABLE IF NOT EXISTS venta_detalle (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  venta_id UUID NOT NULL REFERENCES ventas(id) ON DELETE CASCADE,
  repuesto_id UUID NOT NULL REFERENCES repuestos(id),
  precio NUMERIC(12,2) NOT NULL
);

-- ============================================
-- 12. MOVIMIENTOS
-- ============================================
CREATE TABLE IF NOT EXISTS movimientos (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  repuesto_id UUID NOT NULL REFERENCES repuestos(id),
  tipo TEXT NOT NULL CHECK (tipo IN ('ingreso_vehiculo', 'ingreso_externo', 'venta', 'intercambio', 'traslado', 'descarte', 'reserva', 'devolucion')),
  fecha TIMESTAMPTZ NOT NULL DEFAULT now(),
  usuario_id UUID NOT NULL REFERENCES perfiles(id),
  ubicacion_origen_id UUID REFERENCES ubicaciones(id),
  ubicacion_destino_id UUID REFERENCES ubicaciones(id),
  venta_id UUID REFERENCES ventas(id) ON DELETE SET NULL,
  intercambio_id UUID,
  notas TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================
-- 13. INTERCAMBIOS
-- ============================================
CREATE TABLE IF NOT EXISTS intercambios (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  movimiento_salida_id UUID NOT NULL REFERENCES movimientos(id),
  movimiento_entrada_id UUID NOT NULL REFERENCES movimientos(id),
  notas TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Agregar FK diferida de movimientos → intercambios
-- (se crea la tabla intercambios después de movimientos,
--  así que eliminamos la FK inline y la agregamos así)
DO $$ BEGIN
  ALTER TABLE movimientos DROP CONSTRAINT IF EXISTS movimientos_intercambio_id_fkey;
  ALTER TABLE movimientos ADD CONSTRAINT movimientos_intercambio_id_fkey
    FOREIGN KEY (intercambio_id) REFERENCES intercambios(id) ON DELETE SET NULL DEFERRABLE INITIALLY DEFERRED;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ============================================
-- ÍNDICES
-- ============================================
CREATE INDEX IF NOT EXISTS idx_perfiles_user_id ON perfiles(user_id);
CREATE INDEX IF NOT EXISTS idx_perfiles_rol ON perfiles(rol);
CREATE INDEX IF NOT EXISTS idx_modelos_marca_id ON modelos(marca_id);
CREATE INDEX IF NOT EXISTS idx_plantilla_tipo_vehiculo_id ON plantilla_tipo_vehiculo(tipo_vehiculo_id);
CREATE INDEX IF NOT EXISTS idx_vehiculos_marca_id ON vehiculos(marca_id);
CREATE INDEX IF NOT EXISTS idx_vehiculos_modelo_id ON vehiculos(modelo_id);
CREATE INDEX IF NOT EXISTS idx_vehiculos_tipo_vehiculo_id ON vehiculos(tipo_vehiculo_id);
CREATE INDEX IF NOT EXISTS idx_vehiculos_ubicacion_id ON vehiculos(ubicacion_id);
CREATE INDEX IF NOT EXISTS idx_vehiculos_estado ON vehiculos(estado);
CREATE INDEX IF NOT EXISTS idx_vehiculos_proveedor_id ON vehiculos(proveedor_id);
CREATE INDEX IF NOT EXISTS idx_vehiculos_comprador_id ON vehiculos(comprador_id);
CREATE INDEX IF NOT EXISTS idx_repuestos_vehiculo_id ON repuestos(vehiculo_id);
CREATE INDEX IF NOT EXISTS idx_repuestos_catalogo_parte_id ON repuestos(catalogo_parte_id);
CREATE INDEX IF NOT EXISTS idx_repuestos_estado ON repuestos(estado);
CREATE INDEX IF NOT EXISTS idx_repuestos_ubicacion_id ON repuestos(ubicacion_id);
CREATE INDEX IF NOT EXISTS idx_repuestos_origen ON repuestos(origen);
CREATE INDEX IF NOT EXISTS idx_repuestos_ext_marca_id ON repuestos(ext_marca_id);
CREATE INDEX IF NOT EXISTS idx_repuestos_ext_modelo_id ON repuestos(ext_modelo_id);
CREATE INDEX IF NOT EXISTS idx_ventas_vendedor_id ON ventas(vendedor_id);
CREATE INDEX IF NOT EXISTS idx_ventas_fecha ON ventas(fecha);
CREATE INDEX IF NOT EXISTS idx_venta_detalle_venta_id ON venta_detalle(venta_id);
CREATE INDEX IF NOT EXISTS idx_venta_detalle_repuesto_id ON venta_detalle(repuesto_id);
CREATE INDEX IF NOT EXISTS idx_movimientos_repuesto_id ON movimientos(repuesto_id);
CREATE INDEX IF NOT EXISTS idx_movimientos_tipo ON movimientos(tipo);
CREATE INDEX IF NOT EXISTS idx_movimientos_fecha ON movimientos(fecha);
CREATE INDEX IF NOT EXISTS idx_movimientos_usuario_id ON movimientos(usuario_id);

-- ============================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================

-- Habilitar RLS en todas las tablas
ALTER TABLE perfiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE tipos_vehiculo ENABLE ROW LEVEL SECURITY;
ALTER TABLE catalogo_partes ENABLE ROW LEVEL SECURITY;
ALTER TABLE plantilla_tipo_vehiculo ENABLE ROW LEVEL SECURITY;
ALTER TABLE marcas ENABLE ROW LEVEL SECURITY;
ALTER TABLE modelos ENABLE ROW LEVEL SECURITY;
ALTER TABLE ubicaciones ENABLE ROW LEVEL SECURITY;
ALTER TABLE proveedores ENABLE ROW LEVEL SECURITY;
ALTER TABLE estados_vehiculo ENABLE ROW LEVEL SECURITY;
ALTER TABLE campo_configuracion ENABLE ROW LEVEL SECURITY;
ALTER TABLE vehiculos ENABLE ROW LEVEL SECURITY;
ALTER TABLE repuestos ENABLE ROW LEVEL SECURITY;
ALTER TABLE ventas ENABLE ROW LEVEL SECURITY;
ALTER TABLE venta_detalle ENABLE ROW LEVEL SECURITY;
ALTER TABLE movimientos ENABLE ROW LEVEL SECURITY;
ALTER TABLE intercambios ENABLE ROW LEVEL SECURITY;

-- Función helper para obtener el rol del usuario actual
CREATE OR REPLACE FUNCTION get_user_role()
RETURNS TEXT AS $$
  SELECT rol FROM perfiles WHERE user_id = auth.uid() LIMIT 1;
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- Función helper para obtener el perfil_id del usuario actual
CREATE OR REPLACE FUNCTION get_perfil_id()
RETURNS UUID AS $$
  SELECT id FROM perfiles WHERE user_id = auth.uid() LIMIT 1;
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- ---- PERFILES ----
-- Los usuarios ven su propio perfil; admins ven todos
DROP POLICY IF EXISTS "perfiles_select" ON perfiles;
CREATE POLICY "perfiles_select" ON perfiles FOR SELECT
  USING (user_id = auth.uid() OR get_user_role() = 'administrador');

DROP POLICY IF EXISTS "perfiles_insert" ON perfiles;
CREATE POLICY "perfiles_insert" ON perfiles FOR INSERT
  WITH CHECK (get_user_role() = 'administrador' OR user_id = auth.uid());

DROP POLICY IF EXISTS "perfiles_update" ON perfiles;
CREATE POLICY "perfiles_update" ON perfiles FOR UPDATE
  USING (user_id = auth.uid() OR get_user_role() = 'administrador');

-- ---- CATÁLOGOS (lectura para todos, escritura solo admin) ----
-- tipos_vehiculo
DROP POLICY IF EXISTS "tipos_vehiculo_select" ON tipos_vehiculo;
CREATE POLICY "tipos_vehiculo_select" ON tipos_vehiculo FOR SELECT USING (true);
DROP POLICY IF EXISTS "tipos_vehiculo_insert" ON tipos_vehiculo;
CREATE POLICY "tipos_vehiculo_insert" ON tipos_vehiculo FOR INSERT WITH CHECK (get_user_role() = 'administrador');
DROP POLICY IF EXISTS "tipos_vehiculo_update" ON tipos_vehiculo;
CREATE POLICY "tipos_vehiculo_update" ON tipos_vehiculo FOR UPDATE USING (get_user_role() = 'administrador');
DROP POLICY IF EXISTS "tipos_vehiculo_delete" ON tipos_vehiculo;
CREATE POLICY "tipos_vehiculo_delete" ON tipos_vehiculo FOR DELETE USING (get_user_role() = 'administrador');

-- catalogo_partes
DROP POLICY IF EXISTS "catalogo_partes_select" ON catalogo_partes;
CREATE POLICY "catalogo_partes_select" ON catalogo_partes FOR SELECT USING (true);
DROP POLICY IF EXISTS "catalogo_partes_insert" ON catalogo_partes;
CREATE POLICY "catalogo_partes_insert" ON catalogo_partes FOR INSERT WITH CHECK (get_user_role() = 'administrador');
DROP POLICY IF EXISTS "catalogo_partes_update" ON catalogo_partes;
CREATE POLICY "catalogo_partes_update" ON catalogo_partes FOR UPDATE USING (get_user_role() = 'administrador');
DROP POLICY IF EXISTS "catalogo_partes_delete" ON catalogo_partes;
CREATE POLICY "catalogo_partes_delete" ON catalogo_partes FOR DELETE USING (get_user_role() = 'administrador');

-- plantilla_tipo_vehiculo
DROP POLICY IF EXISTS "plantilla_select" ON plantilla_tipo_vehiculo;
CREATE POLICY "plantilla_select" ON plantilla_tipo_vehiculo FOR SELECT USING (true);
DROP POLICY IF EXISTS "plantilla_insert" ON plantilla_tipo_vehiculo;
CREATE POLICY "plantilla_insert" ON plantilla_tipo_vehiculo FOR INSERT WITH CHECK (get_user_role() = 'administrador');
DROP POLICY IF EXISTS "plantilla_update" ON plantilla_tipo_vehiculo;
CREATE POLICY "plantilla_update" ON plantilla_tipo_vehiculo FOR UPDATE USING (get_user_role() = 'administrador');
DROP POLICY IF EXISTS "plantilla_delete" ON plantilla_tipo_vehiculo;
CREATE POLICY "plantilla_delete" ON plantilla_tipo_vehiculo FOR DELETE USING (get_user_role() = 'administrador');

-- marcas
DROP POLICY IF EXISTS "marcas_select" ON marcas;
CREATE POLICY "marcas_select" ON marcas FOR SELECT USING (true);
DROP POLICY IF EXISTS "marcas_insert" ON marcas;
CREATE POLICY "marcas_insert" ON marcas FOR INSERT WITH CHECK (get_user_role() = 'administrador');
DROP POLICY IF EXISTS "marcas_update" ON marcas;
CREATE POLICY "marcas_update" ON marcas FOR UPDATE USING (get_user_role() = 'administrador');
DROP POLICY IF EXISTS "marcas_delete" ON marcas;
CREATE POLICY "marcas_delete" ON marcas FOR DELETE USING (get_user_role() = 'administrador');

-- modelos
DROP POLICY IF EXISTS "modelos_select" ON modelos;
CREATE POLICY "modelos_select" ON modelos FOR SELECT USING (true);
DROP POLICY IF EXISTS "modelos_insert" ON modelos;
CREATE POLICY "modelos_insert" ON modelos FOR INSERT WITH CHECK (get_user_role() = 'administrador');
DROP POLICY IF EXISTS "modelos_update" ON modelos;
CREATE POLICY "modelos_update" ON modelos FOR UPDATE USING (get_user_role() = 'administrador');
DROP POLICY IF EXISTS "modelos_delete" ON modelos;
CREATE POLICY "modelos_delete" ON modelos FOR DELETE USING (get_user_role() = 'administrador');

-- ubicaciones
DROP POLICY IF EXISTS "ubicaciones_select" ON ubicaciones;
CREATE POLICY "ubicaciones_select" ON ubicaciones FOR SELECT USING (true);
DROP POLICY IF EXISTS "ubicaciones_insert" ON ubicaciones;
CREATE POLICY "ubicaciones_insert" ON ubicaciones FOR INSERT WITH CHECK (get_user_role() = 'administrador');
DROP POLICY IF EXISTS "ubicaciones_update" ON ubicaciones;
CREATE POLICY "ubicaciones_update" ON ubicaciones FOR UPDATE USING (get_user_role() = 'administrador');
DROP POLICY IF EXISTS "ubicaciones_delete" ON ubicaciones;
CREATE POLICY "ubicaciones_delete" ON ubicaciones FOR DELETE USING (get_user_role() = 'administrador');

-- proveedores
DROP POLICY IF EXISTS "proveedores_select" ON proveedores;
CREATE POLICY "proveedores_select" ON proveedores FOR SELECT USING (true);
DROP POLICY IF EXISTS "proveedores_insert" ON proveedores;
CREATE POLICY "proveedores_insert" ON proveedores FOR INSERT WITH CHECK (get_user_role() = 'administrador');
DROP POLICY IF EXISTS "proveedores_update" ON proveedores;
CREATE POLICY "proveedores_update" ON proveedores FOR UPDATE USING (get_user_role() = 'administrador');
DROP POLICY IF EXISTS "proveedores_delete" ON proveedores;
CREATE POLICY "proveedores_delete" ON proveedores FOR DELETE USING (get_user_role() = 'administrador');

-- estados_vehiculo
DROP POLICY IF EXISTS "estados_vehiculo_select" ON estados_vehiculo;
CREATE POLICY "estados_vehiculo_select" ON estados_vehiculo FOR SELECT USING (true);
DROP POLICY IF EXISTS "estados_vehiculo_insert" ON estados_vehiculo;
CREATE POLICY "estados_vehiculo_insert" ON estados_vehiculo FOR INSERT WITH CHECK (get_user_role() = 'administrador');
DROP POLICY IF EXISTS "estados_vehiculo_update" ON estados_vehiculo;
CREATE POLICY "estados_vehiculo_update" ON estados_vehiculo FOR UPDATE USING (get_user_role() = 'administrador');
DROP POLICY IF EXISTS "estados_vehiculo_delete" ON estados_vehiculo;
CREATE POLICY "estados_vehiculo_delete" ON estados_vehiculo FOR DELETE USING (get_user_role() = 'administrador');

-- campo_configuracion
DROP POLICY IF EXISTS "campo_configuracion_select" ON campo_configuracion;
CREATE POLICY "campo_configuracion_select" ON campo_configuracion FOR SELECT USING (true);
DROP POLICY IF EXISTS "campo_configuracion_insert" ON campo_configuracion;
CREATE POLICY "campo_configuracion_insert" ON campo_configuracion FOR INSERT WITH CHECK (get_user_role() = 'administrador');
DROP POLICY IF EXISTS "campo_configuracion_update" ON campo_configuracion;
CREATE POLICY "campo_configuracion_update" ON campo_configuracion FOR UPDATE USING (get_user_role() = 'administrador');
DROP POLICY IF EXISTS "campo_configuracion_delete" ON campo_configuracion;
CREATE POLICY "campo_configuracion_delete" ON campo_configuracion FOR DELETE USING (get_user_role() = 'administrador');

-- ---- DATOS OPERATIVOS (lectura todos, escritura admin + vendedor) ----
-- vehiculos
DROP POLICY IF EXISTS "vehiculos_select" ON vehiculos;
CREATE POLICY "vehiculos_select" ON vehiculos FOR SELECT USING (true);
DROP POLICY IF EXISTS "vehiculos_insert" ON vehiculos;
CREATE POLICY "vehiculos_insert" ON vehiculos FOR INSERT WITH CHECK (get_user_role() IN ('administrador', 'vendedor'));
DROP POLICY IF EXISTS "vehiculos_update" ON vehiculos;
CREATE POLICY "vehiculos_update" ON vehiculos FOR UPDATE USING (get_user_role() IN ('administrador', 'vendedor', 'mecanico'));

-- repuestos
DROP POLICY IF EXISTS "repuestos_select" ON repuestos;
CREATE POLICY "repuestos_select" ON repuestos FOR SELECT USING (true);
DROP POLICY IF EXISTS "repuestos_insert" ON repuestos;
CREATE POLICY "repuestos_insert" ON repuestos FOR INSERT WITH CHECK (get_user_role() IN ('administrador', 'vendedor', 'mecanico'));
DROP POLICY IF EXISTS "repuestos_update" ON repuestos;
CREATE POLICY "repuestos_update" ON repuestos FOR UPDATE USING (get_user_role() IN ('administrador', 'vendedor', 'mecanico'));

-- ventas
DROP POLICY IF EXISTS "ventas_select" ON ventas;
CREATE POLICY "ventas_select" ON ventas FOR SELECT USING (true);
DROP POLICY IF EXISTS "ventas_insert" ON ventas;
CREATE POLICY "ventas_insert" ON ventas FOR INSERT WITH CHECK (get_user_role() IN ('administrador', 'vendedor'));
DROP POLICY IF EXISTS "ventas_update" ON ventas;
CREATE POLICY "ventas_update" ON ventas FOR UPDATE USING (get_user_role() = 'administrador');

-- venta_detalle
DROP POLICY IF EXISTS "venta_detalle_select" ON venta_detalle;
CREATE POLICY "venta_detalle_select" ON venta_detalle FOR SELECT USING (true);
DROP POLICY IF EXISTS "venta_detalle_insert" ON venta_detalle;
CREATE POLICY "venta_detalle_insert" ON venta_detalle FOR INSERT WITH CHECK (get_user_role() IN ('administrador', 'vendedor'));

-- movimientos
DROP POLICY IF EXISTS "movimientos_select" ON movimientos;
CREATE POLICY "movimientos_select" ON movimientos FOR SELECT USING (true);
DROP POLICY IF EXISTS "movimientos_insert" ON movimientos;
CREATE POLICY "movimientos_insert" ON movimientos FOR INSERT WITH CHECK (get_user_role() IN ('administrador', 'vendedor', 'mecanico'));

-- intercambios
DROP POLICY IF EXISTS "intercambios_select" ON intercambios;
CREATE POLICY "intercambios_select" ON intercambios FOR SELECT USING (true);
DROP POLICY IF EXISTS "intercambios_insert" ON intercambios;
CREATE POLICY "intercambios_insert" ON intercambios FOR INSERT WITH CHECK (get_user_role() IN ('administrador', 'vendedor'));

-- ============================================
-- SEED DATA: TIPOS DE VEHÍCULO
-- ============================================
INSERT INTO tipos_vehiculo (nombre, descripcion, icono) VALUES
  ('Sedán', 'Vehículo de 4 puertas con cajuela cerrada', 'directions_car'),
  ('SUV', 'Sport Utility Vehicle', 'suv'),
  ('Pickup', 'Camioneta con cajón de carga', 'local_shipping'),
  ('Hatchback', 'Vehículo compacto con puerta trasera', 'directions_car'),
  ('Van', 'Vehículo tipo furgoneta', 'airport_shuttle'),
  ('Coupé', 'Vehículo deportivo de 2 puertas', 'sports_car'),
  ('Camión', 'Vehículo de carga pesada', 'local_shipping'),
  ('Motocicleta', 'Vehículo de 2 ruedas', 'two_wheeler')
ON CONFLICT (nombre) DO NOTHING;

-- ============================================
-- SEED DATA: MARCAS Y MODELOS
-- ============================================
INSERT INTO marcas (nombre) VALUES
  ('Toyota'), ('Honda'), ('Nissan'), ('Chevrolet'), ('Ford'),
  ('Volkswagen'), ('Hyundai'), ('Kia'), ('Mazda'), ('Suzuki'),
  ('Mitsubishi'), ('Jeep'), ('Dodge'), ('BMW'), ('Mercedes-Benz')
ON CONFLICT (nombre) DO NOTHING;

-- Toyota
INSERT INTO modelos (marca_id, nombre) VALUES
  ((SELECT id FROM marcas WHERE nombre = 'Toyota'), 'Corolla'),
  ((SELECT id FROM marcas WHERE nombre = 'Toyota'), 'Hilux'),
  ((SELECT id FROM marcas WHERE nombre = 'Toyota'), 'RAV4'),
  ((SELECT id FROM marcas WHERE nombre = 'Toyota'), 'Camry'),
  ((SELECT id FROM marcas WHERE nombre = 'Toyota'), 'Yaris'),
  ((SELECT id FROM marcas WHERE nombre = 'Toyota'), 'Prado'),
  ((SELECT id FROM marcas WHERE nombre = 'Toyota'), 'Fortuner')
ON CONFLICT (marca_id, nombre) DO NOTHING;

-- Honda
INSERT INTO modelos (marca_id, nombre) VALUES
  ((SELECT id FROM marcas WHERE nombre = 'Honda'), 'Civic'),
  ((SELECT id FROM marcas WHERE nombre = 'Honda'), 'CR-V'),
  ((SELECT id FROM marcas WHERE nombre = 'Honda'), 'Accord'),
  ((SELECT id FROM marcas WHERE nombre = 'Honda'), 'HR-V'),
  ((SELECT id FROM marcas WHERE nombre = 'Honda'), 'Fit')
ON CONFLICT (marca_id, nombre) DO NOTHING;

-- Nissan
INSERT INTO modelos (marca_id, nombre) VALUES
  ((SELECT id FROM marcas WHERE nombre = 'Nissan'), 'Sentra'),
  ((SELECT id FROM marcas WHERE nombre = 'Nissan'), 'Versa'),
  ((SELECT id FROM marcas WHERE nombre = 'Nissan'), 'X-Trail'),
  ((SELECT id FROM marcas WHERE nombre = 'Nissan'), 'Frontier'),
  ((SELECT id FROM marcas WHERE nombre = 'Nissan'), 'Kicks')
ON CONFLICT (marca_id, nombre) DO NOTHING;

-- Chevrolet
INSERT INTO modelos (marca_id, nombre) VALUES
  ((SELECT id FROM marcas WHERE nombre = 'Chevrolet'), 'Spark'),
  ((SELECT id FROM marcas WHERE nombre = 'Chevrolet'), 'Cruze'),
  ((SELECT id FROM marcas WHERE nombre = 'Chevrolet'), 'Tracker'),
  ((SELECT id FROM marcas WHERE nombre = 'Chevrolet'), 'Onix'),
  ((SELECT id FROM marcas WHERE nombre = 'Chevrolet'), 'Silverado')
ON CONFLICT (marca_id, nombre) DO NOTHING;

-- Ford
INSERT INTO modelos (marca_id, nombre) VALUES
  ((SELECT id FROM marcas WHERE nombre = 'Ford'), 'Ranger'),
  ((SELECT id FROM marcas WHERE nombre = 'Ford'), 'Explorer'),
  ((SELECT id FROM marcas WHERE nombre = 'Ford'), 'EcoSport'),
  ((SELECT id FROM marcas WHERE nombre = 'Ford'), 'Escape'),
  ((SELECT id FROM marcas WHERE nombre = 'Ford'), 'F-150')
ON CONFLICT (marca_id, nombre) DO NOTHING;

-- Volkswagen
INSERT INTO modelos (marca_id, nombre) VALUES
  ((SELECT id FROM marcas WHERE nombre = 'Volkswagen'), 'Jetta'),
  ((SELECT id FROM marcas WHERE nombre = 'Volkswagen'), 'Golf'),
  ((SELECT id FROM marcas WHERE nombre = 'Volkswagen'), 'Tiguan'),
  ((SELECT id FROM marcas WHERE nombre = 'Volkswagen'), 'Polo'),
  ((SELECT id FROM marcas WHERE nombre = 'Volkswagen'), 'T-Cross')
ON CONFLICT (marca_id, nombre) DO NOTHING;

-- Hyundai
INSERT INTO modelos (marca_id, nombre) VALUES
  ((SELECT id FROM marcas WHERE nombre = 'Hyundai'), 'Tucson'),
  ((SELECT id FROM marcas WHERE nombre = 'Hyundai'), 'Accent'),
  ((SELECT id FROM marcas WHERE nombre = 'Hyundai'), 'Creta'),
  ((SELECT id FROM marcas WHERE nombre = 'Hyundai'), 'Santa Fe'),
  ((SELECT id FROM marcas WHERE nombre = 'Hyundai'), 'Elantra')
ON CONFLICT (marca_id, nombre) DO NOTHING;

-- Kia
INSERT INTO modelos (marca_id, nombre) VALUES
  ((SELECT id FROM marcas WHERE nombre = 'Kia'), 'Sportage'),
  ((SELECT id FROM marcas WHERE nombre = 'Kia'), 'Rio'),
  ((SELECT id FROM marcas WHERE nombre = 'Kia'), 'Seltos'),
  ((SELECT id FROM marcas WHERE nombre = 'Kia'), 'Sorento'),
  ((SELECT id FROM marcas WHERE nombre = 'Kia'), 'Cerato')
ON CONFLICT (marca_id, nombre) DO NOTHING;

-- Mazda
INSERT INTO modelos (marca_id, nombre) VALUES
  ((SELECT id FROM marcas WHERE nombre = 'Mazda'), 'Mazda 3'),
  ((SELECT id FROM marcas WHERE nombre = 'Mazda'), 'CX-5'),
  ((SELECT id FROM marcas WHERE nombre = 'Mazda'), 'CX-30'),
  ((SELECT id FROM marcas WHERE nombre = 'Mazda'), 'Mazda 2'),
  ((SELECT id FROM marcas WHERE nombre = 'Mazda'), 'CX-9')
ON CONFLICT (marca_id, nombre) DO NOTHING;

-- ============================================
-- SEED DATA: UBICACIÓN INICIAL
-- ============================================
INSERT INTO ubicaciones (nombre, direccion) VALUES
  ('Bodega Principal', 'Dirección de la bodega principal')
ON CONFLICT (nombre) DO NOTHING;

-- ============================================
-- SEED DATA: ESTADOS DE VEHÍCULO
-- ============================================
INSERT INTO estados_vehiculo (nombre, valor, descripcion, color, orden) VALUES
  ('Siniestrado', 'siniestrado', 'Vehículo siniestrado', '#F44336', 1),
  ('Dado de baja', 'dado_de_baja', 'Vehículo dado de baja', '#9E9E9E', 2),
  ('Incompleto', 'incompleto', 'Vehículo con registro incompleto', '#FF9800', 3),
  ('En remate', 'remate', 'Vehículo en remate', '#2196F3', 4),
  ('En patio', 'patio', 'Vehículo en patio', '#4CAF50', 5),
  ('En taller', 'taller', 'Vehículo en taller', '#FF5722', 6),
  ('Con dueño', 'dueno', 'Vehículo con dueño', '#673AB7', 7)
ON CONFLICT (nombre) DO NOTHING;

-- ============================================
-- SEED DATA: PROVEEDORES
-- ============================================
INSERT INTO proveedores (nombre) VALUES
  ('Proveedor General')
ON CONFLICT (nombre) DO NOTHING;

-- ============================================
-- SEED DATA: CONFIGURACIÓN DE CAMPOS (vehiculos)
-- ============================================
INSERT INTO campo_configuracion (nombre_campo, tabla, etiqueta, obligatorio) VALUES
  ('marca_id', 'vehiculos', 'Marca', true),
  ('modelo_id', 'vehiculos', 'Modelo', true),
  ('tipo_vehiculo_id', 'vehiculos', 'Tipo de Vehículo', true),
  ('anio', 'vehiculos', 'Año', true),
  ('color', 'vehiculos', 'Color', false),
  ('vin', 'vehiculos', 'VIN / Chasis', false),
  ('placa', 'vehiculos', 'Placa', false),
  ('costo_compra', 'vehiculos', 'Costo de Compra', true),
  ('proveedor_id', 'vehiculos', 'Proveedor', false),
  ('estado', 'vehiculos', 'Estado del Vehículo', true),
  ('ubicacion_id', 'vehiculos', 'Ubicación', false),
  ('valor_grua', 'vehiculos', 'Valor de Grúa', false),
  ('comision_viaje', 'vehiculos', 'Comisión de Viaje', false),
  ('comprador_id', 'vehiculos', 'Comprador', false),
  ('notas', 'vehiculos', 'Notas', false)
ON CONFLICT (nombre_campo, tabla) DO NOTHING;

-- Configuración de campos para ingreso externo
INSERT INTO campo_configuracion (nombre_campo, tabla, etiqueta, obligatorio) VALUES
  ('catalogo_parte_id', 'repuestos_externo', 'Repuesto', true),
  ('proveedor_externo', 'repuestos_externo', 'Proveedor', true),
  ('costo_externo', 'repuestos_externo', 'Costo', true),
  ('precio_sugerido', 'repuestos_externo', 'Precio Sugerido', false),
  ('ext_marca_id', 'repuestos_externo', 'Marca del Vehículo', false),
  ('ext_modelo_id', 'repuestos_externo', 'Modelo del Vehículo', false),
  ('ext_anio', 'repuestos_externo', 'Año del Vehículo', false),
  ('ubicacion_id', 'repuestos_externo', 'Ubicación', false),
  ('notas', 'repuestos_externo', 'Notas', false)
ON CONFLICT (nombre_campo, tabla) DO NOTHING;

-- ============================================
-- SEED DATA: CATÁLOGO DE PARTES (~190 partes)
-- ============================================

-- Orden counter helper variables don't work in plain SQL,
-- so we use sequential orden values per category.

-- ======== CARROCERÍA EXTERIOR (25 partes) ========
INSERT INTO catalogo_partes (nombre, categoria, orden) VALUES
  ('Cofre / Capó', 'Carrocería exterior', 1),
  ('Parachoques delantero', 'Carrocería exterior', 2),
  ('Parachoques trasero', 'Carrocería exterior', 3),
  ('Facia delantera', 'Carrocería exterior', 4),
  ('Facia trasera', 'Carrocería exterior', 5),
  ('Salpicadera delantera izquierda', 'Carrocería exterior', 6),
  ('Salpicadera delantera derecha', 'Carrocería exterior', 7),
  ('Puerta delantera izquierda', 'Carrocería exterior', 8),
  ('Puerta delantera derecha', 'Carrocería exterior', 9),
  ('Puerta trasera izquierda', 'Carrocería exterior', 10),
  ('Puerta trasera derecha', 'Carrocería exterior', 11),
  ('Panel lateral izquierdo', 'Carrocería exterior', 12),
  ('Panel lateral derecho', 'Carrocería exterior', 13),
  ('Tapa de cajuela / Compuerta trasera', 'Carrocería exterior', 14),
  ('Toldo / Techo', 'Carrocería exterior', 15),
  ('Bisagras de cofre', 'Carrocería exterior', 16),
  ('Bisagras de puertas', 'Carrocería exterior', 17),
  ('Molduras laterales', 'Carrocería exterior', 18),
  ('Moldura de parachoques', 'Carrocería exterior', 19),
  ('Rejilla frontal / Parrilla', 'Carrocería exterior', 20),
  ('Emblemas / Logos', 'Carrocería exterior', 21),
  ('Manija exterior delantera izquierda', 'Carrocería exterior', 22),
  ('Manija exterior delantera derecha', 'Carrocería exterior', 23),
  ('Manija exterior trasera izquierda', 'Carrocería exterior', 24),
  ('Manija exterior trasera derecha', 'Carrocería exterior', 25)
ON CONFLICT (nombre, categoria) DO NOTHING;

-- ======== VIDRIOS Y ESPEJOS (14 partes) ========
INSERT INTO catalogo_partes (nombre, categoria, orden) VALUES
  ('Parabrisas delantero', 'Vidrios y espejos', 1),
  ('Medallón / Vidrio trasero', 'Vidrios y espejos', 2),
  ('Vidrio puerta delantera izquierda', 'Vidrios y espejos', 3),
  ('Vidrio puerta delantera derecha', 'Vidrios y espejos', 4),
  ('Vidrio puerta trasera izquierda', 'Vidrios y espejos', 5),
  ('Vidrio puerta trasera derecha', 'Vidrios y espejos', 6),
  ('Vidrio de aleta / Cuarto izquierdo', 'Vidrios y espejos', 7),
  ('Vidrio de aleta / Cuarto derecho', 'Vidrios y espejos', 8),
  ('Espejo lateral izquierdo completo', 'Vidrios y espejos', 9),
  ('Espejo lateral derecho completo', 'Vidrios y espejos', 10),
  ('Luna de espejo izquierdo', 'Vidrios y espejos', 11),
  ('Luna de espejo derecho', 'Vidrios y espejos', 12),
  ('Espejo retrovisor interior', 'Vidrios y espejos', 13),
  ('Quemacocos / Techo solar', 'Vidrios y espejos', 14)
ON CONFLICT (nombre, categoria) DO NOTHING;

-- ======== ILUMINACIÓN (22 partes) ========
INSERT INTO catalogo_partes (nombre, categoria, orden) VALUES
  ('Faro delantero izquierdo', 'Iluminación', 1),
  ('Faro delantero derecho', 'Iluminación', 2),
  ('Calavera trasera izquierda', 'Iluminación', 3),
  ('Calavera trasera derecha', 'Iluminación', 4),
  ('Calavera de cajuela izquierda', 'Iluminación', 5),
  ('Calavera de cajuela derecha', 'Iluminación', 6),
  ('Faro antiniebla delantero izquierdo', 'Iluminación', 7),
  ('Faro antiniebla delantero derecho', 'Iluminación', 8),
  ('Faro antiniebla trasero', 'Iluminación', 9),
  ('Luz de freno alta (CHMSL)', 'Iluminación', 10),
  ('Cuarto delantero izquierdo', 'Iluminación', 11),
  ('Cuarto delantero derecho', 'Iluminación', 12),
  ('Luz de reversa', 'Iluminación', 13),
  ('Luz de placa', 'Iluminación', 14),
  ('Luz de cortesía interior', 'Iluminación', 15),
  ('Luz de lectura', 'Iluminación', 16),
  ('Luz de guantera', 'Iluminación', 17),
  ('Luz de cajuela', 'Iluminación', 18),
  ('Foco H1/H4/H7 izquierdo', 'Iluminación', 19),
  ('Foco H1/H4/H7 derecho', 'Iluminación', 20),
  ('Barra LED (si aplica)', 'Iluminación', 21),
  ('Luz direccional lateral', 'Iluminación', 22)
ON CONFLICT (nombre, categoria) DO NOTHING;

-- ======== MOTOR Y MECÁNICA (28 partes) ========
INSERT INTO catalogo_partes (nombre, categoria, orden) VALUES
  ('Motor completo', 'Motor y mecánica', 1),
  ('Cabeza de motor / Culata', 'Motor y mecánica', 2),
  ('Block de motor', 'Motor y mecánica', 3),
  ('Múltiple de admisión', 'Motor y mecánica', 4),
  ('Múltiple de escape', 'Motor y mecánica', 5),
  ('Turbo / Supercargador', 'Motor y mecánica', 6),
  ('Cuerpo de aceleración', 'Motor y mecánica', 7),
  ('Inyectores de combustible', 'Motor y mecánica', 8),
  ('Riel de inyectores', 'Motor y mecánica', 9),
  ('Bomba de combustible', 'Motor y mecánica', 10),
  ('Filtro de aire (carcasa)', 'Motor y mecánica', 11),
  ('Radiador', 'Motor y mecánica', 12),
  ('Ventilador de radiador', 'Motor y mecánica', 13),
  ('Mangueras de radiador', 'Motor y mecánica', 14),
  ('Bomba de agua', 'Motor y mecánica', 15),
  ('Termostato', 'Motor y mecánica', 16),
  ('Compresor de A/C', 'Motor y mecánica', 17),
  ('Condensador de A/C', 'Motor y mecánica', 18),
  ('Alternador', 'Motor y mecánica', 19),
  ('Motor de arranque', 'Motor y mecánica', 20),
  ('Distribuidor / Bobinas de encendido', 'Motor y mecánica', 21),
  ('Banda de distribución / Cadena', 'Motor y mecánica', 22),
  ('Banda serpentina', 'Motor y mecánica', 23),
  ('Carter de aceite', 'Motor y mecánica', 24),
  ('Tapa de válvulas', 'Motor y mecánica', 25),
  ('Sensor de oxígeno', 'Motor y mecánica', 26),
  ('Catalizador', 'Motor y mecánica', 27),
  ('Tubo de escape / Mofle', 'Motor y mecánica', 28)
ON CONFLICT (nombre, categoria) DO NOTHING;

-- ======== TRANSMISIÓN (14 partes) ========
INSERT INTO catalogo_partes (nombre, categoria, orden) VALUES
  ('Transmisión completa (automática)', 'Transmisión', 1),
  ('Transmisión completa (manual)', 'Transmisión', 2),
  ('Clutch / Embrague (kit)', 'Transmisión', 3),
  ('Volante de inercia', 'Transmisión', 4),
  ('Convertidor de torque', 'Transmisión', 5),
  ('Flecha / Semieje izquierdo', 'Transmisión', 6),
  ('Flecha / Semieje derecho', 'Transmisión', 7),
  ('Flecha cardán', 'Transmisión', 8),
  ('Diferencial', 'Transmisión', 9),
  ('Palanca de velocidades', 'Transmisión', 10),
  ('Cables de clutch', 'Transmisión', 11),
  ('Transfer case (4x4)', 'Transmisión', 12),
  ('Soporte de transmisión', 'Transmisión', 13),
  ('Soporte de motor', 'Transmisión', 14)
ON CONFLICT (nombre, categoria) DO NOTHING;

-- ======== SUSPENSIÓN Y DIRECCIÓN (20 partes) ========
INSERT INTO catalogo_partes (nombre, categoria, orden) VALUES
  ('Amortiguador delantero izquierdo', 'Suspensión y dirección', 1),
  ('Amortiguador delantero derecho', 'Suspensión y dirección', 2),
  ('Amortiguador trasero izquierdo', 'Suspensión y dirección', 3),
  ('Amortiguador trasero derecho', 'Suspensión y dirección', 4),
  ('Resorte / Espiral delantero izquierdo', 'Suspensión y dirección', 5),
  ('Resorte / Espiral delantero derecho', 'Suspensión y dirección', 6),
  ('Resorte / Espiral trasero izquierdo', 'Suspensión y dirección', 7),
  ('Resorte / Espiral trasero derecho', 'Suspensión y dirección', 8),
  ('Horquilla / Brazo de control superior izq.', 'Suspensión y dirección', 9),
  ('Horquilla / Brazo de control superior der.', 'Suspensión y dirección', 10),
  ('Horquilla / Brazo de control inferior izq.', 'Suspensión y dirección', 11),
  ('Horquilla / Brazo de control inferior der.', 'Suspensión y dirección', 12),
  ('Barra estabilizadora delantera', 'Suspensión y dirección', 13),
  ('Barra estabilizadora trasera', 'Suspensión y dirección', 14),
  ('Terminal de dirección izquierda', 'Suspensión y dirección', 15),
  ('Terminal de dirección derecha', 'Suspensión y dirección', 16),
  ('Cremallera de dirección', 'Suspensión y dirección', 17),
  ('Bomba de dirección hidráulica', 'Suspensión y dirección', 18),
  ('Columna de dirección', 'Suspensión y dirección', 19),
  ('Volante / Timón', 'Suspensión y dirección', 20)
ON CONFLICT (nombre, categoria) DO NOTHING;

-- ======== FRENOS (12 partes) ========
INSERT INTO catalogo_partes (nombre, categoria, orden) VALUES
  ('Disco de freno delantero izquierdo', 'Frenos', 1),
  ('Disco de freno delantero derecho', 'Frenos', 2),
  ('Disco de freno trasero izquierdo', 'Frenos', 3),
  ('Disco de freno trasero derecho', 'Frenos', 4),
  ('Caliper delantero izquierdo', 'Frenos', 5),
  ('Caliper delantero derecho', 'Frenos', 6),
  ('Caliper trasero izquierdo', 'Frenos', 7),
  ('Caliper trasero derecho', 'Frenos', 8),
  ('Bomba de freno (cilindro maestro)', 'Frenos', 9),
  ('Servofreno (booster)', 'Frenos', 10),
  ('Freno de mano / Palanca', 'Frenos', 11),
  ('Líneas / Mangueras de freno', 'Frenos', 12)
ON CONFLICT (nombre, categoria) DO NOTHING;

-- ======== INTERIOR (30 partes) ========
INSERT INTO catalogo_partes (nombre, categoria, orden) VALUES
  ('Tablero / Dashboard completo', 'Interior', 1),
  ('Guantera', 'Interior', 2),
  ('Consola central', 'Interior', 3),
  ('Palanca de freno de mano', 'Interior', 4),
  ('Asiento delantero izquierdo', 'Interior', 5),
  ('Asiento delantero derecho', 'Interior', 6),
  ('Asiento trasero completo', 'Interior', 7),
  ('Cinturón de seguridad delantero izquierdo', 'Interior', 8),
  ('Cinturón de seguridad delantero derecho', 'Interior', 9),
  ('Cinturón de seguridad trasero', 'Interior', 10),
  ('Bolsa de aire conductor', 'Interior', 11),
  ('Bolsa de aire pasajero', 'Interior', 12),
  ('Bolsa de aire lateral izquierda', 'Interior', 13),
  ('Bolsa de aire lateral derecha', 'Interior', 14),
  ('Panel / Tapizado puerta delantera izq.', 'Interior', 15),
  ('Panel / Tapizado puerta delantera der.', 'Interior', 16),
  ('Panel / Tapizado puerta trasera izq.', 'Interior', 17),
  ('Panel / Tapizado puerta trasera der.', 'Interior', 18),
  ('Alfombra del piso', 'Interior', 19),
  ('Tapete / Alfombra cajuela', 'Interior', 20),
  ('Visera parasol izquierda', 'Interior', 21),
  ('Visera parasol derecha', 'Interior', 22),
  ('Manija interior delantera izquierda', 'Interior', 23),
  ('Manija interior delantera derecha', 'Interior', 24),
  ('Manija interior trasera izquierda', 'Interior', 25),
  ('Manija interior trasera derecha', 'Interior', 26),
  ('Cenicero / Porta objetos', 'Interior', 27),
  ('Tapa / Cubierta del motor interior', 'Interior', 28),
  ('Pedal de acelerador', 'Interior', 29),
  ('Pedal de freno', 'Interior', 30)
ON CONFLICT (nombre, categoria) DO NOTHING;

-- ======== SISTEMA ELÉCTRICO (26 partes) ========
INSERT INTO catalogo_partes (nombre, categoria, orden) VALUES
  ('Batería', 'Sistema eléctrico', 1),
  ('Arnés de cables principal', 'Sistema eléctrico', 2),
  ('Arnés de cables de motor', 'Sistema eléctrico', 3),
  ('Arnés de cables de puertas', 'Sistema eléctrico', 4),
  ('Caja de fusibles interior', 'Sistema eléctrico', 5),
  ('Caja de fusibles motor', 'Sistema eléctrico', 6),
  ('ECU / Computadora del motor', 'Sistema eléctrico', 7),
  ('Módulo BCM (Body Control Module)', 'Sistema eléctrico', 8),
  ('Radio / Estéreo / Unidad principal', 'Sistema eléctrico', 9),
  ('Pantalla / Display', 'Sistema eléctrico', 10),
  ('Bocinas / Altavoces', 'Sistema eléctrico', 11),
  ('Antena', 'Sistema eléctrico', 12),
  ('Claxon / Bocina', 'Sistema eléctrico', 13),
  ('Motor de limpiaparabrisas', 'Sistema eléctrico', 14),
  ('Brazo de limpiaparabrisas', 'Sistema eléctrico', 15),
  ('Pluma de limpiaparabrisas', 'Sistema eléctrico', 16),
  ('Motor de elevador vidrio delantero izq.', 'Sistema eléctrico', 17),
  ('Motor de elevador vidrio delantero der.', 'Sistema eléctrico', 18),
  ('Motor de elevador vidrio trasero izq.', 'Sistema eléctrico', 19),
  ('Motor de elevador vidrio trasero der.', 'Sistema eléctrico', 20),
  ('Switch de encendido / Llave', 'Sistema eléctrico', 21),
  ('Control remoto / Llave electrónica', 'Sistema eléctrico', 22),
  ('Velocímetro / Cluster de instrumentos', 'Sistema eléctrico', 23),
  ('Sensor ABS delantero', 'Sistema eléctrico', 24),
  ('Sensor ABS trasero', 'Sistema eléctrico', 25),
  ('Módulo ABS', 'Sistema eléctrico', 26)
ON CONFLICT (nombre, categoria) DO NOTHING;

-- ======== RUEDAS (8 partes) ========
INSERT INTO catalogo_partes (nombre, categoria, orden) VALUES
  ('Rin delantero izquierdo', 'Ruedas', 1),
  ('Rin delantero derecho', 'Ruedas', 2),
  ('Rin trasero izquierdo', 'Ruedas', 3),
  ('Rin trasero derecho', 'Ruedas', 4),
  ('Llanta delantera izquierda', 'Ruedas', 5),
  ('Llanta delantera derecha', 'Ruedas', 6),
  ('Llanta trasera izquierda', 'Ruedas', 7),
  ('Llanta trasera derecha', 'Ruedas', 8)
ON CONFLICT (nombre, categoria) DO NOTHING;

-- ======== OTROS (11 partes) ========
INSERT INTO catalogo_partes (nombre, categoria, orden) VALUES
  ('Tanque de combustible', 'Otros', 1),
  ('Tapa de tanque de combustible', 'Otros', 2),
  ('Depósito de líquido limpiaparabrisas', 'Otros', 3),
  ('Depósito de líquido de frenos', 'Otros', 4),
  ('Depósito de anticongelante / Overflow', 'Otros', 5),
  ('Gato hidráulico / Herramienta', 'Otros', 6),
  ('Llanta de refacción', 'Otros', 7),
  ('Chapa de puerta delantera izquierda', 'Otros', 8),
  ('Chapa de puerta delantera derecha', 'Otros', 9),
  ('Chapa de cajuela', 'Otros', 10),
  ('Chapa de encendido', 'Otros', 11)
ON CONFLICT (nombre, categoria) DO NOTHING;

-- ============================================
-- GENERACIÓN AUTOMÁTICA DE PLANTILLAS
-- Para cada tipo de vehículo, asociar TODAS
-- las partes del catálogo que tengan
-- activo_por_defecto = true
-- ============================================
INSERT INTO plantilla_tipo_vehiculo (tipo_vehiculo_id, parte_id, activo)
SELECT tv.id, cp.id, true
FROM tipos_vehiculo tv
CROSS JOIN catalogo_partes cp
WHERE cp.activo_por_defecto = true
ON CONFLICT (tipo_vehiculo_id, parte_id) DO NOTHING;

-- ============================================
-- STORAGE: Bucket para fotos
-- (ejecutar en la consola de Supabase > Storage)
-- ============================================
-- INSERT INTO storage.buckets (id, name, public)
-- VALUES ('vehiculos-fotos', 'vehiculos-fotos', true);
--
-- CREATE POLICY "Authenticated users can upload"
-- ON storage.objects FOR INSERT
-- WITH CHECK (bucket_id = 'vehiculos-fotos' AND auth.role() = 'authenticated');
--
-- CREATE POLICY "Public read"
-- ON storage.objects FOR SELECT
-- USING (bucket_id = 'vehiculos-fotos');

-- ============================================
-- TRIGGERS: Validación de stock en ventas
-- ============================================

-- Trigger: Prevenir venta de repuestos no disponibles
CREATE OR REPLACE FUNCTION validar_stock_venta()
RETURNS TRIGGER AS $$
BEGIN
  -- Verificar que el repuesto esté disponible
  IF (SELECT estado FROM repuestos WHERE id = NEW.repuesto_id) != 'disponible' THEN
    RAISE EXCEPTION 'El repuesto % ya no está disponible para venta', NEW.repuesto_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_validar_stock_venta ON venta_detalle;
CREATE TRIGGER trg_validar_stock_venta
  BEFORE INSERT ON venta_detalle
  FOR EACH ROW
  EXECUTE FUNCTION validar_stock_venta();

-- ============================================
-- RPC: Registro atómico de venta
-- ============================================
CREATE OR REPLACE FUNCTION registrar_venta(
  p_vendedor_id UUID,
  p_cliente_nombre TEXT DEFAULT NULL,
  p_cliente_telefono TEXT DEFAULT NULL,
  p_metodo_pago TEXT DEFAULT 'Efectivo',
  p_total NUMERIC DEFAULT 0,
  p_notas TEXT DEFAULT NULL,
  p_items JSONB DEFAULT '[]'::JSONB
) RETURNS JSONB AS $$
DECLARE
  v_venta_id UUID;
  v_item JSONB;
  v_repuesto_id UUID;
  v_estado TEXT;
  v_nombre TEXT;
BEGIN
  -- 1. Bloquear y validar todos los repuestos
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
  LOOP
    v_repuesto_id := (v_item->>'repuesto_id')::UUID;
    SELECT r.estado, cp.nombre INTO v_estado, v_nombre
      FROM repuestos r
      LEFT JOIN catalogo_partes cp ON r.catalogo_parte_id = cp.id
      WHERE r.id = v_repuesto_id
      FOR UPDATE OF r;

    IF v_estado IS NULL THEN
      RAISE EXCEPTION 'Repuesto no encontrado: %', v_repuesto_id;
    END IF;
    IF v_estado != 'disponible' THEN
      RAISE EXCEPTION 'El repuesto "%" ya no está disponible (estado: %)',
        COALESCE(v_nombre, v_repuesto_id::TEXT), v_estado;
    END IF;

    -- Validar que el precio sea mayor a 0
    IF (v_item->>'precio')::NUMERIC <= 0 THEN
      RAISE EXCEPTION 'El precio de "%" debe ser mayor a $0',
        COALESCE(v_nombre, v_repuesto_id::TEXT);
    END IF;
  END LOOP;

  -- 2. Crear registro de venta
  INSERT INTO ventas (fecha, vendedor_id, cliente_nombre, cliente_telefono, metodo_pago, total, notas)
  VALUES (NOW(), p_vendedor_id, NULLIF(p_cliente_nombre, ''), NULLIF(p_cliente_telefono, ''), p_metodo_pago, p_total, NULLIF(p_notas, ''))
  RETURNING id INTO v_venta_id;

  -- 3. Para cada item: crear detalle, actualizar repuesto, crear movimiento
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
  LOOP
    v_repuesto_id := (v_item->>'repuesto_id')::UUID;

    -- Insertar detalle (trigger valida que sigue disponible)
    INSERT INTO venta_detalle (venta_id, repuesto_id, precio)
    VALUES (v_venta_id, v_repuesto_id, (v_item->>'precio')::NUMERIC);

    -- Marcar repuesto como vendido
    UPDATE repuestos SET estado = 'vendido'
    WHERE id = v_repuesto_id;

    -- Registrar movimiento
    INSERT INTO movimientos (repuesto_id, tipo, fecha, usuario_id, venta_id, notas)
    VALUES (v_repuesto_id, 'venta', NOW(), p_vendedor_id, v_venta_id, 'Venta registrada');
  END LOOP;

  RETURN jsonb_build_object('venta_id', v_venta_id, 'success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- RPC: Anular venta y devolver repuestos al stock
-- ============================================
CREATE OR REPLACE FUNCTION anular_venta(
  p_venta_id UUID
) RETURNS JSONB AS $$
DECLARE
  v_venta RECORD;
  v_detalle RECORD;
  v_count INT := 0;
BEGIN
  -- Buscar la venta
  SELECT * INTO v_venta FROM ventas WHERE id = p_venta_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Venta no encontrada: %', p_venta_id;
  END IF;
  IF v_venta.notas IS NOT NULL AND v_venta.notas LIKE '%[ANULADA]%' THEN
    RAISE EXCEPTION 'Esta venta ya fue anulada';
  END IF;

  -- Devolver cada repuesto al stock
  FOR v_detalle IN
    SELECT vd.repuesto_id, vd.id AS detalle_id
    FROM venta_detalle vd
    WHERE vd.venta_id = p_venta_id
  LOOP
    UPDATE repuestos SET estado = 'disponible'
    WHERE id = v_detalle.repuesto_id AND estado = 'vendido';

    INSERT INTO movimientos (repuesto_id, tipo, fecha, usuario_id, venta_id, notas)
    VALUES (v_detalle.repuesto_id, 'devolucion', NOW(), v_venta.vendedor_id, p_venta_id, 'Venta anulada');

    v_count := v_count + 1;
  END LOOP;

  -- Marcar venta como anulada
  UPDATE ventas
  SET notas = COALESCE(notas || ' ', '') || '[ANULADA]',
      total = 0
  WHERE id = p_venta_id;

  RETURN jsonb_build_object('venta_id', p_venta_id, 'items_devueltos', v_count, 'success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- 14. RESERVAS
-- ============================================
CREATE TABLE IF NOT EXISTS reservas (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  repuesto_id UUID NOT NULL REFERENCES repuestos(id),
  cliente_nombre TEXT NOT NULL,
  cliente_telefono TEXT,
  monto_abono NUMERIC(12,2) NOT NULL DEFAULT 0,
  fecha_reserva TIMESTAMPTZ NOT NULL DEFAULT now(),
  fecha_expiracion TIMESTAMPTZ NOT NULL,
  estado TEXT NOT NULL DEFAULT 'activa' CHECK (estado IN ('activa', 'completada', 'expirada', 'cancelada')),
  vendedor_id UUID NOT NULL REFERENCES perfiles(id),
  notas TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_reservas_repuesto_id ON reservas(repuesto_id);
CREATE INDEX IF NOT EXISTS idx_reservas_estado ON reservas(estado);
CREATE INDEX IF NOT EXISTS idx_reservas_fecha_expiracion ON reservas(fecha_expiracion);
CREATE INDEX IF NOT EXISTS idx_reservas_vendedor_id ON reservas(vendedor_id);

ALTER TABLE reservas ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "reservas_select" ON reservas;
CREATE POLICY "reservas_select" ON reservas FOR SELECT USING (true);
DROP POLICY IF EXISTS "reservas_insert" ON reservas;
CREATE POLICY "reservas_insert" ON reservas FOR INSERT
  WITH CHECK (get_user_role() IN ('administrador', 'vendedor'));
DROP POLICY IF EXISTS "reservas_update" ON reservas;
CREATE POLICY "reservas_update" ON reservas FOR UPDATE
  USING (get_user_role() IN ('administrador', 'vendedor'));
DROP POLICY IF EXISTS "reservas_delete" ON reservas;
CREATE POLICY "reservas_delete" ON reservas FOR DELETE
  USING (get_user_role() = 'administrador');

-- DELETE policy para vehiculos (solo admin)
DROP POLICY IF EXISTS "vehiculos_delete" ON vehiculos;
CREATE POLICY "vehiculos_delete" ON vehiculos FOR DELETE
  USING (get_user_role() = 'administrador');

-- DELETE policy para repuestos (solo admin)
DROP POLICY IF EXISTS "repuestos_delete" ON repuestos;
CREATE POLICY "repuestos_delete" ON repuestos FOR DELETE
  USING (get_user_role() = 'administrador');

-- ============================================
-- RPC: Eliminar vehículo (solo si nada vendido)
-- ============================================
CREATE OR REPLACE FUNCTION eliminar_vehiculo(
  p_vehiculo_id UUID
) RETURNS JSONB AS $$
DECLARE
  v_vendidos INT;
  v_reservados INT;
  v_repuestos_count INT;
  v_nombre TEXT;
BEGIN
  SELECT COALESCE(m.nombre || ' ' || mo.nombre || ' ' || v.anio, v.id::TEXT)
  INTO v_nombre
  FROM vehiculos v
  LEFT JOIN marcas m ON v.marca_id = m.id
  LEFT JOIN modelos mo ON v.modelo_id = mo.id
  WHERE v.id = p_vehiculo_id;

  IF v_nombre IS NULL THEN
    RAISE EXCEPTION 'Vehículo no encontrado: %', p_vehiculo_id;
  END IF;

  SELECT COUNT(*) INTO v_vendidos
  FROM repuestos WHERE vehiculo_id = p_vehiculo_id AND estado = 'vendido';
  IF v_vendidos > 0 THEN
    RAISE EXCEPTION 'No se puede eliminar "%": tiene % repuesto(s) vendido(s)', v_nombre, v_vendidos;
  END IF;

  SELECT COUNT(*) INTO v_reservados
  FROM repuestos WHERE vehiculo_id = p_vehiculo_id AND estado = 'reservado';
  IF v_reservados > 0 THEN
    RAISE EXCEPTION 'No se puede eliminar "%": tiene % repuesto(s) reservado(s)', v_nombre, v_reservados;
  END IF;

  SELECT COUNT(*) INTO v_repuestos_count
  FROM repuestos WHERE vehiculo_id = p_vehiculo_id;

  DELETE FROM movimientos WHERE repuesto_id IN (
    SELECT id FROM repuestos WHERE vehiculo_id = p_vehiculo_id
  );
  DELETE FROM repuestos WHERE vehiculo_id = p_vehiculo_id;
  DELETE FROM vehiculos WHERE id = p_vehiculo_id;

  RETURN jsonb_build_object('vehiculo_id', p_vehiculo_id, 'nombre', v_nombre,
    'repuestos_eliminados', v_repuestos_count, 'success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- RPC: Reservar repuesto
-- ============================================
CREATE OR REPLACE FUNCTION reservar_repuesto(
  p_repuesto_id UUID,
  p_cliente_nombre TEXT,
  p_cliente_telefono TEXT DEFAULT NULL,
  p_monto_abono NUMERIC DEFAULT 0,
  p_dias_expiracion INT DEFAULT 7,
  p_vendedor_id UUID DEFAULT NULL,
  p_notas TEXT DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
  v_estado TEXT;
  v_nombre TEXT;
  v_reserva_id UUID;
  v_fecha_exp TIMESTAMPTZ;
  v_perfil_id UUID;
BEGIN
  -- Resolver perfil_id
  v_perfil_id := p_vendedor_id;
  IF v_perfil_id IS NULL THEN
    SELECT id INTO v_perfil_id FROM perfiles WHERE user_id = auth.uid();
  END IF;
  IF v_perfil_id IS NULL THEN
    RAISE EXCEPTION 'No se encontró perfil para el usuario actual';
  END IF;

  SELECT r.estado, cp.nombre INTO v_estado, v_nombre
  FROM repuestos r
  LEFT JOIN catalogo_partes cp ON r.catalogo_parte_id = cp.id
  WHERE r.id = p_repuesto_id
  FOR UPDATE OF r;

  IF v_estado IS NULL THEN
    RAISE EXCEPTION 'Repuesto no encontrado: %', p_repuesto_id;
  END IF;
  IF v_estado != 'disponible' THEN
    RAISE EXCEPTION 'El repuesto "%" no está disponible (estado: %)', COALESCE(v_nombre, p_repuesto_id::TEXT), v_estado;
  END IF;
  IF p_cliente_nombre IS NULL OR p_cliente_nombre = '' THEN
    RAISE EXCEPTION 'El nombre del cliente es obligatorio';
  END IF;

  v_fecha_exp := NOW() + (p_dias_expiracion || ' days')::INTERVAL;

  INSERT INTO reservas (repuesto_id, cliente_nombre, cliente_telefono, monto_abono,
                        fecha_expiracion, vendedor_id, notas)
  VALUES (p_repuesto_id, p_cliente_nombre, NULLIF(p_cliente_telefono, ''),
          p_monto_abono, v_fecha_exp,
          v_perfil_id,
          NULLIF(p_notas, ''))
  RETURNING id INTO v_reserva_id;

  UPDATE repuestos SET estado = 'reservado' WHERE id = p_repuesto_id;

  INSERT INTO movimientos (repuesto_id, tipo, fecha, usuario_id, notas)
  VALUES (p_repuesto_id, 'reserva', NOW(),
          v_perfil_id,
          'Reservado para ' || p_cliente_nombre || ' - Abono: $' || p_monto_abono::TEXT);

  RETURN jsonb_build_object('reserva_id', v_reserva_id, 'repuesto', COALESCE(v_nombre, p_repuesto_id::TEXT),
    'cliente', p_cliente_nombre, 'expira', v_fecha_exp, 'success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- RPC: Cancelar reserva
-- ============================================
CREATE OR REPLACE FUNCTION cancelar_reserva(
  p_reserva_id UUID
) RETURNS JSONB AS $$
DECLARE
  v_reserva RECORD;
BEGIN
  SELECT r.*, cp.nombre AS parte_nombre
  INTO v_reserva
  FROM reservas r
  LEFT JOIN repuestos rep ON r.repuesto_id = rep.id
  LEFT JOIN catalogo_partes cp ON rep.catalogo_parte_id = cp.id
  WHERE r.id = p_reserva_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Reserva no encontrada: %', p_reserva_id;
  END IF;
  IF v_reserva.estado != 'activa' THEN
    RAISE EXCEPTION 'La reserva ya no está activa (estado: %)', v_reserva.estado;
  END IF;

  UPDATE repuestos SET estado = 'disponible'
  WHERE id = v_reserva.repuesto_id AND estado = 'reservado';

  UPDATE reservas SET estado = 'cancelada' WHERE id = p_reserva_id;

  INSERT INTO movimientos (repuesto_id, tipo, fecha, usuario_id, notas)
  VALUES (v_reserva.repuesto_id, 'devolucion', NOW(), v_reserva.vendedor_id,
          'Reserva cancelada - Cliente: ' || v_reserva.cliente_nombre);

  RETURN jsonb_build_object('reserva_id', p_reserva_id,
    'repuesto', COALESCE(v_reserva.parte_nombre, v_reserva.repuesto_id::TEXT), 'success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- RPC: Expirar reservas vencidas
-- ============================================
CREATE OR REPLACE FUNCTION expirar_reservas()
RETURNS JSONB AS $$
DECLARE
  v_reserva RECORD;
  v_count INT := 0;
BEGIN
  FOR v_reserva IN
    SELECT r.id, r.repuesto_id, r.cliente_nombre, r.monto_abono, r.vendedor_id
    FROM reservas r
    WHERE r.estado = 'activa' AND r.fecha_expiracion <= NOW()
  LOOP
    UPDATE repuestos SET estado = 'disponible'
    WHERE id = v_reserva.repuesto_id AND estado = 'reservado';

    UPDATE reservas SET estado = 'expirada' WHERE id = v_reserva.id;

    INSERT INTO movimientos (repuesto_id, tipo, fecha, usuario_id, notas)
    VALUES (v_reserva.repuesto_id, 'devolucion', NOW(), v_reserva.vendedor_id,
            'Reserva expirada - Cliente: ' || v_reserva.cliente_nombre ||
            ' - Abono perdido: $' || v_reserva.monto_abono::TEXT);

    v_count := v_count + 1;
  END LOOP;

  RETURN jsonb_build_object('expiradas', v_count, 'success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- RPC: Trasladar repuestos entre ubicaciones
-- ============================================
CREATE OR REPLACE FUNCTION trasladar_repuestos(
  p_repuesto_ids UUID[],
  p_ubicacion_destino_id UUID,
  p_usuario_id UUID,
  p_notas TEXT DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
  v_repuesto_id UUID;
  v_estado TEXT;
  v_nombre TEXT;
  v_ubicacion_origen UUID;
  v_ubicacion_destino_nombre TEXT;
  v_count INT := 0;
  v_perfil_id UUID;
BEGIN
  -- Resolver perfil_id
  v_perfil_id := p_usuario_id;
  IF v_perfil_id IS NULL THEN
    SELECT id INTO v_perfil_id FROM perfiles WHERE user_id = auth.uid();
  END IF;
  IF v_perfil_id IS NULL THEN
    RAISE EXCEPTION 'No se encontró perfil para el usuario actual';
  END IF;

  SELECT nombre INTO v_ubicacion_destino_nombre
  FROM ubicaciones WHERE id = p_ubicacion_destino_id AND activo = true;
  IF v_ubicacion_destino_nombre IS NULL THEN
    RAISE EXCEPTION 'Ubicación destino no encontrada o inactiva';
  END IF;

  FOREACH v_repuesto_id IN ARRAY p_repuesto_ids
  LOOP
    SELECT r.estado, r.ubicacion_id, cp.nombre
    INTO v_estado, v_ubicacion_origen, v_nombre
    FROM repuestos r
    LEFT JOIN catalogo_partes cp ON r.catalogo_parte_id = cp.id
    WHERE r.id = v_repuesto_id
    FOR UPDATE OF r;

    IF v_estado IS NULL THEN
      RAISE EXCEPTION 'Repuesto no encontrado: %', v_repuesto_id;
    END IF;
    IF v_estado NOT IN ('disponible', 'reservado') THEN
      RAISE EXCEPTION 'El repuesto "%" no se puede trasladar (estado: %)',
        COALESCE(v_nombre, v_repuesto_id::TEXT), v_estado;
    END IF;
    IF v_ubicacion_origen = p_ubicacion_destino_id THEN
      CONTINUE;
    END IF;

    UPDATE repuestos SET ubicacion_id = p_ubicacion_destino_id WHERE id = v_repuesto_id;

    INSERT INTO movimientos (repuesto_id, tipo, fecha, usuario_id,
                             ubicacion_origen_id, ubicacion_destino_id, notas)
    VALUES (v_repuesto_id, 'traslado', NOW(), v_perfil_id,
            v_ubicacion_origen, p_ubicacion_destino_id,
            COALESCE(p_notas, 'Traslado a ' || v_ubicacion_destino_nombre));

    v_count := v_count + 1;
  END LOOP;

  RETURN jsonb_build_object('trasladados', v_count, 'destino', v_ubicacion_destino_nombre, 'success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- FIN DEL SCHEMA
-- ============================================
