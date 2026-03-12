import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/models/vehiculo.dart';

// ─── Modelo auxiliar: Vehículo con conteos ───────────────────
class VehiculoConConteos {
  final Vehiculo vehiculo;
  final int totalRepuestos;
  final int disponibles;
  final int vendidos;
  final int reservados;
  final int faltantes;
  final int danados;

  VehiculoConConteos({
    required this.vehiculo,
    this.totalRepuestos = 0,
    this.disponibles = 0,
    this.vendidos = 0,
    this.reservados = 0,
    this.faltantes = 0,
    this.danados = 0,
  });
}

// ─── Provider: Vehículos con conteos de repuestos ────────────
final vehiculosConConteosProvider =
    FutureProvider<List<VehiculoConConteos>>((ref) async {
  final client = Supabase.instance.client;

  // 1. Traer vehículos con repuestos (solo id y estado)
  final vData = await client
      .from('vehiculos')
      .select(
          '*, marcas(nombre), modelos(nombre), tipos_vehiculo(nombre), ubicaciones(nombre), repuestos(id, estado)')
      .order('created_at', ascending: false);

  return vData.map((e) {
    final vehiculo = Vehiculo.fromJson(e);
    final repuestos = (e['repuestos'] as List<dynamic>?) ?? [];

    int disponibles = 0, vendidos = 0, reservados = 0, faltantes = 0, danados = 0;
    for (final r in repuestos) {
      switch (r['estado']) {
        case 'disponible':
          disponibles++;
          break;
        case 'vendido':
          vendidos++;
          break;
        case 'reservado':
          reservados++;
          break;
        case 'faltante':
          faltantes++;
          break;
        case 'dañado':
          danados++;
          break;
      }
    }

    return VehiculoConConteos(
      vehiculo: vehiculo,
      totalRepuestos: repuestos.length,
      disponibles: disponibles,
      vendidos: vendidos,
      reservados: reservados,
      faltantes: faltantes,
      danados: danados,
    );
  }).toList();
});

// Provider legacy para compatibilidad
final vehiculosProvider = FutureProvider<List<Vehiculo>>((ref) async {
  final datos = await ref.watch(vehiculosConConteosProvider.future);
  return datos.map((e) => e.vehiculo).toList();
});

// ─── Filtro de estado ────────────────────────────────────────
class _VehiculoEstadoFiltroNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  // ignore: use_setters_to_change_properties
  void set(String? value) => state = value;
}

final _vehiculoEstadoFiltroProvider =
    NotifierProvider<_VehiculoEstadoFiltroNotifier, String?>(
  _VehiculoEstadoFiltroNotifier.new,
);

// ─── Screen ──────────────────────────────────────────────────
class VehiculosListScreen extends ConsumerWidget {
  const VehiculosListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehiculosAsync = ref.watch(vehiculosConConteosProvider);
    final filtroEstado = ref.watch(_vehiculoEstadoFiltroProvider);

    return Scaffold(
      body: vehiculosAsync.when(
        data: (lista) {
          if (lista.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.directions_car_outlined,
                      size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No hay vehículos registrados'),
                  SizedBox(height: 8),
                  Text('Presiona + para agregar uno',
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          // Contar por estado
          final estadoConteo = <String, int>{};
          for (final vc in lista) {
            final e = vc.vehiculo.estado;
            estadoConteo[e] = (estadoConteo[e] ?? 0) + 1;
          }

          // Filtrar
          final filtrada = filtroEstado == null
              ? lista
              : lista
                  .where((vc) => vc.vehiculo.estado == filtroEstado)
                  .toList();

          return RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(vehiculosConConteosProvider),
            child: CustomScrollView(
              slivers: [
                // ── Stats header ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Resumen total
                        Card(
                          color: const Color(0xFF1565C0),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                const Icon(Icons.directions_car,
                                    color: Colors.white, size: 32),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${lista.length} vehículos',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      '${lista.fold<int>(0, (a, b) => a + b.disponibles)} repuestos disponibles',
                                      style: const TextStyle(
                                          color: Colors.white70, fontSize: 14),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Chips de estado
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _EstadoChip(
                                label: 'Todos',
                                count: lista.length,
                                color: Colors.blueGrey,
                                selected: filtroEstado == null,
                                onTap: () => ref
                                    .read(_vehiculoEstadoFiltroProvider
                                        .notifier)
                                    .set(null),
                              ),
                              ...estadoConteo.entries.map((e) => _EstadoChip(
                                    label: e.key
                                        .replaceAll('_', ' ')
                                        .toUpperCase(),
                                    count: e.value,
                                    color: _getEstadoColor(e.key),
                                    selected: filtroEstado == e.key,
                                    onTap: () => ref
                                        .read(_vehiculoEstadoFiltroProvider
                                            .notifier)
                                        .set(filtroEstado == e.key
                                            ? null
                                            : e.key),
                                  )),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // ── Lista de vehículos ──
                SliverPadding(
                  padding: const EdgeInsets.all(12),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) =>
                          _VehiculoCard(vc: filtrada[index]),
                      childCount: filtrada.length,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error: $e'),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () =>
                    ref.invalidate(vehiculosConConteosProvider),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/vehiculos/nuevo'),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo Vehículo'),
      ),
    );
  }
}

// ─── Card de vehículo ────────────────────────────────────────
class _VehiculoCard extends StatelessWidget {
  final VehiculoConConteos vc;
  const _VehiculoCard({required this.vc});

  @override
  Widget build(BuildContext context) {
    final v = vc.vehiculo;
    final estadoColor = _getEstadoColor(v.estado);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.go('/vehiculos/${v.id}/detalle'),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nombre + estado
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          v.nombreCompleto,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: estadoColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: estadoColor),
                        ),
                        child: Text(
                          v.estado.replaceAll('_', ' ').toUpperCase(),
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
                  // Info chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      _InfoChip(Icons.calendar_today, '${v.anio}'),
                      if (v.color != null) _InfoChip(Icons.palette, v.color!),
                      _InfoChip(Icons.attach_money,
                          '\$${v.costoCompra.toStringAsFixed(2)}'),
                      if (v.ubicacionNombre != null)
                        _InfoChip(Icons.location_on, v.ubicacionNombre!),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Conteos de repuestos
                  Row(
                    children: [
                      _ConteoBadge(
                          'Disponibles', vc.disponibles, Colors.green),
                      const SizedBox(width: 8),
                      _ConteoBadge('Vendidos', vc.vendidos, Colors.red),
                      const SizedBox(width: 8),
                      if (vc.reservados > 0) ...[
                        _ConteoBadge(
                            'Reservados', vc.reservados, Colors.orange),
                        const SizedBox(width: 8),
                      ],
                      _ConteoBadge('Total', vc.totalRepuestos, Colors.blueGrey),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Condiciones + fecha
                  Row(
                    children: [
                      if (!v.condicionesRegistradas)
                        TextButton.icon(
                          onPressed: () =>
                              context.go('/vehiculos/${v.id}/condiciones'),
                          icon: const Icon(Icons.checklist, size: 18),
                          label: const Text('Registrar condiciones'),
                          style: TextButton.styleFrom(
                              foregroundColor: Colors.orange),
                        ),
                      if (v.condicionesRegistradas)
                        const Chip(
                          label: Text('Inspeccionado',
                              style: TextStyle(fontSize: 11)),
                          backgroundColor: Color(0xFFE8F5E9),
                          avatar: Icon(Icons.check_circle,
                              size: 16, color: Colors.green),
                        ),
                      const Spacer(),
                      Text(
                        'Ingreso: ${v.fechaIngreso.day}/${v.fechaIngreso.month}/${v.fechaIngreso.year}',
                        style: TextStyle(
                            color: Colors.grey[500], fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Widgets auxiliares ──────────────────────────────────────
class _EstadoChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _EstadoChip({
    required this.label,
    required this.count,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text('$label ($count)'),
        selected: selected,
        selectedColor: color.withValues(alpha: 0.2),
        checkmarkColor: color,
        labelStyle: TextStyle(
          color: selected ? color : Colors.grey[700],
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
        ),
        onSelected: (_) => onTap(),
      ),
    );
  }
}

class _ConteoBadge extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _ConteoBadge(this.label, this.count, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: TextStyle(
                fontWeight: FontWeight.bold, color: color, fontSize: 16),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 9, color: color),
          ),
        ],
      ),
    );
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

Color _getEstadoColor(String estado) {
  switch (estado) {
    case 'siniestrado':
      return Colors.red;
    case 'dado_de_baja':
      return Colors.grey;
    case 'incompleto':
      return Colors.orange;
    case 'remate':
      return Colors.blue;
    case 'patio':
      return Colors.green;
    case 'taller':
      return Colors.deepOrange;
    case 'dueno':
      return Colors.purple;
    default:
      return Colors.blueGrey;
  }
}
