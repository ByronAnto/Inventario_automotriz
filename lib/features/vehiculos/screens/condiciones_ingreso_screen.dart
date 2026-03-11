import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/models/catalogo_parte.dart';
import '../../../data/models/vehiculo.dart';

// Provider: cargar plantilla de partes según tipo de vehículo
final plantillaPartesProvider =
    FutureProvider.family<List<PlantillaTipoVehiculo>, String>((ref, tipoVehiculoId) async {
  final data = await Supabase.instance.client
      .from('plantilla_tipo_vehiculo')
      .select('*, catalogo_partes(*)')
      .eq('tipo_vehiculo_id', tipoVehiculoId)
      .eq('activo', true)
      .order('catalogo_partes(categoria)', ascending: true);
  return data.map((e) => PlantillaTipoVehiculo.fromJson(e)).toList();
});

// Provider: cargar vehículo individual
final vehiculoParaCondicionesProvider =
    FutureProvider.family<Vehiculo, String>((ref, vehiculoId) async {
  final data = await Supabase.instance.client
      .from('vehiculos')
      .select('*, marcas(*), modelos(*), tipos_vehiculo(*)')
      .eq('id', vehiculoId)
      .single();
  return Vehiculo.fromJson(data);
});

class CondicionesIngresoScreen extends ConsumerStatefulWidget {
  final String vehiculoId;
  const CondicionesIngresoScreen({super.key, required this.vehiculoId});

  @override
  ConsumerState<CondicionesIngresoScreen> createState() =>
      _CondicionesIngresoScreenState();
}

class _CondicionesIngresoScreenState
    extends ConsumerState<CondicionesIngresoScreen> {
  // Mapa: parteId -> estado ('disponible', 'faltante', 'dañado')
  final Map<String, String> _estadoPartes = {};
  // Mapa: parteId -> notas
  final Map<String, String> _notasPartes = {};
  bool _saving = false;
  String? _categoriaFiltro;

  @override
  Widget build(BuildContext context) {
    final vehiculo = ref.watch(vehiculoParaCondicionesProvider(widget.vehiculoId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registro de Condiciones'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/vehiculos'),
        ),
      ),
      body: vehiculo.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (v) => _buildContent(v),
      ),
    );
  }

  Widget _buildContent(Vehiculo vehiculo) {
    final plantilla = ref.watch(plantillaPartesProvider(vehiculo.tipoVehiculoId));

    return plantilla.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error cargando plantilla: $e')),
      data: (partes) {
        // Inicializar todos como disponibles si no se ha tocado
        for (final p in partes) {
          _estadoPartes.putIfAbsent(p.parteId, () => 'disponible');
        }

        // Obtener categorías únicas
        final categorias = partes
            .where((p) => p.parte != null)
            .map((p) => p.parte!.categoria)
            .toSet()
            .toList()
          ..sort();

        // Filtrar por categoría
        final partesFiltradas = _categoriaFiltro != null
            ? partes
                .where((p) => p.parte?.categoria == _categoriaFiltro)
                .toList()
            : partes;

        // Contar estados
        final disponibles = _estadoPartes.values.where((e) => e == 'disponible').length;
        final faltantes = _estadoPartes.values.where((e) => e == 'faltante').length;
        final danados = _estadoPartes.values.where((e) => e == 'dañado').length;

        return Column(
          children: [
            // Header con info del vehículo
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vehiculo.nombreCompleto,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Total partes: ${partes.length} | '
                    'Disponibles: $disponibles | '
                    'Faltantes: $faltantes | '
                    'Dañados: $danados',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),

            // Filtro por categoría
            SizedBox(
              height: 50,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: const Text('Todas'),
                      selected: _categoriaFiltro == null,
                      onSelected: (_) =>
                          setState(() => _categoriaFiltro = null),
                    ),
                  ),
                  ...categorias.map((cat) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: FilterChip(
                          label: Text(cat),
                          selected: _categoriaFiltro == cat,
                          onSelected: (_) =>
                              setState(() => _categoriaFiltro = cat),
                        ),
                      )),
                ],
              ),
            ),

            // Lista de partes
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: partesFiltradas.length,
                itemBuilder: (context, index) {
                  final plantillaParte = partesFiltradas[index];
                  final parte = plantillaParte.parte;
                  if (parte == null) return const SizedBox.shrink();

                  final estado = _estadoPartes[plantillaParte.parteId] ?? 'disponible';

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _iconForEstado(estado),
                                color: _colorForEstado(estado),
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      parte.nombre,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600),
                                    ),
                                    Text(
                                      parte.categoria,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                              // Selector de estado
                              SegmentedButton<String>(
                                segments: const [
                                  ButtonSegment(
                                    value: 'disponible',
                                    icon: Icon(Icons.check_circle, size: 16),
                                    label: Text('OK', style: TextStyle(fontSize: 11)),
                                  ),
                                  ButtonSegment(
                                    value: 'faltante',
                                    icon: Icon(Icons.remove_circle, size: 16),
                                    label: Text('Falta', style: TextStyle(fontSize: 11)),
                                  ),
                                  ButtonSegment(
                                    value: 'dañado',
                                    icon: Icon(Icons.warning, size: 16),
                                    label: Text('Daño', style: TextStyle(fontSize: 11)),
                                  ),
                                ],
                                selected: {estado},
                                onSelectionChanged: (val) {
                                  setState(() {
                                    _estadoPartes[plantillaParte.parteId] =
                                        val.first;
                                  });
                                },
                                style: SegmentedButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                            ],
                          ),
                          // Campo de notas si está dañado o faltante
                          if (estado != 'disponible') ...[
                            const SizedBox(height: 8),
                            TextFormField(
                              initialValue: _notasPartes[plantillaParte.parteId],
                              decoration: InputDecoration(
                                hintText: estado == 'dañado'
                                    ? 'Describe el daño...'
                                    : 'Observaciones...',
                                isDense: true,
                                border: const OutlineInputBorder(),
                              ),
                              maxLines: 1,
                              onChanged: (v) =>
                                  _notasPartes[plantillaParte.parteId] = v,
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Botón guardar
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton.icon(
                  onPressed: _saving ? null : _guardarCondiciones,
                  icon: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.save),
                  label: const Text('Guardar Condiciones y Generar Inventario'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  IconData _iconForEstado(String estado) {
    switch (estado) {
      case 'disponible':
        return Icons.check_circle;
      case 'faltante':
        return Icons.remove_circle;
      case 'dañado':
        return Icons.warning;
      default:
        return Icons.help;
    }
  }

  Color _colorForEstado(String estado) {
    switch (estado) {
      case 'disponible':
        return Colors.green;
      case 'faltante':
        return Colors.red;
      case 'dañado':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Future<void> _guardarCondiciones() async {
    setState(() => _saving = true);

    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser!.id;

      // Obtener vehículo para la ubicación
      final vehiculoData = await supabase
          .from('vehiculos')
          .select('ubicacion_id')
          .eq('id', widget.vehiculoId)
          .single();

      final ubicacionId = vehiculoData['ubicacion_id'] as String?;

      // Crear repuestos según condiciones
      final repuestos = <Map<String, dynamic>>[];
      final movimientos = <Map<String, dynamic>>[];

      for (final entry in _estadoPartes.entries) {
        final parteId = entry.key;
        final estado = entry.value;
        final notas = _notasPartes[parteId];

        repuestos.add({
          'vehiculo_id': widget.vehiculoId,
          'catalogo_parte_id': parteId,
          'estado': estado,
          'ubicacion_id': ubicacionId,
          'origen': 'vehiculo',
          'notas': notas,
        });
      }

      // Insertar repuestos y obtener IDs
      final insertedRepuestos = await supabase
          .from('repuestos')
          .insert(repuestos)
          .select('id');

      // Crear movimientos de ingreso para cada repuesto
      for (final rep in insertedRepuestos) {
        movimientos.add({
          'repuesto_id': rep['id'],
          'tipo': 'ingreso_vehiculo',
          'fecha': DateTime.now().toIso8601String(),
          'usuario_id': userId,
          'ubicacion_destino_id': ubicacionId,
          'notas': 'Ingreso automático por registro de condiciones',
        });
      }

      if (movimientos.isNotEmpty) {
        await supabase.from('movimientos').insert(movimientos);
      }

      // Marcar vehículo como condiciones registradas
      await supabase.from('vehiculos').update({
        'condiciones_registradas': true,
      }).eq('id', widget.vehiculoId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Condiciones registradas: ${_estadoPartes.length} partes procesadas',
            ),
            backgroundColor: Colors.green,
          ),
        );
        context.go('/vehiculos');
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
