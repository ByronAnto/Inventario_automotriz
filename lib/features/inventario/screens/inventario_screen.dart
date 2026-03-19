import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/repuesto.dart';
import '../../../data/models/ubicacion.dart';
import '../../../data/models/marca_modelo.dart';
import '../../../data/models/proveedor.dart';

// ─── Filtros ─────────────────────────────────────────────────

class InventarioFiltros {
  final String? busqueda;
  final String? categoria;
  final String? estado;
  final String? ubicacionId;
  final String? marcaNombre;

  InventarioFiltros({
    this.busqueda,
    this.categoria,
    this.estado,
    this.ubicacionId,
    this.marcaNombre,
  });

  bool get hasActiveFilters =>
      estado != null ||
      categoria != null ||
      ubicacionId != null ||
      marcaNombre != null;

  /// True when the user explicitly chose to see ALL items (including vendidos)
  bool get mostrandoTodos => estado == '__all__';

  InventarioFiltros copyWith({
    String? busqueda,
    String? categoria,
    String? estado,
    String? ubicacionId,
    String? marcaNombre,
    bool clearBusqueda = false,
    bool clearCategoria = false,
    bool clearEstado = false,
    bool clearUbicacion = false,
    bool clearMarca = false,
  }) {
    return InventarioFiltros(
      busqueda: clearBusqueda ? null : busqueda ?? this.busqueda,
      categoria: clearCategoria ? null : categoria ?? this.categoria,
      estado: clearEstado ? null : estado ?? this.estado,
      ubicacionId: clearUbicacion ? null : ubicacionId ?? this.ubicacionId,
      marcaNombre: clearMarca ? null : marcaNombre ?? this.marcaNombre,
    );
  }
}

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

// ─── Providers ───────────────────────────────────────────────

const _kSelectColumns =
    'id, vehiculo_id, catalogo_parte_id, estado, ubicacion_id, '
    'precio_sugerido, origen, proveedor_externo, costo_externo, notas, fotos, '
    'created_at, ext_marca_id, ext_modelo_id, ext_anio, '
    'catalogo_partes(nombre, categoria), ubicaciones(nombre), '
    'vehiculos(anio, marcas(nombre), modelos(nombre))';

const _kPageSize = 50;

final inventarioProvider = FutureProvider<List<Repuesto>>((ref) async {
  final filtros = ref.watch(inventarioFiltrosProvider);
  var query = Supabase.instance.client.from('repuestos').select(
    _kSelectColumns,
  );

  if (filtros.estado != null && filtros.estado != '__all__') {
    query = query.eq('estado', filtros.estado!);
  } else if (filtros.estado == null) {
    query = query.neq('estado', 'vendido');
  }
  if (filtros.ubicacionId != null) {
    query = query.eq('ubicacion_id', filtros.ubicacionId!);
  }

  final data = await query.order('created_at', ascending: false).limit(_kPageSize);
  var repuestos = data.map((e) => Repuesto.fromJson(e)).toList();

  // Filtros client-side
  if (filtros.categoria != null) {
    repuestos =
        repuestos.where((r) => r.parteCategoria == filtros.categoria).toList();
  }
  if (filtros.marcaNombre != null) {
    repuestos =
        repuestos.where((r) => r.vehiculoMarca == filtros.marcaNombre).toList();
  }
  if (filtros.busqueda != null && filtros.busqueda!.isNotEmpty) {
    final term = filtros.busqueda!.toLowerCase();
    repuestos = repuestos.where((r) {
      final nombre = (r.parteNombre ?? '').toLowerCase();
      final vehiculo = (r.vehiculoNombre ?? '').toLowerCase();
      final marca = (r.vehiculoMarca ?? '').toLowerCase();
      final ubicacion = (r.ubicacionNombre ?? '').toLowerCase();
      return nombre.contains(term) ||
          vehiculo.contains(term) ||
          marca.contains(term) ||
          ubicacion.contains(term);
    }).toList();
  }

  return repuestos;
});

/// Carga más repuestos (paginación offset)
Future<List<Repuesto>> _fetchMoreRepuestos(
    InventarioFiltros filtros, int offset) async {
  var query = Supabase.instance.client.from('repuestos').select(_kSelectColumns);
  if (filtros.estado != null && filtros.estado != '__all__') {
    query = query.eq('estado', filtros.estado!);
  } else if (filtros.estado == null) {
    query = query.neq('estado', 'vendido');
  }
  if (filtros.ubicacionId != null) {
    query = query.eq('ubicacion_id', filtros.ubicacionId!);
  }
  final data = await query
      .order('created_at', ascending: false)
      .range(offset, offset + _kPageSize - 1);
  var repuestos = data.map((e) => Repuesto.fromJson(e)).toList();
  if (filtros.categoria != null) {
    repuestos =
        repuestos.where((r) => r.parteCategoria == filtros.categoria).toList();
  }
  if (filtros.marcaNombre != null) {
    repuestos =
        repuestos.where((r) => r.vehiculoMarca == filtros.marcaNombre).toList();
  }
  if (filtros.busqueda != null && filtros.busqueda!.isNotEmpty) {
    final term = filtros.busqueda!.toLowerCase();
    repuestos = repuestos.where((r) {
      final nombre = (r.parteNombre ?? '').toLowerCase();
      final vehiculo = (r.vehiculoNombre ?? '').toLowerCase();
      final marca = (r.vehiculoMarca ?? '').toLowerCase();
      final ubicacion = (r.ubicacionNombre ?? '').toLowerCase();
      return nombre.contains(term) ||
          vehiculo.contains(term) ||
          marca.contains(term) ||
          ubicacion.contains(term);
    }).toList();
  }
  return repuestos;
}

final ubicacionesInventarioProvider =
    FutureProvider<List<Ubicacion>>((ref) async {
  final data = await Supabase.instance.client
      .from('ubicaciones')
      .select()
      .eq('activo', true)
      .order('nombre');
  return data.map((e) => Ubicacion.fromJson(e)).toList();
});

final marcasInventarioProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final data = await Supabase.instance.client
      .from('marcas')
      .select('id, nombre')
      .order('nombre');
  return data;
});

// Providers para el diálogo IngresoExterno
final marcasExternoProvider = FutureProvider<List<Marca>>((ref) async {
  final data = await Supabase.instance.client
      .from('marcas')
      .select()
      .eq('activo', true)
      .order('nombre');
  return data.map((e) => Marca.fromJson(e)).toList();
});

final modelosExternoProvider =
    FutureProvider.family<List<Modelo>, String>((ref, marcaId) async {
  final data = await Supabase.instance.client
      .from('modelos')
      .select()
      .eq('marca_id', marcaId)
      .eq('activo', true)
      .order('nombre');
  return data.map((e) => Modelo.fromJson(e)).toList();
});

final proveedoresExternoProvider = FutureProvider<List<Proveedor>>((ref) async {
  final data = await Supabase.instance.client
      .from('proveedores')
      .select()
      .eq('activo', true)
      .order('nombre');
  return data.map((e) => Proveedor.fromJson(e)).toList();
});

// ─── Screen ──────────────────────────────────────────────────

class InventarioScreen extends ConsumerStatefulWidget {
  const InventarioScreen({super.key});

  @override
  ConsumerState<InventarioScreen> createState() => _InventarioScreenState();
}

class _InventarioScreenState extends ConsumerState<InventarioScreen> {
  final ScrollController _scrollController = ScrollController();
  final List<Repuesto> _allRepuestos = [];
  bool _isLoadingMore = false;
  bool _hasMore = true;
  bool _initialLoaded = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMore) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    try {
      final filtros = ref.read(inventarioFiltrosProvider);
      final more = await _fetchMoreRepuestos(filtros, _allRepuestos.length);
      setState(() {
        _allRepuestos.addAll(more);
        _hasMore = more.length >= _kPageSize;
        _isLoadingMore = false;
      });
    } catch (_) {
      setState(() => _isLoadingMore = false);
    }
  }

  void _resetPagination() {
    _allRepuestos.clear();
    _hasMore = true;
    _isLoadingMore = false;
    _initialLoaded = false;
  }

  @override
  Widget build(BuildContext context) {
    final inventario = ref.watch(inventarioProvider);
    final filtros = ref.watch(inventarioFiltrosProvider);
    final ubicaciones = ref.watch(ubicacionesInventarioProvider);
    final marcas = ref.watch(marcasInventarioProvider);
    final isWide = MediaQuery.of(context).size.width > 600;

    // Reset pagination when provider is re-loading (filters changed)
    if (inventario.isLoading && _initialLoaded) {
      _resetPagination();
    }

    return Scaffold(
      body: Column(
        children: [
          // Stats summary bar
          const _StatsBar(),

          // Search bar
          _buildSearchBar(context, ref, filtros),

          // Filters row
          _buildFilters(context, ref, filtros, ubicaciones, marcas),

          // Active filter chips
          if (filtros.hasActiveFilters)
            _buildActiveFilterChips(context, ref, filtros, ubicaciones),

          const Divider(height: 1),

          // Results count
          inventario.whenOrNull(
                data: (reps) {
                  // Sincronizar paginación con datos iniciales
                  if (!_initialLoaded) {
                    _allRepuestos.clear();
                    _allRepuestos.addAll(reps);
                    _hasMore = reps.length >= _kPageSize;
                    _initialLoaded = true;
                  }
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${_allRepuestos.length} repuesto${_allRepuestos.length != 1 ? "s" : ""} ${_hasMore ? "(cargando más...)" : "encontrado${_allRepuestos.length != 1 ? "s" : ""}"}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                },
              ) ??
              const SizedBox.shrink(),

          // Repuesto list
          Expanded(
            child: inventario.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 48, color: Colors.red),
                    const SizedBox(height: 12),
                    Text('Error: $e', textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () {
                        _resetPagination();
                        ref.invalidate(inventarioProvider);
                        ref.invalidate(inventarioStatsProvider);
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
              data: (repuestos) {
                if (_allRepuestos.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.inventory_2_outlined,
                            size: 72, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          filtros.hasActiveFilters ||
                                  (filtros.busqueda?.isNotEmpty ?? false)
                              ? 'No se encontraron repuestos\ncon los filtros aplicados'
                              : 'No hay repuestos en el inventario',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 16,
                          ),
                        ),
                        if (filtros.hasActiveFilters) ...[
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: () {
                              _resetPagination();
                              ref
                                  .read(inventarioFiltrosProvider.notifier)
                                  .update((_) => InventarioFiltros());
                            },
                            icon: const Icon(Icons.clear_all),
                            label: const Text('Limpiar filtros'),
                          ),
                        ],
                      ],
                    ),
                  );
                }

                final totalItems =
                    _allRepuestos.length + (_isLoadingMore ? 1 : 0);

                return RefreshIndicator(
                  onRefresh: () async {
                    _resetPagination();
                    return ref.refresh(inventarioProvider.future);
                  },
                  child: isWide
                      ? GridView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(12),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount:
                                MediaQuery.of(context).size.width > 1200
                                    ? 3
                                    : 2,
                            childAspectRatio: 2.2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: totalItems,
                          itemBuilder: (context, index) {
                            if (index >= _allRepuestos.length) {
                              return const Center(
                                  child: Padding(
                                padding: EdgeInsets.all(16),
                                child: CircularProgressIndicator(),
                              ));
                            }
                            return _RepuestoCard(
                                repuesto: _allRepuestos[index]);
                          },
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(8),
                          itemCount: totalItems,
                          itemBuilder: (context, index) {
                            if (index >= _allRepuestos.length) {
                              return const Center(
                                  child: Padding(
                                padding: EdgeInsets.all(16),
                                child: CircularProgressIndicator(),
                              ));
                            }
                            return _RepuestoCard(
                                repuesto: _allRepuestos[index]);
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

  Widget _buildSearchBar(
      BuildContext context, WidgetRef ref, InventarioFiltros filtros) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Buscar por repuesto, vehículo, marca, ubicación...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: filtros.busqueda != null && filtros.busqueda!.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => ref
                      .read(inventarioFiltrosProvider.notifier)
                      .update(
                          (_) => filtros.copyWith(clearBusqueda: true)),
                )
              : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.grey[100],
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          isDense: true,
        ),
        onChanged: (v) => ref
            .read(inventarioFiltrosProvider.notifier)
            .update((_) => filtros.copyWith(
                busqueda: v.isEmpty ? null : v,
                clearBusqueda: v.isEmpty)),
      ),
    );
  }

  Widget _buildFilters(
    BuildContext context,
    WidgetRef ref,
    InventarioFiltros filtros,
    AsyncValue<List<Ubicacion>> ubicaciones,
    AsyncValue<List<Map<String, dynamic>>> marcas,
  ) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          // Estado filter
          _FilterDropdown<String?>(
            value: filtros.estado,
            hint: 'Estado',
            icon: Icons.flag_outlined,
            items: [
              const DropdownMenuItem(
                  value: null,
                  child: Text('Sin vendidos')),
              const DropdownMenuItem(
                  value: '__all__',
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.all_inclusive, size: 14, color: Colors.grey),
                      SizedBox(width: 8),
                      Text('Todos'),
                    ],
                  )),
              ...[
                'disponible',
                'vendido',
                'reservado',
                'faltante',
                'dañado',
                'intercambiado',
                'descartado'
              ].map((e) => DropdownMenuItem(
                  value: e,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _colorForEstado(e),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(e[0].toUpperCase() + e.substring(1)),
                    ],
                  ))),
            ],
            onChanged: (v) => ref
                .read(inventarioFiltrosProvider.notifier)
                .update((_) => v == null
                    ? filtros.copyWith(clearEstado: true)
                    : filtros.copyWith(estado: v)),
          ),

          // Marca filter
          marcas.when(
            data: (list) => _FilterDropdown<String?>(
              value: filtros.marcaNombre,
              hint: 'Marca',
              icon: Icons.directions_car_outlined,
              items: [
                const DropdownMenuItem(value: null, child: Text('Todas')),
                ...list.map((m) => DropdownMenuItem(
                    value: m['nombre'] as String,
                    child: Text(m['nombre'] as String))),
              ],
              onChanged: (v) => ref
                  .read(inventarioFiltrosProvider.notifier)
                  .update((_) => v == null
                      ? filtros.copyWith(clearMarca: true)
                      : filtros.copyWith(marcaNombre: v)),
            ),
            loading: () => const SizedBox(),
            error: (_, _) => const SizedBox(),
          ),

          // Categoría filter
          _FilterDropdown<String?>(
            value: filtros.categoria,
            hint: 'Categoría',
            icon: Icons.category_outlined,
            items: [
              const DropdownMenuItem(value: null, child: Text('Todas')),
              ...AppConstants.categorias
                  .map((c) => DropdownMenuItem(value: c, child: Text(c))),
            ],
            onChanged: (v) => ref
                .read(inventarioFiltrosProvider.notifier)
                .update((_) => v == null
                    ? filtros.copyWith(clearCategoria: true)
                    : filtros.copyWith(categoria: v)),
          ),

          // Ubicación filter
          ubicaciones.when(
            data: (list) => _FilterDropdown<String?>(
              value: filtros.ubicacionId,
              hint: 'Ubicación',
              icon: Icons.location_on_outlined,
              items: [
                const DropdownMenuItem(value: null, child: Text('Todas')),
                ...list.map((u) =>
                    DropdownMenuItem(value: u.id, child: Text(u.nombre))),
              ],
              onChanged: (v) => ref
                  .read(inventarioFiltrosProvider.notifier)
                  .update((_) => v == null
                      ? filtros.copyWith(clearUbicacion: true)
                      : filtros.copyWith(ubicacionId: v)),
            ),
            loading: () => const SizedBox(),
            error: (_, _) => const SizedBox(),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveFilterChips(
    BuildContext context,
    WidgetRef ref,
    InventarioFiltros filtros,
    AsyncValue<List<Ubicacion>> ubicaciones,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: [
          if (filtros.estado != null && filtros.estado != '__all__')
            Chip(
              label: Text(filtros.estado![0].toUpperCase() +
                  filtros.estado!.substring(1)),
              onDeleted: () => ref
                  .read(inventarioFiltrosProvider.notifier)
                  .update((_) => filtros.copyWith(clearEstado: true)),
              backgroundColor:
                  _colorForEstado(filtros.estado!).withValues(alpha: 0.15),
              deleteIconColor: _colorForEstado(filtros.estado!),
              labelStyle: TextStyle(
                color: _colorForEstado(filtros.estado!),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          if (filtros.mostrandoTodos)
            Chip(
              avatar: const Icon(Icons.all_inclusive, size: 14),
              label: const Text('Todos (incl. vendidos)'),
              onDeleted: () => ref
                  .read(inventarioFiltrosProvider.notifier)
                  .update((_) => filtros.copyWith(clearEstado: true)),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          if (filtros.marcaNombre != null)
            Chip(
              avatar: const Icon(Icons.directions_car, size: 14),
              label: Text(filtros.marcaNombre!),
              onDeleted: () => ref
                  .read(inventarioFiltrosProvider.notifier)
                  .update((_) => filtros.copyWith(clearMarca: true)),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          if (filtros.categoria != null)
            Chip(
              avatar: const Icon(Icons.category, size: 14),
              label: Text(filtros.categoria!),
              onDeleted: () => ref
                  .read(inventarioFiltrosProvider.notifier)
                  .update((_) => filtros.copyWith(clearCategoria: true)),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          if (filtros.ubicacionId != null)
            ubicaciones.whenOrNull(
                  data: (list) {
                    final ub = list
                        .where((u) => u.id == filtros.ubicacionId)
                        .firstOrNull;
                    return Chip(
                      avatar: const Icon(Icons.location_on, size: 14),
                      label: Text(ub?.nombre ?? 'Ubicación'),
                      onDeleted: () => ref
                          .read(inventarioFiltrosProvider.notifier)
                          .update(
                              (_) => filtros.copyWith(clearUbicacion: true)),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    );
                  },
                ) ??
                const SizedBox.shrink(),
          ActionChip(
            avatar: const Icon(Icons.clear_all, size: 16),
            label: const Text('Limpiar todo'),
            onPressed: () => ref
                .read(inventarioFiltrosProvider.notifier)
                .update((_) => InventarioFiltros()),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoIngresoExterno(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => const _IngresoExternoDialog(),
    ).then((_) {
      ref.invalidate(inventarioProvider);
      ref.invalidate(inventarioStatsProvider);
    });
  }
}

// ─── Stats Bar ───────────────────────────────────────────────

/// Provider que siempre trae los conteos globales (sin filtros)
final inventarioStatsProvider =
    FutureProvider<Map<String, int>>((ref) async {
  final data = await Supabase.instance.client
      .from('repuestos')
      .select('estado');
  final list = data as List;
  final total = list.length;
  final disponibles = list.where((r) => r['estado'] == 'disponible').length;
  final vendidos = list.where((r) => r['estado'] == 'vendido').length;
  final faltantes = list.where((r) => r['estado'] == 'faltante').length;
  final danados = list.where((r) => r['estado'] == 'dañado').length;
  return {
    'total': total,
    'disponibles': disponibles,
    'vendidos': vendidos,
    'atencion': faltantes + danados,
  };
});

class _StatsBar extends ConsumerWidget {
  const _StatsBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(inventarioStatsProvider);

    return stats.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (s) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.03),
            ],
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _StatItem(
              icon: Icons.inventory_2,
              label: 'Total',
              value: '${s['total']}',
              color: Theme.of(context).colorScheme.primary,
            ),
            _StatItem(
              icon: Icons.check_circle,
              label: 'Disponible',
              value: '${s['disponibles']}',
              color: Colors.green,
            ),
            _StatItem(
              icon: Icons.shopping_cart,
              label: 'Vendido',
              value: '${s['vendidos']}',
              color: Colors.blue,
            ),
            _StatItem(
              icon: Icons.warning_amber,
              label: 'Atención',
              value: '${s['atencion']}',
              color: Colors.orange,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

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
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: color,
              ),
            ),
          ],
        ),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
        ),
      ],
    );
  }
}

// ─── Filter Dropdown Widget ──────────────────────────────────

class _FilterDropdown<T> extends StatelessWidget {
  final T value;
  final String hint;
  final IconData icon;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  const _FilterDropdown({
    required this.value,
    required this.hint,
    required this.icon,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = value != null;
    final primaryColor = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: isActive
              ? primaryColor.withValues(alpha: 0.1)
              : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? primaryColor : Colors.grey[300]!,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16,
                color: isActive ? primaryColor : Colors.grey[600]),
            const SizedBox(width: 4),
            Text(
              '$hint:',
              style: TextStyle(
                fontSize: 11,
                color: isActive ? primaryColor : Colors.grey[600],
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 2),
            DropdownButtonHideUnderline(
              child: DropdownButton<T>(
                value: value,
                hint: Text('Todos',
                    style: TextStyle(fontSize: 13, color: Colors.grey[500])),
                isDense: true,
                icon: Icon(Icons.arrow_drop_down,
                    size: 18,
                    color: isActive ? primaryColor : Colors.grey[600]),
                items: items,
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Repuesto Card (Redesigned) ──────────────────────────────

class _RepuestoCard extends StatelessWidget {
  final Repuesto repuesto;
  const _RepuestoCard({required this.repuesto});

  @override
  Widget build(BuildContext context) {
    final estadoColor = _colorForEstado(repuesto.estado);
    final hasVehicle = repuesto.vehiculoMarca != null;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: estadoColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showRepuestoDetail(context, repuesto),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: Estado badge + Price
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: estadoColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_iconForEstado(repuesto.estado),
                            size: 14, color: estadoColor),
                        const SizedBox(width: 4),
                        Text(
                          repuesto.estado[0].toUpperCase() +
                              repuesto.estado.substring(1),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: estadoColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (repuesto.precioSugerido != null)
                    Text(
                      '\$${repuesto.precioSugerido!.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.green,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),

              // Part name
              Text(
                repuesto.parteNombre ?? 'Sin nombre',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),

              // Category
              if (repuesto.parteCategoria != null)
                Text(
                  repuesto.parteCategoria!,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              const SizedBox(height: 8),

              // Vehicle info row
              if (hasVehicle)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.directions_car,
                          size: 14, color: Colors.blueGrey),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          '${repuesto.vehiculoMarca ?? ""} ${repuesto.vehiculoModelo ?? ""} ${repuesto.vehiculoAnio ?? ""}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.blueGrey,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

              if (!hasVehicle && repuesto.origen == 'externo')
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.local_shipping,
                          size: 14, color: Colors.amber[700]),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Externo${repuesto.proveedorExterno != null ? " · ${repuesto.proveedorExterno}" : ""}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.amber[800],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 6),

              // Bottom row: Location + chevron
              Row(
                children: [
                  if (repuesto.ubicacionNombre != null) ...[
                    Icon(Icons.location_on, size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        repuesto.ubicacionNombre!,
                        style:
                            TextStyle(fontSize: 12, color: Colors.grey[600]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ] else
                    const Spacer(),
                  Icon(Icons.chevron_right, size: 18, color: Colors.grey[400]),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Repuesto Detail Bottom Sheet ────────────────────────────

void _showRepuestoDetail(BuildContext context, Repuesto r) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.65,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      expand: false,
      builder: (context, scrollController) => SingleChildScrollView(
        controller: scrollController,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header: Name + Estado
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    r.parteNombre ?? 'Sin nombre',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color:
                        _colorForEstado(r.estado).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_iconForEstado(r.estado),
                          size: 16, color: _colorForEstado(r.estado)),
                      const SizedBox(width: 4),
                      Text(
                        r.estado[0].toUpperCase() + r.estado.substring(1),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _colorForEstado(r.estado),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            if (r.parteCategoria != null) ...[
              const SizedBox(height: 4),
              Chip(
                avatar: const Icon(Icons.category, size: 14),
                label: Text(r.parteCategoria!),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
            const Divider(height: 24),

            // Vehicle info section
            if (r.vehiculoMarca != null) ...[
              _DetailSection(
                icon: Icons.directions_car,
                title: 'Vehículo',
                children: [
                  _DetailRow('Marca', r.vehiculoMarca!),
                  if (r.vehiculoModelo != null)
                    _DetailRow('Modelo', r.vehiculoModelo!),
                  if (r.vehiculoAnio != null)
                    _DetailRow('Año', '${r.vehiculoAnio}'),
                ],
              ),
              const Divider(height: 24),
            ],

            // Location & Origin
            _DetailSection(
              icon: Icons.info_outline,
              title: 'Información',
              children: [
                if (r.ubicacionNombre != null)
                  _DetailRow('Ubicación', r.ubicacionNombre!),
                _DetailRow(
                    'Origen', r.origen == 'externo' ? 'Externo' : 'Vehículo'),
                if (r.proveedorExterno != null)
                  _DetailRow('Proveedor', r.proveedorExterno!),
              ],
            ),
            const Divider(height: 24),

            // Pricing
            _DetailSection(
              icon: Icons.attach_money,
              title: 'Precios',
              children: [
                if (r.precioSugerido != null)
                  _DetailRow('Precio sugerido',
                      '\$${r.precioSugerido!.toStringAsFixed(2)}'),
                if (r.costoExterno != null)
                  _DetailRow('Costo externo',
                      '\$${r.costoExterno!.toStringAsFixed(2)}'),
                if (r.precioSugerido == null && r.costoExterno == null)
                  const _DetailRow('Sin precios', 'No definido'),
              ],
            ),

            // Notes
            if (r.notas != null && r.notas!.isNotEmpty) ...[
              const Divider(height: 24),
              _DetailSection(
                icon: Icons.notes,
                title: 'Notas',
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child:
                        Text(r.notas!, style: const TextStyle(fontSize: 14)),
                  ),
                ],
              ),
            ],

            // Date
            const Divider(height: 24),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 14, color: Colors.grey[500]),
                const SizedBox(width: 6),
                Text(
                  'Registrado: ${_formatDate(r.createdAt)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── Actions: Trasladar ──
            if (r.estado == 'disponible')
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _showTrasladarDialog(context, r);
                  },
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text('Mover a otra bodega'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.deepPurple,
                  ),
                ),
              ),
            const SizedBox(height: 8),

            // Back button (for mobile APK)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Volver al inventario'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

String _formatDate(DateTime dt) {
  return '${dt.day.toString().padLeft(2, "0")}/${dt.month.toString().padLeft(2, "0")}/${dt.year}';
}

// ─── Diálogo de Traslado entre bodegas ───────────────────────

void _showTrasladarDialog(BuildContext context, Repuesto repuesto) {
  showDialog(
    context: context,
    builder: (_) => _TrasladarDialog(repuesto: repuesto),
  );
}

class _TrasladarDialog extends ConsumerStatefulWidget {
  final Repuesto repuesto;
  const _TrasladarDialog({required this.repuesto});

  @override
  ConsumerState<_TrasladarDialog> createState() => _TrasladarDialogState();
}

class _TrasladarDialogState extends ConsumerState<_TrasladarDialog> {
  String? _ubicacionDestinoId;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final ubicaciones = ref.watch(ubicacionesInventarioProvider);

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.swap_horiz, color: Colors.deepPurple),
          SizedBox(width: 8),
          Text('Trasladar Repuesto'),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.repuesto.parteNombre ?? 'Repuesto',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            if (widget.repuesto.ubicacionNombre != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Ubicación actual: ${widget.repuesto.ubicacionNombre}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ),
            const SizedBox(height: 16),
            ubicaciones.when(
              data: (list) {
                // Excluir la ubicación actual
                final destinos = list
                    .where((u) => u.id != widget.repuesto.ubicacionId)
                    .toList();

                return DropdownButtonFormField<String>(
                  initialValue: _ubicacionDestinoId,
                  decoration: const InputDecoration(
                    labelText: 'Bodega destino *',
                    isDense: true,
                  ),
                  items: destinos
                      .map((u) =>
                          DropdownMenuItem(value: u.id, child: Text(u.nombre)))
                      .toList(),
                  onChanged: (v) =>
                      setState(() => _ubicacionDestinoId = v),
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Error: $e'),
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
          onPressed: _saving || _ubicacionDestinoId == null
              ? null
              : _trasladar,
          child: _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Trasladar'),
        ),
      ],
    );
  }

  Future<void> _trasladar() async {
    setState(() => _saving = true);

    try {
      final perfilId = ref.read(authProvider).perfil!.id;
      await Supabase.instance.client.rpc('trasladar_repuestos', params: {
        'p_repuesto_ids': [widget.repuesto.id],
        'p_ubicacion_destino_id': _ubicacionDestinoId,
        'p_usuario_id': perfilId,
      });

      ref.invalidate(inventarioProvider);
      ref.invalidate(inventarioStatsProvider);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Repuesto trasladado exitosamente'),
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

// ─── Detail Section Widget ───────────────────────────────────

class _DetailSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<Widget> children;

  const _DetailSection({
    required this.icon,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4, left: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Color & Icon helpers ────────────────────────────────────

Color _colorForEstado(String estado) {
  switch (estado) {
    case 'disponible':
      return Colors.green;
    case 'vendido':
      return Colors.blue;
    case 'reservado':
      return Colors.orange;
    case 'faltante':
      return Colors.red;
    case 'dañado':
      return Colors.deepOrange;
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
    case 'reservado':
      return Icons.bookmark;
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

// ─── Ingreso Externo Dialog ──────────────────────────────────

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
  String? _extMarcaId;
  String? _extModeloId;
  String? _proveedorId;
  final _extAnioCtrl = TextEditingController();
  final _costoCtrl = TextEditingController();
  final _precioCtrl = TextEditingController();
  final _notasCtrl = TextEditingController();
  bool _saving = false;

  final _partesProvider =
      FutureProvider<List<Map<String, dynamic>>>((ref) async {
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
    _extAnioCtrl.dispose();
    _costoCtrl.dispose();
    _precioCtrl.dispose();
    _notasCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final partes = ref.watch(_partesProvider);
    final ubicaciones = ref.watch(ubicacionesInventarioProvider);
    final marcas = ref.watch(marcasExternoProvider);
    final proveedores = ref.watch(proveedoresExternoProvider);

    return AlertDialog(
      title: const Text('Ingreso Externo de Repuesto'),
      content: SizedBox(
        width: 450,
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
                const SizedBox(height: 16),

                // --- Vehículo de origen del repuesto ---
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Vehículo de origen',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.grey,
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Marca del vehículo
                marcas.when(
                  data: (list) => DropdownButtonFormField<String>(
                    initialValue: _extMarcaId,
                    decoration: const InputDecoration(
                      labelText: 'Marca del vehículo',
                      isDense: true,
                    ),
                    isExpanded: true,
                    items: list
                        .map((m) => DropdownMenuItem(
                            value: m.id, child: Text(m.nombre)))
                        .toList(),
                    onChanged: (v) => setState(() {
                      _extMarcaId = v;
                      _extModeloId = null;
                    }),
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('Error: $e'),
                ),
                const SizedBox(height: 12),

                // Modelo del vehículo (dependiente de marca)
                if (_extMarcaId != null)
                  ref.watch(modelosExternoProvider(_extMarcaId!)).when(
                        data: (list) => DropdownButtonFormField<String>(
                          initialValue: _extModeloId,
                          decoration: const InputDecoration(
                            labelText: 'Modelo del vehículo',
                            isDense: true,
                          ),
                          isExpanded: true,
                          items: list
                              .map((m) => DropdownMenuItem(
                                  value: m.id, child: Text(m.nombre)))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _extModeloId = v),
                        ),
                        loading: () => const LinearProgressIndicator(),
                        error: (e, _) => Text('Error: $e'),
                      ),
                if (_extMarcaId != null) const SizedBox(height: 12),

                // Año del vehículo
                TextFormField(
                  controller: _extAnioCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Año del vehículo',
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),

                // --- Datos de compra ---
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Datos de compra',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.grey,
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Proveedor (dropdown)
                proveedores.when(
                  data: (list) => DropdownButtonFormField<String>(
                    initialValue: _proveedorId,
                    decoration: const InputDecoration(
                      labelText: 'Proveedor *',
                      isDense: true,
                    ),
                    isExpanded: true,
                    items: list
                        .map((p) => DropdownMenuItem(
                            value: p.id, child: Text(p.nombre)))
                        .toList(),
                    onChanged: (v) => setState(() => _proveedorId = v),
                    validator: (v) =>
                        v == null ? 'Seleccione proveedor' : null,
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('Error: $e'),
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
      final auth = ref.read(authProvider);
      final userId = auth.perfil!.id;

      // Obtener nombre del proveedor para notas
      String proveedorNombre = '';
      if (_proveedorId != null) {
        final provList = ref.read(proveedoresExternoProvider).value ?? [];
        final prov = provList.where((p) => p.id == _proveedorId).firstOrNull;
        proveedorNombre = prov?.nombre ?? '';
      }

      // Crear repuesto externo
      final repuesto = await supabase.from('repuestos').insert({
        'catalogo_parte_id': _parteId,
        'estado': 'disponible',
        'ubicacion_id': _ubicacionId,
        'precio_sugerido': _precioCtrl.text.isNotEmpty
            ? double.parse(_precioCtrl.text)
            : null,
        'origen': 'externo',
        'proveedor_externo': proveedorNombre,
        'costo_externo': double.parse(_costoCtrl.text),
        'notas': _notasCtrl.text.isEmpty ? null : _notasCtrl.text,
        'ext_marca_id': _extMarcaId,
        'ext_modelo_id': _extModeloId,
        'ext_anio': _extAnioCtrl.text.isNotEmpty
            ? int.parse(_extAnioCtrl.text)
            : null,
      }).select('id').single();

      // Crear movimiento
      await supabase.from('movimientos').insert({
        'repuesto_id': repuesto['id'],
        'tipo': 'ingreso_externo',
        'fecha': DateTime.now().toIso8601String(),
        'usuario_id': userId,
        'ubicacion_destino_id': _ubicacionId,
        'notas': 'Ingreso externo: $proveedorNombre',
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
