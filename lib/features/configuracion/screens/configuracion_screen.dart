import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/supabase_config.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/models/catalogo_parte.dart';
import '../../../data/models/tipo_vehiculo.dart';
import '../../../core/constants/app_constants.dart';

// Provider de tipos de vehículo
final tiposVehiculoProvider = FutureProvider<List<TipoVehiculo>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final data = await supabase
      .from('tipos_vehiculo')
      .select()
      .eq('activo', true)
      .order('nombre');
  return data.map((e) => TipoVehiculo.fromJson(e)).toList();
});

// Provider de catálogo de partes
final catalogoPartesProvider = FutureProvider<List<CatalogoParte>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final data = await supabase
      .from('catalogo_partes')
      .select()
      .order('categoria')
      .order('orden');
  return data.map((e) => CatalogoParte.fromJson(e)).toList();
});

// Provider de plantilla por tipo de vehículo
final plantillaTipoProvider =
    FutureProvider.family<List<PlantillaTipoVehiculo>, String>((ref, tipoId) async {
  final supabase = ref.watch(supabaseClientProvider);
  final data = await supabase
      .from('plantilla_tipo_vehiculo')
      .select('*, catalogo_partes(*)')
      .eq('tipo_vehiculo_id', tipoId)
      .order('catalogo_partes(categoria)')
      .order('catalogo_partes(orden)');
  return data.map((e) => PlantillaTipoVehiculo.fromJson(e)).toList();
});

class ConfiguracionScreen extends ConsumerStatefulWidget {
  const ConfiguracionScreen({super.key});

  @override
  ConsumerState<ConfiguracionScreen> createState() => _ConfiguracionScreenState();
}

class _ConfiguracionScreenState extends ConsumerState<ConfiguracionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).primaryColor,
          tabs: const [
            Tab(icon: Icon(Icons.category), text: 'Catálogo de Partes'),
            Tab(icon: Icon(Icons.directions_car), text: 'Tipos de Vehículo'),
            Tab(icon: Icon(Icons.tune), text: 'Plantillas'),
            Tab(icon: Icon(Icons.dns), text: 'Servidor'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [
              _CatalogoPartesTab(),
              _TiposVehiculoTab(),
              _PlantillasTab(),
              _ServidorTab(),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================
// TAB 1: Catálogo de partes
// ============================================
class _CatalogoPartesTab extends ConsumerWidget {
  const _CatalogoPartesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final partes = ref.watch(catalogoPartesProvider);

    return partes.when(
      data: (lista) {
        // Agrupar por categoría
        final Map<String, List<CatalogoParte>> porCategoria = {};
        for (final p in lista) {
          porCategoria.putIfAbsent(p.categoria, () => []).add(p);
        }

        return Scaffold(
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: porCategoria.entries.map((entry) {
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ExpansionTile(
                  leading: const Icon(Icons.build),
                  title: Text(
                    entry.key,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('${entry.value.length} partes'),
                  children: entry.value.map((parte) {
                    return ListTile(
                      title: Text(parte.nombre),
                      trailing: Switch(
                        value: parte.activoPorDefecto,
                        onChanged: (val) => _toggleParte(ref, parte, val),
                      ),
                    );
                  }).toList(),
                ),
              );
            }).toList(),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _showAddParteDialog(context, ref),
            child: const Icon(Icons.add),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Future<void> _toggleParte(WidgetRef ref, CatalogoParte parte, bool value) async {
    final supabase = ref.read(supabaseClientProvider);
    await supabase
        .from('catalogo_partes')
        .update({'activo_por_defecto': value}).eq('id', parte.id);
    ref.invalidate(catalogoPartesProvider);
  }

  void _showAddParteDialog(BuildContext context, WidgetRef ref) {
    final nombreController = TextEditingController();
    String categoriaSeleccionada = AppConstants.categorias.first;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Agregar Parte'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nombreController,
              decoration: const InputDecoration(labelText: 'Nombre de la parte'),
            ),
            const SizedBox(height: 16),
            StatefulBuilder(
              builder: (context, setDialogState) {
                return DropdownButtonFormField<String>(
                  initialValue: categoriaSeleccionada,
                  decoration: const InputDecoration(labelText: 'Categoría'),
                  items: AppConstants.categorias
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (val) {
                    setDialogState(() => categoriaSeleccionada = val!);
                  },
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nombreController.text.isNotEmpty) {
                final supabase = ref.read(supabaseClientProvider);
                await supabase.from('catalogo_partes').insert({
                  'nombre': nombreController.text.trim(),
                  'categoria': categoriaSeleccionada,
                  'activo_por_defecto': true,
                });
                ref.invalidate(catalogoPartesProvider);
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
  }
}

// ============================================
// TAB 2: Tipos de vehículo
// ============================================
class _TiposVehiculoTab extends ConsumerWidget {
  const _TiposVehiculoTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tipos = ref.watch(tiposVehiculoProvider);

    return tipos.when(
      data: (lista) => Scaffold(
        body: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: lista.length,
          itemBuilder: (context, index) {
            final tipo = lista[index];
            return Card(
              child: ListTile(
                leading: const Icon(Icons.directions_car, size: 32),
                title: Text(tipo.nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(tipo.descripcion ?? ''),
                trailing: IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _showEditDialog(context, ref, tipo),
                ),
              ),
            );
          },
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showAddDialog(context, ref),
          child: const Icon(Icons.add),
        ),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    final nombreController = TextEditingController();
    final descripcionController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Agregar Tipo de Vehículo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nombreController,
              decoration: const InputDecoration(labelText: 'Nombre'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descripcionController,
              decoration: const InputDecoration(labelText: 'Descripción'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              if (nombreController.text.isNotEmpty) {
                final supabase = ref.read(supabaseClientProvider);
                await supabase.from('tipos_vehiculo').insert({
                  'nombre': nombreController.text.trim(),
                  'descripcion': descripcionController.text.trim(),
                });
                ref.invalidate(tiposVehiculoProvider);
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, TipoVehiculo tipo) {
    final nombreController = TextEditingController(text: tipo.nombre);
    final descripcionController = TextEditingController(text: tipo.descripcion);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar Tipo de Vehículo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nombreController,
              decoration: const InputDecoration(labelText: 'Nombre'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descripcionController,
              decoration: const InputDecoration(labelText: 'Descripción'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              final supabase = ref.read(supabaseClientProvider);
              await supabase.from('tipos_vehiculo').update({
                'nombre': nombreController.text.trim(),
                'descripcion': descripcionController.text.trim(),
              }).eq('id', tipo.id);
              ref.invalidate(tiposVehiculoProvider);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}

// ============================================
// TAB 3: Plantillas por tipo de vehículo
// ============================================
class _PlantillasTab extends ConsumerStatefulWidget {
  const _PlantillasTab();

  @override
  ConsumerState<_PlantillasTab> createState() => _PlantillasTabState();
}

class _PlantillasTabState extends ConsumerState<_PlantillasTab> {
  String? _selectedTipoId;

  @override
  Widget build(BuildContext context) {
    final tipos = ref.watch(tiposVehiculoProvider);

    return Column(
      children: [
        // Selector de tipo
        Padding(
          padding: const EdgeInsets.all(16),
          child: tipos.when(
            data: (lista) => DropdownButtonFormField<String>(
              initialValue: _selectedTipoId,
              decoration: const InputDecoration(
                labelText: 'Seleccionar tipo de vehículo',
                prefixIcon: Icon(Icons.directions_car),
              ),
              items: lista
                  .map((t) => DropdownMenuItem(value: t.id, child: Text(t.nombre)))
                  .toList(),
              onChanged: (val) => setState(() => _selectedTipoId = val),
            ),
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Error: $e'),
          ),
        ),

        // Lista de partes de la plantilla
        if (_selectedTipoId != null)
          Expanded(
            child: _PlantillaPartesList(tipoId: _selectedTipoId!),
          ),
      ],
    );
  }
}

class _PlantillaPartesList extends ConsumerWidget {
  final String tipoId;
  const _PlantillaPartesList({required this.tipoId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plantilla = ref.watch(plantillaTipoProvider(tipoId));

    return plantilla.when(
      data: (lista) {
        if (lista.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('No hay partes configuradas para este tipo'),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => _generarPlantilla(ref, tipoId),
                  icon: const Icon(Icons.auto_fix_high),
                  label: const Text('Generar plantilla desde catálogo'),
                ),
              ],
            ),
          );
        }

        // Agrupar por categoría
        final Map<String, List<PlantillaTipoVehiculo>> porCategoria = {};
        for (final p in lista) {
          final cat = p.parte?.categoria ?? 'Sin categoría';
          porCategoria.putIfAbsent(cat, () => []).add(p);
        }

        return ListView(
          padding: const EdgeInsets.all(8),
          children: porCategoria.entries.map((entry) {
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ExpansionTile(
                title: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                  '${entry.value.where((p) => p.activo).length}/${entry.value.length} activas',
                ),
                children: entry.value.map((plantillaParte) {
                  return SwitchListTile(
                    title: Text(plantillaParte.parte?.nombre ?? 'Sin nombre'),
                    value: plantillaParte.activo,
                    onChanged: (val) => _togglePlantillaParte(ref, plantillaParte, val),
                  );
                }).toList(),
              ),
            );
          }).toList(),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Future<void> _togglePlantillaParte(
      WidgetRef ref, PlantillaTipoVehiculo plantillaParte, bool value) async {
    final supabase = ref.read(supabaseClientProvider);
    await supabase
        .from('plantilla_tipo_vehiculo')
        .update({'activo': value}).eq('id', plantillaParte.id);
    ref.invalidate(plantillaTipoProvider(tipoId));
  }

  Future<void> _generarPlantilla(WidgetRef ref, String tipoId) async {
    final supabase = ref.read(supabaseClientProvider);
    final partes = await supabase.from('catalogo_partes').select().eq('activo_por_defecto', true);

    final inserts = partes.map((p) => {
          'tipo_vehiculo_id': tipoId,
          'parte_id': p['id'],
          'activo': true,
        }).toList();

    if (inserts.isNotEmpty) {
      await supabase.from('plantilla_tipo_vehiculo').insert(inserts);
    }

    ref.invalidate(plantillaTipoProvider(tipoId));
  }
}

// ============================================
// TAB 4: Configuración del Servidor (Backend)
// ============================================
class _ServidorTab extends StatefulWidget {
  const _ServidorTab();

  @override
  State<_ServidorTab> createState() => _ServidorTabState();
}

class _ServidorTabState extends State<_ServidorTab> {
  final _urlController = TextEditingController();
  final _keyController = TextEditingController();
  bool _hasCustom = false;
  bool _obscureKey = true;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    _urlController.text = SupabaseConfig.supabaseUrl;
    _keyController.text = SupabaseConfig.supabaseAnonKey;
    _hasCustom = await SupabaseConfig.hasCustomConfig();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _urlController.dispose();
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _saveConfig() async {
    final url = _urlController.text.trim();
    final key = _keyController.text.trim();

    if (url.isEmpty || key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('URL y Anon Key son requeridos')),
      );
      return;
    }

    await SupabaseConfig.save(url: url, anonKey: key);
    setState(() => _hasCustom = true);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Configuración guardada. Reinicia la app para aplicar cambios.',
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _resetConfig() async {
    await SupabaseConfig.reset();
    await _loadConfig();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Restaurado a valores por defecto. Reinicia la app para aplicar.',
          ),
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Info card
        Card(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.info_outline,
                    color: Theme.of(context).colorScheme.onPrimaryContainer),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Configura la URL del servidor Supabase y la clave '
                    'anónima (Anon Key). Los cambios requieren reiniciar la app.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Estado actual
        Card(
          child: ListTile(
            leading: Icon(
              _hasCustom ? Icons.cloud_done : Icons.cloud_off,
              color: _hasCustom ? Colors.green : Colors.grey,
            ),
            title: Text(_hasCustom ? 'Servidor personalizado' : 'Sin configurar (valores por defecto)'),
            subtitle: Text(
              SupabaseConfig.supabaseUrl,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ),
        const SizedBox(height: 24),

        // URL del servidor
        TextField(
          controller: _urlController,
          decoration: const InputDecoration(
            labelText: 'URL del Servidor Supabase',
            hintText: 'http://192.168.1.100:8000',
            prefixIcon: Icon(Icons.link),
            helperText: 'Ej: http://IP_SERVIDOR:8000 o https://tu-proyecto.supabase.co',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.url,
        ),
        const SizedBox(height: 16),

        // Anon Key
        TextField(
          controller: _keyController,
          obscureText: _obscureKey,
          decoration: InputDecoration(
            labelText: 'Anon Key (API Key)',
            prefixIcon: const Icon(Icons.key),
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: Icon(_obscureKey ? Icons.visibility : Icons.visibility_off),
              onPressed: () => setState(() => _obscureKey = !_obscureKey),
            ),
            helperText: 'JWT token con role=anon',
          ),
          maxLines: 1,
        ),
        const SizedBox(height: 24),

        // Botones
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _saveConfig,
                icon: const Icon(Icons.save),
                label: const Text('Guardar'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _hasCustom ? _resetConfig : null,
                icon: const Icon(Icons.restore),
                label: const Text('Restaurar'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),

        // Ayuda rápida
        const Divider(),
        const SizedBox(height: 16),
        Text(
          'Guía rápida',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        const Text(
          '1. Levanta el backend con: docker compose up -d\n'
          '2. Abre Supabase Studio en: http://localhost:3100\n'
          '3. La API queda en: http://localhost:8000\n'
          '4. Para el APK, usa la IP de tu PC en la red local\n'
          '   Ej: http://192.168.1.50:8000\n'
          '5. La Anon Key está en el archivo .env del proyecto',
          style: TextStyle(fontFamily: 'monospace', fontSize: 13),
        ),
      ],
    );
  }
}
