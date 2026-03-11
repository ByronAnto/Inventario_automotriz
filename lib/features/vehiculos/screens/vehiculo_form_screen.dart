import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/models/marca_modelo.dart';
import '../../../data/models/tipo_vehiculo.dart';
import '../../../data/models/ubicacion.dart';
import '../../../data/models/vehiculo.dart';

// Providers
final marcasProvider = FutureProvider<List<Marca>>((ref) async {
  final data = await Supabase.instance.client
      .from('marcas')
      .select()
      .eq('activo', true)
      .order('nombre');
  return data.map((e) => Marca.fromJson(e)).toList();
});

final modelosPorMarcaProvider =
    FutureProvider.family<List<Modelo>, String>((ref, marcaId) async {
  final data = await Supabase.instance.client
      .from('modelos')
      .select()
      .eq('marca_id', marcaId)
      .eq('activo', true)
      .order('nombre');
  return data.map((e) => Modelo.fromJson(e)).toList();
});

final tiposVehiculoProvider = FutureProvider<List<TipoVehiculo>>((ref) async {
  final data = await Supabase.instance.client
      .from('tipos_vehiculo')
      .select()
      .eq('activo', true)
      .order('nombre');
  return data.map((e) => TipoVehiculo.fromJson(e)).toList();
});

final ubicacionesProvider = FutureProvider<List<Ubicacion>>((ref) async {
  final data = await Supabase.instance.client
      .from('ubicaciones')
      .select()
      .eq('activo', true)
      .order('nombre');
  return data.map((e) => Ubicacion.fromJson(e)).toList();
});

final vehiculoDetalleProvider =
    FutureProvider.family<Vehiculo?, String?>((ref, id) async {
  if (id == null) return null;
  final data = await Supabase.instance.client
      .from('vehiculos')
      .select('*, marcas(*), modelos(*), tipos_vehiculo(*), ubicaciones(*)')
      .eq('id', id)
      .single();
  return Vehiculo.fromJson(data);
});

class VehiculoFormScreen extends ConsumerStatefulWidget {
  final String? vehiculoId;
  const VehiculoFormScreen({super.key, this.vehiculoId});

  @override
  ConsumerState<VehiculoFormScreen> createState() => _VehiculoFormScreenState();
}

class _VehiculoFormScreenState extends ConsumerState<VehiculoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;
  bool _loaded = false;

  String? _marcaId;
  String? _modeloId;
  String? _tipoVehiculoId;
  String? _ubicacionId;
  final _anioCtrl = TextEditingController();
  final _colorCtrl = TextEditingController();
  final _vinCtrl = TextEditingController();
  final _placaCtrl = TextEditingController();
  final _costoCtrl = TextEditingController();
  final _proveedorCtrl = TextEditingController();
  final _notasCtrl = TextEditingController();
  String _estado = 'incompleto';

  bool get isEditing => widget.vehiculoId != null;

  @override
  void dispose() {
    _anioCtrl.dispose();
    _colorCtrl.dispose();
    _vinCtrl.dispose();
    _placaCtrl.dispose();
    _costoCtrl.dispose();
    _proveedorCtrl.dispose();
    _notasCtrl.dispose();
    super.dispose();
  }

  void _loadVehiculo(Vehiculo v) {
    if (_loaded) return;
    _loaded = true;
    _marcaId = v.marcaId;
    _modeloId = v.modeloId;
    _tipoVehiculoId = v.tipoVehiculoId;
    _ubicacionId = v.ubicacionId;
    _anioCtrl.text = v.anio.toString();
    _colorCtrl.text = v.color ?? '';
    _vinCtrl.text = v.vin ?? '';
    _placaCtrl.text = v.placa ?? '';
    _costoCtrl.text = v.costoCompra.toStringAsFixed(2);
    _proveedorCtrl.text = v.proveedor ?? '';
    _notasCtrl.text = v.notas ?? '';
    _estado = v.estado;
  }

  @override
  Widget build(BuildContext context) {
    final marcas = ref.watch(marcasProvider);
    final tipos = ref.watch(tiposVehiculoProvider);
    final ubicaciones = ref.watch(ubicacionesProvider);

    if (isEditing) {
      final vehiculo = ref.watch(vehiculoDetalleProvider(widget.vehiculoId));
      vehiculo.whenData((v) {
        if (v != null) _loadVehiculo(v);
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Editar Vehículo' : 'Registrar Vehículo'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/vehiculos'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // --- Sección: Identificación ---
                  _SectionTitle('Identificación del Vehículo'),
                  const SizedBox(height: 12),

                  // Marca
                  marcas.when(
                    data: (list) => DropdownButtonFormField<String>(
                      initialValue: _marcaId,
                      decoration: const InputDecoration(
                        labelText: 'Marca *',
                        prefixIcon: Icon(Icons.branding_watermark),
                      ),
                      items: list
                          .map((m) => DropdownMenuItem(
                              value: m.id, child: Text(m.nombre)))
                          .toList(),
                      onChanged: (v) => setState(() {
                        _marcaId = v;
                        _modeloId = null;
                      }),
                      validator: (v) => v == null ? 'Seleccione marca' : null,
                    ),
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('Error: $e'),
                  ),
                  const SizedBox(height: 12),

                  // Modelo (dependiente de marca)
                  if (_marcaId != null)
                    ref.watch(modelosPorMarcaProvider(_marcaId!)).when(
                          data: (list) => DropdownButtonFormField<String>(
                            initialValue: _modeloId,
                            decoration: const InputDecoration(
                              labelText: 'Modelo *',
                              prefixIcon: Icon(Icons.directions_car),
                            ),
                            items: list
                                .map((m) => DropdownMenuItem(
                                    value: m.id, child: Text(m.nombre)))
                                .toList(),
                            onChanged: (v) => setState(() => _modeloId = v),
                            validator: (v) =>
                                v == null ? 'Seleccione modelo' : null,
                          ),
                          loading: () => const LinearProgressIndicator(),
                          error: (e, _) => Text('Error: $e'),
                        ),
                  if (_marcaId != null) const SizedBox(height: 12),

                  // Tipo de vehículo
                  tipos.when(
                    data: (list) => DropdownButtonFormField<String>(
                      initialValue: _tipoVehiculoId,
                      decoration: const InputDecoration(
                        labelText: 'Tipo de Vehículo *',
                        prefixIcon: Icon(Icons.category),
                      ),
                      items: list
                          .map((t) => DropdownMenuItem(
                              value: t.id, child: Text(t.nombre)))
                          .toList(),
                      onChanged: (v) => setState(() => _tipoVehiculoId = v),
                      validator: (v) =>
                          v == null ? 'Seleccione tipo' : null,
                    ),
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('Error: $e'),
                  ),
                  const SizedBox(height: 12),

                  // Año y Color en fila
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _anioCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Año *',
                            prefixIcon: Icon(Icons.calendar_today),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Requerido';
                            final n = int.tryParse(v);
                            if (n == null || n < 1950 || n > 2030) {
                              return 'Año inválido';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _colorCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Color',
                            prefixIcon: Icon(Icons.palette),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // VIN y Placa
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _vinCtrl,
                          decoration: const InputDecoration(
                            labelText: 'VIN / Chasis',
                            prefixIcon: Icon(Icons.pin),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _placaCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Placa',
                            prefixIcon: Icon(Icons.confirmation_number),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                  _SectionTitle('Información de Compra'),
                  const SizedBox(height: 12),

                  // Costo y Proveedor
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _costoCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Costo de Compra *',
                            prefixIcon: Icon(Icons.attach_money),
                            prefixText: '\$ ',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Requerido';
                            if (double.tryParse(v) == null) return 'Monto inválido';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _proveedorCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Proveedor / Vendedor',
                            prefixIcon: Icon(Icons.person),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Estado
                  DropdownButtonFormField<String>(
                    initialValue: _estado,
                    decoration: const InputDecoration(
                      labelText: 'Estado del Vehículo *',
                      prefixIcon: Icon(Icons.info_outline),
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: 'siniestrado', child: Text('Siniestrado')),
                      DropdownMenuItem(
                          value: 'dado_de_baja', child: Text('Dado de baja')),
                      DropdownMenuItem(
                          value: 'incompleto', child: Text('Incompleto')),
                    ],
                    onChanged: (v) => setState(() => _estado = v!),
                  ),
                  const SizedBox(height: 12),

                  // Ubicación
                  ubicaciones.when(
                    data: (list) => DropdownButtonFormField<String>(
                      initialValue: _ubicacionId,
                      decoration: const InputDecoration(
                        labelText: 'Ubicación',
                        prefixIcon: Icon(Icons.location_on),
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
                      labelText: 'Notas / Observaciones',
                      prefixIcon: Icon(Icons.notes),
                    ),
                    maxLines: 3,
                  ),

                  const SizedBox(height: 32),

                  // Botón guardar
                  FilledButton.icon(
                    onPressed: _saving ? null : _guardar,
                    icon: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child:
                                CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.save),
                    label: Text(isEditing ? 'Actualizar Vehículo' : 'Registrar Vehículo'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_marcaId == null || _modeloId == null || _tipoVehiculoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Complete todos los campos requeridos')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser!.id;

      final data = {
        'marca_id': _marcaId,
        'modelo_id': _modeloId,
        'tipo_vehiculo_id': _tipoVehiculoId,
        'anio': int.parse(_anioCtrl.text),
        'color': _colorCtrl.text.isEmpty ? null : _colorCtrl.text,
        'vin': _vinCtrl.text.isEmpty ? null : _vinCtrl.text,
        'placa': _placaCtrl.text.isEmpty ? null : _placaCtrl.text,
        'estado': _estado,
        'costo_compra': double.parse(_costoCtrl.text),
        'proveedor':
            _proveedorCtrl.text.isEmpty ? null : _proveedorCtrl.text,
        'fecha_ingreso': DateTime.now().toIso8601String(),
        'notas': _notasCtrl.text.isEmpty ? null : _notasCtrl.text,
        'ubicacion_id': _ubicacionId,
        'registrado_por': userId,
      };

      if (isEditing) {
        await supabase
            .from('vehiculos')
            .update(data)
            .eq('id', widget.vehiculoId!);
      } else {
        await supabase.from('vehiculos').insert(data);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEditing
                ? 'Vehículo actualizado'
                : 'Vehículo registrado exitosamente'),
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

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
    );
  }
}
