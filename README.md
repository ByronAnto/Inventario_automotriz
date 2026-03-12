# 🚗 AutoPartes Inventory

**Sistema de Inventario de Repuestos Automotrices Usados**

Aplicación multiplataforma (Android APK + Web) para gestionar la compra de vehículos siniestrados/dados de baja, inspección mecánica de ~190 partes, generación automática de inventario de repuestos, ventas con seguimiento por vendedor y reportes de ROI.

---

## 📋 Tabla de Contenidos

- [Características](#-características)
- [Arquitectura](#-arquitectura)
- [Stack Tecnológico](#-stack-tecnológico)
- [Estructura del Proyecto](#-estructura-del-proyecto)
- [Requisitos Previos](#-requisitos-previos)
- [Instalación y Configuración](#-instalación-y-configuración)
- [Base de Datos](#-base-de-datos)
- [Uso](#-uso)
- [Despliegue](#-despliegue)
- [CI/CD](#-cicd)
- [Variables de Entorno](#-variables-de-entorno)
- [Licencia](#-licencia)

---

## ✨ Características

### Gestión de Vehículos
- Registro de vehículos comprados (siniestrados, dados de baja, incompletos)
- Asociación con marca, modelo, año, color, VIN, placa
- Soporte para 4 tipos: sedán, SUV/camioneta, camión, moto
- Registro de costo de compra y proveedor

### Inspección Mecánica (~190 partes)
- Checklist organizado por categorías: Motor, Transmisión, Suspensión, Frenos, Eléctrico, Carrocería, Interior, Accesorios
- Cada parte se evalúa como: bueno, regular, malo, faltante
- Plantillas dinámicas según tipo de vehículo
- Generación automática de repuestos al completar inspección

### Inventario de Repuestos
- Generación automática desde inspección del vehículo
- Estados: disponible, reservado, vendido, descartado
- Precio sugerido y precio final por pieza
- Ubicación física (multi-sucursal)
- Código único por repuesto
- Barra de resumen con contadores (total, disponible, vendido, atención)
- Filtro por marca de vehículo y estado
- Búsqueda ampliada (repuesto, vehículo, marca, ubicación)
- Cards con info de vehículo y origen
- Vista detalle con BottomSheet completo
- Grid responsive en pantallas anchas

### Ventas
- Registro de ventas con detalle por repuesto
- Métodos de pago: efectivo, transferencia, tarjeta
- Seguimiento por vendedor con comisiones configurables
- Datos del cliente (nombre, teléfono)

### Reportes y Dashboard
- ROI por vehículo (costo compra vs. ventas generadas)
- Ventas por período y vendedor
- Inventario por estado y ubicación
- Gráficos interactivos con fl_chart

### Gestión de Usuarios (CRUD)
- Alta de usuarios con rol y comisión configurable
- Edición de nombre, email, teléfono, rol y porcentaje de comisión
- Activar/desactivar usuarios
- Creación vía API admin con `SERVICE_ROLE_KEY`

### Autenticación y Roles
- **Administrador**: Acceso completo, gestión de usuarios, configuración
- **Vendedor**: Ventas, consulta de inventario
- **Mecánico**: Inspecciones, registro de condiciones
- Auto-creación de perfil en primer login
- Primer usuario registrado recibe rol administrador automáticamente

---

## 🏗 Arquitectura

```
┌─────────────────────────────────────────────────────────┐
│                    Flutter App (APK + Web)               │
│  Riverpod 3.x · go_router · fl_chart · supabase_flutter │
└──────────────────────────┬──────────────────────────────┘
                           │ HTTP/REST
                           ▼
┌──────────────────────────────────────────────────────────┐
│                   Kong API Gateway (:8000)                │
│              JWT Auth · CORS · Rate Limiting             │
└──────┬──────────┬──────────┬──────────┬─────────────────┘
       │          │          │          │
       ▼          ▼          ▼          ▼
   GoTrue    PostgREST   Realtime   Storage
   (:9999)   (:3200)     (:4000)    (:5000)
       │          │          │          │
       └──────────┴──────────┴──────────┘
                       │
                       ▼
            ┌───────────────────┐
            │  PostgreSQL 15.8  │
            │     (:5434)       │
            └───────────────────┘

   Studio (:3100) ──► postgres-meta (:8090)
```

---

## 🛠 Stack Tecnológico

| Componente | Tecnología | Versión |
|---|---|---|
| **Frontend** | Flutter / Dart | 3.41.2 / 3.11.0 |
| **State Management** | Riverpod 3.x | flutter_riverpod 3.3.1 |
| **Routing** | go_router | 17.1.0 |
| **Charts** | fl_chart | 1.1.1 |
| **Backend** | Supabase Self-Hosted | Docker |
| **Base de Datos** | PostgreSQL | 15.8.1.085 |
| **Auth** | GoTrue | v2.186.0 |
| **API REST** | PostgREST | v14.5 |
| **Realtime** | Supabase Realtime | v2.76.5 |
| **Storage** | Supabase Storage | v1.37.8 |
| **API Gateway** | Kong | 2.8.1 |
| **Admin UI** | Supabase Studio | 2026.02.16 |
| **Image Proxy** | imgproxy | v3.30.1 |

---

## 📁 Estructura del Proyecto

```
Inventario_automotriz/
├── lib/
│   ├── main.dart                          # Punto de entrada
│   ├── config/
│   │   ├── app_theme.dart                 # Tema Material Design (colores, tipografía)
│   │   ├── router.dart                    # Rutas con go_router y guards de auth
│   │   └── supabase_config.dart           # Config de URL/key + SERVICE_ROLE_KEY (admin API)
│   ├── core/
│   │   └── constants/
│   │       └── app_constants.dart         # Constantes globales
│   ├── data/
│   │   ├── models/
│   │   │   ├── catalogo_parte.dart        # Catálogo maestro de partes
│   │   │   ├── marca_modelo.dart          # Marcas y modelos de vehículos
│   │   │   ├── movimiento.dart            # Movimientos de inventario
│   │   │   ├── perfil.dart                # Perfil de usuario (rol, comisión)
│   │   │   ├── repuesto.dart              # Repuesto individual
│   │   │   ├── tipo_vehiculo.dart         # Tipo (sedán, SUV, camión, moto)
│   │   │   ├── ubicacion.dart             # Sucursales/ubicaciones físicas
│   │   │   ├── vehiculo.dart              # Vehículo comprado
│   │   │   ├── venta.dart                 # Venta con detalle
│   │   │   └── models.dart                # Barrel file (exporta todos)
│   │   └── providers/
│   │       └── auth_provider.dart         # Provider de autenticación (Riverpod 3.x)
│   └── features/
│       ├── auth/
│       │   └── screens/
│       │       └── login_screen.dart      # Pantalla de login
│       ├── configuracion/
│       │   └── screens/
│       │       └── configuracion_screen.dart  # Config: URL backend, Catálogo, Plantillas, Ubicaciones, Usuarios
│       ├── dashboard/
│       │   └── screens/
│       │       └── dashboard_screen.dart  # Dashboard principal con métricas
│       ├── inventario/
│       │   └── screens/
│       │       └── inventario_screen.dart # Listado y búsqueda de repuestos
│       ├── movimientos/
│       │   └── screens/
│       │       └── movimientos_screen.dart # Historial de movimientos
│       ├── reportes/
│       │   └── screens/
│       │       └── reportes_screen.dart   # Gráficos de ROI y ventas
│       ├── vehiculos/
│       │   └── screens/
│       │       ├── vehiculos_list_screen.dart      # Listado de vehículos
│       │       ├── vehiculo_form_screen.dart        # Formulario de ingreso
│       │       └── condiciones_ingreso_screen.dart  # Checklist de inspección
│       └── ventas/
│           └── screens/
│               ├── ventas_screen.dart     # Historial de ventas
│               └── nueva_venta_screen.dart # Registrar nueva venta
├── supabase/
│   └── schema.sql                         # Esquema completo (13 tablas + RLS + seed)
├── docker/
│   ├── kong.yml                           # Configuración declarativa de Kong
│   ├── roles.sql                          # Roles y permisos de PostgreSQL
│   ├── nginx.conf                         # Config Nginx con anti-cache para Flutter
│   └── docker-entrypoint.sh               # Inyección de env vars en runtime
├── Dockerfile                             # Multi-stage: Flutter build + Nginx Alpine
├── docker-compose.yml                     # 10 servicios (Supabase + web-app)
├── setup.sh                               # Deploy automático (detecta IP, genera .env, build, up)
├── init-schema.sh                         # Script para cargar esquema en la DB
├── .github/workflows/flutter-web.yml      # CI/CD: build, test, Docker push, deploy
├── .env                                   # Variables de entorno (NO se sube a git)
├── android/                               # Configuración nativa Android
├── web/                                   # Configuración web (index.html, manifest)
├── pubspec.yaml                           # Dependencias Flutter/Dart
└── analysis_options.yaml                  # Reglas de lint
```

---

## 📌 Requisitos Previos

- **Flutter** ≥ 3.41.0 ([Instalar Flutter](https://docs.flutter.dev/get-started/install))
- **Docker** y **Docker Compose** v2+
- **Git**
- (Opcional) Android Studio o VS Code con extensiones Flutter/Dart

---

## 🚀 Instalación y Configuración

### 1. Clonar el repositorio

```bash
git clone https://github.com/ByronAnto/Inventario_automotriz.git
cd Inventario_automotriz
```

### 2. Configurar variables de entorno

Crear archivo `.env` en la raíz del proyecto:

```env
# ── PostgreSQL ──
POSTGRES_PASSWORD=TuPasswordSeguro123!
POSTGRES_PORT=5434
POSTGRES_DB=postgres

# ── JWT (mínimo 32 caracteres) ──
JWT_SECRET=tu-jwt-secret-de-al-menos-32-caracteres-aqui

# ── URLs ──
SITE_URL=http://localhost:3100
API_EXTERNAL_URL=http://localhost:8000

# ── Puertos ──
KONG_HTTP_PORT=8000
GOTRUE_PORT=9999
REST_PORT=3200
REALTIME_PORT=4000
STORAGE_PORT=5000
IMGPROXY_PORT=5001
STUDIO_PORT=3100
META_PORT=8090

# ── Auth ──
GOTRUE_DISABLE_SIGNUP=false
GOTRUE_EXTERNAL_EMAIL_ENABLED=true
GOTRUE_MAILER_AUTOCONFIRM=true
GOTRUE_SMS_AUTOCONFIRM=true

# ── Postgres Meta ──
PG_META_CRYPTO_KEY=tu-crypto-key-de-al-menos-32-caracteres!

# ── JWT Tokens (generar con tu JWT_SECRET) ──
ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
SERVICE_ROLE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

> **Nota**: Para generar `ANON_KEY` y `SERVICE_ROLE_KEY`, usa [jwt.io](https://jwt.io) con tu `JWT_SECRET`:
> - ANON_KEY payload: `{"role": "anon", "iss": "supabase", "iat": 1700000000, "exp": 2000000000}`
> - SERVICE_ROLE_KEY payload: `{"role": "service_role", "iss": "supabase", "iat": 1700000000, "exp": 2000000000}`

### 3. Levantar backend (Supabase Docker)

```bash
# Crear directorios necesarios para Studio
mkdir -p docker/snippets docker/edge-functions

# Levantar todos los servicios
docker compose up -d

# Verificar que todo esté corriendo
docker compose ps
```

### 4. Cargar esquema de base de datos

```bash
chmod +x init-schema.sh
./init-schema.sh
```

Esto crea las 13 tablas, políticas RLS, índices y datos seed (~1680 plantillas de partes).

### 5. Crear usuario administrador

```bash
# Registrar usuario via API
curl -X POST http://localhost:8000/auth/v1/signup \
  -H "apikey: TU_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"email": "admin@tuempresa.com", "password": "TuPassword123!"}'

# Crear perfil de administrador (reemplazar USER_ID del paso anterior)
docker exec -e PGPASSWORD=TuPasswordSeguro123! NOMBRE_CONTENEDOR_DB \
  psql -U supabase_admin -d postgres -c \
  "INSERT INTO perfiles (user_id, nombre, email, rol) VALUES ('USER_ID', 'Administrador', 'admin@tuempresa.com', 'administrador');"
```

### 6. Instalar dependencias Flutter y ejecutar

```bash
# Instalar dependencias
flutter pub get

# Ejecutar en Chrome (desarrollo)
flutter run -d chrome

# Ejecutar como servidor web accesible en red
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080

# Compilar APK
flutter build apk --release
```

---

## 🗄 Base de Datos

### Diagrama de Tablas (13 tablas)

```
perfiles ──────────── auth.users
    │
    ├── vehiculos ───── marcas
    │       │            └── modelos
    │       ├── tipos_vehiculo
    │       │       └── plantilla_tipo_vehiculo ── catalogo_partes
    │       ├── ubicaciones
    │       └── condicion_partes_vehiculo ── catalogo_partes
    │
    ├── repuestos ───── vehiculos
    │       │           ubicaciones
    │       └── movimientos ── perfiles
    │                         ubicaciones
    │
    └── ventas
            └── venta_detalle ── repuestos
```

### Tablas principales

| Tabla | Descripción | Filas seed |
|---|---|---|
| `perfiles` | Usuarios con roles (admin/vendedor/mecánico) | — |
| `tipos_vehiculo` | Sedán, SUV/Camioneta, Camión, Moto | 4 |
| `catalogo_partes` | Catálogo maestro de ~190 partes | ~190 |
| `plantilla_tipo_vehiculo` | Partes asignadas por tipo de vehículo | ~1680 |
| `marcas` | Marcas de vehículos | — |
| `modelos` | Modelos por marca | — |
| `ubicaciones` | Sucursales/ubicaciones físicas | — |
| `vehiculos` | Vehículos comprados | — |
| `condicion_partes_vehiculo` | Resultado de inspección por parte | — |
| `repuestos` | Repuestos individuales en inventario | — |
| `movimientos` | Trazabilidad de cada movimiento | — |
| `ventas` | Cabecera de ventas | — |
| `venta_detalle` | Detalle de cada venta (repuestos vendidos) | — |

### Row Level Security (RLS)

Todas las tablas tienen RLS habilitado con políticas que permiten lectura a usuarios autenticados (`authenticated`) y escritura según el rol del usuario.

---

## 💻 Uso

### Puertos por defecto

| Servicio | Puerto | URL |
|---|---|---|
| **Flutter Web App** | 3001 | `http://localhost:3001` |
| **Kong API Gateway** | 8000 | `http://localhost:8000` |
| **Supabase Studio** | 3100 | `http://localhost:3100` |
| **PostgreSQL** | 5434 | `localhost:5434` |
| **GoTrue (Auth)** | 9999 | `http://localhost:9999` |
| **PostgREST** | 3200 | `http://localhost:3200` |
| **Realtime** | 4000 | `http://localhost:4000` |
| **Storage** | 5000 | `http://localhost:5000` |
| **imgproxy** | 5001 | `http://localhost:5001` |
| **postgres-meta** | 8090 | `http://localhost:8090` |

### Configurar URL del backend en la app

La app permite configurar la URL del backend de 3 formas (en orden de prioridad):

1. **En tiempo de compilación** con `--dart-define`:
   ```bash
   flutter build apk --dart-define=SUPABASE_URL=http://192.168.1.100:8000
   ```

2. **Desde la pantalla de configuración** dentro de la app (se guarda en SharedPreferences)

3. **Valor por defecto** hardcodeado en `lib/config/supabase_config.dart`

### Acceso desde red local

Para acceder desde otros dispositivos en la misma red:

```bash
# Obtener IP de la máquina
hostname -I | awk '{print $1}'

# Ejecutar Flutter web accesible externamente
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080
```

Acceder desde otro dispositivo: `http://TU_IP:8080`

> **Importante**: El backend (Kong) en puerto 8000 también debe ser accesible. Actualiza `SUPABASE_URL` en la app a `http://TU_IP:8000`.

---

## 📦 Despliegue

### Deploy Automático con `setup.sh`

El script `setup.sh` automatiza completamente el despliegue en cualquier VM (Oracle Cloud, AWS, Azure, GCP):

```bash
chmod +x setup.sh
./setup.sh              # Detecta IP pública automáticamente
./setup.sh 203.0.113.50 # Usa una IP/dominio específico
```

**¿Qué hace `setup.sh`?**
1. Detecta la IP pública de la VM (Oracle IMDS, AWS, Azure, GCP o servicios externos)
2. Genera/actualiza `.env` con las URLs correctas
3. Construye la imagen Docker del frontend web (`--no-cache`)
4. Levanta los 10 servicios con `docker compose up -d --force-recreate`
5. Carga el esquema SQL y crea usuario admin (si no existe)

### Docker Web (Multi-stage)

El `Dockerfile` compila Flutter Web y sirve con Nginx Alpine:

```
Etapa 1: ghcr.io/cirruslabs/flutter:3.41.2 → flutter build web --release
Etapa 2: nginx:1.27-alpine → Sirve /usr/share/nginx/html
```

- **Placeholders en build**: `__SUPABASE_URL_PLACEHOLDER__` y `__SUPABASE_ANON_KEY_PLACEHOLDER__`
- **Inyección en runtime**: `docker-entrypoint.sh` reemplaza los placeholders con env vars reales
- **Anti-cache**: `main.dart.js`, `flutter_service_worker.js`, `flutter_bootstrap.js` y `version.json` usan `no-store, no-cache`

### Compilar APK (Android)

```bash
flutter build apk --release \
  --dart-define=SUPABASE_URL=http://TU_SERVIDOR:8000 \
  --dart-define=SUPABASE_ANON_KEY=TU_ANON_KEY
```

El APK se genera en: `build/app/outputs/flutter-apk/app-release.apk`

### Compilar Web (manual)

```bash
flutter build web --release \
  --dart-define=SUPABASE_URL=http://TU_SERVIDOR:8000 \
  --dart-define=SUPABASE_ANON_KEY=TU_ANON_KEY
```

Los archivos estáticos se generan en: `build/web/`

---

## 🔄 CI/CD

### GitHub Actions Pipeline (`.github/workflows/flutter-web.yml`)

Se ejecuta automáticamente en cada push a `main`:

```
┌──────────────┐
│  build       │  Flutter analyze + test
└──────┬───────┘
       │
  ┌────┴────┐
  ▼         ▼
┌────────┐ ┌───────────┐
│ docker │ │ build-apk │  (en paralelo)
│ (GHCR) │ │ (artifact)│
└────┬───┘ └───────────┘
     │
     ▼
┌──────────┐
│  deploy  │  Self-hosted runner (Oracle VM ARM64)
│  (rsync) │  → setup.sh → docker compose up
└──────────┘
```

**4 jobs:**

| Job | Runner | Descripción |
|---|---|---|
| `build` | `ubuntu-latest` | `flutter analyze` + `flutter test` |
| `docker` | `ubuntu-latest` | Build Docker image → push a `ghcr.io` |
| `build-apk` | `ubuntu-latest` | `flutter build apk --release` → artifact (30 días) |
| `deploy` | `self-hosted, Linux, ARM64` | rsync al VM + `setup.sh` con `--no-cache` |

**Self-hosted runner**: `oraclemv` en Oracle Cloud VM (ARM64)

---

## 🔐 Variables de Entorno

| Variable | Descripción | Obligatoria |
|---|---|---|
| `POSTGRES_PASSWORD` | Contraseña de PostgreSQL | ✅ |
| `JWT_SECRET` | Secreto para firmar JWT (≥32 chars) | ✅ |
| `ANON_KEY` | JWT con rol `anon` | ✅ |
| `SERVICE_ROLE_KEY` | JWT con rol `service_role` | ✅ |
| `PG_META_CRYPTO_KEY` | Clave de cifrado para postgres-meta (≥32 chars) | ✅ |
| `SITE_URL` | URL del frontend | ✅ |
| `API_EXTERNAL_URL` | URL externa del API Gateway | ✅ |
| `POSTGRES_PORT` | Puerto de PostgreSQL (default: 5434) | ❌ |
| `KONG_HTTP_PORT` | Puerto de Kong (default: 8000) | ❌ |
| `STUDIO_PORT` | Puerto de Studio (default: 3100) | ❌ |
| `GOTRUE_DISABLE_SIGNUP` | Deshabilitar registro público (default: false) | ❌ |
| `GOTRUE_MAILER_AUTOCONFIRM` | Auto-confirmar emails (default: true) | ❌ |

---

## 📄 Licencia

Este proyecto es de uso privado. Todos los derechos reservados.
