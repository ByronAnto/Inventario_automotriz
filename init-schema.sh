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
KONG_PORT="${KONG_HTTP_PORT:-8000}"
ANON_KEY="${ANON_KEY:-}"

# Credenciales del admin (se pueden sobreescribir con variables de entorno)
ADMIN_EMAIL="${ADMIN_EMAIL:-admin@autopartes.com}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-Admin2026!}"
ADMIN_NOMBRE="${ADMIN_NOMBRE:-Administrador}"

echo "🔧 Esperando que la base de datos esté lista..."
until docker exec "$CONTAINER_NAME" pg_isready -U supabase_admin > /dev/null 2>&1; do
  sleep 1
done

echo "📦 Cargando esquema desde: $SCHEMA_FILE"
docker exec -i -e PGPASSWORD="$DB_PASSWORD" "$CONTAINER_NAME" psql -U postgres -d postgres < "$SCHEMA_FILE"

echo ""
echo "✅ Esquema cargado exitosamente."

# ── Crear usuario administrador automáticamente ──
echo ""
echo "👤 Creando usuario administrador..."

if [ -z "$ANON_KEY" ]; then
  echo "⚠️  ANON_KEY no encontrada en .env. Saltando creación automática del admin."
  echo "   Crea el usuario manualmente con:"
  echo "   curl -X POST http://localhost:${KONG_PORT}/auth/v1/signup \\"
  echo "     -H 'apikey: TU_ANON_KEY' -H 'Content-Type: application/json' \\"
  echo "     -d '{\"email\": \"${ADMIN_EMAIL}\", \"password\": \"${ADMIN_PASSWORD}\"}'"
  exit 0
fi

# Esperar a que el servicio de Auth esté listo
echo "   Esperando servicio de autenticación..."
for i in $(seq 1 30); do
  if curl -sf "http://localhost:${KONG_PORT}/auth/v1/health" -H "apikey: ${ANON_KEY}" > /dev/null 2>&1; then
    break
  fi
  sleep 2
done

# Verificar si ya existe un usuario admin
EXISTING=$(docker exec -e PGPASSWORD="$DB_PASSWORD" "$CONTAINER_NAME" \
  psql -U supabase_admin -d postgres -tAc \
  "SELECT count(*) FROM auth.users WHERE email = '${ADMIN_EMAIL}';" 2>/dev/null || echo "0")

if [ "$EXISTING" -gt 0 ] 2>/dev/null; then
  echo "   ℹ️  El usuario ${ADMIN_EMAIL} ya existe. Saltando."
else
  # Crear usuario via API de signup
  SIGNUP_RESPONSE=$(curl -sf -X POST "http://localhost:${KONG_PORT}/auth/v1/signup" \
    -H "apikey: ${ANON_KEY}" \
    -H "Content-Type: application/json" \
    -d "{\"email\": \"${ADMIN_EMAIL}\", \"password\": \"${ADMIN_PASSWORD}\"}" 2>/dev/null || echo "ERROR")

  if echo "$SIGNUP_RESPONSE" | grep -q '"id"'; then
    USER_ID=$(echo "$SIGNUP_RESPONSE" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
    echo "   ✅ Usuario creado: ${ADMIN_EMAIL} (ID: ${USER_ID})"

    # Crear perfil de administrador
    docker exec -e PGPASSWORD="$DB_PASSWORD" "$CONTAINER_NAME" \
      psql -U supabase_admin -d postgres -c \
      "INSERT INTO perfiles (user_id, nombre, email, rol)
       VALUES ('${USER_ID}', '${ADMIN_NOMBRE}', '${ADMIN_EMAIL}', 'administrador')
       ON CONFLICT (user_id) DO NOTHING;" > /dev/null 2>&1

    echo "   ✅ Perfil de administrador creado."
  else
    echo "   ❌ Error al crear usuario. Respuesta: ${SIGNUP_RESPONSE}"
    echo "   Puedes crearlo manualmente después."
  fi
fi

echo ""
echo "🎉 Inicialización completa."
echo ""
echo "   📊 Studio:    http://localhost:${STUDIO_PORT:-3100}"
echo "   🔑 API:       http://localhost:${KONG_PORT}"
echo "   👤 Admin:     ${ADMIN_EMAIL} / ${ADMIN_PASSWORD}"
echo ""
echo "   Para cambiar credenciales del admin, edita en .env:"
echo "     ADMIN_EMAIL=tu@email.com"
echo "     ADMIN_PASSWORD=TuPassword123!"
