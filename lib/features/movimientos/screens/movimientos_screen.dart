import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/models/movimiento.dart';
import '../../../data/models/repuesto.dart';
import '../../../data/models/ubicacion.dart';
import '../../../data/providers/auth_provider.dart';

// Provider de movimientos
final movimientosProvider = FutureProvider<List<Movimiento>>((ref) async {
  final data = await Supabase.instance.client
      .from('movimientos')
      .select(
        '*, perfiles(*), repuestos(*, catalogo_partes(*))',
      )
      .order('fecha', ascending: false)
      .limit(200);
  return data.map((e) => Movimiento.fromJson(e)).toList();
});

// Provider de ubicaciones
final _ubicacionesMovProvider = FutureProvider<List<Ubicacion>>((ref) async {
  final data = await Supabase.instance.client
      .from('ubicaciones')
      .select()
      .eq('activo', true)
      .order('nombre');
  return data.map((e) => Ubicacion.fromJson(e)).toList();
});

class MovimientosScreen extends ConsumerWidget {
  const MovimientosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final movimientos = ref.watch(movimientosProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        body: Column(
          children: [
            const TabBar(
              tabs: [
                Tab(text: 'Historial', icon: Icon(Icons.history)),
                Tab(text: 'Acciones', icon: Icon(Icons.swap_horiz)),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  // Tab 1: Historial
                  _HistorialTab(movimientos: movimientos, ref: ref),
                  // Tab 2: Acciones
                  _AccionesTab(ref: ref),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistorialTab extends StatelessWidget {
  final AsyncValue<List<Movimiento>> movimientos;
  final WidgetRef ref;

  const _HistorialTab({required this.movimientos, required this.ref});

  @override
  Widget build(BuildContext context) {
    return movimientos.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (list) {
        if (list.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.swap_horiz, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No hay movimientos registrados',
                    style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => ref.refresh(movimientosProvider.future),
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: list.length,
            itemBuilder: (context, index) {
              final mov = list[index];
              return _MovimientoCard(movimiento: mov);
            },
          ),
        );
      },
    );
  }
}

class _MovimientoCard extends StatelessWidget {
  final Movimiento movimiento;
  const _MovimientoCard({required this.movimiento});

  @override
  Widget build(BuildContext context) {
    final fecha =
        '${movimiento.fecha.day}/${movimiento.fecha.month}/${movimiento.fecha.year}';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _colorForTipo(movimiento.tipo).withValues(alpha: 0.15),
          child: Icon(
            _iconForTipo(movimiento.tipo),
            color: _colorForTipo(movimiento.tipo),
            size: 20,
          ),
        ),
        title: Text(
          movimiento.repuestoNombre ?? 'Repuesto',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_labelForTipo(movimiento.tipo)),
            Text(
              '$fecha  •  ${movimiento.usuarioNombre ?? ''}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            if (movimiento.notas != null && movimiento.notas!.isNotEmpty)
              Text(
                movimiento.notas!,
                style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        trailing: Icon(
          _iconForTipo(movimiento.tipo),
          color: _colorForTipo(movimiento.tipo),
          size: 16,
        ),
      ),
    );
  }

  String _labelForTipo(String tipo) {
    switch (tipo) {
      case 'ingreso_vehiculo':
        return 'Ingreso por vehículo';
      case 'ingreso_externo':
        return 'Ingreso externo';
      case 'venta':
        return 'Venta';
      case 'intercambio':
        return 'Intercambio';
      case 'traslado':
        return 'Traslado';
      case 'descarte':
        return 'Descarte';
      default:
        return tipo;
    }
  }

  IconData _iconForTipo(String tipo) {
    switch (tipo) {
      case 'ingreso_vehiculo':
        return Icons.directions_car;
      case 'ingreso_externo':
        return Icons.add_box;
      case 'venta':
        return Icons.shopping_cart;
      case 'intercambio':
        return Icons.swap_horiz;
      case 'traslado':
        return Icons.local_shipping;
      case 'descarte':
        return Icons.delete;
      default:
        return Icons.help;
    }
  }

  Color _colorForTipo(String tipo) {
    switch (tipo) {
      case 'ingreso_vehiculo':
        return Colors.blue;
      case 'ingreso_externo':
        return Colors.teal;
      case 'venta':
        return Colors.green;
      case 'intercambio':
        return Colors.purple;
      case 'traslado':
        return Colors.orange;
      case 'descarte':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

class _AccionesTab extends StatelessWidget {
  final WidgetRef ref;
  const _AccionesTab({required this.ref});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _AccionCard(
                icon: Icons.local_shipping,
                title: 'Trasladar Repuesto',
                description: 'Mover un repuesto de una ubicación a otra',
                color: Colors.orange,
                onTap: () => _showTrasladoDialog(context),
              ),
              const SizedBox(height: 12),
              _AccionCard(
                icon: Icons.swap_horiz,
                title: 'Registrar Intercambio',
                description: 'Intercambiar un repuesto por otro',
                color: Colors.purple,
                onTap: () => _showIntercambioDialog(context),
              ),
              const SizedBox(height: 12),
              _AccionCard(
                icon: Icons.delete_outline,
                title: 'Descartar Repuesto',
                description: 'Marcar un repuesto como descartado',
                color: Colors.red,
                onTap: () => _showDescarteDialog(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTrasladoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _TrasladoDialog(ref: ref),
    ).then((_) => ref.invalidate(movimientosProvider));
  }

  void _showIntercambioDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _IntercambioDialog(ref: ref),
    ).then((_) => ref.invalidate(movimientosProvider));
  }

  void _showDescarteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _DescarteDialog(ref: ref),
    ).then((_) => ref.invalidate(movimientosProvider));
  }
}

class _AccionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final VoidCallback onTap;

  const _AccionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(description),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}

// --- Diálogo: Traslado ---
class _TrasladoDialog extends ConsumerStatefulWidget {
  final WidgetRef ref;
  const _TrasladoDialog({required this.ref});

  @override
  ConsumerState<_TrasladoDialog> createState() => _TrasladoDialogState();
}

class _TrasladoDialogState extends ConsumerState<_TrasladoDialog> {
  String? _repuestoId;
  String? _repuestoNombre;
  String? _ubicacionDestinoId;
  final _notasCtrl = TextEditingController();
  bool _saving = false;

  List<Repuesto> _repuestos = [];
  String _busqueda = '';

  @override
  void initState() {
    super.initState();
    _cargarRepuestos();
  }

  Future<void> _cargarRepuestos() async {
    final data = await Supabase.instance.client
        .from('repuestos')
        .select('*, catalogo_partes(*), ubicaciones(*)')
        .eq('estado', 'disponible');
    setState(() {
      _repuestos = data.map((e) => Repuesto.fromJson(e)).toList();
    });
  }

  @override
  void dispose() {
    _notasCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ubicaciones = ref.watch(_ubicacionesMovProvider);

    final filtered = _busqueda.isEmpty
        ? _repuestos
        : _repuestos.where((r) {
            final nombre = (r.parteNombre ?? '').toLowerCase();
            return nombre.contains(_busqueda.toLowerCase());
          }).toList();

    return AlertDialog(
      title: const Text('Trasladar Repuesto'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Buscar repuesto
            TextField(
              decoration: const InputDecoration(
                hintText: 'Buscar repuesto...',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _busqueda = v),
            ),
            const SizedBox(height: 8),

            if (_repuestoId != null)
              Chip(
                label: Text(_repuestoNombre ?? ''),
                onDeleted: () => setState(() {
                  _repuestoId = null;
                  _repuestoNombre = null;
                }),
              )
            else
              SizedBox(
                height: 150,
                child: ListView.builder(
                  itemCount: filtered.length > 20 ? 20 : filtered.length,
                  itemBuilder: (context, index) {
                    final r = filtered[index];
                    return ListTile(
                      dense: true,
                      title: Text(r.parteNombre ?? 'Sin nombre'),
                      subtitle: Text(r.ubicacionNombre ?? 'Sin ubicación'),
                      onTap: () => setState(() {
                        _repuestoId = r.id;
                        _repuestoNombre = r.parteNombre;
                      }),
                    );
                  },
                ),
              ),

            const SizedBox(height: 12),

            // Ubicación destino
            ubicaciones.when(
              data: (list) => DropdownButtonFormField<String>(
                initialValue: _ubicacionDestinoId,
                decoration: const InputDecoration(
                  labelText: 'Ubicación destino *',
                  isDense: true,
                ),
                items: list
                    .map((u) =>
                        DropdownMenuItem(value: u.id, child: Text(u.nombre)))
                    .toList(),
                onChanged: (v) => setState(() => _ubicacionDestinoId = v),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Error: $e'),
            ),

            const SizedBox(height: 12),
            TextFormField(
              controller: _notasCtrl,
              decoration: const InputDecoration(
                labelText: 'Notas',
                isDense: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ||
                  _repuestoId == null ||
                  _ubicacionDestinoId == null
              ? null
              : _ejecutarTraslado,
          child: _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Trasladar'),
        ),
      ],
    );
  }

  Future<void> _ejecutarTraslado() async {
    setState(() => _saving = true);
    try {
      final supabase = Supabase.instance.client;

      final perfilId = ref.read(authProvider).perfil!.id;
      await supabase.rpc('trasladar_repuestos', params: {
        'p_repuesto_ids': [_repuestoId],
        'p_ubicacion_destino_id': _ubicacionDestinoId,
        'p_usuario_id': perfilId,
        'p_notas': _notasCtrl.text.isEmpty ? null : _notasCtrl.text,
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Repuesto trasladado'),
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

// --- Diálogo: Intercambio ---
class _IntercambioDialog extends ConsumerStatefulWidget {
  final WidgetRef ref;
  const _IntercambioDialog({required this.ref});

  @override
  ConsumerState<_IntercambioDialog> createState() => _IntercambioDialogState();
}

class _IntercambioDialogState extends ConsumerState<_IntercambioDialog> {
  String? _repuestoSaleId;
  String? _repuestoSaleNombre;
  final _notasCtrl = TextEditingController();

  // Datos del repuesto que entra
  String? _parteEntradaId;
  String? _ubicacionEntradaId;
  final _proveedorCtrl = TextEditingController();
  final _costoCtrl = TextEditingController();

  bool _saving = false;
  List<Repuesto> _repuestos = [];

  @override
  void initState() {
    super.initState();
    _cargarRepuestos();
  }

  Future<void> _cargarRepuestos() async {
    final data = await Supabase.instance.client
        .from('repuestos')
        .select('*, catalogo_partes(*)')
        .eq('estado', 'disponible');
    setState(() {
      _repuestos = data.map((e) => Repuesto.fromJson(e)).toList();
    });
  }

  @override
  void dispose() {
    _notasCtrl.dispose();
    _proveedorCtrl.dispose();
    _costoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ubicaciones = ref.watch(_ubicacionesMovProvider);

    return AlertDialog(
      title: const Text('Registrar Intercambio'),
      content: SizedBox(
        width: 450,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Repuesto que SALE:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (_repuestoSaleId != null)
                Chip(
                  label: Text(_repuestoSaleNombre ?? ''),
                  onDeleted: () => setState(() {
                    _repuestoSaleId = null;
                    _repuestoSaleNombre = null;
                  }),
                )
              else
                SizedBox(
                  height: 120,
                  child: ListView.builder(
                    itemCount:
                        _repuestos.length > 15 ? 15 : _repuestos.length,
                    itemBuilder: (context, index) {
                      final r = _repuestos[index];
                      return ListTile(
                        dense: true,
                        title: Text(r.parteNombre ?? 'Sin nombre'),
                        onTap: () => setState(() {
                          _repuestoSaleId = r.id;
                          _repuestoSaleNombre = r.parteNombre;
                        }),
                      );
                    },
                  ),
                ),

              const Divider(),
              const Text('Repuesto que ENTRA (nuevo):',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),

              // Parte del catálogo para entrada
              FutureBuilder<List<Map<String, dynamic>>>(
                future: Supabase.instance.client
                    .from('catalogo_partes')
                    .select()
                    .eq('activo_por_defecto', true)
                    .order('nombre'),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const LinearProgressIndicator();
                  return DropdownButtonFormField<String>(
                    initialValue: _parteEntradaId,
                    decoration: const InputDecoration(
                      labelText: 'Tipo de repuesto *',
                      isDense: true,
                    ),
                    isExpanded: true,
                    items: snapshot.data!
                        .map((p) => DropdownMenuItem(
                              value: p['id'] as String,
                              child: Text(
                                '${p['nombre']}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _parteEntradaId = v),
                  );
                },
              ),
              const SizedBox(height: 8),

              TextFormField(
                controller: _proveedorCtrl,
                decoration: const InputDecoration(
                  labelText: 'Proveedor del intercambio',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),

              TextFormField(
                controller: _costoCtrl,
                decoration: const InputDecoration(
                  labelText: 'Costo adicional',
                  prefixText: '\$ ',
                  isDense: true,
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 8),

              ubicaciones.when(
                data: (list) => DropdownButtonFormField<String>(
                  initialValue: _ubicacionEntradaId,
                  decoration: const InputDecoration(
                    labelText: 'Ubicación del nuevo repuesto',
                    isDense: true,
                  ),
                  items: list
                      .map((u) =>
                          DropdownMenuItem(value: u.id, child: Text(u.nombre)))
                      .toList(),
                  onChanged: (v) => setState(() => _ubicacionEntradaId = v),
                ),
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Error: $e'),
              ),

              const SizedBox(height: 8),
              TextFormField(
                controller: _notasCtrl,
                decoration: const InputDecoration(
                  labelText: 'Notas del intercambio',
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ||
                  _repuestoSaleId == null ||
                  _parteEntradaId == null
              ? null
              : _ejecutar,
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

  Future<void> _ejecutar() async {
    setState(() => _saving = true);
    try {
      final supabase = Supabase.instance.client;
      final auth = ref.read(authProvider);
      final userId = auth.perfil!.id;

      // 1. Actualizar repuesto que sale → "intercambiado"
      await supabase
          .from('repuestos')
          .update({'estado': 'intercambiado'}).eq('id', _repuestoSaleId!);

      // 2. Crear repuesto que entra
      final nuevoRepuesto = await supabase.from('repuestos').insert({
        'catalogo_parte_id': _parteEntradaId,
        'estado': 'disponible',
        'ubicacion_id': _ubicacionEntradaId,
        'origen': 'externo',
        'proveedor_externo': _proveedorCtrl.text.isEmpty
            ? 'Intercambio'
            : _proveedorCtrl.text,
        'costo_externo':
            _costoCtrl.text.isNotEmpty ? double.parse(_costoCtrl.text) : 0,
        'notas': 'Ingresado por intercambio',
      }).select('id').single();

      // 3. Movimiento de salida
      final movSalida = await supabase.from('movimientos').insert({
        'repuesto_id': _repuestoSaleId,
        'tipo': 'intercambio',
        'fecha': DateTime.now().toIso8601String(),
        'usuario_id': userId,
        'notas': 'Sale por intercambio',
      }).select('id').single();

      // 4. Movimiento de entrada
      final movEntrada = await supabase.from('movimientos').insert({
        'repuesto_id': nuevoRepuesto['id'],
        'tipo': 'intercambio',
        'fecha': DateTime.now().toIso8601String(),
        'usuario_id': userId,
        'ubicacion_destino_id': _ubicacionEntradaId,
        'notas': 'Entra por intercambio',
      }).select('id').single();

      // 5. Crear registro de intercambio
      await supabase.from('intercambios').insert({
        'movimiento_salida_id': movSalida['id'],
        'movimiento_entrada_id': movEntrada['id'],
        'notas': _notasCtrl.text.isEmpty ? null : _notasCtrl.text,
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Intercambio registrado'),
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

// --- Diálogo: Descarte ---
class _DescarteDialog extends ConsumerStatefulWidget {
  final WidgetRef ref;
  const _DescarteDialog({required this.ref});

  @override
  ConsumerState<_DescarteDialog> createState() => _DescarteDialogState();
}

class _DescarteDialogState extends ConsumerState<_DescarteDialog> {
  String? _repuestoId;
  String? _repuestoNombre;
  final _motivoCtrl = TextEditingController();
  bool _saving = false;
  List<Repuesto> _repuestos = [];

  @override
  void initState() {
    super.initState();
    _cargarRepuestos();
  }

  Future<void> _cargarRepuestos() async {
    final data = await Supabase.instance.client
        .from('repuestos')
        .select('*, catalogo_partes(*)')
        .inFilter('estado', ['disponible', 'dañado']);
    setState(() {
      _repuestos = data.map((e) => Repuesto.fromJson(e)).toList();
    });
  }

  @override
  void dispose() {
    _motivoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Descartar Repuesto'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_repuestoId != null)
              Chip(
                label: Text(_repuestoNombre ?? ''),
                onDeleted: () => setState(() {
                  _repuestoId = null;
                  _repuestoNombre = null;
                }),
              )
            else
              SizedBox(
                height: 150,
                child: ListView.builder(
                  itemCount:
                      _repuestos.length > 20 ? 20 : _repuestos.length,
                  itemBuilder: (context, index) {
                    final r = _repuestos[index];
                    return ListTile(
                      dense: true,
                      title: Text(r.parteNombre ?? 'Sin nombre'),
                      subtitle: Text('Estado: ${r.estado}'),
                      onTap: () => setState(() {
                        _repuestoId = r.id;
                        _repuestoNombre = r.parteNombre;
                      }),
                    );
                  },
                ),
              ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _motivoCtrl,
              decoration: const InputDecoration(
                labelText: 'Motivo del descarte *',
                isDense: true,
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving || _repuestoId == null ? null : _ejecutar,
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          child: _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Descartar'),
        ),
      ],
    );
  }

  Future<void> _ejecutar() async {
    if (_motivoCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingrese motivo del descarte')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final supabase = Supabase.instance.client;
      final auth = ref.read(authProvider);

      await supabase
          .from('repuestos')
          .update({'estado': 'descartado'}).eq('id', _repuestoId!);

      await supabase.from('movimientos').insert({
        'repuesto_id': _repuestoId,
        'tipo': 'descarte',
        'fecha': DateTime.now().toIso8601String(),
        'usuario_id': auth.perfil!.id,
        'notas': _motivoCtrl.text,
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Repuesto descartado'),
            backgroundColor: Colors.orange,
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
