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

# Argumentos de build (se pasan desde docker-compose)
ARG SUPABASE_URL=http://localhost:8000
ARG SUPABASE_ANON_KEY=

# Compilar Flutter Web en modo release
RUN flutter build web --release \
    --dart-define=SUPABASE_URL=${SUPABASE_URL} \
    --dart-define=SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY}

# ── Etapa 2: Servir con Nginx ──
FROM nginx:1.27-alpine

# Copiar configuración personalizada de Nginx
COPY docker/nginx.conf /etc/nginx/conf.d/default.conf

# Copiar el build de Flutter Web
COPY --from=build /app/build/web /usr/share/nginx/html

# Exponer puerto 80
EXPOSE 80

# Healthcheck
HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD wget -qO- http://localhost/ || exit 1
