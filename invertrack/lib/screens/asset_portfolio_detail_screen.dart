import 'package:flutter/material.dart';
import 'package:invertrack/screens/sell_asset_screen.dart';
import 'package:provider/provider.dart';
import 'package:invertrack/providers/currency_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/market_service.dart';
import 'package:invertrack/screens/price_alerts_screen.dart';

class AssetPortfolioDetailScreen extends StatefulWidget {
  final Map<String, dynamic> asset;
  const AssetPortfolioDetailScreen({super.key, required this.asset});

  @override
  State<AssetPortfolioDetailScreen> createState() =>
      _AssetPortfolioDetailScreenState();
}

class _AssetPortfolioDetailScreenState
    extends State<AssetPortfolioDetailScreen> {
  final supabase  = Supabase.instance.client;
  bool _isDeleting    = false;
  bool _isLoadingData = true;

  late Map<String, dynamic> _liveAsset;
  String? _thumbUrl;

  static const Map<String, Color> _typeColors = {
    'crypto': Color(0xFFF7931A),
    'stock':  Color(0xFF4FC3F7),
    'etf':    Color(0xFF69F0AE),
  };

  Color  get _color    => _typeColors[_liveAsset['type']] ?? const Color(0xFF4FC3F7);
  double get _price    => (_liveAsset['price']     as num?)?.toDouble() ?? 0;
  double get _buyPrice => (_liveAsset['buy_price'] as num?)?.toDouble() ?? 0;
  double get _quantity => (_liveAsset['quantity']  as num?)?.toDouble() ?? 0;
  double get _value    => (_liveAsset['value']     as num?)?.toDouble() ?? 0;
  double get _change   => (_liveAsset['change']    as num?)?.toDouble() ?? 0;

  double get _currentValue => _price * _quantity;
  double get _gainLoss     => _currentValue - _value;
  double get _gainLossPct  => _value > 0 ? (_gainLoss / _value) * 100 : 0;

  @override
  void initState() {
    super.initState();
    _liveAsset = Map<String, dynamic>.from(widget.asset);
    _loadLiveData();
  }

  Future<void> _loadLiveData() async {
    setState(() => _isLoadingData = true);
    try {
      final symbol = _liveAsset['symbol'] as String;
      final type   = _liveAsset['type']   as String;

      final futures = await Future.wait([
        MarketService.fetchAsset(symbol, type),
        if (type == 'crypto')
          _loadCryptoThumb(symbol)
        else
          Future.value(null),
      ]);

      final live = futures[0] as Map<String, dynamic>?;
      if (live != null && mounted) {
        setState(() => _liveAsset = {..._liveAsset, ...live});
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoadingData = false);
    }
  }

  Future<void> _loadCryptoThumb(String symbol) async {
    try {
      final searchResults = await MarketService.searchCrypto(symbol);
      if (searchResults.isNotEmpty && mounted) {
        setState(() => _thumbUrl = searchResults.first['thumb'] as String?);
      }
    } catch (_) {}
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Eliminar activo',
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(fontWeight: FontWeight.bold)),
        content: Text(
          '¿Seguro que quieres eliminar ${_liveAsset['name']} de tu portfolio?',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar',
                style: TextStyle(
                    color: Color(0xFFFF6B6B),
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    setState(() => _isDeleting = true);
    try {
      await supabase.from('assets').delete().eq('id', _liveAsset['id']);
      if (mounted) Navigator.pop(context, 'deleted');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error al eliminar: $e'),
          backgroundColor: const Color(0xFFFF6B6B),
        ));
      }
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt  = Theme.of(context).textTheme;
    final cp  = context.watch<CurrencyProvider>();

    final isPos     = _change >= 0;
    final gainIsPos = _gainLoss >= 0;
    final changeColor = isPos
        ? const Color(0xFF69F0AE)
        : const Color(0xFFFF6B6B);
    final gainColor = gainIsPos
        ? const Color(0xFF69F0AE)
        : const Color(0xFFFF6B6B);

    const cardColor   = Color(0xFF1E2D3D);
    const borderColor = Color(0xFF1E3A5F);

    final type = _liveAsset['type'] as String? ?? '';

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Text(_liveAsset['symbol'] as String? ?? '',
                style: tt.bodyLarge
                    ?.copyWith(fontWeight: FontWeight.w600, color: _color)),
            const SizedBox(width: 8),
            Flexible(
              child: Text(_liveAsset['name'] as String? ?? '',
                  style: tt.bodyMedium?.copyWith(fontSize: 13),
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        actions: [
          if (_isLoadingData)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white54),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Actualizar datos',
              onPressed: _loadLiveData,
            ),
        ],
      ),

      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [

          // ── CABECERA PRECIO ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_color.withOpacity(0.25), _color.withOpacity(0.05)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _color.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    color: _color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: _thumbUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            _thumbUrl!,
                            width: 36, height: 36,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => Text(
                              _liveAsset['icon'] as String? ?? '?',
                              style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: _color),
                            ),
                          ),
                        )
                      : Text(
                          _liveAsset['icon'] as String? ?? '?',
                          style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: _color),
                        ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Precio actual',
                          style: tt.bodyMedium?.copyWith(fontSize: 12)),
                      _isLoadingData
                          ? const SizedBox(
                              height: 28,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: SizedBox(
                                  width: 20, height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white54),
                                ),
                              ),
                            )
                          : Text(
                              cp.format(_price),
                              style: TextStyle(
                                color: _color,
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.5,
                              ),
                            ),
                    ],
                  ),
                ),
                if (!_isLoadingData)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: changeColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${isPos ? '+' : ''}${_change.toStringAsFixed(2)}%',
                      style: TextStyle(
                          color: changeColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 14),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── GANANCIA / PÉRDIDA ──────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: gainColor.withOpacity(0.07),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: gainColor.withOpacity(0.25)),
            ),
            child: Row(
              children: [
                Icon(
                  gainIsPos
                      ? Icons.trending_up_rounded
                      : Icons.trending_down_rounded,
                  color: gainColor,
                  size: 32,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          gainIsPos ? 'Ganancia actual' : 'Pérdida actual',
                          style: tt.bodyMedium?.copyWith(fontSize: 12)),
                      Text(
                        '${gainIsPos ? '+' : ''}${cp.format(_gainLoss)}',
                        style: TextStyle(
                          color: gainColor,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: gainColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${gainIsPos ? '+' : ''}${_gainLossPct.toStringAsFixed(2)}%',
                    style: TextStyle(
                        color: gainColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 14),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── DATOS DE LA INVERSIÓN ────────────────────────────────────
          _SectionLabel(label: 'Tu inversión'),
          const SizedBox(height: 10),
          _InfoCard(
            cardColor: cardColor,
            borderColor: borderColor,
            children: [
              _InfoRow(
                icon: Icons.attach_money_rounded,
                label: 'Valor invertido',
                value: cp.format(_value),
                color: _color,
              ),
              _Divider(color: borderColor),
              _InfoRow(
                icon: Icons.price_change_rounded,
                label: 'Precio de compra',
                value: cp.format(_buyPrice),
                color: _color,
              ),
              _Divider(color: borderColor),
              _InfoRow(
                icon: Icons.numbers_rounded,
                label: 'Cantidad',
                value: _quantity < 0.001
                    ? _quantity.toStringAsFixed(8)
                    : _quantity.toStringAsFixed(6),
                valueSuffix: '  ${_liveAsset['symbol']}',
                color: _color,
              ),
              _Divider(color: borderColor),
              _InfoRow(
                icon: Icons.account_balance_wallet_rounded,
                label: 'Valor actual',
                value: cp.format(_currentValue),
                color: _color,
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ── MÉTRICAS CLAVE ───────────────────────────────────────────
          _SectionLabel(label: 'Métricas clave'),
          const SizedBox(height: 10),

          if (_isLoadingData)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                        strokeWidth: 2, color: Color(0xFF4FC3F7)),
                    SizedBox(height: 12),
                    Text('Cargando métricas...',
                        style: TextStyle(
                            color: Color(0xFF7BA7C2), fontSize: 13)),
                  ],
                ),
              ),
            )
          else ...[
            if (type == 'crypto') _CryptoMetrics(
                asset: _liveAsset, color: _color,
                cardColor: cardColor, borderColor: borderColor),
            if (type == 'stock')  _StockMetrics(
                asset: _liveAsset, color: _color,
                cardColor: cardColor, borderColor: borderColor),
            if (type == 'etf')    _EtfMetrics(
                asset: _liveAsset, color: _color,
                cardColor: cardColor, borderColor: borderColor),
          ],

          const SizedBox(height: 32),
          
          OutlinedButton.icon(
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => _CreateAlertSheet(
                  assets: [_liveAsset],
                  preselectedAsset: _liveAsset,
                  onCreated: (_) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Alerta creada correctamente')),
                    );
                  },
                ),
              );
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF4FC3F7),
              side: const BorderSide(color: Color(0xFF4FC3F7), width: 1.5),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              minimumSize: const Size(double.infinity, 48),
            ),
            icon: const Icon(Icons.notification_add_rounded, size: 18),
            label: const Text('Crear alerta de precio',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 12),

          // ── BOTONES VENDER / ELIMINAR ────────────────────────────────
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _isDeleting
                        ? null
                        : () async {
                            final result = await Navigator.push<String>(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    SellAssetScreen(asset: _liveAsset),
                              ),
                            );
                            if (result == 'sold' && mounted) {
                              Navigator.pop(context, 'deleted');
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _color,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.sell_rounded, size: 18),
                    label: const Text('Vender',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 52,
                child: OutlinedButton(
                  onPressed: _isDeleting ? null : _delete,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFF6B6B),
                    side: const BorderSide(
                        color: Color(0xFFFF6B6B), width: 1.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: _isDeleting
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFFFF6B6B)))
                      : const Icon(
                          Icons.delete_outline_rounded, size: 20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── MÉTRICAS CRYPTO ───────────────────────────────────────────────────────────
class _CryptoMetrics extends StatelessWidget {
  final Map<String, dynamic> asset;
  final Color color;
  final Color cardColor;
  final Color borderColor;
  const _CryptoMetrics({required this.asset, required this.color,
      required this.cardColor, required this.borderColor});

  Color _scoreColor(int s) {
    if (s >= 80) return const Color(0xFF69F0AE);
    if (s >= 60) return const Color(0xFFFFC107);
    return const Color(0xFFFF6B6B);
  }

  @override
  Widget build(BuildContext context) {
    final hasHashRate = asset.containsKey('hash_rate') &&
        asset['hash_rate'] != null && asset['hash_rate'] != '—';
    final hasTvl = asset.containsKey('tvl') &&
        asset['tvl'] != null && asset['tvl'] != '—';

    return Column(children: [
      Row(children: [
        Expanded(child: _MetricCard(
            label: 'Market Cap', value: asset['market_cap'] ?? '—',
            icon: Icons.pie_chart_rounded, color: color,
            cardColor: cardColor, borderColor: borderColor,
            tooltip: 'Capitalización total. Mayor = más estable')),
        const SizedBox(width: 10),
        Expanded(child: _MetricCard(
            label: 'Volumen 24h', value: asset['volume_24h'] ?? '—',
            icon: Icons.bar_chart_rounded, color: color,
            cardColor: cardColor, borderColor: borderColor,
            tooltip: 'Liquidez del mercado en las últimas 24h')),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: _MetricCard(
            label: 'Oferta circ.', value: asset['circ_supply'] ?? '—',
            icon: Icons.rotate_right_rounded, color: color,
            cardColor: cardColor, borderColor: borderColor,
            tooltip: 'Tokens en circulación vs oferta máxima',
            subtitle: 'Máx: ${asset['max_supply'] ?? '∞'}')),
        const SizedBox(width: 10),
        Expanded(child: _MetricCard(
            label: 'Dir. activas', value: asset['active_addresses'] ?? '—',
            icon: Icons.people_rounded, color: color,
            cardColor: cardColor, borderColor: borderColor,
            tooltip: 'Adopción real de la red')),
      ]),
      const SizedBox(height: 10),
      if (hasHashRate) ...[
        Row(children: [
          Expanded(child: _MetricCard(
              label: 'Hash Rate', value: asset['hash_rate'] ?? '—',
              icon: Icons.memory_rounded, color: color,
              cardColor: cardColor, borderColor: borderColor,
              tooltip: 'Potencia computacional de la red (PoW)')),
          const SizedBox(width: 10),
          Expanded(child: _MetricCard(
              label: 'Comunidad',
              value: '${asset['community_score'] ?? '—'}/100',
              icon: Icons.group_rounded, color: color,
              cardColor: cardColor, borderColor: borderColor,
              tooltip: 'Actividad y transparencia de la comunidad',
              valueColor: _scoreColor(
                  (asset['community_score'] as num?)?.toInt() ?? 0))),
        ]),
      ] else if (hasTvl) ...[
        Row(children: [
          Expanded(child: _MetricCard(
              label: 'TVL', value: '\$${asset['tvl'] ?? '—'}',
              icon: Icons.lock_rounded, color: color,
              cardColor: cardColor, borderColor: borderColor,
              tooltip: 'Total Value Locked en protocolos DeFi')),
          const SizedBox(width: 10),
          Expanded(child: _MetricCard(
              label: 'Comunidad',
              value: '${asset['community_score'] ?? '—'}/100',
              icon: Icons.group_rounded, color: color,
              cardColor: cardColor, borderColor: borderColor,
              tooltip: 'Actividad y transparencia de la comunidad',
              valueColor: _scoreColor(
                  (asset['community_score'] as num?)?.toInt() ?? 0))),
        ]),
      ] else ...[
        Row(children: [
          Expanded(child: _MetricCard(
              label: 'Comunidad',
              value: '${asset['community_score'] ?? '—'}/100',
              icon: Icons.group_rounded, color: color,
              cardColor: cardColor, borderColor: borderColor,
              tooltip: 'Actividad y transparencia de la comunidad',
              valueColor: _scoreColor(
                  (asset['community_score'] as num?)?.toInt() ?? 0))),
          const SizedBox(width: 10),
          const Expanded(child: SizedBox()),
        ]),
      ],
    ]);
  }
}

// ── MÉTRICAS STOCK ────────────────────────────────────────────────────────────
class _StockMetrics extends StatelessWidget {
  final Map<String, dynamic> asset;
  final Color color;
  final Color cardColor;
  final Color borderColor;
  const _StockMetrics({required this.asset, required this.color,
      required this.cardColor, required this.borderColor});

  Color _peColor(double pe) {
    if (pe < 15) return const Color(0xFF69F0AE);
    if (pe < 35) return const Color(0xFFFFC107);
    return const Color(0xFFFF6B6B);
  }

  Color _debtColor(double d) {
    if (d < 0.5) return const Color(0xFF69F0AE);
    if (d < 1.0) return const Color(0xFFFFC107);
    return const Color(0xFFFF6B6B);
  }

  @override
  Widget build(BuildContext context) {
    final pe   = (asset['pe_ratio']    as num?)?.toDouble();
    final debt = (asset['debt_equity'] as num?)?.toDouble();

    return Column(children: [
      Row(children: [
        Expanded(child: _MetricCard(
            label: 'P/E Ratio',
            value: pe != null ? '${pe.toStringAsFixed(1)}x' : '—',
            icon: Icons.show_chart_rounded, color: color,
            cardColor: cardColor, borderColor: borderColor,
            tooltip: 'Alto = posible sobrevaloración. Bajo = oportunidad',
            valueColor: pe != null ? _peColor(pe) : null)),
        const SizedBox(width: 10),
        Expanded(child: _MetricCard(
            label: 'EPS',
            value: asset['eps'] != null
                ? '\$${(asset['eps'] as num).toStringAsFixed(2)}'
                : '—',
            icon: Icons.trending_up_rounded, color: color,
            cardColor: cardColor, borderColor: borderColor,
            tooltip: 'Ganancias por acción. Mayor = mejor rendimiento')),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: _MetricCard(
            label: 'ROE',
            value: asset['roe'] != null
                ? '${(asset['roe'] as num).toStringAsFixed(1)}%'
                : '—',
            icon: Icons.percent_rounded, color: color,
            cardColor: cardColor, borderColor: borderColor,
            tooltip: 'Retorno sobre el patrimonio',
            valueColor: const Color(0xFF69F0AE))),
        const SizedBox(width: 10),
        Expanded(child: _MetricCard(
            label: 'Deuda/Capital',
            value: debt != null ? debt.toStringAsFixed(2) : '—',
            icon: Icons.account_balance_rounded, color: color,
            cardColor: cardColor, borderColor: borderColor,
            tooltip: 'Ratio alto = mayor riesgo financiero',
            valueColor: debt != null ? _debtColor(debt) : null)),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: _MetricCard(
            label: 'Div. Yield',
            value: '${asset['dividend_yield'] ?? 0}%',
            icon: Icons.savings_rounded, color: color,
            cardColor: cardColor, borderColor: borderColor,
            tooltip: 'Rentabilidad por dividendos')),
        const SizedBox(width: 10),
        Expanded(child: _MetricCard(
            label: 'Flujo de caja',
            value: asset['free_cash_flow'] ?? '—',
            icon: Icons.water_drop_rounded, color: color,
            cardColor: cardColor, borderColor: borderColor,
            tooltip: 'Dinero disponible tras gastos',
            valueColor: const Color(0xFF69F0AE))),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: _MetricCard(
            label: 'Market Cap',
            value: asset['market_cap'] ?? '—',
            icon: Icons.corporate_fare_rounded, color: color,
            cardColor: cardColor, borderColor: borderColor,
            tooltip: 'Capitalización bursátil total')),
        const SizedBox(width: 10),
        Expanded(child: _MetricCard(
            label: 'Sector',
            value: asset['sector'] ?? '—',
            icon: Icons.category_rounded, color: color,
            cardColor: cardColor, borderColor: borderColor,
            tooltip: 'Sector de actividad de la empresa')),
      ]),
    ]);
  }
}

// ── MÉTRICAS ETF ──────────────────────────────────────────────────────────────
class _EtfMetrics extends StatelessWidget {
  final Map<String, dynamic> asset;
  final Color color;
  final Color cardColor;
  final Color borderColor;
  const _EtfMetrics({required this.asset, required this.color,
      required this.cardColor, required this.borderColor});

  Color _expenseColor(double e) {
    if (e < 0.2) return const Color(0xFF69F0AE);
    if (e < 0.5) return const Color(0xFFFFC107);
    return const Color(0xFFFF6B6B);
  }

  @override
  Widget build(BuildContext context) {
    final expense = (asset['expense_ratio'] as num?)?.toDouble();
    return Column(children: [
      Row(children: [
        Expanded(child: _MetricCard(
            label: 'Expense Ratio',
            value: expense != null ? '${expense.toStringAsFixed(2)}%' : '—',
            icon: Icons.receipt_long_rounded, color: color,
            cardColor: cardColor, borderColor: borderColor,
            tooltip: 'Comisión anual de administración. Menor = mejor',
            valueColor: expense != null ? _expenseColor(expense) : null)),
        const SizedBox(width: 10),
        Expanded(child: _MetricCard(
            label: 'Tracking Error',
            value: asset['tracking_error'] != null
                ? '${asset['tracking_error']}%' : '—',
            icon: Icons.track_changes_rounded, color: color,
            cardColor: cardColor, borderColor: borderColor,
            tooltip: 'Desviación respecto al índice. Menor = más fiel')),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: _MetricCard(
            label: 'Índice', value: asset['index'] ?? '—',
            icon: Icons.list_alt_rounded, color: color,
            cardColor: cardColor, borderColor: borderColor,
            tooltip: 'Índice subyacente que replica el ETF')),
        const SizedBox(width: 10),
        Expanded(child: _MetricCard(
            label: 'Estructura', value: asset['structure'] ?? '—',
            icon: Icons.account_tree_rounded, color: color,
            cardColor: cardColor, borderColor: borderColor,
            tooltip: 'Réplica total = compra física de activos del índice')),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: _MetricCard(
            label: 'AUM',
            value: asset['aum'] != null ? '\$${asset['aum']}' : '—',
            icon: Icons.account_balance_wallet_rounded, color: color,
            cardColor: cardColor, borderColor: borderColor,
            tooltip: 'Activos bajo gestión. Mayor = más liquidez')),
        const SizedBox(width: 10),
        Expanded(child: _MetricCard(
            label: 'Div. Yield',
            value: '${asset['dividend_yield'] ?? 0}%',
            icon: Icons.savings_rounded, color: color,
            cardColor: cardColor, borderColor: borderColor,
            tooltip: 'Rentabilidad por dividendos distribuidos')),
      ]),
    ]);
  }
}

// ── WIDGETS AUXILIARES ────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final List<Widget> children;
  final Color cardColor;
  final Color borderColor;
  const _InfoCard({required this.children,
      required this.cardColor, required this.borderColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(children: children),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? valueSuffix;
  final Color color;
  const _InfoRow({required this.icon, required this.label,
      required this.value, required this.color, this.valueSuffix});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(label,
                style: tt.bodyMedium?.copyWith(fontSize: 13)),
          ),
          RichText(
            text: TextSpan(children: [
              TextSpan(
                text: value,
                style: tt.bodyLarge?.copyWith(
                    fontSize: 14, fontWeight: FontWeight.w600),
              ),
              if (valueSuffix != null)
                TextSpan(
                  text: valueSuffix,
                  style: tt.bodyMedium?.copyWith(fontSize: 12),
                ),
            ]),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color cardColor;
  final Color borderColor;
  final String tooltip;
  final String? subtitle;
  final Color? valueColor;
  const _MetricCard({required this.label, required this.value,
      required this.icon, required this.color, required this.cardColor,
      required this.borderColor, required this.tooltip,
      this.subtitle, this.valueColor});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 5),
              Expanded(
                child: Text(label,
                    style: tt.bodyMedium?.copyWith(fontSize: 11),
                    overflow: TextOverflow.ellipsis),
              ),
              Icon(Icons.info_outline_rounded,
                  size: 12, color: const Color(0xFF7BA7C2)),
            ]),
            const SizedBox(height: 8),
            Text(value,
                style: TextStyle(
                    color: valueColor ?? const Color(0xFFE8F4FD),
                    fontSize: 15,
                    fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(subtitle!,
                  style: tt.bodyMedium?.copyWith(fontSize: 10),
                  overflow: TextOverflow.ellipsis),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(label.toUpperCase(),
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontSize: 11,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w600));
  }
}

class _Divider extends StatelessWidget {
  const _Divider({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Divider(height: 1, color: color, indent: 56, endIndent: 16);
  }
}

class _CreateAlertSheet extends StatefulWidget {
  final List<Map<String, dynamic>> assets;
  final Map<String, dynamic>? preselectedAsset;
  final void Function(Map<String, dynamic>) onCreated;

  const _CreateAlertSheet({
    required this.assets,
    required this.onCreated,
    this.preselectedAsset,
  });

  @override
  State<_CreateAlertSheet> createState() => _CreateAlertSheetState();
}

class _CreateAlertSheetState extends State<_CreateAlertSheet> {
  final supabase      = Supabase.instance.client;
  final _priceCtrl    = TextEditingController();
  final _formKey      = GlobalKey<FormState>();

  Map<String, dynamic>? _selectedAsset;
  String _condition   = 'above';
  bool   _isSaving    = false;
  bool   _loadingPrice= false;
  double _currentPrice= 0;

  static const Map<String, Color> _typeColors = {
    'crypto': Color(0xFFF7931A),
    'stock':  Color(0xFF4FC3F7),
    'etf':    Color(0xFF69F0AE),
  };

  @override
  void initState() {
    super.initState();
    if (widget.preselectedAsset != null) {
      _selectedAsset = widget.preselectedAsset;
      _fetchCurrentPrice();
    }
  }

  @override
  void dispose() {
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchCurrentPrice() async {
    if (_selectedAsset == null) return;
    setState(() => _loadingPrice = true);
    try {
      final live = await MarketService.fetchAsset(
        _selectedAsset!['symbol'] as String,
        _selectedAsset!['type']   as String,
      );
      if (live != null && mounted) {
        setState(() {
          _currentPrice = (live['price'] as num?)?.toDouble() ?? 0;
        });
      }
    } finally {
      if (mounted) setState(() => _loadingPrice = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedAsset == null) return;

    setState(() => _isSaving = true);
    try {
      final cp        = context.read<CurrencyProvider>();
      final uid       = supabase.auth.currentUser!.id;
      final rawPrice  = double.parse(_priceCtrl.text.replaceAll(',', '.'));
      // Guardar siempre en USD
      final priceUsd  = cp.rate > 0 ? rawPrice / cp.rate : rawPrice;

      final inserted = await supabase.from('price_alerts').insert({
        'user_id':      uid,
        'asset_id':     _selectedAsset!['id'],
        'name':         _selectedAsset!['name'],
        'symbol':       _selectedAsset!['symbol'],
        'type':         _selectedAsset!['type'],
        'icon':         _selectedAsset!['icon'],
        'condition':    _condition,
        'target_price': priceUsd,
      }).select().single();

      if (mounted) {
        widget.onCreated(inserted);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Alerta creada correctamente')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: const Color(0xFFFF6B6B),
        ));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt     = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final cp     = context.watch<CurrencyProvider>();

    const cardColor   = Color(0xFF1E2D3D);
    const borderColor = Color(0xFF1E3A5F);

    final typeColor = _selectedAsset != null
        ? (_typeColors[_selectedAsset!['type']] ?? scheme.primary)
        : scheme.primary;

    final condColor = _condition == 'above'
        ? const Color(0xFF69F0AE)
        : const Color(0xFFFF6B6B);

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF111827),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 20, left: 20, right: 20,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // Handle
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E3A5F),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            Text('Nueva alerta de precio',
                style: tt.bodyLarge
                    ?.copyWith(fontWeight: FontWeight.bold, fontSize: 17)),
            const SizedBox(height: 20),

            // ── SELECTOR DE ACTIVO ──────────────────────────────────────
            Text('Activo', style: tt.bodyMedium?.copyWith(fontSize: 12)),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<Map<String, dynamic>>(
                  value: _selectedAsset,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF1E2D3D),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 4),
                  hint: Text('Selecciona un activo',
                      style: tt.bodyMedium),
                  items: widget.assets.map((asset) {
                    final tc = _typeColors[asset['type']] ??
                        scheme.primary;
                    return DropdownMenuItem(
                      value: asset,
                      child: Row(
                        children: [
                          Container(
                            width: 28, height: 28,
                            decoration: BoxDecoration(
                              color: tc.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              asset['icon'] as String? ?? '?',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: tc),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '${asset['name']}  (${asset['symbol']})',
                            style: tt.bodyMedium,
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (asset) {
                    setState(() {
                      _selectedAsset = asset;
                      _currentPrice  = 0;
                      _priceCtrl.clear();
                    });
                    _fetchCurrentPrice();
                  },
                ),
              ),
            ),

            // Precio actual
            if (_selectedAsset != null) ...[
              const SizedBox(height: 8),
              _loadingPrice
                  ? Row(
                      children: [
                        const SizedBox(
                          width: 12, height: 12,
                          child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: Color(0xFF7BA7C2)),
                        ),
                        const SizedBox(width: 8),
                        Text('Cargando precio...',
                            style: tt.bodyMedium
                                ?.copyWith(fontSize: 11)),
                      ],
                    )
                  : Text(
                      'Precio actual: ${_currentPrice > 0 ? cp.format(_currentPrice) : '—'}',
                      style: tt.bodyMedium?.copyWith(
                          fontSize: 11,
                          color: typeColor),
                    ),
            ],

            const SizedBox(height: 20),

            // ── CONDICIÓN ────────────────────────────────────────────────
            Text('Condición', style: tt.bodyMedium?.copyWith(fontSize: 12)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _condition = 'above'),
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _condition == 'above'
                            ? const Color(0xFF69F0AE).withOpacity(0.12)
                            : cardColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _condition == 'above'
                              ? const Color(0xFF69F0AE)
                              : borderColor,
                          width: _condition == 'above' ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.arrow_upward_rounded,
                              size: 16,
                              color: _condition == 'above'
                                  ? const Color(0xFF69F0AE)
                                  : const Color(0xFF7BA7C2)),
                          const SizedBox(width: 6),
                          Text('Por encima',
                              style: TextStyle(
                                color: _condition == 'above'
                                    ? const Color(0xFF69F0AE)
                                    : const Color(0xFF7BA7C2),
                                fontSize: 13,
                                fontWeight: _condition == 'above'
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              )),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _condition = 'below'),
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _condition == 'below'
                            ? const Color(0xFFFF6B6B).withOpacity(0.12)
                            : cardColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _condition == 'below'
                              ? const Color(0xFFFF6B6B)
                              : borderColor,
                          width: _condition == 'below' ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.arrow_downward_rounded,
                              size: 16,
                              color: _condition == 'below'
                                  ? const Color(0xFFFF6B6B)
                                  : const Color(0xFF7BA7C2)),
                          const SizedBox(width: 6),
                          Text('Por debajo',
                              style: TextStyle(
                                color: _condition == 'below'
                                    ? const Color(0xFFFF6B6B)
                                    : const Color(0xFF7BA7C2),
                                fontSize: 13,
                                fontWeight: _condition == 'below'
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              )),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── PRECIO OBJETIVO ───────────────────────────────────────────
            Text('Precio objetivo (${cp.currency})',
                style: tt.bodyMedium?.copyWith(fontSize: 12)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: condColor.withOpacity(0.4)),
              ),
              child: TextFormField(
                controller: _priceCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: '0.00',
                  prefixText: '${cp.symbol} ',
                  prefixStyle: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: condColor),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) {
                    return 'Ingresa el precio objetivo';
                  }
                  final n = double.tryParse(v.replaceAll(',', '.'));
                  if (n == null) return 'Número no válido';
                  if (n <= 0) return 'Debe ser mayor que 0';
                  return null;
                },
              ),
            ),

            const SizedBox(height: 28),

            // ── BOTÓN CREAR ───────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: (_isSaving || _selectedAsset == null)
                    ? null
                    : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: condColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                icon: _isSaving
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Icon(
                        _condition == 'above'
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded,
                        size: 18),
                label: Text(
                  _isSaving ? 'Creando...' : 'Crear alerta',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}