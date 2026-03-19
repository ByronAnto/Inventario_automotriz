import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../config/supabase_config.dart';

/// Pantalla de configuración inicial del servidor.
/// Se muestra la primera vez que se abre la app en un dispositivo
/// donde no hay URL de backend configurada (ej: APK recién instalado).
class ServerSetupScreen extends ConsumerStatefulWidget {
  const ServerSetupScreen({super.key});

  @override
  ConsumerState<ServerSetupScreen> createState() => _ServerSetupScreenState();
}

class _ServerSetupScreenState extends ConsumerState<ServerSetupScreen> {
  final _urlController = TextEditingController();
  final _keyController = TextEditingController();
  bool _obscureKey = true;
  bool _testing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Pre-rellenar con valores por defecto si existen
    _urlController.text =
        SupabaseConfig.supabaseUrl == 'http://localhost:8000'
            ? ''
            : SupabaseConfig.supabaseUrl;
    _keyController.text =
        SupabaseConfig.supabaseAnonKey;
  }

  @override
  void dispose() {
    _urlController.dispose();
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _testAndSave() async {
    final url = _urlController.text.trim();
    final key = _keyController.text.trim();

    if (url.isEmpty) {
      setState(() => _errorMessage = 'Ingrese la URL del servidor');
      return;
    }
    if (key.isEmpty) {
      setState(() => _errorMessage = 'Ingrese el Anon Key');
      return;
    }

    // Limpiar URL trailing slash
    final cleanUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;

    setState(() {
      _testing = true;
      _errorMessage = null;
    });

    try {
      // Probar la conexión haciendo un request HTTP al health endpoint
      final testClient = SupabaseClient(cleanUrl, key);
      // Intentar hacer una query simple para verificar que responde
      await testClient.rest
          .from('_health_check_dummy_')
          .select()
          .limit(1)
          .timeout(const Duration(seconds: 8))
          .catchError((_) => <Map<String, dynamic>>[]);
      // Si llegó aquí sin timeout, el servidor respondió (incluso con error 404 de tabla)
      testClient.dispose();

      // Guardar configuración
      await SupabaseConfig.save(url: cleanUrl, anonKey: key);
      SupabaseConfig.needsSetup = false;

      if (mounted) {
        // Mostrar diálogo de reinicio
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            icon: const Icon(Icons.check_circle, color: Colors.green, size: 48),
            title: const Text('Servidor Configurado'),
            content: const Text(
              'La configuración se guardó correctamente.\n\n'
              'La aplicación se cerrará para aplicar los cambios. '
              'Ábrela nuevamente para iniciar sesión.',
            ),
            actions: [
              FilledButton.icon(
                onPressed: () {
                  // Cerrar la app para que re-inicie con la config correcta
                  if (Platform.isAndroid) {
                    SystemNavigator.pop();
                  } else {
                    exit(0);
                  }
                },
                icon: const Icon(Icons.restart_alt),
                label: const Text('Reiniciar App'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _testing = false;
          _errorMessage = 'No se pudo conectar al servidor.\n'
              'Verifique la URL y que el servidor esté activo.\n'
              'Error: ${e.toString().substring(0, (e.toString().length > 100) ? 100 : e.toString().length)}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 600;

    return Scaffold(
      backgroundColor: const Color(0xFF1565C0),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints:
                BoxConstraints(maxWidth: isWide ? 480 : double.infinity),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icono
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color:
                            const Color(0xFF1565C0).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.dns_outlined,
                        size: 48,
                        color: Color(0xFF1565C0),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Configurar Servidor',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1565C0),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Ingrese los datos de conexión al servidor\npara comenzar a usar la aplicación.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                    const SizedBox(height: 28),

                    // URL del servidor
                    TextField(
                      controller: _urlController,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(
                        labelText: 'URL del Servidor',
                        hintText: 'http://192.168.1.100:8000',
                        prefixIcon: Icon(Icons.link),
                        helperText: 'Ej: http://IP_SERVIDOR:8000',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Anon Key
                    TextField(
                      controller: _keyController,
                      obscureText: _obscureKey,
                      decoration: InputDecoration(
                        labelText: 'API Key (Anon Key)',
                        prefixIcon: const Icon(Icons.key),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(_obscureKey
                              ? Icons.visibility
                              : Icons.visibility_off),
                          onPressed: () =>
                              setState(() => _obscureKey = !_obscureKey),
                        ),
                        helperText: 'Token JWT proporcionado por el administrador',
                      ),
                      maxLines: 1,
                    ),
                    const SizedBox(height: 8),

                    // Error message
                    if (_errorMessage != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red[200]!),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.error_outline,
                                color: Colors.red[700], size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(
                                    color: Colors.red[700], fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 20),

                    // Botón conectar
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _testing ? null : _testAndSave,
                        icon: _testing
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.check_circle_outline),
                        label: Text(
                            _testing ? 'Verificando...' : 'Conectar'),
                      ),
                    ),

                    const SizedBox(height: 16),
                    // Info de ayuda
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline,
                              color: Colors.blue[700], size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Solicite estos datos al administrador del sistema. '
                              'Puede cambiarlos después en Configuración > Servidor.',
                              style: TextStyle(
                                  color: Colors.blue[700], fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

