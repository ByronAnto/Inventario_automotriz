-- ============================================
-- MIGRACIÓN 003: Reservas, traslados, eliminar vehículo
-- ============================================

-- 1. Ampliar CHECK de repuestos.estado para incluir 'reservado'
ALTER TABLE repuestos DROP CONSTRAINT IF EXISTS repuestos_estado_check;
ALTER TABLE repuestos ADD CONSTRAINT repuestos_estado_check
  CHECK (estado IN ('disponible', 'vendido', 'faltante', 'dañado', 'intercambiado', 'descartado', 'reservado'));

-- 2. Ampliar CHECK de movimientos.tipo para incluir 'reserva' y 'devolucion'
ALTER TABLE movimientos DROP CONSTRAINT IF EXISTS movimientos_tipo_check;
ALTER TABLE movimientos ADD CONSTRAINT movimientos_tipo_check
  CHECK (tipo IN ('ingreso_vehiculo', 'ingreso_externo', 'venta', 'intercambio', 'traslado', 'descarte', 'reserva', 'devolucion'));

-- ============================================
-- 3. TABLA reservas
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

-- Índices
CREATE INDEX IF NOT EXISTS idx_reservas_repuesto_id ON reservas(repuesto_id);
CREATE INDEX IF NOT EXISTS idx_reservas_estado ON reservas(estado);
CREATE INDEX IF NOT EXISTS idx_reservas_fecha_expiracion ON reservas(fecha_expiracion);
CREATE INDEX IF NOT EXISTS idx_reservas_vendedor_id ON reservas(vendedor_id);

-- RLS
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

-- ============================================
-- 4. DELETE policy para vehiculos (solo admin)
-- ============================================
DROP POLICY IF EXISTS "vehiculos_delete" ON vehiculos;
CREATE POLICY "vehiculos_delete" ON vehiculos FOR DELETE
  USING (get_user_role() = 'administrador');

-- DELETE policy para repuestos (solo admin, para eliminar vehículo)
DROP POLICY IF EXISTS "repuestos_delete" ON repuestos;
CREATE POLICY "repuestos_delete" ON repuestos FOR DELETE
  USING (get_user_role() = 'administrador');

-- ============================================
-- 5. RPC: Eliminar vehículo (solo si nada vendido)
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
  -- Obtener nombre del vehículo
  SELECT COALESCE(m.nombre || ' ' || mo.nombre || ' ' || v.anio, v.id::TEXT)
  INTO v_nombre
  FROM vehiculos v
  LEFT JOIN marcas m ON v.marca_id = m.id
  LEFT JOIN modelos mo ON v.modelo_id = mo.id
  WHERE v.id = p_vehiculo_id;

  IF v_nombre IS NULL THEN
    RAISE EXCEPTION 'Vehículo no encontrado: %', p_vehiculo_id;
  END IF;

  -- Verificar que no haya repuestos vendidos
  SELECT COUNT(*) INTO v_vendidos
  FROM repuestos WHERE vehiculo_id = p_vehiculo_id AND estado = 'vendido';

  IF v_vendidos > 0 THEN
    RAISE EXCEPTION 'No se puede eliminar "%": tiene % repuesto(s) vendido(s)', v_nombre, v_vendidos;
  END IF;

  -- Verificar que no haya repuestos reservados
  SELECT COUNT(*) INTO v_reservados
  FROM repuestos WHERE vehiculo_id = p_vehiculo_id AND estado = 'reservado';

  IF v_reservados > 0 THEN
    RAISE EXCEPTION 'No se puede eliminar "%": tiene % repuesto(s) reservado(s)', v_nombre, v_reservados;
  END IF;

  -- Contar repuestos a eliminar
  SELECT COUNT(*) INTO v_repuestos_count
  FROM repuestos WHERE vehiculo_id = p_vehiculo_id;

  -- Eliminar movimientos asociados a repuestos del vehículo
  DELETE FROM movimientos WHERE repuesto_id IN (
    SELECT id FROM repuestos WHERE vehiculo_id = p_vehiculo_id
  );

  -- Eliminar repuestos del vehículo
  DELETE FROM repuestos WHERE vehiculo_id = p_vehiculo_id;

  -- Eliminar el vehículo
  DELETE FROM vehiculos WHERE id = p_vehiculo_id;

  RETURN jsonb_build_object(
    'vehiculo_id', p_vehiculo_id,
    'nombre', v_nombre,
    'repuestos_eliminados', v_repuestos_count,
    'success', true
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- 6. RPC: Reservar repuesto
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
  -- Resolver perfil_id: si se pasa p_vendedor_id lo usamos directo,
  -- sino buscamos el perfil del usuario autenticado
  v_perfil_id := p_vendedor_id;
  IF v_perfil_id IS NULL THEN
    SELECT id INTO v_perfil_id FROM perfiles WHERE user_id = auth.uid();
  END IF;
  IF v_perfil_id IS NULL THEN
    RAISE EXCEPTION 'No se encontró perfil para el usuario actual';
  END IF;

  -- Bloquear y validar el repuesto
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

  -- Calcular fecha de expiración
  v_fecha_exp := NOW() + (p_dias_expiracion || ' days')::INTERVAL;

  -- Crear reserva
  INSERT INTO reservas (repuesto_id, cliente_nombre, cliente_telefono, monto_abono,
                        fecha_expiracion, vendedor_id, notas)
  VALUES (p_repuesto_id, p_cliente_nombre, NULLIF(p_cliente_telefono, ''),
          p_monto_abono, v_fecha_exp,
          v_perfil_id,
          NULLIF(p_notas, ''))
  RETURNING id INTO v_reserva_id;

  -- Marcar repuesto como reservado
  UPDATE repuestos SET estado = 'reservado' WHERE id = p_repuesto_id;

  -- Registrar movimiento
  INSERT INTO movimientos (repuesto_id, tipo, fecha, usuario_id, notas)
  VALUES (p_repuesto_id, 'reserva', NOW(),
          v_perfil_id,
          'Reservado para ' || p_cliente_nombre || ' - Abono: $' || p_monto_abono::TEXT);

  RETURN jsonb_build_object(
    'reserva_id', v_reserva_id,
    'repuesto', COALESCE(v_nombre, p_repuesto_id::TEXT),
    'cliente', p_cliente_nombre,
    'expira', v_fecha_exp,
    'success', true
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- 7. RPC: Cancelar reserva (devolver a disponible)
-- ============================================
CREATE OR REPLACE FUNCTION cancelar_reserva(
  p_reserva_id UUID
) RETURNS JSONB AS $$
DECLARE
  v_reserva RECORD;
  v_nombre TEXT;
BEGIN
  -- Buscar la reserva
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

  -- Devolver repuesto a disponible
  UPDATE repuestos SET estado = 'disponible'
  WHERE id = v_reserva.repuesto_id AND estado = 'reservado';

  -- Marcar reserva como cancelada
  UPDATE reservas SET estado = 'cancelada'
  WHERE id = p_reserva_id;

  -- Registrar movimiento
  INSERT INTO movimientos (repuesto_id, tipo, fecha, usuario_id, notas)
  VALUES (v_reserva.repuesto_id, 'devolucion', NOW(), v_reserva.vendedor_id,
          'Reserva cancelada - Cliente: ' || v_reserva.cliente_nombre);

  RETURN jsonb_build_object(
    'reserva_id', p_reserva_id,
    'repuesto', COALESCE(v_reserva.parte_nombre, v_reserva.repuesto_id::TEXT),
    'success', true
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- 8. RPC: Expirar reservas vencidas
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
    WHERE r.estado = 'activa'
      AND r.fecha_expiracion <= NOW()
  LOOP
    -- Devolver repuesto a disponible
    UPDATE repuestos SET estado = 'disponible'
    WHERE id = v_reserva.repuesto_id AND estado = 'reservado';

    -- Marcar reserva como expirada
    UPDATE reservas SET estado = 'expirada'
    WHERE id = v_reserva.id;

    -- Registrar movimiento de devolución
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
-- 9. RPC: Trasladar repuestos entre ubicaciones
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
  -- Resolver perfil_id: si se pasa p_usuario_id lo usamos directo,
  -- sino buscamos el perfil del usuario autenticado
  v_perfil_id := p_usuario_id;
  IF v_perfil_id IS NULL THEN
    SELECT id INTO v_perfil_id FROM perfiles WHERE user_id = auth.uid();
  END IF;
  IF v_perfil_id IS NULL THEN
    RAISE EXCEPTION 'No se encontró perfil para el usuario actual';
  END IF;

  -- Validar ubicación destino
  SELECT nombre INTO v_ubicacion_destino_nombre
  FROM ubicaciones WHERE id = p_ubicacion_destino_id AND activo = true;

  IF v_ubicacion_destino_nombre IS NULL THEN
    RAISE EXCEPTION 'Ubicación destino no encontrada o inactiva';
  END IF;

  FOREACH v_repuesto_id IN ARRAY p_repuesto_ids
  LOOP
    -- Obtener datos del repuesto
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
      CONTINUE; -- Ya está en la ubicación destino
    END IF;

    -- Actualizar ubicación
    UPDATE repuestos SET ubicacion_id = p_ubicacion_destino_id
    WHERE id = v_repuesto_id;

    -- Registrar movimiento de traslado
    INSERT INTO movimientos (repuesto_id, tipo, fecha, usuario_id,
                             ubicacion_origen_id, ubicacion_destino_id, notas)
    VALUES (v_repuesto_id, 'traslado', NOW(), v_perfil_id,
            v_ubicacion_origen, p_ubicacion_destino_id,
            COALESCE(p_notas, 'Traslado a ' || v_ubicacion_destino_nombre));

    v_count := v_count + 1;
  END LOOP;

  RETURN jsonb_build_object(
    'trasladados', v_count,
    'destino', v_ubicacion_destino_nombre,
    'success', true
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
