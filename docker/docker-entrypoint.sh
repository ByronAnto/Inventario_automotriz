#!/bin/sh
# ============================================
# docker-entrypoint.sh — Runtime env injection
# Reemplaza placeholders en los archivos JS compilados
# con las variables de entorno reales del contenedor.
# ============================================
set -e

WEB_ROOT="/usr/share/nginx/html"

# Valores por defecto si no se pasan variables
SUPABASE_URL="${SUPABASE_URL:-http://localhost:8000}"
SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-}"

echo "🔧 Configurando frontend..."
echo "   SUPABASE_URL = ${SUPABASE_URL}"
echo "   SUPABASE_ANON_KEY = ${SUPABASE_ANON_KEY:0:20}..."

# Reemplazar en todos los archivos JS compilados
# Flutter compila los dart-define como strings literales en main.dart.js
find "$WEB_ROOT" -name '*.js' -type f | while read -r file; do
    # Reemplazar la URL placeholder
    sed -i "s|__SUPABASE_URL_PLACEHOLDER__|${SUPABASE_URL}|g" "$file"
    # Reemplazar el ANON_KEY placeholder
    sed -i "s|__SUPABASE_ANON_KEY_PLACEHOLDER__|${SUPABASE_ANON_KEY}|g" "$file"
done

echo "✅ Frontend configurado correctamente"

# Ejecutar nginx
exec nginx -g 'daemon off;'
