import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/repuesto.dart';
import '../../../data/models/ubicacion.dart';

// Provider de inventario con filtros
class InventarioFiltrosNotifier extends Notifier<InventarioFiltros> {
  @override
  InventarioFiltros build() => InventarioFiltros();

  void update(InventarioFiltros Function(InventarioFiltros) updater) {
    state = updater(state);
  }
}

final inventarioFiltrosProvider =
    NotifierProvider<InventarioFiltrosNotifier, InventarioFiltros>(
  InventarioFiltrosNotifier.new,
);

class InventarioFiltros {
  final String? busqueda;
  final String? categoria;
  final String? estado;
  final String? ubicacionId;

  InventarioFiltros({
    this.busqueda,
    this.categoria,
    this.estado,
    this.ubicacionId,
  });

  InventarioFiltros copyWith({
    String? busqueda,
    String? categoria,
    String? estado,
    String? ubicacionId,
    bool clearBusqueda = false,
    bool clearCategoria = false,
    bool clearEstado = false,
    bool clearUbicacion = false,
  }) {
    return InventarioFiltros(
      busqueda: clearBusqueda ? null : busqueda ?? this.busqueda,
      categoria: clearCategoria ? null : categoria ?? this.categoria,
      estado: clearEstado ? null : estado ?? this.estado,
      ubicacionId: clearUbicacion ? null : ubicacionId ?? this.ubicacionId,
    );
  }
}

final inventarioProvider = FutureProvider<List<Repuesto>>((ref) async {
  final filtros = ref.watch(inventarioFiltrosProvider);
  var query = Supabase.instance.client.from('repuestos').select(
    '*, catalogo_partes(*), ubicaciones(*), vehiculos(*, marcas(*), modelos(*))',
  );

  if (filtros.estado != null) {
    query = query.eq('estado', filtros.estado!);
  }
  if (filtros.ubicacionId != null) {
    query = query.eq('ubicacion_id', filtros.ubicacionId!);
  }

  final data = await query.order('created_at', ascending: false);
  var repuestos = data.map((e) => Repuesto.fromJson(e)).toList();

  // Filtros client-side
  if (filtros.categoria != null) {
    repuestos = repuestos
        .where((r) => r.parteCategoria == filtros.categoria)
        .toList();
  }
  if (filtros.busqueda != null && filtros.busqueda!.isNotEmpty) {
    final term = filtros.busqueda!.toLowerCase();
    repuestos = repuestos.where((r) {
      final nombre = (r.parteNombre ?? '').toLowerCase();
      final vehiculo = (r.vehiculoNombre ?? '').toLowerCase();
      return nombre.contains(term) || vehiculo.contains(term);
    }).toList();
  }

  return repuestos;
});

final ubicacionesInventarioProvider = FutureProvider<List<Ubicacion>>((ref) async {
  final data = await Supabase.instance.client
      .from('ubicaciones')
      .select()
      .eq('activo', true)
      .order('nombre');
  return data.map((e) => Ubicacion.fromJson(e)).toList();
});

class InventarioScreen extends ConsumerWidget {
  const InventarioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inventario = ref.watch(inventarioProvider);
    final filtros = ref.watch(inventarioFiltrosProvider);
    final ubicaciones = ref.watch(ubicacionesInventarioProvider);

    return Scaffold(
      body: Column(
        children: [
          // Barra de búsqueda
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Buscar repuesto por nombre o vehículo...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: filtros.busqueda != null
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => ref
                            .read(inventarioFiltrosProvider.notifier)
                            .update((_) => filtros.copyWith(clearBusqueda: true)),
                      )
                    : null,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => ref
                  .read(inventarioFiltrosProvider.notifier)
                  .update((_) => filtros.copyWith(busqueda: v)),
            ),
          ),

          // Chips de filtro
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                // Filtro estado
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: DropdownButton<String?>(
                    value: filtros.estado,
                    hint: const Text('Estado'),
                    underline: const SizedBox(),
                    isDense: true,
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Todos')),
                      ...['disponible', 'vendido', 'faltante', 'dañado', 'intercambiado', 'descartado']
                          .map((e) => DropdownMenuItem(
                              value: e,
                              child: Text(e[0].toUpperCase() + e.substring(1)))),
                    ],
                    onChanged: (v) => ref
                        .read(inventarioFiltrosProvider.notifier)
                        .update((_) => v == null
                        ? filtros.copyWith(clearEstado: true)
                        : filtros.copyWith(estado: v)),
                  ),
                ),

                // Filtro categoría
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: DropdownButton<String?>(
                    value: filtros.categoria,
                    hint: const Text('Categoría'),
                    underline: const SizedBox(),
                    isDense: true,
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Todas')),
                      ...AppConstants.categorias.map((c) =>
                          DropdownMenuItem(value: c, child: Text(c))),
                    ],
                    onChanged: (v) => ref
                        .read(inventarioFiltrosProvider.notifier)
                        .update((_) => v == null
                        ? filtros.copyWith(clearCategoria: true)
                        : filtros.copyWith(categoria: v)),
                  ),
                ),

                // Filtro ubicación
                ubicaciones.when(
                  data: (list) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: DropdownButton<String?>(
                      value: filtros.ubicacionId,
                      hint: const Text('Ubicación'),
                      underline: const SizedBox(),
                      isDense: true,
                      items: [
                        const DropdownMenuItem(
                            value: null, child: Text('Todas')),
                        ...list.map((u) => DropdownMenuItem(
                            value: u.id, child: Text(u.nombre))),
                      ],
                      onChanged: (v) => ref
                          .read(inventarioFiltrosProvider.notifier)
                          .update((_) => v == null
                          ? filtros.copyWith(clearUbicacion: true)
                          : filtros.copyWith(ubicacionId: v)),
                    ),
                  ),
                  loading: () => const SizedBox(),
                  error: (_, _) => const SizedBox(),
                ),

                // Limpiar filtros
                if (filtros.estado != null ||
                    filtros.categoria != null ||
                    filtros.ubicacionId != null)
                  ActionChip(
                    avatar: const Icon(Icons.clear_all, size: 18),
                    label: const Text('Limpiar'),
                    onPressed: () => ref
                        .read(inventarioFiltrosProvider.notifier)
                        .update((_) => InventarioFiltros()),
                  ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Lista de repuestos
          Expanded(
            child: inventario.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (repuestos) {
                if (repuestos.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.inventory_2_outlined,
                            size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('No se encontraron repuestos',
                            style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () => ref.refresh(inventarioProvider.future),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: repuestos.length,
                    itemBuilder: (context, index) {
                      final r = repuestos[index];
                      return _RepuestoCard(repuesto: r);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _mostrarDialogoIngresoExterno(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Ingreso Externo'),
      ),
    );
  }

  void _mostrarDialogoIngresoExterno(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => const _IngresoExternoDialog(),
    ).then((_) => ref.invalidate(inventarioProvider));
  }
}

class _RepuestoCard extends StatelessWidget {
  final Repuesto repuesto;
  const _RepuestoCard({required this.repuesto});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _colorForEstado(repuesto.estado).withValues(alpha: 0.2),
          child: Icon(
            _iconForEstado(repuesto.estado),
            color: _colorForEstado(repuesto.estado),
          ),
        ),
        title: Text(
          repuesto.parteNombre ?? 'Sin nombre',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (repuesto.vehiculoNombre != null)
              Text('Vehículo: ${repuesto.vehiculoNombre}'),
            Row(
              children: [
                if (repuesto.parteCategoria != null)
                  Text(
                    repuesto.parteCategoria!,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                const SizedBox(width: 8),
                if (repuesto.ubicacionNombre != null)
                  Text(
                    '📍 ${repuesto.ubicacionNombre}',
                    style: const TextStyle(fontSize: 12),
                  ),
              ],
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _colorForEstado(repuesto.estado).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                repuesto.estado.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: _colorForEstado(repuesto.estado),
                ),
              ),
            ),
            if (repuesto.precioSugerido != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '\$${repuesto.precioSugerido!.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _colorForEstado(String estado) {
    switch (estado) {
      case 'disponible':
        return Colors.green;
      case 'vendido':
        return Colors.blue;
      case 'faltante':
        return Colors.red;
      case 'dañado':
        return Colors.orange;
      case 'intercambiado':
        return Colors.purple;
      case 'descartado':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  IconData _iconForEstado(String estado) {
    switch (estado) {
      case 'disponible':
        return Icons.check_circle;
      case 'vendido':
        return Icons.shopping_cart;
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

// Dialog para ingreso externo de repuestos
class _IngresoExternoDialog extends ConsumerStatefulWidget {
  const _IngresoExternoDialog();

  @override
  ConsumerState<_IngresoExternoDialog> createState() =>
      _IngresoExternoDialogState();
}

class _IngresoExternoDialogState
    extends ConsumerState<_IngresoExternoDialog> {
  final _formKey = GlobalKey<FormState>();
  String? _parteId;
  String? _ubicacionId;
  final _proveedorCtrl = TextEditingController();
  final _costoCtrl = TextEditingController();
  final _precioCtrl = TextEditingController();
  final _notasCtrl = TextEditingController();
  bool _saving = false;

  final _partesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
    final data = await Supabase.instance.client
        .from('catalogo_partes')
        .select()
        .eq('activo_por_defecto', true)
        .order('categoria')
        .order('nombre');
    return data;
  });

  @override
  void dispose() {
    _proveedorCtrl.dispose();
    _costoCtrl.dispose();
    _precioCtrl.dispose();
    _notasCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final partes = ref.watch(_partesProvider);
    final ubicaciones = ref.watch(ubicacionesInventarioProvider);

    return AlertDialog(
      title: const Text('Ingreso Externo de Repuesto'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Parte del catálogo
                partes.when(
                  data: (list) => DropdownButtonFormField<String>(
                    initialValue: _parteId,
                    decoration: const InputDecoration(
                      labelText: 'Repuesto *',
                      isDense: true,
                    ),
                    isExpanded: true,
                    items: list
                        .map((p) => DropdownMenuItem(
                              value: p['id'] as String,
                              child: Text(
                                '${p['nombre']} (${p['categoria']})',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _parteId = v),
                    validator: (v) =>
                        v == null ? 'Seleccione repuesto' : null,
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('Error: $e'),
                ),
                const SizedBox(height: 12),

                // Proveedor
                TextFormField(
                  controller: _proveedorCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Proveedor *',
                    isDense: true,
                  ),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Requerido' : null,
                ),
                const SizedBox(height: 12),

                // Costo y Precio sugerido
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _costoCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Costo *',
                          prefixText: '\$ ',
                          isDense: true,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Requerido';
                          if (double.tryParse(v) == null) return 'Inválido';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _precioCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Precio sugerido',
                          prefixText: '\$ ',
                          isDense: true,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Ubicación
                ubicaciones.when(
                  data: (list) => DropdownButtonFormField<String>(
                    initialValue: _ubicacionId,
                    decoration: const InputDecoration(
                      labelText: 'Ubicación',
                      isDense: true,
                    ),
                    items: list
                        .map((u) => DropdownMenuItem(
                            value: u.id, child: Text(u.nombre)))
                        .toList(),
                    onChanged: (v) => setState(() => _ubicacionId = v),
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('Error: $e'),
                ),
                const SizedBox(height: 12),

                // Notas
                TextFormField(
                  controller: _notasCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Notas',
                    isDense: true,
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _guardar,
          child: _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Registrar'),
        ),
      ],
    );
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser!.id;

      // Crear repuesto externo
      final repuesto = await supabase.from('repuestos').insert({
        'catalogo_parte_id': _parteId,
        'estado': 'disponible',
        'ubicacion_id': _ubicacionId,
        'precio_sugerido': _precioCtrl.text.isNotEmpty
            ? double.parse(_precioCtrl.text)
            : null,
        'origen': 'externo',
        'proveedor_externo': _proveedorCtrl.text,
        'costo_externo': double.parse(_costoCtrl.text),
        'notas': _notasCtrl.text.isEmpty ? null : _notasCtrl.text,
      }).select('id').single();

      // Crear movimiento
      await supabase.from('movimientos').insert({
        'repuesto_id': repuesto['id'],
        'tipo': 'ingreso_externo',
        'fecha': DateTime.now().toIso8601String(),
        'usuario_id': userId,
        'ubicacion_destino_id': _ubicacionId,
        'notas': 'Ingreso externo: ${_proveedorCtrl.text}',
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Repuesto externo registrado'),
            backgroundColor: Colors.green,
          ),
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
