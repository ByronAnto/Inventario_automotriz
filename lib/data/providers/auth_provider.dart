import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/supabase_config.dart';
import '../models/perfil.dart';

// Estado de autenticación
enum AuthStatus { initial, authenticated, unauthenticated }

class AppAuthState {
  final AuthStatus status;
  final User? user;
  final Perfil? perfil;
  final String? errorMessage;
  final bool isLoading;

  const AppAuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.perfil,
    this.errorMessage,
    this.isLoading = false,
  });

  AppAuthState copyWith({
    AuthStatus? status,
    User? user,
    Perfil? perfil,
    String? errorMessage,
    bool? isLoading,
  }) {
    return AppAuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      perfil: perfil ?? this.perfil,
      errorMessage: errorMessage,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  bool get isAdmin => perfil?.rol == 'administrador';
  bool get isVendedor => perfil?.rol == 'vendedor';
  bool get isMecanico => perfil?.rol == 'mecanico';
}

class AuthNotifier extends Notifier<AppAuthState> {
  late final SupabaseClient _supabase;

  @override
  AppAuthState build() {
    _supabase = Supabase.instance.client;
    _initialize();
    return const AppAuthState();
  }

  void _initialize() {
    final session = _supabase.auth.currentSession;
    if (session != null) {
      _loadPerfil(session.user);
    } else {
      state = const AppAuthState(status: AuthStatus.unauthenticated);
    }

    _supabase.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn && data.session != null) {
        _loadPerfil(data.session!.user);
      } else if (data.event == AuthChangeEvent.signedOut) {
        state = const AppAuthState(status: AuthStatus.unauthenticated);
      }
    });
  }

  Future<void> _loadPerfil(User user) async {
    try {
      final response = await _supabase
          .from('perfiles')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      if (response != null) {
        final perfil = Perfil.fromJson(response);
        state = AppAuthState(
          status: AuthStatus.authenticated,
          user: user,
          perfil: perfil,
        );
      } else {
        // Auto-crear perfil si no existe (primer login sin perfil)
        final nombre = user.userMetadata?['nombre'] as String? ??
            user.email?.split('@').first ??
            'Usuario';
        final isFirstUser = await _isFirstUser();

        final inserted = await _supabase.from('perfiles').insert({
          'user_id': user.id,
          'nombre': nombre,
          'email': user.email,
          'rol': isFirstUser ? 'administrador' : 'vendedor',
          'activo': true,
        }).select().single();

        final perfil = Perfil.fromJson(inserted);
        state = AppAuthState(
          status: AuthStatus.authenticated,
          user: user,
          perfil: perfil,
        );
      }
    } catch (e) {
      state = AppAuthState(
        status: AuthStatus.authenticated,
        user: user,
        errorMessage: 'Error al cargar perfil: $e',
      );
    }
  }

  /// Verifica si es el primer usuario (para asignarle rol admin)
  Future<bool> _isFirstUser() async {
    try {
      final count = await _supabase
          .from('perfiles')
          .select('id')
          .limit(1);
      return (count as List).isEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> signIn(String email, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } on AuthException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _translateAuthError(e.message),
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Error de conexión: $e',
      );
    }
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
    state = const AppAuthState(status: AuthStatus.unauthenticated);
  }

  Future<void> createUser({
    required String email,
    required String password,
    required String nombre,
    required String rol,
    String? telefono,
    double? comision,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      // Crear un cliente admin con SERVICE_ROLE_KEY para poder usar auth.admin
      final adminClient = SupabaseClient(
        SupabaseConfig.supabaseUrl,
        SupabaseConfig.serviceRoleKey,
      );

      // Crear usuario en auth usando el cliente admin
      final response = await adminClient.auth.admin.createUser(
        AdminUserAttributes(
          email: email,
          password: password,
          emailConfirm: true,
        ),
      );

      if (response.user != null) {
        // Crear perfil usando el cliente admin (tiene permisos service_role)
        await adminClient.from('perfiles').insert({
          'user_id': response.user!.id,
          'nombre': nombre,
          'email': email,
          'telefono': telefono,
          'rol': rol,
          'comision_porcentaje': comision,
          'activo': true,
        });
      }

      // Cerrar el cliente admin
      adminClient.dispose();

      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Error al crear usuario: $e',
      );
      rethrow; // Relanzar para que el diálogo pueda mostrar el error
    }
  }

  String _translateAuthError(String message) {
    if (message.contains('Invalid login credentials')) {
      return 'Credenciales inválidas. Verifique email y contraseña.';
    }
    if (message.contains('Email not confirmed')) {
      return 'Email no confirmado.';
    }
    if (message.contains('User not found')) {
      return 'Usuario no encontrado.';
    }
    return message;
  }
}

// Provider principal de autenticación
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final authProvider = NotifierProvider<AuthNotifier, AppAuthState>(
  AuthNotifier.new,
);
