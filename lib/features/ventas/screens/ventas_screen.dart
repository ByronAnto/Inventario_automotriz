import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/models/venta.dart';
import '../../inventario/screens/inventario_screen.dart'; // inventarioProvider
import 'nueva_venta_screen.dart'; // repuestosDisponiblesProvider

/// Hora actual en Ecuador (UTC-5)
DateTime _nowEcuador() => DateTime.now().toUtc().subtract(const Duration(hours: 5));

// Provider de ventas
final ventasProvider = FutureProvider<List<Venta>>((ref) async {
  final data = await Supabase.instance.client
      .from('ventas')
      .select('*, perfiles(*), venta_detalle(*, repuestos(*, catalogo_partes(*), vehiculos(*, marcas(*), modelos(*))))')
      .order('fecha', ascending: false);
  return data.map((e) => Venta.fromJson(e)).toList();
});

/// Estado del filtro de fecha
class _VentasFiltroHoyNotifier extends Notifier<bool> {
  @override
  bool build() => true;
  // ignore: use_setters_to_change_properties
  void set(bool value) => state = value;
}

final _ventasFiltroHoyProvider =
    NotifierProvider<_VentasFiltroHoyNotifier, bool>(
  _VentasFiltroHoyNotifier.new,
);

class VentasScreen extends ConsumerWidget {
  const VentasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ventas = ref.watch(ventasProvider);
    final soloHoy = ref.watch(_ventasFiltroHoyProvider);

    return Scaffold(
      body: ventas.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (allList) {
          // Filtrar por fecha de hoy (Ecuador) si el toggle está activo
          final hoyEc = _nowEcuador();
          final list = soloHoy
              ? allList.where((v) {
                  // Convertir la fecha de la venta a Ecuador
                  final fec = v.fecha.toUtc().subtract(const Duration(hours: 5));
                  return fec.year == hoyEc.year &&
                      fec.month == hoyEc.month &&
                      fec.day == hoyEc.day;
                }).toList()
              : allList;

          // Calcular totales de lo filtrado
          final totalVentas = list.fold<double>(0, (sum, v) => sum + v.total);

          return Column(
            children: [
              // Resumen + filtro
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${list.length} venta(s)${soloHoy ? " hoy" : ""}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            'Total: \$${totalVentas.toStringAsFixed(2)}',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    // Toggle hoy / todas
                    ChoiceChip(
                      avatar: Icon(
                        soloHoy ? Icons.today : Icons.date_range,
                        size: 18,
                      ),
                      label: Text(soloHoy ? 'Hoy' : 'Todas'),
                      selected: soloHoy,
                      onSelected: (_) {
                        ref.read(_ventasFiltroHoyProvider.notifier).set(
                            !soloHoy);
                      },
                    ),
                  ],
                ),
              ),

              // Lista
              Expanded(
                child: list.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.point_of_sale,
                                size: 64, color: Colors.grey),
                            const SizedBox(height: 16),
                            Text(
                              soloHoy
                                  ? 'No hay ventas hoy'
                                  : 'No hay ventas registradas',
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 16),
                            ),
                            if (soloHoy) ...[
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: () => ref
                                    .read(_ventasFiltroHoyProvider.notifier)
                                    .set(false),
                                child: const Text('Ver todas las ventas'),
                              ),
                            ],
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => ref.refresh(ventasProvider.future),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(8),
                          itemCount: list.length,
                          itemBuilder: (context, index) {
                            final venta = list[index];
                            return _VentaCard(venta: venta);
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/ventas/nueva'),
        icon: const Icon(Icons.add),
        label: const Text('Nueva Venta'),
      ),
    );
  }
}

class _VentaCard extends ConsumerWidget {
  final Venta venta;
  const _VentaCard({required this.venta});

  bool get _esAnulada =>
      venta.notas != null && venta.notas!.contains('[ANULADA]');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Fecha en zona Ecuador
    final fecEc = venta.fecha.toUtc().subtract(const Duration(hours: 5));
    final fecha = '${fecEc.day}/${fecEc.month}/${fecEc.year}';
    final hora =
        '${fecEc.hour.toString().padLeft(2, '0')}:${fecEc.minute.toString().padLeft(2, '0')}';
    final cantItems = venta.detalles?.length ?? 0;
    final anulada = _esAnulada;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: anulada ? Colors.red.shade50 : null,
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: anulada
              ? Colors.red.withValues(alpha: 0.15)
              : Colors.green.withValues(alpha: 0.15),
          child: Icon(
            anulada ? Icons.cancel : Icons.receipt_long,
            color: anulada ? Colors.red : Colors.green,
          ),
        ),
        title: Row(
          children: [
            Text(
              '\$${venta.total.toStringAsFixed(2)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                decoration: anulada ? TextDecoration.lineThrough : null,
                color: anulada ? Colors.red : null,
              ),
            ),
            if (anulada) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'ANULADA',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$fecha $hora  |  $cantItems artículo(s)'),
            if (venta.vendedorNombre != null)
              Text('Vendedor: ${venta.vendedorNombre}'),
            if (venta.clienteNombre != null)
              Text('Cliente: ${venta.clienteNombre}'),
            Text(
              venta.metodoPago,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        children: [
          if (venta.detalles != null && venta.detalles!.isNotEmpty)
            ...venta.detalles!.map(
              (d) => ListTile(
                dense: true,
                leading: const Icon(Icons.build, size: 20),
                title: Text(d.repuestoNombre ?? 'Repuesto'),
                subtitle: d.vehiculoInfo != null
                    ? Text(d.vehiculoInfo!,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey[600]))
                    : null,
                trailing: Text(
                  '\$${d.precio.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          if (venta.notas != null && venta.notas!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Notas: ${venta.notas}',
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
            ),
          // Botón anular (solo si no está ya anulada)
          if (!anulada)
            Padding(
              padding: const EdgeInsets.only(
                  left: 16, right: 16, bottom: 12, top: 4),
              child: Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                  ),
                  icon: const Icon(Icons.undo, size: 18),
                  label: const Text('Anular Venta'),
                  onPressed: () => _confirmarAnulacion(context, ref),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmarAnulacion(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.warning_amber, color: Colors.orange, size: 48),
        title: const Text('Anular Venta'),
        content: Text(
          '¿Anular esta venta de \$${venta.total.toStringAsFixed(2)}?\n\n'
          'Los repuestos volverán al inventario como disponibles.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sí, Anular'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    if (!context.mounted) return;

    try {
      await Supabase.instance.client.rpc('anular_venta', params: {
        'p_venta_id': venta.id,
      });

      // Refrescar datos
      ref.invalidate(ventasProvider);
      ref.invalidate(repuestosDisponiblesProvider);
      // Inventario también necesita refrescarse
      try {
        ref.invalidate(inventarioProvider);
      } catch (_) {}

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Venta anulada — repuestos devueltos al stock'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } on PostgrestException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
