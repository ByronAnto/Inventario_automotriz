import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/supabase_config.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/models/catalogo_parte.dart';
import '../../../data/models/perfil.dart';
import '../../../data/models/tipo_vehiculo.dart';
import '../../../core/constants/app_constants.dart';

// Provider de perfiles (usuarios)
final perfilesProvider = FutureProvider<List<Perfil>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final data = await supabase
      .from('perfiles')
      .select()
      .order('created_at', ascending: false);
  return data.map((e) => Perfil.fromJson(e)).toList();
});

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
    _tabController = TabController(length: 5, vsync: this);
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
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.people), text: 'Usuarios'),
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
              _UsuariosTab(),
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
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Switch(
                            value: parte.activoPorDefecto,
                            onChanged: (val) => _toggleParte(ref, parte, val),
                          ),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, size: 20),
                            onSelected: (action) {
                              if (action == 'editar') {
                                _showEditParteDialog(context, ref, parte);
                              } else if (action == 'eliminar') {
                                _confirmDeleteParte(context, ref, parte);
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'editar',
                                child: ListTile(
                                  leading: Icon(Icons.edit, size: 20),
                                  title: Text('Editar'),
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                              PopupMenuItem(
                                value: 'eliminar',
                                child: ListTile(
                                  leading: Icon(Icons.delete, size: 20, color: Colors.red),
                                  title: Text('Eliminar', style: TextStyle(color: Colors.red)),
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ],
                          ),
                        ],
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

  void _showEditParteDialog(BuildContext context, WidgetRef ref, CatalogoParte parte) {
    final nombreCtrl = TextEditingController(text: parte.nombre);
    String categoriaSeleccionada = parte.categoria;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar Parte'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nombreCtrl,
              decoration: const InputDecoration(labelText: 'Nombre de la parte'),
            ),
            const SizedBox(height: 16),
            StatefulBuilder(
              builder: (context, setDialogState) {
                return DropdownButtonFormField<String>(
                  initialValue: categoriaSeleccionada,
                  decoration: const InputDecoration(labelText: 'Categor\u00eda'),
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
              if (nombreCtrl.text.isNotEmpty) {
                final supabase = ref.read(supabaseClientProvider);
                await supabase.from('catalogo_partes').update({
                  'nombre': nombreCtrl.text.trim(),
                  'categoria': categoriaSeleccionada,
                }).eq('id', parte.id);
                ref.invalidate(catalogoPartesProvider);
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteParte(BuildContext context, WidgetRef ref, CatalogoParte parte) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar parte'),
        content: Text('\u00bfEliminar "${parte.nombre}"?\n\nTambi\u00e9n se quitar\u00e1 de todas las plantillas.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final supabase = ref.read(supabaseClientProvider);
              // Primero eliminar de plantillas
              await supabase.from('plantilla_tipo_vehiculo').delete().eq('parte_id', parte.id);
              // Luego eliminar la parte del cat\u00e1logo
              await supabase.from('catalogo_partes').delete().eq('id', parte.id);
              ref.invalidate(catalogoPartesProvider);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
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

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: ListView(
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
                    return ListTile(
                      title: Text(plantillaParte.parte?.nombre ?? 'Sin nombre'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Switch(
                            value: plantillaParte.activo,
                            onChanged: (val) =>
                                _togglePlantillaParte(ref, plantillaParte, val),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                size: 20, color: Colors.red),
                            tooltip: 'Quitar de la plantilla',
                            onPressed: () => _confirmDeletePlantillaParte(
                                context, ref, plantillaParte),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              );
            }).toList(),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showAddParteToPlantilla(context, ref, lista),
            icon: const Icon(Icons.add),
            label: const Text('Agregar parte'),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  void _showAddParteToPlantilla(
      BuildContext context, WidgetRef ref, List<PlantillaTipoVehiculo> existentes) {
    final supabase = ref.read(supabaseClientProvider);
    final existingParteIds = existentes.map((e) => e.parteId).toSet();

    showDialog(
      context: context,
      builder: (ctx) {
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: supabase.from('catalogo_partes').select().order('categoria').order('nombre'),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const AlertDialog(
                content: SizedBox(
                  height: 100,
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }
            if (snapshot.hasError) {
              return AlertDialog(
                title: const Text('Error'),
                content: Text('${snapshot.error}'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cerrar')),
                ],
              );
            }

            final todasPartes = snapshot.data ?? [];
            final disponibles = todasPartes
                .where((p) => !existingParteIds.contains(p['id']))
                .toList();

            if (disponibles.isEmpty) {
              return AlertDialog(
                title: const Text('Sin partes disponibles'),
                content: const Text(
                    'Todas las partes del catálogo ya están en esta plantilla.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cerrar')),
                ],
              );
            }

            // Agrupar por categoría
            final porCategoria = <String, List<Map<String, dynamic>>>{};
            for (final p in disponibles) {
              final cat = (p['categoria'] as String?) ?? 'Sin categoría';
              porCategoria.putIfAbsent(cat, () => []).add(p);
            }

            return AlertDialog(
              title: const Text('Agregar parte a la plantilla'),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: ListView(
                  children: porCategoria.entries.map((entry) {
                    return ExpansionTile(
                      title: Text(entry.key,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      children: entry.value.map((parte) {
                        return ListTile(
                          title: Text(parte['nombre'] ?? ''),
                          trailing: IconButton(
                            icon: const Icon(Icons.add_circle,
                                color: Colors.green),
                            onPressed: () async {
                              await supabase
                                  .from('plantilla_tipo_vehiculo')
                                  .insert({
                                'tipo_vehiculo_id': tipoId,
                                'parte_id': parte['id'],
                                'activo': true,
                              });
                              ref.invalidate(plantillaTipoProvider(tipoId));
                              if (ctx.mounted) Navigator.pop(ctx);
                            },
                          ),
                        );
                      }).toList(),
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cerrar')),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDeletePlantillaParte(
      BuildContext context, WidgetRef ref, PlantillaTipoVehiculo plantillaParte) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quitar parte'),
        content: Text(
            '\u00bfQuitar "${plantillaParte.parte?.nombre ?? ''}" de esta plantilla?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final supabase = ref.read(supabaseClientProvider);
              await supabase
                  .from('plantilla_tipo_vehiculo')
                  .delete()
                  .eq('id', plantillaParte.id);
              ref.invalidate(plantillaTipoProvider(tipoId));
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Quitar'),
          ),
        ],
      ),
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

// ============================================
// TAB 5: Gestión de Usuarios
// ============================================
class _UsuariosTab extends ConsumerWidget {
  const _UsuariosTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perfiles = ref.watch(perfilesProvider);
    final currentUser = ref.watch(authProvider).perfil;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: perfiles.when(
        data: (lista) {
          if (lista.isEmpty) {
            return const Center(child: Text('No hay usuarios registrados.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: lista.length,
            itemBuilder: (context, index) {
              final perfil = lista[index];
              final esUsuarioActual = perfil.userId == currentUser?.userId;

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _rolColor(perfil.rol),
                    child: Text(
                      perfil.nombre.isNotEmpty
                          ? perfil.nombre[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Row(
                    children: [
                      Flexible(
                        child: Text(
                          perfil.nombre,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (esUsuarioActual) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('Tú',
                              style: TextStyle(fontSize: 11, color: Colors.blue)),
                        ),
                      ],
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(perfil.email ?? 'Sin email'),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _RolChip(rol: perfil.rol),
                          const SizedBox(width: 8),
                          if (perfil.comisionPorcentaje != null &&
                              perfil.comisionPorcentaje! > 0)
                            Chip(
                              label: Text(
                                'Comisión: ${perfil.comisionPorcentaje!.toStringAsFixed(1)}%',
                                style: const TextStyle(fontSize: 11),
                              ),
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                            ),
                          const Spacer(),
                          Icon(
                            perfil.activo
                                ? Icons.check_circle
                                : Icons.cancel,
                            color:
                                perfil.activo ? Colors.green : Colors.red,
                            size: 18,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            perfil.activo ? 'Activo' : 'Inactivo',
                            style: TextStyle(
                              fontSize: 12,
                              color:
                                  perfil.activo ? Colors.green : Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  isThreeLine: true,
                  trailing: esUsuarioActual
                      ? null
                      : PopupMenuButton<String>(
                          onSelected: (action) {
                            switch (action) {
                              case 'editar':
                                _showEditDialog(context, ref, perfil);
                                break;
                              case 'toggle':
                                _toggleActivo(ref, perfil);
                                break;
                            }
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'editar',
                              child: ListTile(
                                leading: Icon(Icons.edit),
                                title: Text('Editar'),
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                            PopupMenuItem(
                              value: 'toggle',
                              child: ListTile(
                                leading: Icon(
                                  perfil.activo
                                      ? Icons.person_off
                                      : Icons.person,
                                ),
                                title: Text(
                                  perfil.activo
                                      ? 'Desactivar'
                                      : 'Activar',
                                ),
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ],
                        ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error al cargar usuarios: $e')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateDialog(context, ref),
        icon: const Icon(Icons.person_add),
        label: const Text('Nuevo Usuario'),
      ),
    );
  }

  Color _rolColor(String rol) {
    switch (rol) {
      case 'administrador':
        return Colors.indigo;
      case 'vendedor':
        return Colors.teal;
      case 'mecanico':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Future<void> _toggleActivo(WidgetRef ref, Perfil perfil) async {
    final supabase = ref.read(supabaseClientProvider);
    await supabase
        .from('perfiles')
        .update({'activo': !perfil.activo}).eq('id', perfil.id);
    ref.invalidate(perfilesProvider);
  }

  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final nombreCtrl = TextEditingController();
    final telefonoCtrl = TextEditingController();
    final comisionCtrl = TextEditingController(text: '0');
    String selectedRol = 'vendedor';
    bool obscurePassword = true;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Crear Nuevo Usuario'),
          content: SizedBox(
            width: 400,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nombreCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nombre completo *',
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Requerido' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: emailCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Correo electrónico *',
                        prefixIcon: Icon(Icons.email),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Requerido';
                        if (!v.contains('@')) return 'Email inválido';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: passwordCtrl,
                      obscureText: obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Contraseña *',
                        prefixIcon: const Icon(Icons.lock),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(obscurePassword
                              ? Icons.visibility
                              : Icons.visibility_off),
                          onPressed: () => setDialogState(
                              () => obscurePassword = !obscurePassword),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Requerido';
                        if (v.length < 6) return 'Mínimo 6 caracteres';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: telefonoCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Teléfono',
                        prefixIcon: Icon(Icons.phone),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedRol,
                      decoration: const InputDecoration(
                        labelText: 'Rol *',
                        prefixIcon: Icon(Icons.badge),
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'administrador',
                          child: Text('Administrador'),
                        ),
                        DropdownMenuItem(
                          value: 'vendedor',
                          child: Text('Vendedor'),
                        ),
                        DropdownMenuItem(
                          value: 'mecanico',
                          child: Text('Mecánico'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          setDialogState(() => selectedRol = v);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    if (selectedRol == 'vendedor')
                      TextFormField(
                        controller: comisionCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Comisión (%)',
                          prefixIcon: Icon(Icons.percent),
                          border: OutlineInputBorder(),
                          helperText: 'Porcentaje de comisión por venta',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        validator: (v) {
                          if (v != null && v.isNotEmpty) {
                            final n = double.tryParse(v);
                            if (n == null || n < 0 || n > 100) {
                              return 'Debe ser entre 0 y 100';
                            }
                          }
                          return null;
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;

                // Mostrar loading
                showDialog(
                  context: ctx,
                  barrierDismissible: false,
                  builder: (_) => const Center(
                    child: CircularProgressIndicator(),
                  ),
                );

                try {
                  await ref.read(authProvider.notifier).createUser(
                        email: emailCtrl.text.trim(),
                        password: passwordCtrl.text,
                        nombre: nombreCtrl.text.trim(),
                        rol: selectedRol,
                        telefono: telefonoCtrl.text.trim().isNotEmpty
                            ? telefonoCtrl.text.trim()
                            : null,
                        comision: selectedRol == 'vendedor'
                            ? double.tryParse(comisionCtrl.text)
                            : null,
                      );

                  ref.invalidate(perfilesProvider);

                  if (ctx.mounted) {
                    Navigator.pop(ctx); // loading
                    Navigator.pop(ctx); // dialog
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            'Usuario "${nombreCtrl.text.trim()}" creado exitosamente'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (ctx.mounted) {
                    Navigator.pop(ctx); // loading
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.save),
              label: const Text('Crear Usuario'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, Perfil perfil) {
    final nombreCtrl = TextEditingController(text: perfil.nombre);
    final telefonoCtrl = TextEditingController(text: perfil.telefono ?? '');
    final comisionCtrl = TextEditingController(
        text: (perfil.comisionPorcentaje ?? 0).toString());
    String selectedRol = perfil.rol;
    bool activo = perfil.activo;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Editar: ${perfil.nombre}'),
          content: SizedBox(
            width: 400,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Email (solo lectura)
                    TextFormField(
                      initialValue: perfil.email ?? '',
                      enabled: false,
                      decoration: const InputDecoration(
                        labelText: 'Correo electrónico',
                        prefixIcon: Icon(Icons.email),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: nombreCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nombre completo *',
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Requerido' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: telefonoCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Teléfono',
                        prefixIcon: Icon(Icons.phone),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedRol,
                      decoration: const InputDecoration(
                        labelText: 'Rol *',
                        prefixIcon: Icon(Icons.badge),
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'administrador',
                          child: Text('Administrador'),
                        ),
                        DropdownMenuItem(
                          value: 'vendedor',
                          child: Text('Vendedor'),
                        ),
                        DropdownMenuItem(
                          value: 'mecanico',
                          child: Text('Mecánico'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          setDialogState(() => selectedRol = v);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    if (selectedRol == 'vendedor')
                      TextFormField(
                        controller: comisionCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Comisión (%)',
                          prefixIcon: Icon(Icons.percent),
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        validator: (v) {
                          if (v != null && v.isNotEmpty) {
                            final n = double.tryParse(v);
                            if (n == null || n < 0 || n > 100) {
                              return 'Debe ser entre 0 y 100';
                            }
                          }
                          return null;
                        },
                      ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      title: const Text('Usuario activo'),
                      subtitle: Text(activo
                          ? 'Puede iniciar sesión'
                          : 'No puede iniciar sesión'),
                      value: activo,
                      onChanged: (v) => setDialogState(() => activo = v),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;

                final supabase = ref.read(supabaseClientProvider);
                final updates = <String, dynamic>{
                  'nombre': nombreCtrl.text.trim(),
                  'telefono': telefonoCtrl.text.trim().isNotEmpty
                      ? telefonoCtrl.text.trim()
                      : null,
                  'rol': selectedRol,
                  'activo': activo,
                  'comision_porcentaje': selectedRol == 'vendedor'
                      ? double.tryParse(comisionCtrl.text) ?? 0
                      : null,
                };

                await supabase
                    .from('perfiles')
                    .update(updates)
                    .eq('id', perfil.id);

                ref.invalidate(perfilesProvider);

                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'Usuario "${nombreCtrl.text.trim()}" actualizado'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.save),
              label: const Text('Guardar Cambios'),
            ),
          ],
        ),
      ),
    );
  }
}

// Widget para mostrar el chip de rol con color
class _RolChip extends StatelessWidget {
  final String rol;
  const _RolChip({required this.rol});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (rol) {
      'administrador' => ('Admin', Colors.indigo),
      'vendedor' => ('Vendedor', Colors.teal),
      'mecanico' => ('Mecánico', Colors.orange),
      _ => (rol, Colors.grey),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 0.5),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
