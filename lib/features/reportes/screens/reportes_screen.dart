import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// =============== PROVIDERS ===============

// ROI por vehículo
final roiPorVehiculoProvider =
    FutureProvider<List<_VehiculoROI>>((ref) async {
  final supabase = Supabase.instance.client;

  // Obtener todos los vehículos con su costo
  final vehiculos = await supabase
      .from('vehiculos')
      .select('id, costo_compra, marcas(nombre), modelos(nombre), anio');

  final result = <_VehiculoROI>[];

  for (final v in vehiculos) {
    final vehiculoId = v['id'] as String;
    final costoCompra = (v['costo_compra'] as num).toDouble();
    final marca = v['marcas']?['nombre'] ?? '';
    final modelo = v['modelos']?['nombre'] ?? '';
    final anio = v['anio'] ?? 0;

    // Obtener ventas de repuestos de este vehículo
    final ventasData = await supabase
        .from('venta_detalle')
        .select('precio, repuestos!inner(vehiculo_id)')
        .eq('repuestos.vehiculo_id', vehiculoId);

    double totalVentas = 0;
    for (final vd in ventasData) {
      totalVentas += (vd['precio'] as num).toDouble();
    }

    // Costos de repuestos externos asociados al vehículo (si los hay)
    final externosData = await supabase
        .from('repuestos')
        .select('costo_externo')
        .eq('vehiculo_id', vehiculoId)
        .eq('origen', 'externo');

    double costoExterno = 0;
    for (final e in externosData) {
      costoExterno += ((e['costo_externo'] as num?) ?? 0).toDouble();
    }

    final inversion = costoCompra + costoExterno;
    final roi = inversion > 0 ? ((totalVentas - inversion) / inversion) * 100 : 0;

    result.add(_VehiculoROI(
      nombre: '$marca $modelo $anio',
      costoCompra: costoCompra,
      costoExterno: costoExterno,
      totalVentas: totalVentas,
      ganancia: totalVentas - inversion,
      roiPorcentaje: roi.toDouble(),
    ));
  }

  // Ordenar por ganancia descendente
  result.sort((a, b) => b.ganancia.compareTo(a.ganancia));
  return result;
});

// Ventas mensuales
final ventasMensualesProvider =
    FutureProvider<List<_VentaMensual>>((ref) async {
  final supabase = Supabase.instance.client;
  final now = DateTime.now();
  final result = <_VentaMensual>[];

  for (int i = 5; i >= 0; i--) {
    final mesDate = DateTime(now.year, now.month - i, 1);
    final mesEnd = DateTime(mesDate.year, mesDate.month + 1, 0, 23, 59, 59);

    final data = await supabase
        .from('ventas')
        .select('total')
        .gte('fecha', mesDate.toIso8601String())
        .lte('fecha', mesEnd.toIso8601String());

    double total = 0;
    int cantidad = data.length;
    for (final v in data) {
      total += (v['total'] as num).toDouble();
    }

    final meses = [
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
    ];

    result.add(_VentaMensual(
      mes: meses[mesDate.month - 1],
      total: total,
      cantidad: cantidad,
    ));
  }

  return result;
});

// Ventas por vendedor
final ventasPorVendedorProvider =
    FutureProvider<List<_VendedorStats>>((ref) async {
  final supabase = Supabase.instance.client;

  final data = await supabase.from('ventas').select('total, vendedor_id, perfiles(nombre)');

  final Map<String, _VendedorStats> map = {};
  for (final v in data) {
    final vendedorId = v['vendedor_id'] as String;
    final nombre = v['perfiles']?['nombre'] as String? ?? 'Desconocido';
    final total = (v['total'] as num).toDouble();

    if (map.containsKey(vendedorId)) {
      map[vendedorId] = _VendedorStats(
        nombre: nombre,
        totalVentas: map[vendedorId]!.totalVentas + total,
        cantidadVentas: map[vendedorId]!.cantidadVentas + 1,
      );
    } else {
      map[vendedorId] = _VendedorStats(
        nombre: nombre,
        totalVentas: total,
        cantidadVentas: 1,
      );
    }
  }

  final result = map.values.toList();
  result.sort((a, b) => b.totalVentas.compareTo(a.totalVentas));
  return result;
});

// Resumen de inventario
final resumenInventarioProvider =
    FutureProvider<Map<String, int>>((ref) async {
  final data = await Supabase.instance.client
      .from('repuestos')
      .select('estado');

  final Map<String, int> counts = {};
  for (final r in data) {
    final estado = r['estado'] as String;
    counts[estado] = (counts[estado] ?? 0) + 1;
  }
  return counts;
});

// =============== SCREEN ===============

class ReportesScreen extends ConsumerWidget {
  const ReportesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        body: Column(
          children: [
            const TabBar(
              isScrollable: true,
              tabs: [
                Tab(text: 'ROI Vehículos', icon: Icon(Icons.trending_up)),
                Tab(text: 'Ventas Mensuales', icon: Icon(Icons.bar_chart)),
                Tab(text: 'Por Vendedor', icon: Icon(Icons.people)),
                Tab(text: 'Inventario', icon: Icon(Icons.inventory_2)),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _ROITab(),
                  _VentasMensualesTab(),
                  _VendedoresTab(),
                  _InventarioResumenTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============== TAB: ROI por Vehículo ===============

class _ROITab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roi = ref.watch(roiPorVehiculoProvider);

    return roi.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (list) {
        if (list.isEmpty) {
          return const Center(child: Text('No hay datos de vehículos'));
        }

        // Calcular totales
        final totalInversion = list.fold<double>(
            0, (sum, v) => sum + v.costoCompra + v.costoExterno);
        final totalVentas =
            list.fold<double>(0, (sum, v) => sum + v.totalVentas);
        final totalGanancia =
            list.fold<double>(0, (sum, v) => sum + v.ganancia);

        return Column(
          children: [
            // Resumen global
            Container(
              padding: const EdgeInsets.all(16),
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Row(
                children: [
                  _StatBox('Inversión Total',
                      '\$${totalInversion.toStringAsFixed(0)}', Colors.blue),
                  _StatBox('Total Ventas',
                      '\$${totalVentas.toStringAsFixed(0)}', Colors.green),
                  _StatBox(
                    'Ganancia',
                    '\$${totalGanancia.toStringAsFixed(0)}',
                    totalGanancia >= 0 ? Colors.green : Colors.red,
                  ),
                ],
              ),
            ),

            // Lista
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => ref.refresh(roiPorVehiculoProvider.future),
                child: ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final v = list[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    v.nombre,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: v.roiPorcentaje >= 0
                                        ? Colors.green.withValues(alpha: 0.15)
                                        : Colors.red.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${v.roiPorcentaje.toStringAsFixed(1)}% ROI',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: v.roiPorcentaje >= 0
                                          ? Colors.green
                                          : Colors.red,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                _MiniStat(
                                    'Compra',
                                    '\$${v.costoCompra.toStringAsFixed(0)}',
                                    Colors.blue),
                                if (v.costoExterno > 0)
                                  _MiniStat(
                                      'Externos',
                                      '\$${v.costoExterno.toStringAsFixed(0)}',
                                      Colors.orange),
                                _MiniStat(
                                    'Ventas',
                                    '\$${v.totalVentas.toStringAsFixed(0)}',
                                    Colors.green),
                                _MiniStat(
                                  'Ganancia',
                                  '\$${v.ganancia.toStringAsFixed(0)}',
                                  v.ganancia >= 0 ? Colors.green : Colors.red,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Barra de progreso
                            LinearProgressIndicator(
                              value: v.costoCompra > 0
                                  ? (v.totalVentas / (v.costoCompra + v.costoExterno))
                                      .clamp(0.0, 2.0) / 2
                                  : 0,
                              backgroundColor: Colors.grey[200],
                              valueColor: AlwaysStoppedAnimation(
                                v.totalVentas >= v.costoCompra + v.costoExterno
                                    ? Colors.green
                                    : Colors.orange,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// =============== TAB: Ventas Mensuales ===============

class _VentasMensualesTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ventas = ref.watch(ventasMensualesProvider);

    return ventas.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (list) {
        if (list.isEmpty) {
          return const Center(child: Text('No hay datos'));
        }

        final maxValue =
            list.fold<double>(0, (max, v) => v.total > max ? v.total : max);

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ventas Últimos 6 Meses',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 24),

              // Gráfico de barras
              SizedBox(
                height: 300,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: maxValue * 1.2,
                    barGroups: list.asMap().entries.map((entry) {
                      return BarChartGroupData(
                        x: entry.key,
                        barRods: [
                          BarChartRodData(
                            toY: entry.value.total,
                            color: const Color(0xFF1565C0),
                            width: 24,
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4)),
                          ),
                        ],
                      );
                    }).toList(),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 60,
                          getTitlesWidget: (value, meta) {
                            return Text(
                              '\$${(value / 1000).toStringAsFixed(0)}k',
                              style: const TextStyle(fontSize: 11),
                            );
                          },
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final idx = value.toInt();
                            if (idx >= 0 && idx < list.length) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  list[idx].mes,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              );
                            }
                            return const Text('');
                          },
                        ),
                      ),
                      rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                    ),
                    gridData: const FlGridData(show: true),
                    borderData: FlBorderData(show: false),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Tabla resumen
              ...list.map((v) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        SizedBox(width: 40, child: Text(v.mes)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: LinearProgressIndicator(
                            value: maxValue > 0 ? v.total / maxValue : 0,
                            backgroundColor: Colors.grey[200],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '\$${v.total.toStringAsFixed(0)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '(${v.cantidad})',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )),
            ],
          ),
        );
      },
    );
  }
}

// =============== TAB: Vendedores ===============

class _VendedoresTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vendedores = ref.watch(ventasPorVendedorProvider);

    return vendedores.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (list) {
        if (list.isEmpty) {
          return const Center(child: Text('No hay datos de vendedores'));
        }

        final total = list.fold<double>(0, (sum, v) => sum + v.totalVentas);

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Rendimiento por Vendedor',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 24),

              // Gráfico de pie
              SizedBox(
                height: 200,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 40,
                    sections: list.asMap().entries.map((entry) {
                      final colors = [
                        Colors.blue,
                        Colors.green,
                        Colors.orange,
                        Colors.purple,
                        Colors.teal,
                        Colors.red,
                      ];
                      final color = colors[entry.key % colors.length];
                      final porcentaje = total > 0
                          ? (entry.value.totalVentas / total * 100)
                          : 0;
                      return PieChartSectionData(
                        value: entry.value.totalVentas,
                        title: '${porcentaje.toStringAsFixed(0)}%',
                        color: color,
                        radius: 60,
                        titleStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Lista de vendedores
              Expanded(
                child: ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final v = list[index];
                    final colors = [
                      Colors.blue,
                      Colors.green,
                      Colors.orange,
                      Colors.purple,
                      Colors.teal,
                      Colors.red,
                    ];
                    final color = colors[index % colors.length];

                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: color,
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Text(
                          v.nombre,
                          style:
                              const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                            '${v.cantidadVentas} ventas realizadas'),
                        trailing: Text(
                          '\$${v.totalVentas.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.green,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// =============== TAB: Inventario Resumen ===============

class _InventarioResumenTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resumen = ref.watch(resumenInventarioProvider);

    return resumen.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (counts) {
        if (counts.isEmpty) {
          return const Center(child: Text('No hay datos de inventario'));
        }

        final total = counts.values.fold<int>(0, (sum, v) => sum + v);

        final estadoConfig = {
          'disponible': (Colors.green, Icons.check_circle),
          'vendido': (Colors.blue, Icons.shopping_cart),
          'faltante': (Colors.red, Icons.remove_circle),
          'dañado': (Colors.orange, Icons.warning),
          'intercambiado': (Colors.purple, Icons.swap_horiz),
          'descartado': (Colors.grey, Icons.delete),
        };

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Distribución del Inventario',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Total: $total repuestos',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 24),

              // Gráfico
              SizedBox(
                height: 200,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 50,
                    sections: counts.entries.map((entry) {
                      final config = estadoConfig[entry.key];
                      final color = config?.$1 ?? Colors.grey;
                      final porcentaje =
                          total > 0 ? (entry.value / total * 100) : 0;
                      return PieChartSectionData(
                        value: entry.value.toDouble(),
                        title: '${porcentaje.toStringAsFixed(0)}%',
                        color: color,
                        radius: 60,
                        titleStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Leyenda
              Expanded(
                child: ListView(
                  children: counts.entries.map((entry) {
                    final config = estadoConfig[entry.key];
                    final color = config?.$1 ?? Colors.grey;
                    final icon = config?.$2 ?? Icons.help;

                    return Card(
                      child: ListTile(
                        leading: Icon(icon, color: color),
                        title: Text(
                          entry.key[0].toUpperCase() + entry.key.substring(1),
                          style:
                              const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        trailing: Text(
                          '${entry.value}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                            color: color,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// =============== HELPERS ===============

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatBox(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(label,
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MiniStat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(label,
              style: const TextStyle(fontSize: 10, color: Colors.grey)),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// =============== DATA CLASSES ===============

class _VehiculoROI {
  final String nombre;
  final double costoCompra;
  final double costoExterno;
  final double totalVentas;
  final double ganancia;
  final double roiPorcentaje;

  _VehiculoROI({
    required this.nombre,
    required this.costoCompra,
    required this.costoExterno,
    required this.totalVentas,
    required this.ganancia,
    required this.roiPorcentaje,
  });
}

class _VentaMensual {
  final String mes;
  final double total;
  final int cantidad;

  _VentaMensual({
    required this.mes,
    required this.total,
    required this.cantidad,
  });
}

class _VendedorStats {
  final String nombre;
  final double totalVentas;
  final int cantidadVentas;

  _VendedorStats({
    required this.nombre,
    required this.totalVentas,
    required this.cantidadVentas,
  });
}
