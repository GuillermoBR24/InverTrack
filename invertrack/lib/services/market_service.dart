import 'dart:convert';
import 'package:http/http.dart' as http;

class MarketService {
  static const _coinGeckoBase = 'https://api.coingecko.com/api/v3';
  static const _finnhubBase   = 'https://finnhub.io/api/v1';

  // ── SUSTITUYE CON TUS KEYS ───────────────────────────────────────────────────
  static const _coinGeckoKey = 'CG-5oVoUJHTDAbbRsyDt4CzokGa';
  static const _finnhubKey   = 'd6tbb41r01qhkb43fpn0d6tbb41r01qhkb43fpng';

  // Mapa símbolo CoinGecko → id de la API
  static const Map<String, String> _cryptoIds = {
    'BTC':  'bitcoin',
    'ETH':  'ethereum',
    'SOL':  'solana',
    'BNB':  'binancecoin',
    'XRP':  'ripple',
  };

  // ── FORMATEO DE NÚMEROS GRANDES ──────────────────────────────────────────────
  static String formatLargeNumber(double n) {
    if (n >= 1e12) return '${(n / 1e12).toStringAsFixed(2)}T';
    if (n >= 1e9)  return '${(n / 1e9).toStringAsFixed(2)}B';
    if (n >= 1e6)  return '${(n / 1e6).toStringAsFixed(2)}M';
    if (n >= 1e3)  return '${(n / 1e3).toStringAsFixed(2)}K';
    return n.toStringAsFixed(2);
  }

  // ────────────────────────────────────────────────────────────────────────────
  // CRYPTO — CoinGecko
  // ────────────────────────────────────────────────────────────────────────────

  /// Devuelve datos en tiempo real de una cripto por símbolo (BTC, ETH, etc.)
  static Future<Map<String, dynamic>?> fetchCrypto(String symbol) async {
    final id = _cryptoIds[symbol.toUpperCase()];
    if (id == null) return null;

    try {
      final uri = Uri.parse(
        '$_coinGeckoBase/coins/$id'
        '?localization=false&tickers=false&market_data=true'
        '&community_data=true&developer_data=false',
      );

      final res = await http.get(uri, headers: {
        'x-cg-demo-api-key': _coinGeckoKey,
      }).timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) return null;

      final data   = jsonDecode(res.body);
      final market = data['market_data'];
      final comm   = data['community_data'];

      final price     = (market['current_price']['usd'] as num).toDouble();
      final change24h = (market['price_change_percentage_24h'] as num?)?.toDouble() ?? 0.0;
      final marketCap = (market['market_cap']['usd'] as num?)?.toDouble() ?? 0.0;
      final volume    = (market['total_volume']['usd'] as num?)?.toDouble() ?? 0.0;
      final circSupply= (market['circulating_supply'] as num?)?.toDouble() ?? 0.0;
      final maxSupply = market['max_supply'];
      final tvl       = (market['total_value_locked']?['usd'] as num?)?.toDouble();

      // Community score (0-100)
      int communityScore = 70;
      if (comm != null) {
        final twitter = (comm['twitter_followers'] as num?)?.toDouble() ?? 0;
        final reddit  = (comm['reddit_subscribers'] as num?)?.toDouble() ?? 0;
        communityScore = ((twitter / 5000000 + reddit / 1000000).clamp(0, 1) * 100).toInt();
        communityScore = communityScore.clamp(40, 99);
      }

      final result = <String, dynamic>{
        'price':  price,
        'change': change24h,
        'market_cap':   formatLargeNumber(marketCap),
        'volume_24h':   formatLargeNumber(volume),
        'circ_supply':  formatLargeNumber(circSupply),
        'max_supply':   maxSupply != null
            ? formatLargeNumber((maxSupply as num).toDouble())
            : '∞',
        'community_score': communityScore,
        'active_addresses': '—', // CoinGecko no lo provee en tier gratuito
      };

      // TVL solo para DeFi (ETH, SOL, BNB...)
      if (tvl != null && tvl > 0) {
        result['tvl'] = formatLargeNumber(tvl);
      }

      // Hash rate solo para Bitcoin (PoW)
      if (symbol.toUpperCase() == 'BTC') {
        result['hash_rate'] = '~620 EH/s'; // dato semestático, no disponible en CoinGecko free
      }

      return result;
    } catch (_) {
      return null;
    }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // STOCKS — Finnhub
  // ────────────────────────────────────────────────────────────────────────────

  /// Devuelve precio + métricas fundamentales de una acción
  static Future<Map<String, dynamic>?> fetchStock(String symbol) async {
    try {
      // Llamadas en paralelo: precio y métricas
      final results = await Future.wait([
        http.get(
          Uri.parse('$_finnhubBase/quote?symbol=$symbol&token=$_finnhubKey'),
        ).timeout(const Duration(seconds: 10)),
        http.get(
          Uri.parse('$_finnhubBase/stock/metric?symbol=$symbol&metric=all&token=$_finnhubKey'),
        ).timeout(const Duration(seconds: 10)),
        http.get(
          Uri.parse('$_finnhubBase/stock/profile2?symbol=$symbol&token=$_finnhubKey'),
        ).timeout(const Duration(seconds: 10)),
      ]);

      if (results[0].statusCode != 200) return null;

      final quote   = jsonDecode(results[0].body);
      final metrics = results[1].statusCode == 200
          ? (jsonDecode(results[1].body)['metric'] as Map<String, dynamic>? ?? {})
          : <String, dynamic>{};
      final profile = results[2].statusCode == 200
          ? jsonDecode(results[2].body) as Map<String, dynamic>
          : <String, dynamic>{};

      final price     = (quote['c'] as num?)?.toDouble() ?? 0.0;
      final prevClose = (quote['pc'] as num?)?.toDouble() ?? price;
      final change24h = prevClose > 0
          ? ((price - prevClose) / prevClose) * 100
          : 0.0;

      final marketCap = (profile['marketCapitalization'] as num?)?.toDouble() ?? 0.0;
      final peRatio   = (metrics['peNormalizedAnnual'] as num?)?.toDouble() ??
                        (metrics['peTTM'] as num?)?.toDouble();
      final eps       = (metrics['epsTTM'] as num?)?.toDouble();
      final roe       = (metrics['roeTTM'] as num?)?.toDouble();
      final debtEq    = (metrics['totalDebt/totalEquityAnnual'] as num?)?.toDouble() ??
                        (metrics['longTermDebt/equityAnnual'] as num?)?.toDouble();
      final divYield  = (metrics['dividendYieldIndicatedAnnual'] as num?)?.toDouble() ?? 0.0;
      final fcf       = (metrics['freeCashFlowTTM'] as num?)?.toDouble();

      return {
        'price':  price,
        'change': double.parse(change24h.toStringAsFixed(2)),
        'market_cap':      marketCap > 0 ? formatLargeNumber(marketCap * 1e6) : '—',
        'sector':          profile['finnhubIndustry'] ?? '—',
        'pe_ratio':        peRatio != null ? double.parse(peRatio.toStringAsFixed(1)) : null,
        'eps':             eps != null ? double.parse(eps.toStringAsFixed(2)) : null,
        'roe':             roe != null ? double.parse(roe.toStringAsFixed(1)) : null,
        'debt_equity':     debtEq != null ? double.parse(debtEq.toStringAsFixed(2)) : null,
        'dividend_yield':  double.parse(divYield.toStringAsFixed(2)),
        'free_cash_flow':  fcf != null ? formatLargeNumber(fcf * 1e6) : '—',
      };
    } catch (_) {
      return null;
    }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // ETFs — Finnhub (precio) + datos estáticos enriquecidos
  // ────────────────────────────────────────────────────────────────────────────

  // Finnhub free no devuelve expense_ratio ni tracking_error para ETFs,
  // así que mantenemos esos datos estáticos (cambian muy poco) y solo
  // actualizamos precio, variación y AUM en tiempo real.
  static const Map<String, Map<String, dynamic>> _etfStaticData = {
    'SPY': {'expense_ratio': 0.0945, 'tracking_error': 0.02, 'index': 'S&P 500',           'structure': 'Réplica total'},
    'QQQ': {'expense_ratio': 0.20,   'tracking_error': 0.04, 'index': 'Nasdaq-100',         'structure': 'Réplica total'},
    'GLD': {'expense_ratio': 0.40,   'tracking_error': 0.05, 'index': 'Precio del Oro',     'structure': 'Respaldado físicamente'},
    'EEM': {'expense_ratio': 0.68,   'tracking_error': 0.08, 'index': 'MSCI Emerging Mkts', 'structure': 'Réplica total'},
  };

  static Future<Map<String, dynamic>?> fetchEtf(String symbol) async {
    try {
      final results = await Future.wait([
        http.get(
          Uri.parse('$_finnhubBase/quote?symbol=$symbol&token=$_finnhubKey'),
        ).timeout(const Duration(seconds: 10)),
        http.get(
          Uri.parse('$_finnhubBase/stock/metric?symbol=$symbol&metric=all&token=$_finnhubKey'),
        ).timeout(const Duration(seconds: 10)),
      ]);

      if (results[0].statusCode != 200) return null;

      final quote   = jsonDecode(results[0].body);
      final metrics = results[1].statusCode == 200
          ? (jsonDecode(results[1].body)['metric'] as Map<String, dynamic>? ?? {})
          : <String, dynamic>{};

      final price     = (quote['c'] as num?)?.toDouble() ?? 0.0;
      final prevClose = (quote['pc'] as num?)?.toDouble() ?? price;
      final change24h = prevClose > 0
          ? ((price - prevClose) / prevClose) * 100
          : 0.0;

      final divYield = (metrics['dividendYieldIndicatedAnnual'] as num?)?.toDouble() ?? 0.0;
      final aum      = (metrics['marketCapitalization'] as num?)?.toDouble();

      final staticData = _etfStaticData[symbol.toUpperCase()] ?? {};

      return {
        'price':  price,
        'change': double.parse(change24h.toStringAsFixed(2)),
        'dividend_yield': double.parse(divYield.toStringAsFixed(2)),
        'aum':    aum != null ? formatLargeNumber(aum * 1e6) : '—',
        'avg_volume': '—',
        ...staticData,
      };
    } catch (_) {
      return null;
    }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // MÉTODO UNIFICADO — detecta el tipo y llama al correcto
  // ────────────────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>?> fetchAsset(
      String symbol, String type) async {
    switch (type) {
      case 'crypto': return fetchCrypto(symbol);
      case 'stock':  return fetchStock(symbol);
      case 'etf':    return fetchEtf(symbol);
      default:       return null;
    }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // LISTA COMPLETA — para AddAssetScreen (todos los activos disponibles)
  // ────────────────────────────────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> fetchAllAssets() async {
    // Datos base que no cambian
    final baseAssets = _baseAssets;

    // Fetchear precios en paralelo (máx 5 a la vez para no saturar el rate limit)
    final chunks = <List<Map<String, dynamic>>>[];
    for (var i = 0; i < baseAssets.length; i += 5) {
      chunks.add(baseAssets.sublist(
          i, i + 5 > baseAssets.length ? baseAssets.length : i + 5));
    }

    final result = <Map<String, dynamic>>[];
    for (final chunk in chunks) {
      final futures = chunk.map((a) async {
        final live = await fetchAsset(a['symbol'] as String, a['type'] as String);
        if (live != null) {
          return {...a, ...live};
        }
        return a;
      });
      result.addAll(await Future.wait(futures));
      // Pequeña pausa entre chunks para respetar rate limits
      if (chunks.indexOf(chunk) < chunks.length - 1) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
    return result;
  }

  // Datos estáticos base (lo que no viene de la API)
  static final List<Map<String, dynamic>> _baseAssets = [
    // CRYPTO
    {'name': 'Bitcoin',    'symbol': 'BTC', 'type': 'crypto', 'icon': '₿',
     'price': 0.0, 'change': 0.0},
    {'name': 'Ethereum',   'symbol': 'ETH', 'type': 'crypto', 'icon': 'Ξ',
     'price': 0.0, 'change': 0.0},
    {'name': 'Solana',     'symbol': 'SOL', 'type': 'crypto', 'icon': 'S',
     'price': 0.0, 'change': 0.0},
    {'name': 'BNB',        'symbol': 'BNB', 'type': 'crypto', 'icon': 'B',
     'price': 0.0, 'change': 0.0},
    {'name': 'XRP',        'symbol': 'XRP', 'type': 'crypto', 'icon': 'X',
     'price': 0.0, 'change': 0.0},
    // STOCKS
    {'name': 'Apple Inc.', 'symbol': 'AAPL', 'type': 'stock', 'icon': 'A',
     'price': 0.0, 'change': 0.0},
    {'name': 'Tesla',      'symbol': 'TSLA', 'type': 'stock', 'icon': 'T',
     'price': 0.0, 'change': 0.0},
    {'name': 'Microsoft',  'symbol': 'MSFT', 'type': 'stock', 'icon': 'M',
     'price': 0.0, 'change': 0.0},
    {'name': 'Nvidia',     'symbol': 'NVDA', 'type': 'stock', 'icon': 'N',
     'price': 0.0, 'change': 0.0},
    {'name': 'Amazon',     'symbol': 'AMZN', 'type': 'stock', 'icon': 'A',
     'price': 0.0, 'change': 0.0},
    // ETFs
    {'name': 'S&P 500 ETF',  'symbol': 'SPY', 'type': 'etf', 'icon': 'S',
     'price': 0.0, 'change': 0.0},
    {'name': 'Nasdaq ETF',   'symbol': 'QQQ', 'type': 'etf', 'icon': 'Q',
     'price': 0.0, 'change': 0.0},
    {'name': 'Gold ETF',     'symbol': 'GLD', 'type': 'etf', 'icon': 'G',
     'price': 0.0, 'change': 0.0},
    {'name': 'iShares MSCI', 'symbol': 'EEM', 'type': 'etf', 'icon': 'I',
     'price': 0.0, 'change': 0.0},
  ];

  static Future<List<Map<String, dynamic>>> searchCrypto(String query) async {
    if (query.trim().isEmpty) return [];
    try {
      final res = await http.get(
        Uri.parse('$_coinGeckoBase/search?query=${Uri.encodeComponent(query)}'),
        headers: {'x-cg-demo-api-key': _coinGeckoKey},
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode != 200) return [];
      final data  = jsonDecode(res.body);
      final coins = (data['coins'] as List).take(20).toList();

      return coins.map<Map<String, dynamic>>((c) {
        final symbol = (c['symbol'] as String).toUpperCase();
        return {
          'name':   c['name'] as String,
          'symbol': symbol,
          'type':   'crypto',
          'icon':   _cryptoIcon(symbol),
          'coingecko_id': c['id'] as String,
          'price':  0.0,
          'change': 0.0,
          'thumb':  c['thumb'] as String? ?? '',
        };
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// Busca acciones y ETFs por nombre o símbolo en Finnhub
  static Future<List<Map<String, dynamic>>> searchStocksAndEtfs(
      String query, String type) async {
    if (query.trim().isEmpty) return [];
    try {
      final res = await http.get(
        Uri.parse('$_finnhubBase/search?q=${Uri.encodeComponent(query)}&token=$_finnhubKey'),
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode != 200) return [];
      final data   = jsonDecode(res.body);
      final result = data['result'] as List? ?? [];

      // Finnhub no diferencia stocks de ETFs en la búsqueda,
      // filtramos por tipo de instrumento
      final filtered = result.where((r) {
        final rtype = (r['type'] as String? ?? '').toLowerCase();
        if (type == 'stock') {
          return rtype == 'common stock' || rtype == 'stock' || rtype == 'equity';
        } else {
          return rtype == 'etf' || rtype == 'etp' || rtype == 'exchange-traded fund';
        }
      }).take(20).toList();

      return filtered.map<Map<String, dynamic>>((r) {
        final symbol = (r['symbol'] as String).toUpperCase();
        return {
          'name':        r['description'] as String? ?? symbol,
          'symbol':      symbol,
          'type':        type,
          'icon':        symbol.isNotEmpty ? symbol[0].toUpperCase() : '?',
          'price':       0.0,
          'change':      0.0,
        };
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// Obtiene precio live de una cripto por su CoinGecko id
  static Future<Map<String, dynamic>?> fetchCryptoById(
      String id, String symbol) async {
    try {
      final res = await http.get(
        Uri.parse(
          '$_coinGeckoBase/coins/$id'
          '?localization=false&tickers=false&market_data=true'
          '&community_data=true&developer_data=false',
        ),
        headers: {'x-cg-demo-api-key': _coinGeckoKey},
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) return null;
      final data   = jsonDecode(res.body);
      final market = data['market_data'];
      final comm   = data['community_data'];

      final price     = (market['current_price']['usd'] as num).toDouble();
      final change24h = (market['price_change_percentage_24h'] as num?)?.toDouble() ?? 0.0;
      final marketCap = (market['market_cap']['usd'] as num?)?.toDouble() ?? 0.0;
      final volume    = (market['total_volume']['usd'] as num?)?.toDouble() ?? 0.0;
      final circSupply= (market['circulating_supply'] as num?)?.toDouble() ?? 0.0;
      final maxSupply = market['max_supply'];
      final tvl       = (market['total_value_locked']?['usd'] as num?)?.toDouble();

      int communityScore = 70;
      if (comm != null) {
        final twitter = (comm['twitter_followers'] as num?)?.toDouble() ?? 0;
        final reddit  = (comm['reddit_subscribers'] as num?)?.toDouble() ?? 0;
        communityScore =
            ((twitter / 5000000 + reddit / 1000000).clamp(0, 1) * 100).toInt();
        communityScore = communityScore.clamp(40, 99);
      }

      final result = <String, dynamic>{
        'price':             price,
        'change':            change24h,
        'market_cap':        formatLargeNumber(marketCap),
        'volume_24h':        formatLargeNumber(volume),
        'circ_supply':       formatLargeNumber(circSupply),
        'max_supply':        maxSupply != null
            ? formatLargeNumber((maxSupply as num).toDouble())
            : '∞',
        'community_score':   communityScore,
        'active_addresses':  '—',
      };

      if (tvl != null && tvl > 0) result['tvl'] = formatLargeNumber(tvl);
      if (symbol.toUpperCase() == 'BTC') result['hash_rate'] = '~620 EH/s';

      return result;
    } catch (_) {
      return null;
    }
  }

  // Icono por símbolo para criptos conocidas, inicial para el resto
  static String _cryptoIcon(String symbol) {
    const icons = {
      'BTC': '₿', 'ETH': 'Ξ', 'SOL': 'S', 'BNB': 'B',
      'XRP': 'X', 'ADA': 'A', 'DOGE': 'D', 'DOT': 'D',
      'MATIC': 'M', 'AVAX': 'A', 'LINK': 'L', 'UNI': 'U',
      'LTC': 'L', 'ATOM': 'A', 'XLM': 'X', 'TRX': 'T',
    };
    return icons[symbol] ?? (symbol.isNotEmpty ? symbol[0] : '?');
  }

  /// Top 10 más populares de cada tipo (sin búsqueda activa)
  static Future<List<Map<String, dynamic>>> fetchTop10(String type) async {
    try {
      if (type == 'crypto') {
        final res = await http.get(
          Uri.parse(
            '$_coinGeckoBase/coins/markets'
            '?vs_currency=usd&order=market_cap_desc&per_page=10&page=1'
            '&sparkline=false&price_change_percentage=24h',
          ),
          headers: {'x-cg-demo-api-key': _coinGeckoKey},
        ).timeout(const Duration(seconds: 8));

        if (res.statusCode != 200) return [];
        final list = jsonDecode(res.body) as List;

        return list.map<Map<String, dynamic>>((c) {
          final symbol = (c['symbol'] as String).toUpperCase();
          final price  = (c['current_price'] as num?)?.toDouble() ?? 0.0;
          final change = (c['price_change_percentage_24h'] as num?)?.toDouble() ?? 0.0;
          return {
            'name':         c['name'] as String,
            'symbol':       symbol,
            'type':         'crypto',
            'icon':         _cryptoIcon(symbol),
            'coingecko_id': c['id'] as String,
            'price':        price,
            'change':       change,
            'thumb':        c['image'] as String? ?? '',
          };
        }).toList();

      } else if (type == 'stock') {
        // Top 10 acciones más conocidas — Finnhub no tiene endpoint de ranking
        // así que usamos una lista curada y obtenemos precios en paralelo
        const topStocks = [
          {'name': 'Apple Inc.',  'symbol': 'AAPL', 'icon': 'A'},
          {'name': 'Microsoft',   'symbol': 'MSFT', 'icon': 'M'},
          {'name': 'Nvidia',      'symbol': 'NVDA', 'icon': 'N'},
          {'name': 'Amazon',      'symbol': 'AMZN', 'icon': 'A'},
          {'name': 'Alphabet',    'symbol': 'GOOGL','icon': 'G'},
          {'name': 'Meta',        'symbol': 'META', 'icon': 'M'},
          {'name': 'Tesla',       'symbol': 'TSLA', 'icon': 'T'},
          {'name': 'Berkshire',   'symbol': 'BRK.B','icon': 'B'},
          {'name': 'JPMorgan',    'symbol': 'JPM',  'icon': 'J'},
          {'name': 'Visa',        'symbol': 'V',    'icon': 'V'},
        ];

        final results = await Future.wait(
          topStocks.map((s) async {
            final live = await fetchStock(s['symbol']!);
            return <String, dynamic>{
              'name':   s['name'],
              'symbol': s['symbol'],
              'type':   'stock',
              'icon':   s['icon'],
              'price':  live?['price']  ?? 0.0,
              'change': live?['change'] ?? 0.0,
              if (live != null) ...live,
            };
          }),
        );
        return results;

      } else {
        // Top 10 ETFs más populares
        const topEtfs = [
          {'name': 'S&P 500 ETF',    'symbol': 'SPY',  'icon': 'S'},
          {'name': 'Nasdaq-100 ETF', 'symbol': 'QQQ',  'icon': 'Q'},
          {'name': 'Total Market',   'symbol': 'VTI',  'icon': 'V'},
          {'name': 'S&P 500 Vang.',  'symbol': 'VOO',  'icon': 'V'},
          {'name': 'Growth ETF',     'symbol': 'VUG',  'icon': 'V'},
          {'name': 'iShares Core',   'symbol': 'IVV',  'icon': 'I'},
          {'name': 'Gold ETF',       'symbol': 'GLD',  'icon': 'G'},
          {'name': 'iShares MSCI',   'symbol': 'EEM',  'icon': 'I'},
          {'name': 'Real Estate',    'symbol': 'VNQ',  'icon': 'V'},
          {'name': 'Bond ETF',       'symbol': 'BND',  'icon': 'B'},
        ];

        final results = await Future.wait(
          topEtfs.map((e) async {
            final live = await fetchEtf(e['symbol']!);
            return <String, dynamic>{
              'name':   e['name'],
              'symbol': e['symbol'],
              'type':   'etf',
              'icon':   e['icon'],
              'price':  live?['price']  ?? 0.0,
              'change': live?['change'] ?? 0.0,
              if (live != null) ...live,
            };
          }),
        );
        return results;
      }
    } catch (_) {
      return [];
    }
  }

  /// Devuelve la URL del logo de una cripto por su símbolo
  static Future<String?> fetchCryptoThumb(String symbol) async {
    final id = _cryptoIds[symbol.toUpperCase()];
    if (id == null) return null;
    try {
      final res = await http.get(
        Uri.parse('$_coinGeckoBase/coins/$id?localization=false'
            '&tickers=false&market_data=false'
            '&community_data=false&developer_data=false'),
        headers: {'x-cg-demo-api-key': _coinGeckoKey},
      ).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body);
      return data['image']?['thumb'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Expone el id de CoinGecko para un símbolo dado
  static String? getCoinGeckoId(String symbol) =>
      _cryptoIds[symbol.toUpperCase()];

      /// Obtiene la URL del logo de una cripto directamente por su símbolo
  static Future<String?> fetchCryptoImageUrl(String symbol) async {
    final id = _cryptoIds[symbol.toUpperCase()];
    if (id != null) {
      // Si está en el mapa conocido, usar markets endpoint (más fiable)
      try {
        final res = await http.get(
          Uri.parse(
            '$_coinGeckoBase/coins/markets'
            '?vs_currency=usd&ids=$id&per_page=1&page=1',
          ),
          headers: {'x-cg-demo-api-key': _coinGeckoKey},
        ).timeout(const Duration(seconds: 8));
        if (res.statusCode == 200) {
          final list = jsonDecode(res.body) as List;
          if (list.isNotEmpty) {
            return list.first['image'] as String?;
          }
        }
      } catch (_) {}
    }

    // Si no está en el mapa, buscar por símbolo
    try {
      final results = await searchCrypto(symbol);
      if (results.isNotEmpty) {
        return results.first['thumb'] as String?;
      }
    } catch (_) {}

    return null;
  }

  static Future<double?> fetchExchangeRate(String toCurrency) async {
    try {
      // Usamos CoinGecko para obtener el tipo de cambio
      // ya que tenemos la key y evitamos APIs externas
      final res = await http.get(
        Uri.parse(
          '$_coinGeckoBase/simple/price'
          '?ids=tether&vs_currencies=${toCurrency.toLowerCase()}',
        ),
        headers: {'x-cg-demo-api-key': _coinGeckoKey},
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body);
      final rate = (data['tether']?[toCurrency.toLowerCase()] as num?)
          ?.toDouble();
      return rate;
    } catch (_) {
      return null;
    }
  }
}