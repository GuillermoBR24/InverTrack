import 'dart:async';
import 'package:flutter/material.dart';
import 'package:invertrack/screens/add_asset_screen.dart';
import 'package:invertrack/screens/asset_portfolio_detail_screen.dart';
import 'package:invertrack/screens/profile_screen.dart';
import 'package:invertrack/services/market_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _assets = [];
  String  _username  = '';
  String? _avatarUrl;
  bool    _isLoading = true;
  Timer?  _priceTimer;

  String get _userEmail => supabase.auth.currentUser?.email ?? '';

  @override
  void initState() {
    super.initState();
    _loadAll();
    _priceTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      _refreshPrices();
    });
  }

  @override
  void dispose() {
    _priceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadProfile(), _loadAssets()]);
  }

  Future<void> _loadProfile() async {
    try {
      final uid  = supabase.auth.currentUser!.id;
      final data = await supabase
          .from('profiles')
          .select()
          .eq('id', uid)
          .maybeSingle();
      if (mounted) {
        setState(() {
          _username  = data?['username'] ?? _userEmail.split('@').first;
          _avatarUrl = data?['avatar_url'];
        });
      }
    } catch (_) {
      if (mounted) setState(() => _username = _userEmail.split('@').first);
    }
  }

  Future<void> _loadAssets() async {
    setState(() => _isLoading = true);
    try {
      final uid  = supabase.auth.currentUser!.id;
      final data = await supabase
          .from('assets')
          .select()
          .eq('user_id', uid)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() => _assets = List<Map<String, dynamic>>.from(data));
      }
      await _refreshPrices();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error al cargar activos: $e'),
          backgroundColor: const Color(0xFFFF6B6B),
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshPrices() async {
    if (_assets.isEmpty) return;
    try {
      final updated = await Future.wait(
        _assets.map((asset) async {
          // Obtener thumb para criptos primero (en paralelo con el precio)
          String? thumb = asset['thumb'] as String?;

          final futures = await Future.wait([
            MarketService.fetchAsset(
              asset['symbol'] as String,
              asset['type']   as String,
            ),
            // Solo buscar thumb si es cripto y no lo tenemos aún
            if (asset['type'] == 'crypto' && (thumb == null || thumb.isEmpty))
              MarketService.fetchCryptoImageUrl(asset['symbol'] as String)
            else
              Future.value(null),
          ]);

          final live     = futures[0] as Map<String, dynamic>?;
          final newThumb = futures[1] as String?;

          if (newThumb != null && newThumb.isNotEmpty) thumb = newThumb;
          // También intentar coger thumb del propio live (fetchCryptoById lo incluye)
          if ((thumb == null || thumb.isEmpty) && live != null) {
            thumb = live['thumb'] as String?;
          }

          if (live != null) {
            return {
              ...asset,
              'price':  live['price'],
              'change': live['change'],
              if (thumb != null && thumb.isNotEmpty) 'thumb': thumb,
            };
          }

          return {
            ...asset,
            if (thumb != null && thumb.isNotEmpty) 'thumb': thumb,
          };
        }),
      );
      if (mounted) {
        setState(() => _assets = List<Map<String, dynamic>>.from(updated));
      }
    } catch (_) {}
  }

  // Valor actual total = suma de (precio live × cantidad)
  double get _totalCurrentValue => _assets.fold(0, (sum, a) {
    final price    = (a['price']    as num?)?.toDouble() ?? 0.0;
    final quantity = (a['quantity'] as num?)?.toDouble() ?? 0.0;
    final invested = (a['value']    as num?)?.toDouble() ?? 0.0;
    return sum + (price > 0 ? price * quantity : invested);
  });

  // Total invertido = suma de value (lo que se pagó en su momento)
  double get _totalInvested => _assets.fold(
      0, (sum, a) => sum + ((a['value'] as num?)?.toDouble() ?? 0.0));

  // Ganancia/pérdida total en $
  double get _totalGainLoss => _totalCurrentValue - _totalInvested;

  // Variación total del portfolio en % respecto a lo invertido
  double get _totalGainPct =>
      _totalInvested > 0 ? (_totalGainLoss / _totalInvested) * 100 : 0.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt     = Theme.of(context).textTheme;

    const cardColor   = Color(0xFF1E2D3D);
    const borderColor = Color(0xFF1E3A5F);

    final gainIsPos = _totalGainLoss >= 0;
    final gainColor = gainIsPos
        ? const Color(0xFF69F0AE)
        : const Color(0xFFFF6B6B);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            GestureDetector(
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                );
                _loadAll();
              },
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0D47A1), Color(0xFF0288D1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(
                    color: const Color(0xFF4FC3F7),
                    width: 1.5,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(9.5),
                  child: _avatarUrl != null
                      ? Image.network(
                          _avatarUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _AvatarInitial(name: _username),
                        )
                      : _AvatarInitial(name: _username),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              _username.isEmpty ? '' : _username,
              style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Configuración',
            icon: const Icon(Icons.settings_rounded),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
              _loadAll();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),

      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              color: scheme.primary,
              onRefresh: _loadAll,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                children: [

                  // ── TARJETA TOTAL PORTFOLIO ──────────────────────────
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0D47A1), Color(0xFF0288D1)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.account_balance_wallet_rounded,
                              color: Colors.white70,
                              size: 30,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Valor total del portfolio',
                              style: tt.bodyMedium?.copyWith(
                                  color: Colors.white70, fontSize: 13),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '\$${_totalCurrentValue.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Ganancia total en $ y %
                        Row(
                          children: [
                            Icon(
                              gainIsPos
                                  ? Icons.trending_up_rounded
                                  : Icons.trending_down_rounded,
                              color: gainColor,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${gainIsPos ? '+' : ''}\$${_totalGainLoss.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: gainColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: gainColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${gainIsPos ? '+' : ''}${_totalGainPct.toStringAsFixed(2)}%',
                                style: TextStyle(
                                  color: gainColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            _MiniStat(
                              label: 'Activos',
                              value: '${_assets.length}',
                              icon: Icons.pie_chart_rounded,
                            ),
                            const SizedBox(width: 24),
                            _MiniStat(
                              label: 'Invertido',
                              value:
                                  '\$${_totalInvested.toStringAsFixed(2)}',
                              icon: Icons.attach_money_rounded,
                              valueColor: Colors.white,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── DISTRIBUCIÓN ─────────────────────────────────────
                  Text('Distribución',
                      style: tt.bodyLarge
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _TypeCard(
                        label: 'Cripto',
                        icon: Icons.currency_bitcoin_rounded,
                        count: _assets
                            .where((a) => a['type'] == 'crypto')
                            .length,
                        color: const Color(0xFFF7931A),
                      ),
                      const SizedBox(width: 12),
                      _TypeCard(
                        label: 'Acciones',
                        icon: Icons.show_chart_rounded,
                        count: _assets
                            .where((a) => a['type'] == 'stock')
                            .length,
                        color: const Color(0xFF4FC3F7),
                      ),
                      const SizedBox(width: 12),
                      _TypeCard(
                        label: 'ETFs',
                        icon: Icons.donut_small_rounded,
                        count: _assets
                            .where((a) => a['type'] == 'etf')
                            .length,
                        color: const Color(0xFF69F0AE),
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  // ── CABECERA LISTA ────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Tus activos',
                          style: tt.bodyLarge
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      GestureDetector(
                        onTap: () async {
                          final newAsset =
                              await Navigator.push<Map<String, dynamic>>(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const AddAssetScreen()),
                          );
                          if (newAsset != null) await _loadAssets();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: borderColor),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.add_rounded,
                                  color: scheme.primary, size: 16),
                              const SizedBox(width: 4),
                              Text('Añadir',
                                  style: tt.bodyMedium?.copyWith(
                                    color: scheme.primary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  )),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── LISTA O ESTADO VACÍO ──────────────────────────────
                  if (_assets.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.add_circle_outline_rounded,
                                size: 52,
                                color: const Color(0xFF7BA7C2)),
                            const SizedBox(height: 12),
                            Text('Aún no tienes activos',
                                style: tt.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 6),
                            Text('Pulsa "Añadir" para empezar',
                                style: tt.bodyMedium),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._assets.map((asset) => GestureDetector(
                          onTap: () async {
                            final result = await Navigator.push<String>(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    AssetPortfolioDetailScreen(
                                        asset: asset),
                              ),
                            );
                            if (result == 'deleted') await _loadAssets();
                          },
                          child: _AssetTile(
                            asset: asset,
                            cardColor: cardColor,
                            borderColor: borderColor,
                          ),
                        )),
                ],
              ),
            ),
    );
  }
}

// ── WIDGETS AUXILIARES ────────────────────────────────────────────────────────

class _AvatarInitial extends StatelessWidget {
  const _AvatarInitial({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.icon,
    this.valueColor = Colors.white,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white54, size: 28),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    color: Colors.white54, fontSize: 11)),
            Text(value,
                style: TextStyle(
                    color: valueColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ],
    );
  }
}

class _TypeCard extends StatelessWidget {
  const _TypeCard({
    required this.label,
    required this.icon,
    required this.count,
    required this.color,
  });

  final String label;
  final IconData icon;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding:
            const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E2D3D),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF1E3A5F)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text('$count',
                style: TextStyle(
                    color: color,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(label,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _AssetTile extends StatelessWidget {
  const _AssetTile({
    required this.asset,
    required this.cardColor,
    required this.borderColor,
  });

  final Map<String, dynamic> asset;
  final Color cardColor;
  final Color borderColor;

  static const Map<String, Color> _typeColors = {
    'crypto': Color(0xFFF7931A),
    'stock':  Color(0xFF4FC3F7),
    'etf':    Color(0xFF69F0AE),
  };

  @override
  Widget build(BuildContext context) {
    final price        = (asset['price']    as num?)?.toDouble() ?? 0.0;
    final invested     = (asset['value']    as num?)?.toDouble() ?? 0.0;
    final quantity     = (asset['quantity'] as num?)?.toDouble() ?? 0.0;
    final currentValue = price > 0 ? price * quantity : invested;
    final gainLoss     = currentValue - invested;
    // % ganancia = (ganancia / invertido) × 100
    final gainPct      = invested > 0 ? (gainLoss / invested) * 100 : 0.0;
    final gainIsPos    = gainLoss >= 0;
    final gainColor    = gainIsPos
        ? const Color(0xFF69F0AE)
        : const Color(0xFFFF6B6B);
    final typeColor    =
        _typeColors[asset['type']] ?? const Color(0xFF4FC3F7);
    final thumb        = asset['thumb'] as String?;

    final String quantityStr = quantity < 0.001
        ? quantity.toStringAsFixed(8)
        : quantity < 1
            ? quantity.toStringAsFixed(6)
            : quantity.toStringAsFixed(4);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: typeColor.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          // ── Icono / logo ─────────────────────────────────────────────
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: typeColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: thumb != null && thumb.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      thumb,
                      width: 28, height: 28,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Text(
                        asset['icon'] as String? ?? '?',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: typeColor),
                      ),
                    ),
                  )
                : Text(
                    asset['icon'] as String? ?? '?',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: typeColor),
                  ),
          ),
          const SizedBox(width: 14),

          // ── Nombre + símbolo + badge + cantidad ───────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  asset['name'] as String? ?? '',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      asset['symbol'] as String? ?? '',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(fontSize: 12),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: typeColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        asset['type'] == 'crypto'
                            ? 'Cripto'
                            : asset['type'] == 'stock'
                                ? 'Acción'
                                : 'ETF',
                        style: TextStyle(
                            color: typeColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '$quantityStr ${asset['symbol'] ?? ''}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 11,
                      color: typeColor.withOpacity(0.8)),
                ),
              ],
            ),
          ),

          // ── Valor actual + ganancia $ + ganancia % ────────────────────
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Valor actual
              Text(
                '\$${currentValue.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 2),
              // Ganancia/pérdida en $
              Text(
                '${gainIsPos ? '+' : ''}\$${gainLoss.toStringAsFixed(2)}',
                style: TextStyle(
                    color: gainColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              // % ganancia total respecto a lo invertido
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: gainColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${gainIsPos ? '+' : ''}${gainPct.toStringAsFixed(2)}%',
                  style: TextStyle(
                      color: gainColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}