import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/repuesto.dart';
import '../../../data/models/vehiculo.dart';
import '../../../data/providers/auth_provider.dart';
import '../../ventas/screens/ventas_screen.dart';
import 'vehiculo_detalle_screen.dart';

// ─── Provider: repuestos disponibles de un vehículo ──────────
final _repuestosVehiculoProvider =
    FutureProvider.family<_VehiculoVentaData, String>((ref, vehiculoId) async {
  final client = Supabase.instance.client;

  final vData = await client
      .from('vehiculos')
      .select('*, marcas(nombre), modelos(nombre), tipos_vehiculo(nombre)')
      .eq('id', vehiculoId)
      .single();

  final rData = await client
      .from('repuestos')
      .select('*, catalogo_partes(*), ubicaciones(*)')
      .eq('vehiculo_id', vehiculoId)
      .eq('estado', 'disponible')
      .order('created_at', ascending: false);

  return _VehiculoVentaData(
    vehiculo: Vehiculo.fromJson(vData),
    repuestosDisponibles: rData.map((e) => Repuesto.fromJson(e)).toList(),
  );
});

class _VehiculoVentaData {
  final Vehiculo vehiculo;
  final List<Repuesto> repuestosDisponibles;
  _VehiculoVentaData(
      {required this.vehiculo, required this.repuestosDisponibles});
}

// ─── Screen ──────────────────────────────────────────────────
class VentaVehiculoScreen extends ConsumerStatefulWidget {
  final String vehiculoId;
  const VentaVehiculoScreen({super.key, required this.vehiculoId});

  @override
  ConsumerState<VentaVehiculoScreen> createState() =>
      _VentaVehiculoScreenState();
}

class _VentaVehiculoScreenState extends ConsumerState<VentaVehiculoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _clienteNombreCtrl = TextEditingController();
  final _clienteTelefonoCtrl = TextEditingController();
  final _notasCtrl = TextEditingController();
  final _precioGlobalCtrl = TextEditingController();
  String _metodoPago = 'Efectivo';
  bool _saving = false;
  bool _selectAll = true;
  double _precioGlobal = 0;

  // repuestoId -> seleccionado
  final Map<String, bool> _seleccionados = {};

  @override
  void dispose() {
    _clienteNombreCtrl.dispose();
    _clienteTelefonoCtrl.dispose();
    _notasCtrl.dispose();
    _precioGlobalCtrl.dispose();
    super.dispose();
  }

  int get _cantidadSeleccionados =>
      _seleccionados.values.where((v) => v).length;

  void _initSeleccion(List<Repuesto> repuestos) {
    if (_seleccionados.isNotEmpty) return;
    for (final r in repuestos) {
      _seleccionados[r.id] = true;
    }
  }

  void _toggleSelectAll(List<Repuesto> repuestos) {
    setState(() {
      _selectAll = !_selectAll;
      for (final r in repuestos) {
        _seleccionados[r.id] = _selectAll;
      }
    });
  }

  /// Distribuye el precio global proporcionalmente según precio_sugerido.
  /// Las partes sin precio sugerido reciben una porción igual del remanente.
  List<Map<String, dynamic>> _distribuirPrecios(List<Repuesto> repuestos) {
    final seleccionados =
        repuestos.where((r) => _seleccionados[r.id] == true).toList();
    if (seleccionados.isEmpty || _precioGlobal <= 0) return [];

    final conPrecio =
        seleccionados.where((r) => (r.precioSugerido ?? 0) > 0).toList();
    final sinPrecio =
        seleccionados.where((r) => (r.precioSugerido ?? 0) <= 0).toList();

    final totalSugerido =
        conPrecio.fold<double>(0, (s, r) => s + r.precioSugerido!);

    final items = <Map<String, dynamic>>[];
    double acumulado = 0;

    if (totalSugerido > 0) {
      // Repartir 90% proporcional a los que tienen precio,
      // 10% equitativo a los sin precio (si los hay)
      final factorConPrecio = sinPrecio.isEmpty ? 1.0 : 0.9;
      final montoConPrecio = _precioGlobal * factorConPrecio;
      final montoSinPrecio = _precioGlobal - montoConPrecio;

      for (final r in conPrecio) {
        final proporcion = r.precioSugerido! / totalSugerido;
        final precio =
            (montoConPrecio * proporcion * 100).roundToDouble() / 100;
        items.add({'repuesto_id': r.id, 'precio': max(0.01, precio)});
        acumulado += max(0.01, precio);
      }

      if (sinPrecio.isNotEmpty) {
        final precioCada = sinPrecio.length == 1
            ? montoSinPrecio
            : (montoSinPrecio / sinPrecio.length * 100).roundToDouble() / 100;
        for (final r in sinPrecio) {
          items.add({'repuesto_id': r.id, 'precio': max(0.01, precioCada)});
          acumulado += max(0.01, precioCada);
        }
      }
    } else {
      // Todos sin precio sugerido → repartir equitativamente
      final precioCada = seleccionados.length == 1
          ? _precioGlobal
          : (_precioGlobal / seleccionados.length * 100).roundToDouble() / 100;
      for (final r in seleccionados) {
        items.add({'repuesto_id': r.id, 'precio': max(0.01, precioCada)});
        acumulado += max(0.01, precioCada);
      }
    }

    // Ajustar diferencia por redondeo al primer item
    final diff =
        ((_precioGlobal - acumulado) * 100).roundToDouble() / 100;
    if (diff.abs() > 0.001 && items.isNotEmpty) {
      final ajustado = (items[0]['precio'] as double) + diff;
      items[0]['precio'] = (ajustado * 100).roundToDouble() / 100;
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    final dataAsync = ref.watch(_repuestosVehiculoProvider(widget.vehiculoId));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.go('/vehiculos/${widget.vehiculoId}/detalle'),
        ),
        title: const Text('Vender Vehículo Completo'),
      ),
      body: dataAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error: $e'),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => ref.invalidate(
                    _repuestosVehiculoProvider(widget.vehiculoId)),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
        data: (data) {
          _initSeleccion(data.repuestosDisponibles);

          if (data.repuestosDisponibles.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2_outlined,
                      size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text(
                    'No hay repuestos disponibles para vender',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Todos los repuestos ya fueron vendidos o no están disponibles.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }

          return _buildBody(data);
        },
      ),
    );
  }

  Widget _buildBody(_VehiculoVentaData data) {
    final repuestos = data.repuestosDisponibles;
    final totalSugerido = repuestos
        .where((r) => _seleccionados[r.id] == true)
        .fold<double>(0, (s, r) => s + (r.precioSugerido ?? 0));

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        // ── Info del vehículo ──
        _VehiculoHeader(vehiculo: data.vehiculo),

        // ── Precio global ──
        Card(
          margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Precio de venta del vehículo',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  '$_cantidadSeleccionados repuestos seleccionados'
                  '${totalSugerido > 0 ? ' · Ref. sugerido: \$${totalSugerido.toStringAsFixed(2)}' : ''}',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _precioGlobalCtrl,
                  decoration: const InputDecoration(
                    prefixText: '\$ ',
                    labelText: 'Precio total de venta',
                    hintText: '0.00',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold),
                  onChanged: (v) {
                    setState(() {
                      _precioGlobal = double.tryParse(v) ?? 0;
                    });
                  },
                ),
                if (_precioGlobal > 0 && totalSugerido > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _precioGlobal >= totalSugerido
                          ? '↑ ${((_precioGlobal / totalSugerido - 1) * 100).toStringAsFixed(1)}% sobre precio sugerido'
                          : '↓ ${((1 - _precioGlobal / totalSugerido) * 100).toStringAsFixed(1)}% bajo precio sugerido',
                      style: TextStyle(
                        fontSize: 12,
                        color: _precioGlobal >= totalSugerido
                            ? Colors.green[700]
                            : Colors.orange[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // ── Datos del cliente ──
        Card(
          margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Datos de la venta',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _clienteNombreCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nombre del cliente',
                      isDense: true,
                      prefixIcon: Icon(Icons.person),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _clienteTelefonoCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Teléfono del cliente',
                      isDense: true,
                      prefixIcon: Icon(Icons.phone),
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _metodoPago,
                    decoration: const InputDecoration(
                      labelText: 'Método de pago',
                      isDense: true,
                      prefixIcon: Icon(Icons.payment),
                    ),
                    items: AppConstants.metodosPago
                        .map(
                            (m) => DropdownMenuItem(value: m, child: Text(m)))
                        .toList(),
                    onChanged: (v) => setState(() => _metodoPago = v!),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _notasCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Notas',
                      isDense: true,
                      prefixIcon: Icon(Icons.notes),
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ),
        ),

        // ── Repuestos incluidos ──
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 4),
          child: Row(
            children: [
              const Text('Repuestos incluidos',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _toggleSelectAll(repuestos),
                icon: Icon(
                    _selectAll ? Icons.deselect : Icons.select_all,
                    size: 18),
                label:
                    Text(_selectAll ? 'Deseleccionar' : 'Seleccionar todo',
                        style: const TextStyle(fontSize: 13)),
              ),
            ],
          ),
        ),

        // Lista de repuestos (checkboxes)
        ...repuestos.map((r) {
          final sel = _seleccionados[r.id] ?? true;
          return CheckboxListTile(
            value: sel,
            dense: true,
            onChanged: (v) => setState(() => _seleccionados[r.id] = v!),
            secondary: CircleAvatar(
              radius: 16,
              backgroundColor: sel
                  ? Colors.green.withValues(alpha: 0.15)
                  : Colors.grey.withValues(alpha: 0.1),
              child: Icon(Icons.build, size: 16,
                  color: sel ? Colors.green : Colors.grey),
            ),
            title: Text(
              r.parteNombre ?? 'Sin nombre',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: sel ? null : Colors.grey,
                decoration: sel ? null : TextDecoration.lineThrough,
              ),
            ),
            subtitle: Text(
              [
                if (r.parteCategoria != null) r.parteCategoria!,
                if (r.ubicacionNombre != null) r.ubicacionNombre!,
                if (r.precioSugerido != null && r.precioSugerido! > 0)
                  'Sug. \$${r.precioSugerido!.toStringAsFixed(2)}',
              ].join(' · '),
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          );
        }),

        const SizedBox(height: 16),

        // ── Botón confirmar ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: FilledButton.icon(
            onPressed:
                _saving || _cantidadSeleccionados == 0 || _precioGlobal <= 0
                    ? null
                    : () => _finalizarVenta(repuestos),
            icon: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.sell),
            label: Text(
              _precioGlobal > 0
                  ? 'Vender $_cantidadSeleccionados repuestos por \$${_precioGlobal.toStringAsFixed(2)}'
                  : 'Ingrese el precio de venta',
            ),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              minimumSize: const Size(double.infinity, 52),
            ),
          ),
        ),
      ],
    );
  }

  // ── Ejecutar venta ──
  Future<void> _finalizarVenta(List<Repuesto> repuestos) async {
    if (_cantidadSeleccionados == 0 || _precioGlobal <= 0) return;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar venta de vehículo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¿Vender $_cantidadSeleccionados repuestos por \$${_precioGlobal.toStringAsFixed(2)}?',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Los precios se distribuirán proporcionalmente en los detalles de la venta.',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (confirmar != true || !mounted) return;

    setState(() => _saving = true);

    try {
      final supabase = Supabase.instance.client;
      final auth = ref.read(authProvider);
      final vendedorId = auth.perfil!.id;

      // Distribuir precio global proporcionalmente
      final items = _distribuirPrecios(repuestos);

      if (items.isEmpty) {
        throw Exception('No hay repuestos seleccionados');
      }

      // Recalcular total real (puede diferir ligeramente por redondeo)
      final totalReal =
          items.fold<double>(0, (s, i) => s + (i['precio'] as double));

      await supabase.rpc('registrar_venta', params: {
        'p_vendedor_id': vendedorId,
        'p_cliente_nombre': _clienteNombreCtrl.text,
        'p_cliente_telefono': _clienteTelefonoCtrl.text,
        'p_metodo_pago': _metodoPago,
        'p_total': totalReal,
        'p_notas':
            'Venta vehículo completo${_notasCtrl.text.isNotEmpty ? ': ${_notasCtrl.text}' : ''}',
        'p_items': items,
      });

      ref.invalidate(_repuestosVehiculoProvider(widget.vehiculoId));
      ref.invalidate(vehiculoDetalleProvider(widget.vehiculoId));
      ref.invalidate(ventasProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Venta registrada: $_cantidadSeleccionados repuestos por \$${_precioGlobal.toStringAsFixed(2)}'),
            backgroundColor: Colors.green,
          ),
        );
        context.go('/vehiculos/${widget.vehiculoId}/detalle');
      }
    } on PostgrestException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// ─── Header compacto del vehículo ────────────────────────────
class _VehiculoHeader extends StatelessWidget {
  final Vehiculo vehiculo;
  const _VehiculoHeader({required this.vehiculo});

  @override
  Widget build(BuildContext context) {
    final v = vehiculo;
    return Container(
      padding: const EdgeInsets.all(12),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Row(
        children: [
          const Icon(Icons.directions_car, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  v.nombreCompleto,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  'Año ${v.anio} · Costo: \$${v.costoCompra.toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
