import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/models/venta.dart';

// Provider de ventas
final ventasProvider = FutureProvider<List<Venta>>((ref) async {
  final data = await Supabase.instance.client
      .from('ventas')
      .select('*, perfiles(*), venta_detalle(*, repuestos(*, catalogo_partes(*)))')
      .order('fecha', ascending: false);
  return data.map((e) => Venta.fromJson(e)).toList();
});

class VentasScreen extends ConsumerWidget {
  const VentasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ventas = ref.watch(ventasProvider);

    return Scaffold(
      body: ventas.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.point_of_sale, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No hay ventas registradas',
                      style: TextStyle(color: Colors.grey, fontSize: 16)),
                ],
              ),
            );
          }

          // Calcular totales
          final totalVentas = list.fold<double>(0, (sum, v) => sum + v.total);

          return Column(
            children: [
              // Resumen
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
                            '${list.length} ventas registradas',
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
                  ],
                ),
              ),

              // Lista
              Expanded(
                child: RefreshIndicator(
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

class _VentaCard extends StatelessWidget {
  final Venta venta;
  const _VentaCard({required this.venta});

  @override
  Widget build(BuildContext context) {
    final fecha =
        '${venta.fecha.day}/${venta.fecha.month}/${venta.fecha.year}';
    final cantItems = venta.detalles?.length ?? 0;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: Colors.green.withValues(alpha: 0.15),
          child: const Icon(Icons.receipt_long, color: Colors.green),
        ),
        title: Text(
          '\$${venta.total.toStringAsFixed(2)}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Fecha: $fecha  |  $cantItems artículo(s)'),
            if (venta.vendedorNombre != null)
              Text('Vendedor: ${venta.vendedorNombre}'),
            if (venta.clienteNombre != null)
              Text('Cliente: ${venta.clienteNombre}'),
            Text(
              venta.metodoPago,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
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
        ],
      ),
    );
  }
}
