import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/models/marca_modelo.dart';
import '../../../data/models/tipo_vehiculo.dart';
import '../../../data/models/ubicacion.dart';
import '../../../data/models/vehiculo.dart';
import '../../../data/models/proveedor.dart';
import '../../../data/models/estado_vehiculo.dart';
import '../../../data/models/perfil.dart';

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

final proveedoresFormProvider = FutureProvider<List<Proveedor>>((ref) async {
  final data = await Supabase.instance.client
      .from('proveedores')
      .select()
      .eq('activo', true)
      .order('nombre');
  return data.map((e) => Proveedor.fromJson(e)).toList();
});

final estadosVehiculoFormProvider =
    FutureProvider<List<EstadoVehiculo>>((ref) async {
  final data = await Supabase.instance.client
      .from('estados_vehiculo')
      .select()
      .eq('activo', true)
      .order('orden');
  return data.map((e) => EstadoVehiculo.fromJson(e)).toList();
});

final vendedoresFormProvider = FutureProvider<List<Perfil>>((ref) async {
  final data = await Supabase.instance.client
      .from('perfiles')
      .select()
      .eq('activo', true)
      .order('nombre');
  return data.map((e) => Perfil.fromJson(e)).toList();
});

final campoConfigVehiculoProvider =
    FutureProvider<Map<String, bool>>((ref) async {
  final data = await Supabase.instance.client
      .from('campo_configuracion')
      .select()
      .eq('tabla', 'vehiculos')
      .eq('activo', true);
  final map = <String, bool>{};
  for (final row in data) {
    map[row['nombre_campo'] as String] = row['obligatorio'] as bool? ?? false;
  }
  return map;
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
  String? _proveedorId;
  String? _compradorId;
  final _anioCtrl = TextEditingController();
  final _colorCtrl = TextEditingController();
  final _vinCtrl = TextEditingController();
  final _placaCtrl = TextEditingController();
  final _costoCtrl = TextEditingController();
  final _valorGruaCtrl = TextEditingController();
  final _comisionViajeCtrl = TextEditingController();
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
    _valorGruaCtrl.dispose();
    _comisionViajeCtrl.dispose();
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
    _proveedorId = v.proveedorId;
    _compradorId = v.compradorId;
    _anioCtrl.text = v.anio.toString();
    _colorCtrl.text = v.color ?? '';
    _vinCtrl.text = v.vin ?? '';
    _placaCtrl.text = v.placa ?? '';
    _costoCtrl.text = v.costoCompra.toStringAsFixed(2);
    _valorGruaCtrl.text = v.valorGrua?.toStringAsFixed(2) ?? '';
    _comisionViajeCtrl.text = v.comisionViaje?.toStringAsFixed(2) ?? '';
    _notasCtrl.text = v.notas ?? '';
    _estado = v.estado;
  }

  @override
  Widget build(BuildContext context) {
    final marcas = ref.watch(marcasProvider);
    final tipos = ref.watch(tiposVehiculoProvider);
    final ubicaciones = ref.watch(ubicacionesProvider);
    final proveedores = ref.watch(proveedoresFormProvider);
    final estadosVehiculo = ref.watch(estadosVehiculoFormProvider);
    final vendedores = ref.watch(vendedoresFormProvider);
    final campoConfig = ref.watch(campoConfigVehiculoProvider);
    final reqFields = campoConfig.value ?? <String, bool>{};

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

                  // Costo de Compra
                  TextFormField(
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
                  const SizedBox(height: 12),

                  // Proveedor (dropdown)
                  proveedores.when(
                    data: (list) => DropdownButtonFormField<String>(
                      initialValue: _proveedorId,
                      decoration: InputDecoration(
                        labelText: reqFields['proveedor_id'] == true
                            ? 'Proveedor *'
                            : 'Proveedor',
                        prefixIcon: const Icon(Icons.local_shipping),
                      ),
                      items: list
                          .map((p) => DropdownMenuItem(
                              value: p.id, child: Text(p.nombre)))
                          .toList(),
                      onChanged: (v) => setState(() => _proveedorId = v),
                      validator: reqFields['proveedor_id'] == true
                          ? (v) => v == null ? 'Seleccione proveedor' : null
                          : null,
                    ),
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('Error: $e'),
                  ),
                  const SizedBox(height: 12),

                  // Valor Grúa y Comisión de Viaje
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _valorGruaCtrl,
                          decoration: InputDecoration(
                            labelText: reqFields['valor_grua'] == true
                                ? 'Valor Grúa *'
                                : 'Valor Grúa',
                            prefixIcon: const Icon(Icons.fire_truck),
                            prefixText: '\$ ',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          validator: reqFields['valor_grua'] == true
                              ? (v) {
                                  if (v == null || v.isEmpty) return 'Requerido';
                                  if (double.tryParse(v) == null) return 'Inválido';
                                  return null;
                                }
                              : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _comisionViajeCtrl,
                          decoration: InputDecoration(
                            labelText: reqFields['comision_viaje'] == true
                                ? 'Comisión Viaje *'
                                : 'Comisión Viaje',
                            prefixIcon: const Icon(Icons.flight),
                            prefixText: '\$ ',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          validator: reqFields['comision_viaje'] == true
                              ? (v) {
                                  if (v == null || v.isEmpty) return 'Requerido';
                                  if (double.tryParse(v) == null) return 'Inválido';
                                  return null;
                                }
                              : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Comprador (vendedores/personal)
                  vendedores.when(
                    data: (list) => DropdownButtonFormField<String>(
                      initialValue: _compradorId,
                      decoration: InputDecoration(
                        labelText: reqFields['comprador_id'] == true
                            ? 'Comprador *'
                            : 'Comprador',
                        prefixIcon: const Icon(Icons.person_outline),
                      ),
                      items: list
                          .map((p) => DropdownMenuItem(
                              value: p.id, child: Text(p.nombre)))
                          .toList(),
                      onChanged: (v) => setState(() => _compradorId = v),
                      validator: reqFields['comprador_id'] == true
                          ? (v) => v == null ? 'Seleccione comprador' : null
                          : null,
                    ),
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('Error: $e'),
                  ),
                  const SizedBox(height: 12),

                  // Estado (dinámico desde DB)
                  estadosVehiculo.when(
                    data: (list) => DropdownButtonFormField<String>(
                      initialValue: list.any((e) => e.valor == _estado) ? _estado : null,
                      decoration: const InputDecoration(
                        labelText: 'Estado del Vehículo *',
                        prefixIcon: Icon(Icons.info_outline),
                      ),
                      items: list
                          .map((e) => DropdownMenuItem(
                              value: e.valor, child: Text(e.nombre)))
                          .toList(),
                      onChanged: (v) => setState(() => _estado = v!),
                      validator: (v) =>
                          v == null ? 'Seleccione estado' : null,
                    ),
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('Error: $e'),
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
      final auth = ref.read(authProvider);
      final userId = auth.perfil!.id;

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
        'proveedor_id': _proveedorId,
        'valor_grua': _valorGruaCtrl.text.isNotEmpty
            ? double.parse(_valorGruaCtrl.text)
            : null,
        'comision_viaje': _comisionViajeCtrl.text.isNotEmpty
            ? double.parse(_comisionViajeCtrl.text)
            : null,
        'comprador_id': _compradorId,
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
