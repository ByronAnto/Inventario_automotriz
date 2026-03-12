import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/models/vehiculo.dart';
import '../../../data/models/repuesto.dart';
import 'vehiculos_list_screen.dart';

// ─── Provider: Detalle con repuestos ─────────────────────────
final vehiculoDetalleProvider =
    FutureProvider.family<_VehiculoDetalle, String>((ref, id) async {
  final client = Supabase.instance.client;

  final vData = await client
      .from('vehiculos')
      .select(
          '*, marcas(nombre), modelos(nombre), tipos_vehiculo(nombre), ubicaciones(nombre)')
      .eq('id', id)
      .single();

  final rData = await client
      .from('repuestos')
      .select('*, catalogo_partes(*), ubicaciones(*)')
      .eq('vehiculo_id', id)
      .order('created_at', ascending: false);

  return _VehiculoDetalle(
    vehiculo: Vehiculo.fromJson(vData),
    repuestos: rData.map((e) => Repuesto.fromJson(e)).toList(),
  );
});

class _VehiculoDetalle {
  final Vehiculo vehiculo;
  final List<Repuesto> repuestos;
  _VehiculoDetalle({required this.vehiculo, required this.repuestos});
}

// ─── Filtro de estado de repuestos ───────────────────────────
class _RepuestoEstadoFiltroNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  // ignore: use_setters_to_change_properties
  void set(String? value) => state = value;
}

final _repuestoEstadoFiltroProvider =
    NotifierProvider<_RepuestoEstadoFiltroNotifier, String?>(
  _RepuestoEstadoFiltroNotifier.new,
);

// ─── Screen ──────────────────────────────────────────────────
class VehiculoDetalleScreen extends ConsumerWidget {
  final String vehiculoId;
  const VehiculoDetalleScreen({super.key, required this.vehiculoId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detalleAsync = ref.watch(vehiculoDetalleProvider(vehiculoId));
    final filtroEstado = ref.watch(_repuestoEstadoFiltroProvider);
    final auth = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/vehiculos'),
        ),
        title: const Text('Detalle del Vehículo'),
        actions: [
          if (auth.isAdmin || auth.isVendedor)
            PopupMenuButton<String>(
              onSelected: (v) => _onMenuAction(context, ref, v),
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'editar',
                  child: ListTile(
                    leading: Icon(Icons.edit),
                    title: Text('Editar vehículo'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'condiciones',
                  child: ListTile(
                    leading: Icon(Icons.checklist),
                    title: Text('Inspección / Condiciones'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                if (auth.isAdmin)
                  const PopupMenuItem(
                    value: 'eliminar',
                    child: ListTile(
                      leading: Icon(Icons.delete, color: Colors.red),
                      title: Text('Eliminar vehículo',
                          style: TextStyle(color: Colors.red)),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
              ],
            ),
        ],
      ),
      body: detalleAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error: $e'),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () =>
                    ref.invalidate(vehiculoDetalleProvider(vehiculoId)),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
        data: (detalle) {
          final v = detalle.vehiculo;
          final repuestos = detalle.repuestos;

          // Conteos
          final conteo = <String, int>{};
          for (final r in repuestos) {
            conteo[r.estado] = (conteo[r.estado] ?? 0) + 1;
          }

          // Filtrar repuestos
          final repFiltrados = filtroEstado == null
              ? repuestos
              : repuestos.where((r) => r.estado == filtroEstado).toList();

          return RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(vehiculoDetalleProvider(vehiculoId)),
            child: CustomScrollView(
              slivers: [
                // ── Info del vehículo ──
                SliverToBoxAdapter(
                  child: _VehiculoInfoCard(vehiculo: v),
                ),
                // ── Conteos + filtros ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${repuestos.length} repuestos registrados',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _filtroChip(
                                ref,
                                label: 'Todos',
                                count: repuestos.length,
                                color: Colors.blueGrey,
                                selected: filtroEstado == null,
                                estado: null,
                              ),
                              ...conteo.entries.map(
                                (e) => _filtroChip(
                                  ref,
                                  label: e.key[0].toUpperCase() +
                                      e.key.substring(1),
                                  count: e.value,
                                  color: _colorRepuesto(e.key),
                                  selected: filtroEstado == e.key,
                                  estado: e.key,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // ── Lista de repuestos ──
                if (repFiltrados.isEmpty)
                  const SliverFillRemaining(
                    child: Center(
                      child: Text('No hay repuestos con este filtro'),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (_, i) => _RepuestoTile(repuesto: repFiltrados[i]),
                        childCount: repFiltrados.length,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _filtroChip(
    WidgetRef ref, {
    required String label,
    required int count,
    required Color color,
    required bool selected,
    required String? estado,
  }) {
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
        onSelected: (_) => ref
            .read(_repuestoEstadoFiltroProvider.notifier)
            .set(selected ? null : estado),
      ),
    );
  }

  void _onMenuAction(BuildContext context, WidgetRef ref, String action) {
    switch (action) {
      case 'editar':
        context.go('/vehiculos/$vehiculoId/editar');
        break;
      case 'condiciones':
        context.go('/vehiculos/$vehiculoId/condiciones');
        break;
      case 'eliminar':
        _confirmarEliminar(context, ref);
        break;
    }
  }

  Future<void> _confirmarEliminar(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar vehículo'),
        content: const Text(
          '¿Está seguro de eliminar este vehículo y todos sus repuestos?\n\n'
          'Solo se puede eliminar si no tiene repuestos vendidos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (ok != true || !context.mounted) return;

    try {
      await Supabase.instance.client.rpc('eliminar_vehiculo', params: {
        'p_vehiculo_id': vehiculoId,
      });

      ref.invalidate(vehiculosConConteosProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vehículo eliminado'),
            backgroundColor: Colors.green,
          ),
        );
        context.go('/vehiculos');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Color _colorRepuesto(String estado) {
    switch (estado) {
      case 'disponible':
        return Colors.green;
      case 'vendido':
        return Colors.blue;
      case 'reservado':
        return Colors.orange;
      case 'faltante':
        return Colors.red;
      case 'dañado':
        return Colors.deepOrange;
      case 'intercambiado':
        return Colors.purple;
      case 'descartado':
        return Colors.grey;
      default:
        return Colors.blueGrey;
    }
  }
}

// ─── Info Card del Vehículo ──────────────────────────────────
class _VehiculoInfoCard extends StatelessWidget {
  final Vehiculo vehiculo;
  const _VehiculoInfoCard({required this.vehiculo});

  @override
  Widget build(BuildContext context) {
    final v = vehiculo;
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Nombre + Estado
            Row(
              children: [
                Expanded(
                  child: Text(
                    v.nombreCompleto,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ),
                _EstadoBadge(v.estado),
              ],
            ),
            const SizedBox(height: 12),
            // Detalles en grid
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _campo('Año', '${v.anio}'),
                if (v.color != null) _campo('Color', v.color!),
                if (v.vin != null) _campo('VIN', v.vin!),
                if (v.placa != null) _campo('Placa', v.placa!),
                _campo('Costo compra', '\$${v.costoCompra.toStringAsFixed(2)}'),
                if (v.valorGrua != null && v.valorGrua! > 0)
                  _campo('Grúa', '\$${v.valorGrua!.toStringAsFixed(2)}'),
                if (v.comisionViaje != null && v.comisionViaje! > 0)
                  _campo(
                      'Comisión', '\$${v.comisionViaje!.toStringAsFixed(2)}'),
                if (v.ubicacionNombre != null)
                  _campo('Ubicación', v.ubicacionNombre!),
                if (v.proveedorNombre != null)
                  _campo('Proveedor', v.proveedorNombre!),
                if (v.compradorNombre != null)
                  _campo('Comprador', v.compradorNombre!),
                _campo('Ingreso',
                    '${v.fechaIngreso.day}/${v.fechaIngreso.month}/${v.fechaIngreso.year}'),
              ],
            ),
            if (v.notas != null && v.notas!.isNotEmpty) ...[
              const Divider(height: 24),
              Text('Notas: ${v.notas}',
                  style: TextStyle(color: Colors.grey[700], fontSize: 13)),
            ],
            const SizedBox(height: 8),
            // Condiciones
            Row(
              children: [
                if (v.condicionesRegistradas)
                  const Chip(
                    avatar: Icon(Icons.check_circle,
                        size: 16, color: Colors.green),
                    label: Text('Inspección registrada',
                        style: TextStyle(fontSize: 11)),
                    backgroundColor: Color(0xFFE8F5E9),
                  )
                else
                  Chip(
                    avatar: const Icon(Icons.warning_amber,
                        size: 16, color: Colors.orange),
                    label: const Text('Sin inspección',
                        style: TextStyle(fontSize: 11)),
                    backgroundColor: Colors.orange.withValues(alpha: 0.1),
                  ),
                const SizedBox(width: 8),
                Chip(
                  avatar: const Icon(Icons.bar_chart,
                      size: 16, color: Colors.blue),
                  label: Text('Completitud: ${v.completitud}%',
                      style: const TextStyle(fontSize: 11)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _campo(String label, String value) {
    return SizedBox(
      width: 160,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          Text(value,
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _EstadoBadge extends StatelessWidget {
  final String estado;
  const _EstadoBadge(this.estado);

  @override
  Widget build(BuildContext context) {
    final color = _getVehiculoEstadoColor(estado);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        estado.replaceAll('_', ' ').toUpperCase(),
        style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  Color _getVehiculoEstadoColor(String estado) {
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
}

// ─── Repuesto Tile ───────────────────────────────────────────
class _RepuestoTile extends StatelessWidget {
  final Repuesto repuesto;
  const _RepuestoTile({required this.repuesto});

  @override
  Widget build(BuildContext context) {
    final r = repuesto;
    final color = _colorForEstadoRepuesto(r.estado);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: color.withValues(alpha: 0.3)),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(_iconForEstado(r.estado), color: color, size: 20),
        ),
        title: Text(
          r.parteNombre ?? 'Sin nombre',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Text(
          [
            if (r.parteCategoria != null) r.parteCategoria!,
            if (r.ubicacionNombre != null) r.ubicacionNombre!,
            if (r.precioSugerido != null)
              '\$${r.precioSugerido!.toStringAsFixed(2)}',
          ].join(' · '),
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            r.estado[0].toUpperCase() + r.estado.substring(1),
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.bold, color: color),
          ),
        ),
      ),
    );
  }

  Color _colorForEstadoRepuesto(String estado) {
    switch (estado) {
      case 'disponible':
        return Colors.green;
      case 'vendido':
        return Colors.blue;
      case 'reservado':
        return Colors.orange;
      case 'faltante':
        return Colors.red;
      case 'dañado':
        return Colors.deepOrange;
      case 'intercambiado':
        return Colors.purple;
      case 'descartado':
        return Colors.grey;
      default:
        return Colors.blueGrey;
    }
  }

  IconData _iconForEstado(String estado) {
    switch (estado) {
      case 'disponible':
        return Icons.check_circle;
      case 'vendido':
        return Icons.shopping_cart;
      case 'reservado':
        return Icons.bookmark;
      case 'faltante':
        return Icons.remove_circle;
      case 'dañado':
        return Icons.warning;
      case 'intercambiado':
        return Icons.swap_horiz;
      case 'descartado':
        return Icons.delete;
      default:
        return Icons.help;
    }
  }
}
