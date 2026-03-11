import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/models/vehiculo.dart';

// Provider de lista de vehículos
final vehiculosProvider = FutureProvider<List<Vehiculo>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final data = await supabase
      .from('vehiculos')
      .select('*, marcas(nombre), modelos(nombre), tipos_vehiculo(nombre), ubicaciones(nombre)')
      .order('created_at', ascending: false);
  return data.map((e) => Vehiculo.fromJson(e)).toList();
});

class VehiculosListScreen extends ConsumerWidget {
  const VehiculosListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehiculos = ref.watch(vehiculosProvider);

    return Scaffold(
      body: vehiculos.when(
        data: (lista) {
          if (lista.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.directions_car_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No hay vehículos registrados'),
                  SizedBox(height: 8),
                  Text('Presiona + para agregar uno', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(vehiculosProvider),
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: lista.length,
              itemBuilder: (context, index) {
                final v = lista[index];
                return _VehiculoCard(vehiculo: v);
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/vehiculos/nuevo'),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo Vehículo'),
      ),
    );
  }
}

class _VehiculoCard extends StatelessWidget {
  final Vehiculo vehiculo;
  const _VehiculoCard({required this.vehiculo});

  @override
  Widget build(BuildContext context) {
    final estadoColor = _getEstadoColor(vehiculo.estado);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.go('/vehiculos/${vehiculo.id}/editar'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      vehiculo.nombreCompleto,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: estadoColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: estadoColor),
                    ),
                    child: Text(
                      vehiculo.estado.replaceAll('_', ' ').toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: estadoColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _InfoChip(Icons.calendar_today, '${vehiculo.anio}'),
                  const SizedBox(width: 8),
                  if (vehiculo.color != null) _InfoChip(Icons.palette, vehiculo.color!),
                  const SizedBox(width: 8),
                  _InfoChip(Icons.attach_money, '\$${vehiculo.costoCompra.toStringAsFixed(2)}'),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (vehiculo.ubicacionNombre != null)
                    _InfoChip(Icons.location_on, vehiculo.ubicacionNombre!),
                  const Spacer(),
                  if (!vehiculo.condicionesRegistradas)
                    TextButton.icon(
                      onPressed: () =>
                          context.go('/vehiculos/${vehiculo.id}/condiciones'),
                      icon: const Icon(Icons.checklist, size: 18),
                      label: const Text('Registrar condiciones'),
                      style: TextButton.styleFrom(foregroundColor: Colors.orange),
                    ),
                  if (vehiculo.condicionesRegistradas)
                    const Chip(
                      label: Text('Inspeccionado', style: TextStyle(fontSize: 11)),
                      backgroundColor: Color(0xFFE8F5E9),
                      avatar: Icon(Icons.check_circle, size: 16, color: Colors.green),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getEstadoColor(String estado) {
    switch (estado) {
      case 'siniestrado':
        return Colors.red;
      case 'dado_de_baja':
        return Colors.orange;
      case 'incompleto':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[700])),
      ],
    );
  }
}
