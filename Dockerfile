# ============================================
# Dockerfile - Flutter Web + Nginx
# Multi-stage build: compila Flutter y sirve con Nginx
# ============================================

# ── Etapa 1: Build Flutter Web ──
FROM ghcr.io/cirruslabs/flutter:3.41.2 AS build

WORKDIR /app

# Copiar dependencias primero (cache de Docker)
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

# Copiar código fuente
COPY lib/ lib/
COPY web/ web/
COPY analysis_options.yaml ./

# Compilar Flutter Web con PLACEHOLDERS (se reemplazan en runtime)
RUN flutter build web --release \
    --dart-define=SUPABASE_URL=__SUPABASE_URL_PLACEHOLDER__ \
    --dart-define=SUPABASE_ANON_KEY=__SUPABASE_ANON_KEY_PLACEHOLDER__

# ── Etapa 2: Servir con Nginx ──
FROM nginx:1.27-alpine

# Copiar configuración personalizada de Nginx
COPY docker/nginx.conf /etc/nginx/conf.d/default.conf

# Copiar entrypoint que inyecta env vars en runtime
COPY docker/docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh && apk add --no-cache curl

# Copiar el build de Flutter Web
COPY --from=build /app/build/web /usr/share/nginx/html

# Exponer puerto 80
EXPOSE 80

# Healthcheck
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD curl -f http://localhost/ || exit 1

ENTRYPOINT ["/docker-entrypoint.sh"]
