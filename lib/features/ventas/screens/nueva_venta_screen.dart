import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/repuesto.dart';
import '../../../data/providers/auth_provider.dart';
import 'ventas_screen.dart';

// Provider: repuestos disponibles para venta
final repuestosDisponiblesProvider = FutureProvider<List<Repuesto>>((ref) async {
  final data = await Supabase.instance.client
      .from('repuestos')
      .select('*, catalogo_partes(*), ubicaciones(*), vehiculos(*, marcas(*), modelos(*))')
      .eq('estado', 'disponible')
      .order('created_at', ascending: false);
  return data.map((e) => Repuesto.fromJson(e)).toList();
});

class NuevaVentaScreen extends ConsumerStatefulWidget {
  const NuevaVentaScreen({super.key});

  @override
  ConsumerState<NuevaVentaScreen> createState() => _NuevaVentaScreenState();
}

class _NuevaVentaScreenState extends ConsumerState<NuevaVentaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _clienteNombreCtrl = TextEditingController();
  final _clienteTelefonoCtrl = TextEditingController();
  final _notasCtrl = TextEditingController();
  String _metodoPago = 'Efectivo';
  bool _saving = false;

  // Carrito de venta: repuestoId -> precio
  final Map<String, _ItemVenta> _carrito = {};
  String _busqueda = '';
  bool _showingCart = false; // Móvil: alternar entre lista y carrito

  @override
  void dispose() {
    _clienteNombreCtrl.dispose();
    _clienteTelefonoCtrl.dispose();
    _notasCtrl.dispose();
    super.dispose();
  }

  double get _total =>
      _carrito.values.fold<double>(0, (sum, item) => sum + item.precio);

  bool get _tienePreciosCero =>
      _carrito.values.any((item) => item.precio <= 0);

  @override
  Widget build(BuildContext context) {
    final repuestos = ref.watch(repuestosDisponiblesProvider);
    final isWide = MediaQuery.of(context).size.width > 800;

    return PopScope(
      canPop: isWide || !_showingCart,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          setState(() => _showingCart = false);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(!isWide && _showingCart ? 'Carrito de Venta' : 'Nueva Venta'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (!isWide && _showingCart) {
                setState(() => _showingCart = false);
              } else {
                context.go('/ventas');
              }
            },
          ),
          actions: !isWide && _showingCart
              ? [
                  TextButton.icon(
                    onPressed: () => setState(() => _showingCart = false),
                    icon: const Icon(Icons.add_shopping_cart, size: 18),
                    label: const Text('Agregar más'),
                  ),
                ]
              : null,
        ),
        body: isWide
            ? Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: _buildRepuestosList(repuestos),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(
                    flex: 2,
                    child: _buildCarritoPanel(),
                  ),
                ],
              )
            : _showingCart
                ? _buildCarritoPanel()
                : Column(
                    children: [
                      // Carrito resumen arriba
                      if (_carrito.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(12),
                          color: Theme.of(context).colorScheme.primaryContainer,
                          child: Row(
                            children: [
                              Text(
                                '${_carrito.length} artículo(s)',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const Spacer(),
                              Text(
                                'Total: \$${_total.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(width: 8),
                              FilledButton(
                                onPressed: () => setState(() => _showingCart = true),
                                child: const Text('Finalizar'),
                              ),
                            ],
                          ),
                        ),
                      Expanded(child: _buildRepuestosList(repuestos)),
                    ],
                  ),
      ),
    );
  }

  Widget _buildRepuestosList(AsyncValue<List<Repuesto>> repuestos) {
    return Column(
      children: [
        // Barra de búsqueda
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Buscar repuesto disponible...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _busqueda = v.toLowerCase()),
          ),
        ),

        Expanded(
          child: repuestos.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (list) {
              var filtered = list;
              if (_busqueda.isNotEmpty) {
                filtered = list.where((r) {
                  final nombre = (r.parteNombre ?? '').toLowerCase();
                  final vehiculo = (r.vehiculoNombre ?? '').toLowerCase();
                  return nombre.contains(_busqueda) ||
                      vehiculo.contains(_busqueda);
                }).toList();
              }

              // Excluir los ya agregados al carrito
              filtered = filtered
                  .where((r) => !_carrito.containsKey(r.id))
                  .toList();

              if (filtered.isEmpty) {
                return const Center(
                  child: Text('No hay repuestos disponibles',
                      style: TextStyle(color: Colors.grey)),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final r = filtered[index];
                  return Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.build),
                      ),
                      title: Text(r.parteNombre ?? 'Sin nombre'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (r.vehiculoNombre != null)
                            Text('De: ${r.vehiculoNombre}'),
                          if (r.parteCategoria != null)
                            Text(r.parteCategoria!,
                                style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.add_shopping_cart,
                            color: Colors.green),
                        onPressed: () => _agregarAlCarrito(r),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCarritoPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Título
        Container(
          padding: const EdgeInsets.all(16),
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Text(
            'Carrito de Venta',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),

        // Items del carrito
        Expanded(
          child: _carrito.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.shopping_cart_outlined,
                          size: 48, color: Colors.grey),
                      SizedBox(height: 8),
                      Text('Agregue repuestos al carrito',
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(8),
                  children: [
                    ..._carrito.entries.map((entry) {
                      final item = entry.value;
                      final sinPrecio = item.precio <= 0;
                      return Card(
                        color: sinPrecio
                            ? Colors.red.shade50
                            : null,
                        child: ListTile(
                          dense: true,
                          title: Text(item.nombre,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (item.vehiculo != null)
                                Text(item.vehiculo!),
                              if (sinPrecio)
                                const Text(
                                  'Ingrese un precio de venta',
                                  style: TextStyle(
                                      color: Colors.red, fontSize: 12),
                                ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 80,
                                child: TextFormField(
                                  initialValue:
                                      item.precio > 0
                                          ? item.precio.toStringAsFixed(2)
                                          : '',
                                  decoration: InputDecoration(
                                    prefixText: '\$ ',
                                    isDense: true,
                                    hintText: '0.00',
                                    border: const OutlineInputBorder(),
                                    enabledBorder: sinPrecio
                                        ? const OutlineInputBorder(
                                            borderSide: BorderSide(
                                                color: Colors.red, width: 2),
                                          )
                                        : null,
                                  ),
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  onChanged: (v) {
                                    final p = double.tryParse(v);
                                    setState(() {
                                      _carrito[entry.key] =
                                          item.copyWith(precio: p ?? 0);
                                    });
                                  },
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.remove_circle,
                                    color: Colors.red, size: 20),
                                onPressed: () {
                                  setState(() {
                                    _carrito.remove(entry.key);
                                    if (_carrito.isEmpty) _showingCart = false;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    }),

                    const Divider(),

                    // Total
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
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
                              fontSize: 22,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Divider(),

                    // Datos del cliente
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Form(
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
                                  .map((m) => DropdownMenuItem(
                                      value: m, child: Text(m)))
                                  .toList(),
                              onChanged: (v) =>
                                  setState(() => _metodoPago = v!),
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

                    // Aviso de precios faltantes
                    if (_tienePreciosCero)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Icon(Icons.warning_amber, color: Colors.orange, size: 18),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Todos los artículos deben tener un precio mayor a \$0',
                                style: TextStyle(color: Colors.orange, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Botón finalizar
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: FilledButton.icon(
                        onPressed:
                            _saving || _carrito.isEmpty || _tienePreciosCero
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
                        label: const Text('Confirmar Venta'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  void _agregarAlCarrito(Repuesto r) {
    setState(() {
      _carrito[r.id] = _ItemVenta(
        repuestoId: r.id,
        nombre: r.parteNombre ?? 'Sin nombre',
        vehiculo: r.vehiculoNombre,
        precio: r.precioSugerido ?? 0,
      );
    });
  }

  // _mostrarResumenVenta ya no se usa; en móvil se alterna
  // con _showingCart = true para mostrar el carrito a pantalla completa.

  Future<void> _finalizarVenta() async {
    if (_carrito.isEmpty) return;

    // Validar que todos los items tengan precio > 0
    final sinPrecio = _carrito.entries
        .where((e) => e.value.precio <= 0)
        .map((e) => e.value.nombre)
        .toList();
    if (sinPrecio.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Ingrese precio para: ${sinPrecio.join(", ")}'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final supabase = Supabase.instance.client;
      final auth = ref.read(authProvider);
      final vendedorId = auth.perfil!.id;

      // ── Construir lista de items para el RPC ──
      final items = _carrito.entries.map((entry) => {
        'repuesto_id': entry.key,
        'precio': entry.value.precio,
      }).toList();

      // ── Llamar función atómica del servidor ──
      // Todo ocurre en una sola transacción: validación, venta,
      // detalles, actualización de estado y movimientos.
      await supabase.rpc('registrar_venta', params: {
        'p_vendedor_id': vendedorId,
        'p_cliente_nombre': _clienteNombreCtrl.text,
        'p_cliente_telefono': _clienteTelefonoCtrl.text,
        'p_metodo_pago': _metodoPago,
        'p_total': _total,
        'p_notas': _notasCtrl.text,
        'p_items': items,
      });

      // ── Invalidar providers para refrescar datos ──
      ref.invalidate(repuestosDisponiblesProvider);
      ref.invalidate(ventasProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Venta registrada: \$${_total.toStringAsFixed(2)}'),
            backgroundColor: Colors.green,
          ),
        );
        context.go('/ventas');
      }
    } on PostgrestException catch (e) {
      if (mounted) {
        // Extraer mensaje legible del error
        final msg = e.message.contains('"')
            ? e.message
            : 'Error al registrar venta: ${e.message}';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
        // Refrescar la lista por si algún item cambió de estado
        ref.invalidate(repuestosDisponiblesProvider);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _ItemVenta {
  final String repuestoId;
  final String nombre;
  final String? vehiculo;
  final double precio;

  _ItemVenta({
    required this.repuestoId,
    required this.nombre,
    this.vehiculo,
    required this.precio,
  });

  _ItemVenta copyWith({double? precio}) {
    return _ItemVenta(
      repuestoId: repuestoId,
      nombre: nombre,
      vehiculo: vehiculo,
      precio: precio ?? this.precio,
    );
  }
}
