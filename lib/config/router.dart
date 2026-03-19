import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/providers/auth_provider.dart';
import '../config/supabase_config.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/server_setup_screen.dart';
import '../features/dashboard/screens/dashboard_screen.dart';
import '../features/vehiculos/screens/vehiculos_list_screen.dart';
import '../features/vehiculos/screens/vehiculo_form_screen.dart';
import '../features/vehiculos/screens/vehiculo_detalle_screen.dart';
import '../features/vehiculos/screens/condiciones_ingreso_screen.dart';
import '../features/inventario/screens/inventario_screen.dart';
import '../features/ventas/screens/ventas_screen.dart';
import '../features/ventas/screens/nueva_venta_screen.dart';
import '../features/movimientos/screens/movimientos_screen.dart';
import '../features/reportes/screens/reportes_screen.dart';
import '../features/configuracion/screens/configuracion_screen.dart';
import '../features/reservas/screens/reservas_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: SupabaseConfig.needsSetup ? '/setup' : '/login',
    redirect: (context, state) {
      final isSetupRoute = state.matchedLocation == '/setup';

      // Si necesita setup, forzar a la pantalla de configuración
      if (SupabaseConfig.needsSetup) {
        return isSetupRoute ? null : '/setup';
      }

      // Flujo normal de autenticación
      final isAuth = authState.status == AuthStatus.authenticated;
      final isLoginRoute = state.matchedLocation == '/login';

      // No permitir acceso a /setup si ya está configurado
      if (isSetupRoute) return '/login';

      if (!isAuth && !isLoginRoute) return '/login';
      if (isAuth && isLoginRoute) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(
        path: '/setup',
        builder: (context, state) => const ServerSetupScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/vehiculos',
            builder: (context, state) => const VehiculosListScreen(),
          ),
          GoRoute(
            path: '/vehiculos/nuevo',
            builder: (context, state) => const VehiculoFormScreen(),
          ),
          GoRoute(
            path: '/vehiculos/:id/editar',
            builder: (context, state) => VehiculoFormScreen(
              vehiculoId: state.pathParameters['id'],
            ),
          ),
          GoRoute(
            path: '/vehiculos/:id/condiciones',
            builder: (context, state) => CondicionesIngresoScreen(
              vehiculoId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: '/vehiculos/:id/detalle',
            builder: (context, state) => VehiculoDetalleScreen(
              vehiculoId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: '/inventario',
            builder: (context, state) => const InventarioScreen(),
          ),
          GoRoute(
            path: '/ventas',
            builder: (context, state) => const VentasScreen(),
          ),
          GoRoute(
            path: '/ventas/nueva',
            builder: (context, state) => const NuevaVentaScreen(),
          ),
          GoRoute(
            path: '/movimientos',
            builder: (context, state) => const MovimientosScreen(),
          ),
          GoRoute(
            path: '/reservas',
            builder: (context, state) => const ReservasScreen(),
          ),
          GoRoute(
            path: '/reportes',
            builder: (context, state) => const ReportesScreen(),
          ),
          GoRoute(
            path: '/configuracion',
            builder: (context, state) => const ConfiguracionScreen(),
          ),
        ],
      ),
    ],
  );
});

// Shell principal con navegación lateral (drawer) o bottom nav
class AppShell extends ConsumerWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final isWide = MediaQuery.of(context).size.width > 800;

    final menuItems = _buildMenuItems(auth);

    if (isWide) {
      // Layout web/tablet: NavigationRail + contenido
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              extended: MediaQuery.of(context).size.width > 1100,
              backgroundColor: const Color(0xFF1565C0),
              unselectedIconTheme: const IconThemeData(color: Colors.white70),
              selectedIconTheme: const IconThemeData(color: Colors.white),
              unselectedLabelTextStyle: const TextStyle(color: Colors.white70),
              selectedLabelTextStyle: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              indicatorColor: Colors.white24,
              selectedIndex: _getSelectedIndex(context),
              onDestinationSelected: (index) => _onItemTap(context, index, menuItems),
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  children: [
                    const Icon(Icons.directions_car, color: Colors.white, size: 32),
                    const SizedBox(height: 4),
                    if (MediaQuery.of(context).size.width > 1100)
                      const Text(
                        'AutoPartes',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                  ],
                ),
              ),
              trailing: Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: IconButton(
                      icon: const Icon(Icons.logout, color: Colors.white70),
                      onPressed: () => ref.read(authProvider.notifier).signOut(),
                      tooltip: 'Cerrar sesión',
                    ),
                  ),
                ),
              ),
              destinations: menuItems
                  .map(
                    (item) => NavigationRailDestination(
                      icon: Icon(item.icon),
                      label: Text(item.label),
                    ),
                  )
                  .toList(),
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(child: child),
          ],
        ),
      );
    }

    // Layout móvil: Drawer
    final location = GoRouterState.of(context).matchedLocation;
    final isOnDashboard = location.startsWith('/dashboard');
    final scaffoldKey = GlobalKey<ScaffoldState>();

    return Scaffold(
      key: scaffoldKey,
      appBar: AppBar(
        leading: isOnDashboard
            ? null // Muestra el ícono del Drawer automáticamente
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.go('/dashboard'),
                tooltip: 'Volver al Dashboard',
              ),
        title: Text(_getTitle(context)),
        actions: [
          // Botón de menú cuando no estamos en dashboard (la flecha reemplazó el hamburguesa)
          if (!isOnDashboard)
            IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => scaffoldKey.currentState?.openDrawer(),
              tooltip: 'Menú',
            ),
          if (auth.perfil != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Chip(
                avatar: const Icon(Icons.person, size: 18, color: Colors.white),
                label: Text(
                  auth.perfil!.nombre,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
                backgroundColor: Colors.white24,
              ),
            ),
        ],
      ),
      drawer: Drawer(
        child: Column(
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Color(0xFF1565C0)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Icon(Icons.directions_car, color: Colors.white, size: 40),
                  const SizedBox(height: 8),
                  const Text(
                    'AutoPartes Inventory',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (auth.perfil != null)
                    Text(
                      '${auth.perfil!.nombre} (${auth.perfil!.rol})',
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                ],
              ),
            ),
            ...menuItems.map(
              (item) => ListTile(
                leading: Icon(item.icon),
                title: Text(item.label),
                selected: GoRouterState.of(context).matchedLocation == item.route,
                onTap: () {
                  Navigator.pop(context);
                  context.go(item.route);
                },
              ),
            ),
            const Spacer(),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Cerrar sesión', style: TextStyle(color: Colors.red)),
              onTap: () => ref.read(authProvider.notifier).signOut(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
      body: child,
    );
  }

  List<_MenuItem> _buildMenuItems(AppAuthState auth) {
    final items = <_MenuItem>[
      _MenuItem(Icons.dashboard, 'Dashboard', '/dashboard'),
      _MenuItem(Icons.directions_car, 'Vehículos', '/vehiculos'),
      _MenuItem(Icons.inventory_2, 'Inventario', '/inventario'),
      _MenuItem(Icons.point_of_sale, 'Ventas', '/ventas'),
      _MenuItem(Icons.bookmark, 'Reservas', '/reservas'),
      _MenuItem(Icons.swap_horiz, 'Movimientos', '/movimientos'),
    ];

    if (auth.isAdmin) {
      items.addAll([
        _MenuItem(Icons.bar_chart, 'Reportes', '/reportes'),
        _MenuItem(Icons.settings, 'Configuración', '/configuracion'),
      ]);
    }

    return items;
  }

  int _getSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/dashboard')) return 0;
    if (location.startsWith('/vehiculos')) return 1;
    if (location.startsWith('/inventario')) return 2;
    if (location.startsWith('/ventas')) return 3;
    if (location.startsWith('/reservas')) return 4;
    if (location.startsWith('/movimientos')) return 5;
    if (location.startsWith('/reportes')) return 6;
    if (location.startsWith('/configuracion')) return 7;
    return 0;
  }

  void _onItemTap(BuildContext context, int index, List<_MenuItem> items) {
    if (index < items.length) {
      context.go(items[index].route);
    }
  }

  String _getTitle(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/dashboard')) return 'Dashboard';
    if (location.contains('/detalle')) return 'Detalle Vehículo';
    if (location.contains('/condiciones')) return 'Condiciones de Ingreso';
    if (location.contains('/nuevo') || location.contains('/editar')) return 'Vehículo';
    if (location.startsWith('/vehiculos')) return 'Vehículos';
    if (location.startsWith('/inventario')) return 'Inventario';
    if (location.startsWith('/ventas')) return 'Ventas';
    if (location.startsWith('/reservas')) return 'Reservas';
    if (location.startsWith('/movimientos')) return 'Movimientos';
    if (location.startsWith('/reportes')) return 'Reportes';
    if (location.startsWith('/configuracion')) return 'Configuración';
    return 'AutoPartes';
  }
}

class _MenuItem {
  final IconData icon;
  final String label;
  final String route;

  _MenuItem(this.icon, this.label, this.route);
}
