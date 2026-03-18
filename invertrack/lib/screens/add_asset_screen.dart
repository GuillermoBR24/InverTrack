import 'package:flutter/material.dart';
import 'asset_detail_invest_screen.dart';

class AddAssetScreen extends StatefulWidget {
  const AddAssetScreen({super.key});

  @override
  State<AddAssetScreen> createState() => _AddAssetScreenState();
}

class _AddAssetScreenState extends State<AddAssetScreen> {
  String _searchQuery    = '';
  String _selectedType   = 'crypto';
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

  // ── Lista de ejemplo — reemplazar por API en tiempo real ─────────────────────
  final List<Map<String, dynamic>> _availableAssets = [
    // CRYPTO
    {
      'name': 'Bitcoin', 'symbol': 'BTC', 'type': 'crypto', 'icon': '₿',
      'price': 67432.50, 'change': 3.24,
      'market_cap': '1.32T', 'volume_24h': '28.4B',
      'circ_supply': '19.7M', 'max_supply': '21M',
      'hash_rate': '620 EH/s', 'active_addresses': '1.1M',
      'community_score': 92, 'has_product': true,
    },
    {
      'name': 'Ethereum', 'symbol': 'ETH', 'type': 'crypto', 'icon': 'Ξ',
      'price': 3512.80, 'change': -1.47,
      'market_cap': '422B', 'volume_24h': '14.2B',
      'circ_supply': '120.2M', 'max_supply': '∞',
      'tvl': '48.2B', 'active_addresses': '650K',
      'community_score': 95, 'has_product': true,
    },
    {
      'name': 'Solana', 'symbol': 'SOL', 'type': 'crypto', 'icon': 'S',
      'price': 178.40, 'change': 5.12,
      'market_cap': '82B', 'volume_24h': '4.1B',
      'circ_supply': '460M', 'max_supply': '∞',
      'tvl': '5.8B', 'active_addresses': '400K',
      'community_score': 88, 'has_product': true,
    },
    {
      'name': 'BNB', 'symbol': 'BNB', 'type': 'crypto', 'icon': 'B',
      'price': 605.30, 'change': 0.87,
      'market_cap': '88B', 'volume_24h': '1.9B',
      'circ_supply': '145.8M', 'max_supply': '200M',
      'tvl': '6.1B', 'active_addresses': '320K',
      'community_score': 80, 'has_product': true,
    },
    {
      'name': 'XRP', 'symbol': 'XRP', 'type': 'crypto', 'icon': 'X',
      'price': 0.62, 'change': -0.54,
      'market_cap': '34B', 'volume_24h': '1.2B',
      'circ_supply': '54.9B', 'max_supply': '100B',
      'active_addresses': '210K',
      'community_score': 75, 'has_product': true,
    },
    // STOCKS
    {
      'name': 'Apple Inc.', 'symbol': 'AAPL', 'type': 'stock', 'icon': 'A',
      'price': 189.30, 'change': 0.85,
      'pe_ratio': 29.4, 'eps': 6.43, 'roe': 147.9,
      'debt_equity': 1.76, 'dividend_yield': 0.52, 'free_cash_flow': '99.6B',
      'market_cap': '2.93T', 'sector': 'Tecnología',
    },
    {
      'name': 'Tesla', 'symbol': 'TSLA', 'type': 'stock', 'icon': 'T',
      'price': 242.10, 'change': -2.13,
      'pe_ratio': 62.1, 'eps': 3.90, 'roe': 17.4,
      'debt_equity': 0.18, 'dividend_yield': 0.0, 'free_cash_flow': '2.6B',
      'market_cap': '771B', 'sector': 'Automoción / Energía',
    },
    {
      'name': 'Microsoft', 'symbol': 'MSFT', 'type': 'stock', 'icon': 'M',
      'price': 415.20, 'change': 1.02,
      'pe_ratio': 35.8, 'eps': 11.59, 'roe': 38.5,
      'debt_equity': 0.35, 'dividend_yield': 0.72, 'free_cash_flow': '70.2B',
      'market_cap': '3.08T', 'sector': 'Tecnología',
    },
    {
      'name': 'Nvidia', 'symbol': 'NVDA', 'type': 'stock', 'icon': 'N',
      'price': 878.40, 'change': 4.21,
      'pe_ratio': 68.3, 'eps': 12.85, 'roe': 91.2,
      'debt_equity': 0.42, 'dividend_yield': 0.03, 'free_cash_flow': '27.0B',
      'market_cap': '2.16T', 'sector': 'Semiconductores',
    },
    {
      'name': 'Amazon', 'symbol': 'AMZN', 'type': 'stock', 'icon': 'A',
      'price': 192.50, 'change': 0.64,
      'pe_ratio': 52.4, 'eps': 3.67, 'roe': 22.1,
      'debt_equity': 0.55, 'dividend_yield': 0.0, 'free_cash_flow': '32.3B',
      'market_cap': '2.01T', 'sector': 'Tecnología / Retail',
    },
    // ETFs
    {
      'name': 'S&P 500 ETF', 'symbol': 'SPY', 'type': 'etf', 'icon': 'S',
      'price': 521.40, 'change': 0.44,
      'expense_ratio': 0.0945, 'tracking_error': 0.02,
      'index': 'S&P 500', 'structure': 'Réplica total',
      'aum': '523B', 'dividend_yield': 1.32, 'avg_volume': '80M',
    },
    {
      'name': 'Nasdaq ETF', 'symbol': 'QQQ', 'type': 'etf', 'icon': 'Q',
      'price': 448.70, 'change': 0.91,
      'expense_ratio': 0.20, 'tracking_error': 0.04,
      'index': 'Nasdaq-100', 'structure': 'Réplica total',
      'aum': '259B', 'dividend_yield': 0.58, 'avg_volume': '42M',
    },
    {
      'name': 'Gold ETF', 'symbol': 'GLD', 'type': 'etf', 'icon': 'G',
      'price': 213.80, 'change': -0.22,
      'expense_ratio': 0.40, 'tracking_error': 0.05,
      'index': 'Precio del Oro', 'structure': 'Respaldado físicamente',
      'aum': '57B', 'dividend_yield': 0.0, 'avg_volume': '8M',
    },
    {
      'name': 'iShares MSCI', 'symbol': 'EEM', 'type': 'etf', 'icon': 'I',
      'price': 42.30, 'change': -0.38,
      'expense_ratio': 0.68, 'tracking_error': 0.08,
      'index': 'MSCI Emerging Markets', 'structure': 'Réplica total',
      'aum': '18B', 'dividend_yield': 2.41, 'avg_volume': '32M',
    },
  ];

  List<Map<String, dynamic>> get _filtered {
    return _availableAssets.where((a) {
      final matchType  = a['type'] == _selectedType;
      final matchQuery = _searchQuery.isEmpty ||
          (a['name'] as String).toLowerCase().contains(_searchQuery.toLowerCase()) ||
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
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(
              children: [
                // ── SELECTOR DE TIPO ─────────────────────────────────────
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
                          margin: EdgeInsets.only(
                              right: e.key != 'etf' ? 10 : 0),
                          padding: const EdgeInsets.symmetric(vertical: 11),
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

                // ── BUSCADOR ─────────────────────────────────────────────
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

          // ── LISTA ────────────────────────────────────────────────────
          Expanded(
            child: _filtered.isEmpty
                ? Center(
                    child: Text('No se encontraron activos',
                        style: tt.bodyMedium))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                    itemCount: _filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final asset = _filtered[i];
                      final color = _typeColors[asset['type']]!;
                      final isPos = (asset['change'] as double) >= 0;

                      return GestureDetector(
                        onTap: () async {
                          final result =
                              await Navigator.push<Map<String, dynamic>>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AssetDetailInvestScreen(
                                  asset: asset),
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
                              // Icono
                              Container(
                                width: 44, height: 44,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0A0E1A),
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

                              // Nombre + símbolo
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
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

                              // Precio + variación
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '\$${(asset['price'] as double).toStringAsFixed(2)}',
                                    style: tt.bodyLarge?.copyWith(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: (isPos
                                              ? const Color(0xFF69F0AE)
                                              : const Color(0xFFFF6B6B))
                                          .withOpacity(0.12),
                                      borderRadius:
                                          BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '${isPos ? '+' : ''}${(asset['change'] as double).toStringAsFixed(2)}%',
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
        ],
      ),
    );
  }
}