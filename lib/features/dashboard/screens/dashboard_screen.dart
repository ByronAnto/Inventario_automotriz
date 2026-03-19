import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/providers/auth_provider.dart';

// Providers para datos del dashboard
final dashboardStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);

  final vehiculos = await supabase.from('vehiculos').select('id').count(CountOption.exact);
  final repuestos = await supabase
      .from('repuestos')
      .select('id')
      .eq('estado', 'disponible')
      .count(CountOption.exact);
  final ventasMes = await supabase
      .from('ventas')
      .select('total')
      .gte('fecha', DateTime(DateTime.now().year, DateTime.now().month, 1).toIso8601String());
  final vehiculosSinCondiciones = await supabase
      .from('vehiculos')
      .select('id')
      .eq('condiciones_registradas', false)
      .count(CountOption.exact);

  double totalVentasMes = 0;
  for (final v in ventasMes) {
    totalVentasMes += (v['total'] as num).toDouble();
  }

  return {
    'vehiculos': vehiculos.count,
    'repuestos_disponibles': repuestos.count,
    'ventas_mes': totalVentasMes,
    'pendientes_condiciones': vehiculosSinCondiciones.count,
  };
});

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(dashboardStatsProvider);
    final auth = ref.watch(authProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(dashboardStatsProvider),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Saludo
            Text(
              '¡Hola, ${auth.perfil?.nombre ?? 'Usuario'}!',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Panel de control',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),

            // Tarjetas de estadísticas
            stats.when(
              data: (data) => _buildStatsGrid(context, data),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 8),
                    Text('Error al cargar datos: $e'),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () => ref.invalidate(dashboardStatsProvider),
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Accesos rápidos
            const Text(
              'Accesos rápidos',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildQuickActions(context, auth),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid(BuildContext context, Map<String, dynamic> data) {
    final isWide = MediaQuery.of(context).size.width > 800;
    final crossAxisCount = isWide ? 4 : 2;

    return GridView.count(
      crossAxisCount: crossAxisCount,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: isWide ? 1.8 : 1.4,
      children: [
        _StatCard(
          icon: Icons.directions_car,
          label: 'Vehículos',
          value: '${data['vehiculos'] ?? 0}',
          color: const Color(0xFF1565C0),
          route: '/vehiculos',
        ),
        _StatCard(
          icon: Icons.inventory_2,
          label: 'Repuestos disponibles',
          value: '${data['repuestos_disponibles'] ?? 0}',
          color: const Color(0xFF2E7D32),
          route: '/inventario',
        ),
        _StatCard(
          icon: Icons.attach_money,
          label: 'Ventas del mes',
          value: '\$${(data['ventas_mes'] as double? ?? 0).toStringAsFixed(2)}',
          color: const Color(0xFFFF6F00),
          route: '/ventas',
        ),
        _StatCard(
          icon: Icons.pending_actions,
          label: 'Pendientes inspección',
          value: '${data['pendientes_condiciones'] ?? 0}',
          color: const Color(0xFFC62828),
          route: '/vehiculos',
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context, AppAuthState auth) {
    final actions = <_QuickAction>[
      _QuickAction(
        Icons.add_circle,
        'Registrar Vehículo',
        '/vehiculos/nuevo',
        const Color(0xFF1565C0),
      ),
      _QuickAction(
        Icons.search,
        'Buscar Repuesto',
        '/inventario',
        const Color(0xFF2E7D32),
      ),
      _QuickAction(
        Icons.point_of_sale,
        'Nueva Venta',
        '/ventas/nueva',
        const Color(0xFFFF6F00),
      ),
      _QuickAction(
        Icons.swap_horiz,
        'Movimientos',
        '/movimientos',
        const Color(0xFF7B1FA2),
      ),
    ];

    if (auth.isAdmin) {
      actions.add(_QuickAction(
        Icons.bar_chart,
        'Ver Reportes',
        '/reportes',
        const Color(0xFF00838F),
      ));
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: actions.map((action) {
        return SizedBox(
          width: MediaQuery.of(context).size.width > 800 ? 180 : (MediaQuery.of(context).size.width - 44) / 2,
          child: Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => context.go(action.route),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(action.icon, size: 36, color: action.color),
                    const SizedBox(height: 8),
                    Text(
                      action.label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final String route;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.route,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.go(route),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                label,
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickAction {
  final IconData icon;
  final String label;
  final String route;
  final Color color;

  _QuickAction(this.icon, this.label, this.route, this.color);
}
