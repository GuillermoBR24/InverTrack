import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/market_service.dart';

class AssetDetailInvestScreen extends StatefulWidget {
  final Map<String, dynamic> asset;
  const AssetDetailInvestScreen({super.key, required this.asset});

  @override
  State<AssetDetailInvestScreen> createState() =>
      _AssetDetailInvestScreenState();
}

class _AssetDetailInvestScreenState extends State<AssetDetailInvestScreen> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  bool _isSaving     = false;
  bool _loadingPrice = false;

  late Map<String, dynamic> _asset;

  @override
  void initState() {
    super.initState();
    _asset = Map<String, dynamic>.from(widget.asset);
    _refreshPrice();
  }

  Future<void> _refreshPrice() async {
    setState(() => _loadingPrice = true);
    try {
      final live = await MarketService.fetchAsset(
        _asset['symbol'] as String,
        _asset['type']   as String,
      );
      if (live != null && mounted) {
        setState(() => _asset = {..._asset, ...live});
      }
    } finally {
      if (mounted) setState(() => _loadingPrice = false);
    }
  }

  static const Map<String, Color> _typeColors = {
    'crypto': Color(0xFFF7931A),
    'stock':  Color(0xFF4FC3F7),
    'etf':    Color(0xFF69F0AE),
  };

  Color  get _color => _typeColors[_asset['type']] ?? const Color(0xFF4FC3F7);
  double get _price => (_asset['price'] as num?)?.toDouble() ?? 0.0;

  double get _amountInvested =>
      double.tryParse(_amountController.text.replaceAll(',', '.')) ?? 0;

  double get _unitsCalculated =>
      _amountInvested > 0 && _price > 0 ? _amountInvested / _price : 0;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final uid   = supabase.auth.currentUser!.id;
      final qty   = _unitsCalculated;
      final total = _amountInvested;

      await supabase.from('assets').insert({
        'user_id':    uid,
        'name':       _asset['name'],
        'symbol':     _asset['symbol'],
        'type':       _asset['type'],
        'icon':       _asset['icon'],
        'quantity':   qty,
        'buy_price':  _price,
        'value':      total,
        'price':      _price,
        'change':     (_asset['change'] as num?)?.toDouble() ?? 0.0,
        'created_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        Navigator.pop(context, {
          'name':   _asset['name'],
          'symbol': _asset['symbol'],
          'type':   _asset['type'],
          'icon':   _asset['icon'],
          'price':  _price,
          'change': (_asset['change'] as num?)?.toDouble() ?? 0.0,
          'value':  total,
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error al guardar: $e'),
          backgroundColor: const Color(0xFFFF6B6B),
        ));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tt   = Theme.of(context).textTheme;
    final type = _asset['type'] as String;

    const cardColor   = Color(0xFF1E2D3D);
    const borderColor = Color(0xFF1E3A5F);

    final change = (_asset['change'] as num?)?.toDouble() ?? 0.0;
    final isPos  = change >= 0;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Text(_asset['symbol'] as String,
                style: tt.bodyLarge
                    ?.copyWith(fontWeight: FontWeight.w600, color: _color)),
            const SizedBox(width: 8),
            Flexible(
              child: Text(_asset['name'] as String,
                  style: tt.bodyMedium?.copyWith(fontSize: 13),
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        actions: [
          if (_loadingPrice)
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
              tooltip: 'Actualizar precio',
              onPressed: _refreshPrice,
            ),
        ],
      ),

      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          children: [

            // ── CABECERA PRECIO ────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _color.withOpacity(0.25),
                    _color.withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _color.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                      color: _color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: Text(_asset['icon'] as String,
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: _color)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Precio actual',
                            style: tt.bodyMedium?.copyWith(fontSize: 12)),
                        _loadingPrice
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
                                _price > 0
                                    ? '\$${_price.toStringAsFixed(2)}'
                                    : '—',
                                style: TextStyle(
                                  color: _color,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -0.5,
                                ),
                              ),
                      ],
                    ),
                  ),
                  if (!_loadingPrice && _price > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: (isPos
                                ? const Color(0xFF69F0AE)
                                : const Color(0xFFFF6B6B))
                            .withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${isPos ? '+' : ''}${change.toStringAsFixed(2)}%',
                        style: TextStyle(
                          color: isPos
                              ? const Color(0xFF69F0AE)
                              : const Color(0xFFFF6B6B),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── MÉTRICAS ───────────────────────────────────────────────
            _SectionLabel(label: 'Métricas clave'),
            const SizedBox(height: 12),

            if (type == 'crypto') _CryptoMetrics(
                asset: _asset, color: _color,
                cardColor: cardColor, borderColor: borderColor),
            if (type == 'stock')  _StockMetrics(
                asset: _asset, color: _color,
                cardColor: cardColor, borderColor: borderColor),
            if (type == 'etf')    _EtfMetrics(
                asset: _asset, color: _color,
                cardColor: cardColor, borderColor: borderColor),

            const SizedBox(height: 24),

            // ── INVERSIÓN ──────────────────────────────────────────────
            _SectionLabel(label: 'Tu inversión'),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                children: [
                  TextFormField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      labelText: 'Cantidad a invertir',
                      prefixText: '\$ ',
                      prefixStyle: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: _color),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      contentPadding: EdgeInsets.zero,
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Ingresa el importe';
                      final n = double.tryParse(v.replaceAll(',', '.'));
                      if (n == null) return 'Número no válido';
                      if (n <= 0) return 'Debe ser mayor que 0';
                      return null;
                    },
                  ),

                  if (_amountInvested > 0 && _price > 0) ...[
                    const SizedBox(height: 16),
                    Divider(color: borderColor, height: 1),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Recibirás',
                            style: tt.bodyMedium?.copyWith(fontSize: 13)),
                        RichText(
                          text: TextSpan(children: [
                            TextSpan(
                              text: _unitsCalculated < 0.001
                                  ? _unitsCalculated.toStringAsFixed(8)
                                  : _unitsCalculated.toStringAsFixed(6),
                              style: TextStyle(
                                  color: _color,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold),
                            ),
                            TextSpan(
                              text: '  ${_asset['symbol']}',
                              style: tt.bodyMedium?.copyWith(fontSize: 13),
                            ),
                          ]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Precio por unidad',
                            style: tt.bodyMedium?.copyWith(fontSize: 13)),
                        Text('\$${_price.toStringAsFixed(2)}',
                            style: tt.bodyLarge?.copyWith(
                                fontSize: 13,
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 32),

            // ── BOTÓN CONFIRMAR ────────────────────────────────────────
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: (_isSaving || _price == 0) ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      Theme.of(context).colorScheme.secondary,
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5))
                    : Text(
                        _amountInvested > 0 && _price > 0
                            ? 'Invertir \$${_amountInvested.toStringAsFixed(2)} en ${_asset['symbol']}'
                            : 'Confirmar inversión',
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
    final hasHashRate = asset.containsKey('hash_rate');
    final hasTvl      = asset.containsKey('tvl');

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
              valueColor: _scoreColor(asset['community_score'] ?? 0))),
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
              valueColor: _scoreColor(asset['community_score'] ?? 0))),
        ]),
      ] else ...[
        Row(children: [
          Expanded(child: _MetricCard(
              label: 'Comunidad',
              value: '${asset['community_score'] ?? '—'}/100',
              icon: Icons.group_rounded, color: color,
              cardColor: cardColor, borderColor: borderColor,
              tooltip: 'Actividad y transparencia de la comunidad',
              valueColor: _scoreColor(asset['community_score'] ?? 0))),
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

  String _fmt(dynamic v, {String suffix = '', String prefix = ''}) {
    if (v == null) return '—';
    return '$prefix$v$suffix';
  }

  @override
  Widget build(BuildContext context) {
    final pe   = (asset['pe_ratio']     as num?)?.toDouble();
    final debt = (asset['debt_equity']  as num?)?.toDouble();

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
            value: _fmt(asset['eps'], prefix: '\$'),
            icon: Icons.trending_up_rounded, color: color,
            cardColor: cardColor, borderColor: borderColor,
            tooltip: 'Ganancias por acción. Mayor = mejor rendimiento')),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: _MetricCard(
            label: 'ROE',
            value: _fmt(asset['roe'], suffix: '%'),
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
            value: _fmt(asset['dividend_yield'], suffix: '%'),
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
                ? '${asset['tracking_error']}%'
                : '—',
            icon: Icons.track_changes_rounded, color: color,
            cardColor: cardColor, borderColor: borderColor,
            tooltip: 'Desviación respecto al índice. Menor = más fiel')),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: _MetricCard(
            label: 'Índice',
            value: asset['index'] ?? '—',
            icon: Icons.list_alt_rounded, color: color,
            cardColor: cardColor, borderColor: borderColor,
            tooltip: 'Índice subyacente que replica el ETF')),
        const SizedBox(width: 10),
        Expanded(child: _MetricCard(
            label: 'Estructura',
            value: asset['structure'] ?? '—',
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

  const _MetricCard({
    required this.label, required this.value, required this.icon,
    required this.color, required this.cardColor, required this.borderColor,
    required this.tooltip, this.subtitle, this.valueColor,
  });

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
            fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w600));
  }
}