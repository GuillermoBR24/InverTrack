import 'package:flutter/material.dart';
import '../services/market_service.dart';
import 'asset_detail_invest_screen.dart';

class AddAssetScreen extends StatefulWidget {
  const AddAssetScreen({super.key});

  @override
  State<AddAssetScreen> createState() => _AddAssetScreenState();
}

class _AddAssetScreenState extends State<AddAssetScreen> {
  String _searchQuery     = '';
  String _selectedType    = 'crypto';
  bool   _isLoading       = true;
  String? _error;
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _allAssets = [];

  static const Map<String, String> _typeLabels = {
    'crypto': 'Cripto',
    'stock':  'Acciones',
    'etf':    'ETFs',
  };

  static const Map<String, Color> _typeColors = {
    'crypto': Color(0xFFF7931A),
    'stock':  Color(0xFF4FC3F7),
    'etf':    Color(0xFF69F0AE),
  };

  @override
  void initState() {
    super.initState();
    _loadAssets();
  }

  Future<void> _loadAssets() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final assets = await MarketService.fetchAllAssets();
      if (mounted) setState(() { _allAssets = assets; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = 'Error al cargar activos'; _isLoading = false; });
    }
  }

  List<Map<String, dynamic>> get _filtered {
    return _allAssets.where((a) {
      final matchType  = a['type'] == _selectedType;
      final matchQuery = _searchQuery.isEmpty ||
          (a['name']   as String).toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (a['symbol'] as String).toLowerCase().contains(_searchQuery.toLowerCase());
      return matchType && matchQuery;
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tt     = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    const cardColor   = Color(0xFF1E2D3D);
    const borderColor = Color(0xFF1E3A5F);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Añadir activo',
            style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
        actions: [
          // Botón recargar precios
          if (!_isLoading)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Actualizar precios',
              onPressed: _loadAssets,
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(
              children: [
                // ── SELECTOR DE TIPO ───────────────────────────────────
                Row(
                  children: _typeLabels.entries.map((e) {
                    final isSelected = _selectedType == e.key;
                    final color      = _typeColors[e.key]!;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _selectedType = e.key;
                          _searchController.clear();
                          _searchQuery = '';
                        }),
                        child: Container(
                          margin: EdgeInsets.only(right: e.key != 'etf' ? 10 : 0),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          decoration: BoxDecoration(
                            color: isSelected ? color.withOpacity(0.15) : cardColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? color : borderColor,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Text(e.value,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: isSelected ? color : const Color(0xFF7BA7C2),
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              )),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),

                // ── BUSCADOR ───────────────────────────────────────────
                TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: InputDecoration(
                    hintText: 'Buscar por nombre o símbolo...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),

          // ── LISTA ──────────────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: scheme.primary),
                        const SizedBox(height: 16),
                        Text('Cargando precios en tiempo real...',
                            style: tt.bodyMedium),
                      ],
                    ),
                  )
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.wifi_off_rounded,
                                size: 48, color: Color(0xFF7BA7C2)),
                            const SizedBox(height: 12),
                            Text(_error!, style: tt.bodyMedium),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _loadAssets,
                              icon: const Icon(Icons.refresh_rounded, size: 16),
                              label: const Text('Reintentar'),
                            ),
                          ],
                        ),
                      )
                    : _filtered.isEmpty
                        ? Center(
                            child: Text('No se encontraron activos',
                                style: tt.bodyMedium))
                        : RefreshIndicator(
                            color: scheme.primary,
                            onRefresh: _loadAssets,
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                              itemCount: _filtered.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (_, i) {
                                final asset = _filtered[i];
                                final color = _typeColors[asset['type']]!;
                                final price  = (asset['price'] as num?)?.toDouble() ?? 0.0;
                                final change = (asset['change'] as num?)?.toDouble() ?? 0.0;
                                final isPos  = change >= 0;

                                return GestureDetector(
                                  onTap: () async {
                                    final result =
                                        await Navigator.push<Map<String, dynamic>>(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            AssetDetailInvestScreen(asset: asset),
                                      ),
                                    );
                                    if (result != null && context.mounted) {
                                      Navigator.pop(context, result);
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 14),
                                    decoration: BoxDecoration(
                                      color: cardColor,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: borderColor),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 44, height: 44,
                                          decoration: BoxDecoration(
                                            color: color.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(asset['icon'] as String,
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: color,
                                              )),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(asset['name'] as String,
                                                  style: tt.bodyLarge?.copyWith(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w600)),
                                              Text(asset['symbol'] as String,
                                                  style: tt.bodyMedium
                                                      ?.copyWith(fontSize: 12)),
                                            ],
                                          ),
                                        ),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              price > 0
                                                  ? '\$${price.toStringAsFixed(2)}'
                                                  : '—',
                                              style: tt.bodyLarge?.copyWith(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600),
                                            ),
                                            const SizedBox(height: 4),
                                            if (price > 0)
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 7, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: (isPos
                                                          ? const Color(0xFF69F0AE)
                                                          : const Color(0xFFFF6B6B))
                                                      .withOpacity(0.12),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  '${isPos ? '+' : ''}${change.toStringAsFixed(2)}%',
                                                  style: TextStyle(
                                                    color: isPos
                                                        ? const Color(0xFF69F0AE)
                                                        : const Color(0xFFFF6B6B),
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(width: 8),
                                        const Icon(Icons.chevron_right_rounded,
                                            color: Color(0xFF7BA7C2), size: 18),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}