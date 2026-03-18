import 'dart:async';
import 'package:flutter/material.dart';
import '../services/market_service.dart';
import 'asset_detail_invest_screen.dart';

class AddAssetScreen extends StatefulWidget {
  const AddAssetScreen({super.key});

  @override
  State<AddAssetScreen> createState() => _AddAssetScreenState();
}

class _AddAssetScreenState extends State<AddAssetScreen> {
  String _selectedType = 'crypto';
  bool   _isSearching  = false;
  bool   _isLoadingPrice = false;
  bool   _isLoadingTop    = false;
  String? _error;
  List<Map<String, dynamic>> _results = [];
  List<Map<String, dynamic>> _top10    = [];
  Timer? _debounce;
  final _searchController = TextEditingController();

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
    _loadTop10();  // ← carga top al entrar
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() { _results = []; _isSearching = false; _error = null; });
      return;
    }
    setState(() => _isSearching = true);
    _debounce = Timer(const Duration(milliseconds: 500), () => _search(query));
  }

  Future<void> _loadTop10() async {
    setState(() { _isLoadingTop = true; _error = null; });
    try {
      final top = await MarketService.fetchTop10(_selectedType);
      if (mounted) setState(() { _top10 = top; _isLoadingTop = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoadingTop = false);
    }
  }

  Future<void> _search(String query) async {
    setState(() { _isSearching = true; _error = null; });
    try {
      List<Map<String, dynamic>> results;
      if (_selectedType == 'crypto') {
        results = await MarketService.searchCrypto(query);
      } else {
        results = await MarketService.searchStocksAndEtfs(query, _selectedType);
      }
      if (mounted) setState(() { _results = results; _isSearching = false; });
    } catch (e) {
      if (mounted) setState(() {
        _error = 'Error al buscar. Comprueba tu conexión.';
        _isSearching = false;
      });
    }
  }

  /// Al tocar un resultado primero carga el precio y métricas, luego navega
  Future<void> _onAssetTap(Map<String, dynamic> asset) async {
    setState(() => _isLoadingPrice = true);
    try {
      Map<String, dynamic>? live;
      if (_selectedType == 'crypto') {
        final id = asset['coingecko_id'] as String?;
        if (id != null) {
          live = await MarketService.fetchCryptoById(id, asset['symbol'] as String);
        }
      } else {
        live = await MarketService.fetchAsset(
          asset['symbol'] as String,
          asset['type']   as String,
        );
      }

      if (!mounted) return;
      final enriched = live != null ? {...asset, ...live} : asset;

      final result = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(
          builder: (_) => AssetDetailInvestScreen(asset: enriched),
        ),
      );
      if (result != null && context.mounted) {
        Navigator.pop(context, result);
      }
    } finally {
      if (mounted) setState(() => _isLoadingPrice = false);
    }
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
      ),

      // Overlay de carga al obtener precio del activo seleccionado
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Column(
                  children: [

                    // ── SELECTOR DE TIPO ─────────────────────────────────
                    Row(
                      children: _typeLabels.entries.map((e) {
                        final isSelected = _selectedType == e.key;
                        final color      = _typeColors[e.key]!;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedType = e.key;
                                _results      = [];
                                _error        = null;
                                _searchController.clear();
                              });
                              _loadTop10();  // recarga top al cambiar tipo
                            },
                            child: Container(
                              margin: EdgeInsets.only(
                                  right: e.key != 'etf' ? 10 : 0),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 11),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? color.withOpacity(0.15)
                                    : cardColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected ? color : borderColor,
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: Text(e.value,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: isSelected
                                        ? color
                                        : const Color(0xFF7BA7C2),
                                    fontSize: 13,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  )),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 12),

                    // ── BUSCADOR ─────────────────────────────────────────
                    TextField(
                      controller: _searchController,
                      autofocus: true,
                      onChanged: _onSearchChanged,
                      decoration: InputDecoration(
                        hintText: _selectedType == 'crypto'
                            ? 'Busca cualquier criptomoneda...'
                            : _selectedType == 'stock'
                                ? 'Busca cualquier acción (AAPL, Tesla...)'
                                : 'Busca cualquier ETF (SPY, QQQ...)',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close_rounded),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _results   = [];
                                    _error     = null;
                                    _isSearching = false;
                                  });
                                },
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),

              // ── CONTENIDO ──────────────────────────────────────────────
              Expanded(
                child: _isSearching
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: scheme.primary),
                            const SizedBox(height: 12),
                            Text('Buscando...', style: tt.bodyMedium),
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
                              ],
                            ),
                          )
                        : _results.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _selectedType == 'crypto'
                                          ? Icons.currency_bitcoin_rounded
                                          : _selectedType == 'stock'
                                              ? Icons.show_chart_rounded
                                              : Icons.donut_small_rounded,
                                      size: 52,
                                      color: _typeColors[_selectedType]!
                                          .withOpacity(0.4),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      _searchController.text.isEmpty
                                          ? 'Escribe para buscar ${_typeLabels[_selectedType]}'
                                          : 'Sin resultados para "${_searchController.text}"',
                                      style: tt.bodyMedium,
                                      textAlign: TextAlign.center,
                                    ),
                                    if (_selectedType != 'crypto') ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        'Prueba con el símbolo exacto\nej. AAPL, MSFT, SPY',
                                        style: tt.bodyMedium
                                            ?.copyWith(fontSize: 12),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ],
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                                itemCount: _results.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (_, i) {
                                  final asset = _results[i];
                                  final color =
                                      _typeColors[asset['type']]!;
                                  final price = (asset['price'] as num?)
                                          ?.toDouble() ??
                                      0.0;
                                  final change = (asset['change'] as num?)
                                          ?.toDouble() ??
                                      0.0;
                                  final isPos = change >= 0;
                                  final thumb =
                                      asset['thumb'] as String? ?? '';

                                  return GestureDetector(
                                    onTap: () => _onAssetTap(asset),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 14),
                                      decoration: BoxDecoration(
                                        color: cardColor,
                                        borderRadius:
                                            BorderRadius.circular(14),
                                        border:
                                            Border.all(color: borderColor),
                                      ),
                                      child: Row(
                                        children: [
                                          // Icono/thumb
                                          Container(
                                            width: 44, height: 44,
                                            decoration: BoxDecoration(
                                              color:
                                                  color.withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            alignment: Alignment.center,
                                            child: thumb.isNotEmpty
                                                ? ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10),
                                                    child: Image.network(
                                                      thumb,
                                                      width: 28,
                                                      height: 28,
                                                      fit: BoxFit.contain,
                                                      errorBuilder: (_, __, ___) =>
                                                          Text(
                                                        asset['icon']
                                                            as String,
                                                        style: TextStyle(
                                                          fontSize: 18,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: color,
                                                        ),
                                                      ),
                                                    ),
                                                  )
                                                : Text(
                                                    asset['icon'] as String,
                                                    style: TextStyle(
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: color,
                                                    ),
                                                  ),
                                          ),
                                          const SizedBox(width: 14),

                                          // Nombre + símbolo
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  asset['name'] as String,
                                                  style: tt.bodyLarge
                                                      ?.copyWith(
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight
                                                                  .w600),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                Text(
                                                  asset['symbol'] as String,
                                                  style: tt.bodyMedium
                                                      ?.copyWith(
                                                          fontSize: 12),
                                                ),
                                              ],
                                            ),
                                          ),

                                          // Precio si ya tiene
                                          if (price > 0) ...[
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.end,
                                              children: [
                                                Text(
                                                  '\$${price.toStringAsFixed(2)}',
                                                  style: tt.bodyLarge
                                                      ?.copyWith(
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight
                                                                  .w600),
                                                ),
                                                const SizedBox(height: 4),
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 7,
                                                      vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: (isPos
                                                            ? const Color(
                                                                0xFF69F0AE)
                                                            : const Color(
                                                                0xFFFF6B6B))
                                                        .withOpacity(0.12),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            6),
                                                  ),
                                                  child: Text(
                                                    '${isPos ? '+' : ''}${change.toStringAsFixed(2)}%',
                                                    style: TextStyle(
                                                      color: isPos
                                                          ? const Color(
                                                              0xFF69F0AE)
                                                          : const Color(
                                                              0xFFFF6B6B),
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],

                                          const SizedBox(width: 8),
                                          const Icon(
                                              Icons.chevron_right_rounded,
                                              color: Color(0xFF7BA7C2),
                                              size: 18),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
              ),
            ],
          ),

          // Overlay carga al seleccionar activo
          if (_isLoadingPrice)
            Container(
              color: Colors.black54,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 28, vertical: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E2D3D),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF1E3A5F)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: scheme.primary),
                      const SizedBox(height: 14),
                      Text('Cargando datos del activo...',
                          style: tt.bodyMedium),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}