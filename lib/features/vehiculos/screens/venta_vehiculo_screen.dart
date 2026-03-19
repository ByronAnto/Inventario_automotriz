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
  String _metodoPago = 'Efectivo';
  bool _saving = false;
  bool _selectAll = true;

  // repuestoId -> precio editable
  final Map<String, double> _precios = {};
  // repuestoId -> seleccionado
  final Map<String, bool> _seleccionados = {};

  @override
  void dispose() {
    _clienteNombreCtrl.dispose();
    _clienteTelefonoCtrl.dispose();
    _notasCtrl.dispose();
    super.dispose();
  }

  double get _total => _seleccionados.entries
      .where((e) => e.value)
      .fold<double>(0, (sum, e) => sum + (_precios[e.key] ?? 0));

  int get _cantidadSeleccionados =>
      _seleccionados.values.where((v) => v).length;

  bool get _tienePreciosCero => _seleccionados.entries
      .where((e) => e.value)
      .any((e) => (_precios[e.key] ?? 0) <= 0);

  void _initPrecios(List<Repuesto> repuestos) {
    if (_precios.isNotEmpty) return; // Ya inicializado
    for (final r in repuestos) {
      _precios[r.id] = r.precioSugerido ?? 0;
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

  @override
  Widget build(BuildContext context) {
    final dataAsync = ref.watch(_repuestosVehiculoProvider(widget.vehiculoId));
    final isWide = MediaQuery.of(context).size.width > 800;

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
          _initPrecios(data.repuestosDisponibles);

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
                    'Todos los repuestos de este vehículo ya fueron vendidos o no están disponibles.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }

          return isWide
              ? Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: _buildRepuestosPanel(data),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      flex: 2,
                      child: _buildResumenPanel(data),
                    ),
                  ],
                )
              : _buildMobileView(data);
        },
      ),
    );
  }

  // ── Vista Móvil ──
  Widget _buildMobileView(_VehiculoVentaData data) {
    return Column(
      children: [
        // Info del vehículo compacta
        _VehiculoHeader(vehiculo: data.vehiculo),

        // Resumen flotante
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Row(
            children: [
              Text(
                '$_cantidadSeleccionados de ${data.repuestosDisponibles.length} seleccionados',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const Spacer(),
              Text(
                'Total: \$${_total.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),

        // Lista de repuestos
        Expanded(
          child: _buildRepuestosList(data.repuestosDisponibles),
        ),

        // Botón finalizar fijo
        _buildBottomBar(data),
      ],
    );
  }

  // ── Panel izquierdo: repuestos ──
  Widget _buildRepuestosPanel(_VehiculoVentaData data) {
    return Column(
      children: [
        _VehiculoHeader(vehiculo: data.vehiculo),
        _buildToolbar(data.repuestosDisponibles),
        Expanded(child: _buildRepuestosList(data.repuestosDisponibles)),
      ],
    );
  }

  Widget _buildToolbar(List<Repuesto> repuestos) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Text(
            '${repuestos.length} repuestos disponibles',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: () => _toggleSelectAll(repuestos),
            icon: Icon(
              _selectAll ? Icons.deselect : Icons.select_all,
              size: 18,
            ),
            label: Text(_selectAll ? 'Deseleccionar todo' : 'Seleccionar todo'),
          ),
        ],
      ),
    );
  }

  Widget _buildRepuestosList(List<Repuesto> repuestos) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      itemCount: repuestos.length + 1, // +1 for select all header on mobile
      itemBuilder: (context, index) {
        if (index == 0) {
          // Toolbar on mobile
          return _buildToolbar(repuestos);
        }
        final r = repuestos[index - 1];
        final seleccionado = _seleccionados[r.id] ?? true;
        final precio = _precios[r.id] ?? 0;
        final sinPrecio = seleccionado && precio <= 0;

        return Card(
          color: sinPrecio
              ? Colors.red.shade50
              : seleccionado
                  ? null
                  : Colors.grey.shade100,
          child: CheckboxListTile(
            value: seleccionado,
            onChanged: (v) {
              setState(() => _seleccionados[r.id] = v ?? false);
            },
            secondary: CircleAvatar(
              backgroundColor: seleccionado
                  ? Colors.green.withValues(alpha: 0.15)
                  : Colors.grey.withValues(alpha: 0.15),
              child: Icon(
                Icons.build,
                color: seleccionado ? Colors.green : Colors.grey,
                size: 20,
              ),
            ),
            title: Text(
              r.parteNombre ?? 'Sin nombre',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: seleccionado ? null : Colors.grey,
                decoration: seleccionado ? null : TextDecoration.lineThrough,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (r.parteCategoria != null)
                  Text(r.parteCategoria!,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                if (r.ubicacionNombre != null)
                  Text('📍 ${r.ubicacionNombre}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                const SizedBox(height: 4),
                // Campo precio editable
                SizedBox(
                  width: 120,
                  child: TextFormField(
                    initialValue: precio > 0 ? precio.toStringAsFixed(2) : '',
                    decoration: InputDecoration(
                      prefixText: '\$ ',
                      isDense: true,
                      hintText: '0.00',
                      labelText: 'Precio',
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 8),
                      enabledBorder: sinPrecio
                          ? const OutlineInputBorder(
                              borderSide:
                                  BorderSide(color: Colors.red, width: 2),
                            )
                          : null,
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    enabled: seleccionado,
                    onChanged: (v) {
                      setState(() {
                        _precios[r.id] = double.tryParse(v) ?? 0;
                      });
                    },
                  ),
                ),
                if (sinPrecio)
                  const Text(
                    'Ingrese un precio de venta',
                    style: TextStyle(color: Colors.red, fontSize: 11),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Panel derecho: resumen + cliente ──
  Widget _buildResumenPanel(_VehiculoVentaData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Título
        Container(
          padding: const EdgeInsets.all(16),
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Resumen de Venta',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                '$_cantidadSeleccionados de ${data.repuestosDisponibles.length} repuestos seleccionados',
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
            ],
          ),
        ),

        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              // Total destacado
              Card(
                color: Colors.green.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('TOTAL',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 18)),
                      Text(
                        '\$${_total.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Formulario cliente
              Form(
                key: _formKey,
                child: Column(
                  children: [
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
                          .map((m) =>
                              DropdownMenuItem(value: m, child: Text(m)))
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

              const SizedBox(height: 16),

              // Aviso precio
              if (_tienePreciosCero)
                Card(
                  color: Colors.orange.shade50,
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber,
                            color: Colors.orange, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Todos los artículos seleccionados deben tener un precio mayor a \$0',
                            style:
                                TextStyle(color: Colors.orange, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 16),

              // Botón confirmar
              FilledButton.icon(
                onPressed: _saving ||
                        _cantidadSeleccionados == 0 ||
                        _tienePreciosCero
                    ? null
                    : _finalizarVenta,
                icon: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check),
                label: Text(
                    'Confirmar Venta ($_cantidadSeleccionados repuestos)'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Barra inferior móvil ──
  Widget _buildBottomBar(_VehiculoVentaData data) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_tienePreciosCero)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.orange, size: 16),
                    SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Todos los seleccionados deben tener precio > \$0',
                        style: TextStyle(color: Colors.orange, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            FilledButton.icon(
              onPressed: _saving ||
                      _cantidadSeleccionados == 0 ||
                      _tienePreciosCero
                  ? null
                  : () => _mostrarDatosCliente(data),
              icon: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.shopping_cart_checkout),
              label: Text(
                'Vender $_cantidadSeleccionados repuestos — \$${_total.toStringAsFixed(2)}',
              ),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Diálogo de datos del cliente (móvil) ──
  Future<void> _mostrarDatosCliente(_VehiculoVentaData data) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Datos de la Venta'),
        content: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Resumen
                Card(
                  color: Colors.green.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('$_cantidadSeleccionados repuestos'),
                        Text(
                          '\$${_total.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
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
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar Venta'),
          ),
        ],
      ),
    );

    if (ok == true) {
      _finalizarVenta();
    }
  }

  // ── Ejecutar venta ──
  Future<void> _finalizarVenta() async {
    if (_cantidadSeleccionados == 0) return;

    // Confirmar
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar venta'),
        content: Text(
          '¿Vender $_cantidadSeleccionados repuestos por \$${_total.toStringAsFixed(2)}?',
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

      // Construir lista de items seleccionados
      final items = _seleccionados.entries
          .where((e) => e.value)
          .map((e) => {
                'repuesto_id': e.key,
                'precio': _precios[e.key] ?? 0,
              })
          .toList();

      // Usar la misma RPC atómica existente
      await supabase.rpc('registrar_venta', params: {
        'p_vendedor_id': vendedorId,
        'p_cliente_nombre': _clienteNombreCtrl.text,
        'p_cliente_telefono': _clienteTelefonoCtrl.text,
        'p_metodo_pago': _metodoPago,
        'p_total': _total,
        'p_notas':
            'Venta vehículo completo${_notasCtrl.text.isNotEmpty ? ': ${_notasCtrl.text}' : ''}',
        'p_items': items,
      });

      // Invalidar providers
      ref.invalidate(_repuestosVehiculoProvider(widget.vehiculoId));
      ref.invalidate(vehiculoDetalleProvider(widget.vehiculoId));
      ref.invalidate(ventasProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Venta registrada: $_cantidadSeleccionados repuestos por \$${_total.toStringAsFixed(2)}'),
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
