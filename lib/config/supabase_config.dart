// ============================================
// Configuración de Supabase
// ============================================
// Se puede configurar de 3 formas (en orden de prioridad):
//
// 1. En tiempo de compilación con --dart-define:
//    flutter build apk --dart-define=SUPABASE_URL=http://192.168.1.100:8000 \
//                       --dart-define=SUPABASE_ANON_KEY=tu_key
//
// 2. Desde la pantalla de configuración en la app (se guarda en SharedPreferences)
//
// 3. Valores por defecto hardcodeados abajo (para desarrollo local)

import 'package:shared_preferences/shared_preferences.dart';

class SupabaseConfig {
  // ── Valores por defecto (desarrollo local con Docker) ──
  static const String _defaultUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'http://localhost:8000',
  );
  static const String _defaultAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlIiwiaWF0IjoxNzAwMDAwMDAwLCJleHAiOjIwMDAwMDAwMDB9.6ldkvHM8WjwyHI_tKbJOgWu-VbulTx9jmeuEvNGSFkY',
  );
  static const String _defaultServiceRoleKey = String.fromEnvironment(
    'SUPABASE_SERVICE_ROLE_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIiwiaXNzIjoic3VwYWJhc2UiLCJpYXQiOjE3MDAwMDAwMDAsImV4cCI6MjAwMDAwMDAwMH0.mjENke8J4x_734atFXjInx76tWeHpG_5y1KaXY_3Smg',
  );

  // ── Keys de SharedPreferences ──
  static const String _urlKey = 'supabase_url';
  static const String _anonKeyKey = 'supabase_anon_key';

  // ── Valores activos (se cargan al iniciar) ──
  static String supabaseUrl = _defaultUrl;
  static String supabaseAnonKey = _defaultAnonKey;
  static String serviceRoleKey = _defaultServiceRoleKey;

  // Bucket para almacenar fotos
  static const String vehiculosBucket = 'vehiculos';
  static const String repuestosBucket = 'repuestos';

  /// Cargar configuración guardada (llamar antes de Supabase.initialize)
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    supabaseUrl = prefs.getString(_urlKey) ?? _defaultUrl;
    supabaseAnonKey = prefs.getString(_anonKeyKey) ?? _defaultAnonKey;
  }

  /// Guardar nueva configuración de backend
  static Future<void> save({required String url, required String anonKey}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_urlKey, url);
    await prefs.setString(_anonKeyKey, anonKey);
    supabaseUrl = url;
    supabaseAnonKey = anonKey;
  }

  /// Resetear a valores por defecto
  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_urlKey);
    await prefs.remove(_anonKeyKey);
    supabaseUrl = _defaultUrl;
    supabaseAnonKey = _defaultAnonKey;
  }

  /// Verificar si tiene configuración personalizada
  static Future<bool> hasCustomConfig() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_urlKey);
  }
}
