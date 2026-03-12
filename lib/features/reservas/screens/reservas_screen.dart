import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/models/reserva.dart';
import '../../../data/models/repuesto.dart';
import '../../inventario/screens/inventario_screen.dart';

// ─── Providers ───────────────────────────────────────────────

class _ReservaEstadoFiltroNotifier extends Notifier<String?> {
  @override
  String? build() => 'activa';
  // ignore: use_setters_to_change_properties
  void set(String? value) => state = value;
}

final _reservaEstadoFiltroProvider =
    NotifierProvider<_ReservaEstadoFiltroNotifier, String?>(
  _ReservaEstadoFiltroNotifier.new,
);

final reservasProvider = FutureProvider<List<Reserva>>((ref) async {
  final client = Supabase.instance.client;

  // Auto-expirar reservas vencidas
  try {
    await client.rpc('expirar_reservas');
  } catch (_) {}

  final filtro = ref.watch(_reservaEstadoFiltroProvider);

  var query = client.from('reservas').select(
    '*, repuestos(*, catalogo_partes(*), vehiculos(*, marcas(*), modelos(*))), perfiles(nombre)',
  );

  if (filtro != null) {
    query = query.eq('estado', filtro);
  }

  final data =
      await query.order('created_at', ascending: false);
  return data.map((e) => Reserva.fromJson(e)).toList();
});

// Provider de repuestos disponibles para reservar
final _repuestosParaReservarProvider =
    FutureProvider<List<Repuesto>>((ref) async {
  final data = await Supabase.instance.client
      .from('repuestos')
      .select(
          '*, catalogo_partes(*), ubicaciones(*), vehiculos(*, marcas(*), modelos(*))')
      .eq('estado', 'disponible')
      .order('created_at', ascending: false);
  return data.map((e) => Repuesto.fromJson(e)).toList();
});

// ─── Screen ──────────────────────────────────────────────────
class ReservasScreen extends ConsumerWidget {
  const ReservasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reservasAsync = ref.watch(reservasProvider);
    final filtroEstado = ref.watch(_reservaEstadoFiltroProvider);
    final auth = ref.watch(authProvider);

    return Scaffold(
      body: Column(
        children: [
          // Stats bar
          _ReservasStatsBar(),

          // Filtros de estado
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                _FiltroChip(
                  label: 'Activas',
                  estado: 'activa',
                  color: Colors.orange,
                  selected: filtroEstado == 'activa',
                  ref: ref,
                ),
                _FiltroChip(
                  label: 'Completadas',
                  estado: 'completada',
                  color: Colors.green,
                  selected: filtroEstado == 'completada',
                  ref: ref,
                ),
                _FiltroChip(
                  label: 'Expiradas',
                  estado: 'expirada',
                  color: Colors.red,
                  selected: filtroEstado == 'expirada',
                  ref: ref,
                ),
                _FiltroChip(
                  label: 'Canceladas',
                  estado: 'cancelada',
                  color: Colors.grey,
                  selected: filtroEstado == 'cancelada',
                  ref: ref,
                ),
                _FiltroChip(
                  label: 'Todas',
                  estado: null,
                  color: Colors.blueGrey,
                  selected: filtroEstado == null,
                  ref: ref,
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Lista
          Expanded(
            child: reservasAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Error: $e'),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () => ref.invalidate(reservasProvider),
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
              data: (reservas) {
                if (reservas.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bookmark_border,
                            size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          filtroEstado != null
                              ? 'No hay reservas ${filtroEstado}s'
                              : 'No hay reservas',
                          style: TextStyle(
                              fontSize: 16, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(reservasProvider),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: reservas.length,
                    itemBuilder: (_, i) => _ReservaCard(
                      reserva: reservas[i],
                      isAdmin: auth.isAdmin,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: (auth.isAdmin || auth.isVendedor)
          ? FloatingActionButton.extended(
              onPressed: () => _mostrarDialogoReserva(context, ref),
              icon: const Icon(Icons.bookmark_add),
              label: const Text('Nueva Reserva'),
            )
          : null,
    );
  }
}

// ─── Stats Bar ───────────────────────────────────────────────
class _ReservasStatsBar extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reservas = ref.watch(reservasProvider);

    return reservas.whenOrNull(
          data: (list) {
            // We always need all reservas for stats, so let's count from what we have
            // This is simplified - ideally we'd have a separate stats provider
            return Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.orange.withValues(alpha: 0.08),
                    Colors.orange.withValues(alpha: 0.03),
                  ],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatItem(Icons.bookmark, '${list.length}', 'Mostradas',
                      Colors.orange),
                ],
              ),
            );
          },
        ) ??
        const SizedBox.shrink();
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatItem(this.icon, this.value, this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(value,
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 18, color: color)),
          ],
        ),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
      ],
    );
  }
}

// ─── Filtro Chip ─────────────────────────────────────────────
class _FiltroChip extends StatelessWidget {
  final String label;
  final String? estado;
  final Color color;
  final bool selected;
  final WidgetRef ref;

  const _FiltroChip({
    required this.label,
    required this.estado,
    required this.color,
    required this.selected,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        selectedColor: color.withValues(alpha: 0.2),
        checkmarkColor: color,
        labelStyle: TextStyle(
          color: selected ? color : Colors.grey[700],
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
        ),
        onSelected: (_) =>
            ref.read(_reservaEstadoFiltroProvider.notifier).set(estado),
      ),
    );
  }
}

// ─── Reserva Card ────────────────────────────────────────────
class _ReservaCard extends ConsumerWidget {
  final Reserva reserva;
  final bool isAdmin;

  const _ReservaCard({required this.reserva, required this.isAdmin});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = reserva;
    final color = _colorForReservaEstado(r.estado);
    final isActive = r.estado == 'activa';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Repuesto + Estado
            Row(
              children: [
                Expanded(
                  child: Text(
                    r.repuestoNombre ?? 'Repuesto',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    r.estado.toUpperCase(),
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: color),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Info del repuesto
            if (r.vehiculoInfo != null && r.vehiculoInfo!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Icon(Icons.directions_car,
                        size: 14, color: Colors.blueGrey),
                    const SizedBox(width: 4),
                    Text(r.vehiculoInfo!,
                        style: const TextStyle(
                            fontSize: 13, color: Colors.blueGrey)),
                  ],
                ),
              ),

            const Divider(height: 16),

            // Cliente info
            Row(
              children: [
                const Icon(Icons.person, size: 16, color: Colors.grey),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(r.clienteNombre,
                      style: const TextStyle(fontWeight: FontWeight.w500)),
                ),
                if (r.clienteTelefono != null) ...[
                  const Icon(Icons.phone, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(r.clienteTelefono!,
                      style:
                          TextStyle(fontSize: 13, color: Colors.grey[600])),
                ],
              ],
            ),
            const SizedBox(height: 8),

            // Abono + Precio
            Row(
              children: [
                const Icon(Icons.attach_money, size: 16, color: Colors.green),
                const SizedBox(width: 4),
                Text(
                  'Abono: \$${r.montoAbono.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                      fontSize: 15),
                ),
                if (r.repuestoPrecio != null) ...[
                  const SizedBox(width: 12),
                  Text(
                    'Precio: \$${r.repuestoPrecio!.toStringAsFixed(2)}',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),

            // Fechas
            Row(
              children: [
                Icon(Icons.calendar_today, size: 14, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(
                  'Reservado: ${_formatDate(r.fechaReserva)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(width: 12),
                Icon(Icons.timer,
                    size: 14,
                    color: isActive && r.diasRestantes <= 2
                        ? Colors.red
                        : Colors.grey[500]),
                const SizedBox(width: 4),
                Text(
                  isActive
                      ? 'Expira: ${_formatDate(r.fechaExpiracion)} (${r.diasRestantes}d)'
                      : 'Expiración: ${_formatDate(r.fechaExpiracion)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isActive && r.diasRestantes <= 2
                        ? Colors.red
                        : Colors.grey[600],
                    fontWeight: isActive && r.diasRestantes <= 2
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),

            // Vendedor + notas
            if (r.vendedorNombre != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Vendedor: ${r.vendedorNombre}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ),

            if (r.notas != null && r.notas!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Nota: ${r.notas}',
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic),
                ),
              ),

            // Actions
            if (isActive) ...[
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _cancelarReserva(context, ref),
                    icon: const Icon(Icons.cancel, size: 18),
                    label: const Text('Cancelar'),
                    style:
                        TextButton.styleFrom(foregroundColor: Colors.red),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _cancelarReserva(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar reserva'),
        content: Text(
          '¿Cancelar la reserva de "${reserva.repuestoNombre}" para ${reserva.clienteNombre}?\n\n'
          'El repuesto volverá a estar disponible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );

    if (ok != true || !context.mounted) return;

    try {
      await Supabase.instance.client.rpc('cancelar_reserva', params: {
        'p_reserva_id': reserva.id,
      });

      ref.invalidate(reservasProvider);
      ref.invalidate(inventarioProvider);
      ref.invalidate(inventarioStatsProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reserva cancelada'),
            backgroundColor: Colors.green,
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

  Color _colorForReservaEstado(String estado) {
    switch (estado) {
      case 'activa':
        return Colors.orange;
      case 'completada':
        return Colors.green;
      case 'expirada':
        return Colors.red;
      case 'cancelada':
        return Colors.grey;
      default:
        return Colors.blueGrey;
    }
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, "0")}/${dt.month.toString().padLeft(2, "0")}/${dt.year}';
  }
}

// ─── Diálogo para crear nueva reserva ────────────────────────
void _mostrarDialogoReserva(BuildContext context, WidgetRef ref) {
  showDialog(
    context: context,
    builder: (_) => const _NuevaReservaDialog(),
  ).then((_) {
    ref.invalidate(reservasProvider);
    ref.invalidate(inventarioProvider);
    ref.invalidate(inventarioStatsProvider);
  });
}

class _NuevaReservaDialog extends ConsumerStatefulWidget {
  const _NuevaReservaDialog();

  @override
  ConsumerState<_NuevaReservaDialog> createState() =>
      _NuevaReservaDialogState();
}

class _NuevaReservaDialogState extends ConsumerState<_NuevaReservaDialog> {
  final _formKey = GlobalKey<FormState>();
  String? _repuestoId;
  final _clienteNombreCtrl = TextEditingController();
  final _clienteTelefonoCtrl = TextEditingController();
  final _montoAbonoCtrl = TextEditingController();
  final _notasCtrl = TextEditingController();
  int _diasExpiracion = 7;
  bool _saving = false;
  String _busqueda = '';

  @override
  void dispose() {
    _clienteNombreCtrl.dispose();
    _clienteTelefonoCtrl.dispose();
    _montoAbonoCtrl.dispose();
    _notasCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repuestosAsync = ref.watch(_repuestosParaReservarProvider);

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.bookmark_add, color: Colors.orange),
          SizedBox(width: 8),
          Text('Nueva Reserva'),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Buscar repuesto
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Buscar repuesto disponible...',
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onChanged: (v) => setState(() => _busqueda = v),
                ),
                const SizedBox(height: 8),

                // Lista de repuestos disponibles
                SizedBox(
                  height: 180,
                  child: repuestosAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Text('Error: $e'),
                    data: (repuestos) {
                      var filtrados = repuestos;
                      if (_busqueda.isNotEmpty) {
                        final term = _busqueda.toLowerCase();
                        filtrados = repuestos.where((r) {
                          final nombre =
                              (r.parteNombre ?? '').toLowerCase();
                          final vehiculo =
                              (r.vehiculoMarca ?? '').toLowerCase();
                          final modelo =
                              (r.vehiculoModelo ?? '').toLowerCase();
                          return nombre.contains(term) ||
                              vehiculo.contains(term) ||
                              modelo.contains(term);
                        }).toList();
                      }

                      if (filtrados.isEmpty) {
                        return const Center(
                            child: Text('No hay repuestos disponibles'));
                      }

                      return ListView.builder(
                        itemCount: filtrados.length,
                        itemBuilder: (_, i) {
                          final r = filtrados[i];
                          final isSelected = _repuestoId == r.id;
                          return ListTile(
                            dense: true,
                            selected: isSelected,
                            selectedTileColor:
                                Colors.orange.withValues(alpha: 0.1),
                            leading: Icon(
                              isSelected
                                  ? Icons.check_circle
                                  : Icons.circle_outlined,
                              color:
                                  isSelected ? Colors.orange : Colors.grey,
                              size: 20,
                            ),
                            title: Text(
                              r.parteNombre ?? 'Sin nombre',
                              style: const TextStyle(fontSize: 13),
                            ),
                            subtitle: Text(
                              [
                                if (r.vehiculoMarca != null)
                                  '${r.vehiculoMarca} ${r.vehiculoModelo ?? ""} ${r.vehiculoAnio ?? ""}',
                                if (r.precioSugerido != null)
                                  '\$${r.precioSugerido!.toStringAsFixed(2)}',
                              ].join(' · '),
                              style: const TextStyle(fontSize: 11),
                            ),
                            onTap: () =>
                                setState(() => _repuestoId = r.id),
                          );
                        },
                      );
                    },
                  ),
                ),

                if (_repuestoId == null)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text('Seleccione un repuesto *',
                        style: TextStyle(color: Colors.red, fontSize: 12)),
                  ),

                const Divider(height: 20),

                // Datos del cliente
                const Text('Datos del cliente',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.grey)),
                const SizedBox(height: 8),

                TextFormField(
                  controller: _clienteNombreCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del cliente *',
                    isDense: true,
                  ),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Requerido' : null,
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _clienteTelefonoCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Teléfono',
                    isDense: true,
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),

                // Monto abono
                const Text('Abono y plazo',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.grey)),
                const SizedBox(height: 8),

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _montoAbonoCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Monto abono *',
                          prefixText: '\$ ',
                          isDense: true,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Requerido';
                          final n = double.tryParse(v);
                          if (n == null || n <= 0) return 'Monto > 0';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: _diasExpiracion,
                        decoration: const InputDecoration(
                          labelText: 'Días de reserva',
                          isDense: true,
                        ),
                        items: [3, 5, 7, 10, 14, 21, 30]
                            .map((d) => DropdownMenuItem(
                                value: d, child: Text('$d días')))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _diasExpiracion = v ?? 7),
                      ),
                    ),
                  ],
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
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Reservar'),
        ),
      ],
    );
  }

  Future<void> _guardar() async {
    if (_repuestoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Seleccione un repuesto'),
            backgroundColor: Colors.red),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      await Supabase.instance.client.rpc('reservar_repuesto', params: {
        'p_repuesto_id': _repuestoId,
        'p_cliente_nombre': _clienteNombreCtrl.text.trim(),
        'p_cliente_telefono': _clienteTelefonoCtrl.text.trim().isEmpty
            ? null
            : _clienteTelefonoCtrl.text.trim(),
        'p_monto_abono': double.parse(_montoAbonoCtrl.text),
        'p_dias_expiracion': _diasExpiracion,
        'p_vendedor_id': Supabase.instance.client.auth.currentUser!.id,
        'p_notas':
            _notasCtrl.text.trim().isEmpty ? null : _notasCtrl.text.trim(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Repuesto reservado exitosamente'),
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
