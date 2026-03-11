#!/bin/bash
# ============================================================
# init-schema.sh
# Ejecutar DESPUÉS de que todos los contenedores estén corriendo
# Carga el esquema SQL en la base de datos Supabase
# ============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMA_FILE="${SCRIPT_DIR}/supabase/schema.sql"
CONTAINER_NAME="autopartes-db"

# Cargar variables de .env si existe
if [ -f "${SCRIPT_DIR}/.env" ]; then
  export $(grep -v '^#' "${SCRIPT_DIR}/.env" | xargs)
fi

DB_PASSWORD="${POSTGRES_PASSWORD:-AutoPartes2026Secure!}"
DB_PORT="${POSTGRES_PORT:-5434}"

echo "🔧 Esperando que la base de datos esté lista..."
until docker exec "$CONTAINER_NAME" pg_isready -U supabase_admin > /dev/null 2>&1; do
  sleep 1
done

echo "📦 Cargando esquema desde: $SCHEMA_FILE"
docker exec -i -e PGPASSWORD="$DB_PASSWORD" "$CONTAINER_NAME" psql -U postgres -d postgres < "$SCHEMA_FILE"

echo ""
echo "✅ Esquema cargado exitosamente."
echo ""
echo "📋 Para crear el primer usuario administrador:"
echo "   1. Abre Supabase Studio en: http://localhost:${STUDIO_PORT:-3100}"
echo "   2. Ve a Authentication → Users → Add user"
echo "   3. Crea el usuario con email y contraseña"
echo "   4. Ve a Table Editor → perfiles"
echo "   5. Agrega un registro con:"
echo "      - user_id: (el UUID del usuario creado)"
echo "      - nombre: Admin"
echo "      - rol: administrador"
echo ""
echo "   O ejecuta directamente en SQL Editor:"
echo "   -- Después de crear el usuario en Auth:"
echo "   INSERT INTO perfiles (user_id, nombre, email, rol)"
echo "   SELECT id, 'Administrador', email, 'administrador'"
echo "   FROM auth.users LIMIT 1;"
