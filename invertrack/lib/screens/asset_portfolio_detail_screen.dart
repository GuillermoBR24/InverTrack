import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AssetPortfolioDetailScreen extends StatefulWidget {
  final Map<String, dynamic> asset;
  const AssetPortfolioDetailScreen({super.key, required this.asset});

  @override
  State<AssetPortfolioDetailScreen> createState() =>
      _AssetPortfolioDetailScreenState();
}

class _AssetPortfolioDetailScreenState
    extends State<AssetPortfolioDetailScreen> {
  final supabase = Supabase.instance.client;
  bool _isDeleting = false;

  static const Map<String, Color> _typeColors = {
    'crypto': Color(0xFFF7931A),
    'stock':  Color(0xFF4FC3F7),
    'etf':    Color(0xFF69F0AE),
  };

  Color get _color =>
      _typeColors[widget.asset['type']] ?? const Color(0xFF4FC3F7);

  double get _price     => (widget.asset['price']     as num?)?.toDouble() ?? 0;
  double get _buyPrice  => (widget.asset['buy_price'] as num?)?.toDouble() ?? 0;
  double get _quantity  => (widget.asset['quantity']  as num?)?.toDouble() ?? 0;
  double get _value     => (widget.asset['value']     as num?)?.toDouble() ?? 0;
  double get _change    => (widget.asset['change']    as num?)?.toDouble() ?? 0;

  double get _currentValue  => _price * _quantity;
  double get _gainLoss      => _currentValue - _value;
  double get _gainLossPct   => _value > 0 ? (_gainLoss / _value) * 100 : 0;

  // ── ELIMINAR ─────────────────────────────────────────────────────────────────
  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Eliminar activo',
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(fontWeight: FontWeight.bold)),
        content: Text(
          '¿Seguro que quieres eliminar ${widget.asset['name']} de tu portfolio? Esta acción no se puede deshacer.',
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
                    color: Color(0xFFFF6B6B), fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isDeleting = true);
    try {
      await supabase
          .from('assets')
          .delete()
          .eq('id', widget.asset['id']);

      if (mounted) {
        Navigator.pop(context, 'deleted');
      }
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
    final tt          = Theme.of(context).textTheme;
    final isPos       = _change >= 0;
    final gainIsPos   = _gainLoss >= 0;
    final changeColor = isPos
        ? const Color(0xFF69F0AE)
        : const Color(0xFFFF6B6B);
    final gainColor   = gainIsPos
        ? const Color(0xFF69F0AE)
        : const Color(0xFFFF6B6B);

    const cardColor   = Color(0xFF1E2D3D);
    const borderColor = Color(0xFF1E3A5F);

    final type = widget.asset['type'] as String? ?? '';

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Text(widget.asset['symbol'] as String? ?? '',
                style: tt.bodyLarge
                    ?.copyWith(fontWeight: FontWeight.w600, color: _color)),
            const SizedBox(width: 8),
            Text(widget.asset['name'] as String? ?? '',
                style: tt.bodyMedium?.copyWith(fontSize: 13)),
          ],
        ),
      ),

      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [

          // ── CABECERA ────────────────────────────────────────────────────
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
                  child: Text(
                    widget.asset['icon'] as String? ?? '?',
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
                      Text(
                        '\$${_price.toStringAsFixed(2)}',
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

          // ── GANANCIA / PÉRDIDA ──────────────────────────────────────────
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
                      Text(gainIsPos ? 'Ganancia actual' : 'Pérdida actual',
                          style: tt.bodyMedium?.copyWith(fontSize: 12)),
                      Text(
                        '${gainIsPos ? '+' : ''}\$${_gainLoss.toStringAsFixed(2)}',
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

          // ── DATOS DE LA INVERSIÓN ───────────────────────────────────────
          _SectionLabel(label: 'Tu inversión'),
          const SizedBox(height: 10),
          _InfoCard(
            cardColor: cardColor,
            borderColor: borderColor,
            children: [
              _InfoRow(
                icon: Icons.attach_money_rounded,
                label: 'Valor invertido',
                value: '\$${_value.toStringAsFixed(2)}',
                color: _color,
              ),
              _Divider(color: borderColor),
              _InfoRow(
                icon: Icons.price_change_rounded,
                label: 'Precio de compra',
                value: '\$${_buyPrice.toStringAsFixed(2)}',
                color: _color,
              ),
              _Divider(color: borderColor),
              _InfoRow(
                icon: Icons.numbers_rounded,
                label: 'Cantidad',
                value: _quantity < 0.001
                    ? _quantity.toStringAsFixed(8)
                    : _quantity.toStringAsFixed(6),
                valueSuffix: '  ${widget.asset['symbol']}',
                color: _color,
              ),
              _Divider(color: borderColor),
              _InfoRow(
                icon: Icons.account_balance_wallet_rounded,
                label: 'Valor actual',
                value: '\$${_currentValue.toStringAsFixed(2)}',
                color: _color,
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ── MÉTRICAS SEGÚN TIPO ─────────────────────────────────────────
          _SectionLabel(label: 'Métricas clave'),
          const SizedBox(height: 10),

          if (type == 'crypto') _CryptoMetrics(
              asset: widget.asset, color: _color,
              cardColor: cardColor, borderColor: borderColor),
          if (type == 'stock')  _StockMetrics(
              asset: widget.asset, color: _color,
              cardColor: cardColor, borderColor: borderColor),
          if (type == 'etf')    _EtfMetrics(
              asset: widget.asset, color: _color,
              cardColor: cardColor, borderColor: borderColor),

          const SizedBox(height: 32),

          // ── BOTÓN ELIMINAR ──────────────────────────────────────────────
          SizedBox(
            height: 52,
            child: OutlinedButton.icon(
              onPressed: _isDeleting ? null : _delete,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFFF6B6B),
                side: const BorderSide(color: Color(0xFFFF6B6B), width: 1.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              icon: _isDeleting
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Color(0xFFFF6B6B)))
                  : const Icon(Icons.delete_outline_rounded, size: 20),
              label: Text(
                _isDeleting
                    ? 'Eliminando...'
                    : 'Eliminar ${widget.asset['name']} del portfolio',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
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

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Row(children: [
        _MetricCard(label: 'Market Cap', value: asset['market_cap'] ?? '—',
            icon: Icons.pie_chart_rounded, color: color,
            cardColor: cardColor, borderColor: borderColor,
            tooltip: 'Capitalización total. Mayor = más estable'),
        const SizedBox(width: 10),
        _MetricCard(label: 'Volumen 24h', value: asset['volume_24h'] ?? '—',
            icon: Icons.bar_chart_rounded, color: color,
            cardColor: cardColor, borderColor: borderColor,
            tooltip: 'Liquidez del mercado en las últimas 24h'),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        _MetricCard(
            label: 'Oferta circ.', value: asset['circ_supply'] ?? '—',
            icon: Icons.rotate_right_rounded, color: color,
            cardColor: cardColor, borderColor: borderColor,
            tooltip: 'Tokens en circulación vs oferta máxima',
            subtitle: 'Máx: ${asset['max_supply'] ?? '∞'}'),
        const SizedBox(width: 10),
        _MetricCard(label: 'Dir. activas',
            value: asset['active_addresses'] ?? '—',
            icon: Icons.people_rounded, color: color,
            cardColor: cardColor, borderColor: borderColor,
            tooltip: 'Adopción real de la red'),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        if (asset.containsKey('hash_rate')) ...[
          Expanded(child: _MetricCard(label: 'Hash Rate',
              value: asset['hash_rate'] ?? '—',
              icon: Icons.memory_rounded, color: color,
              cardColor: cardColor, borderColor: borderColor,
              tooltip: 'Potencia computacional (PoW)')),
          const SizedBox(width: 10),
        ],
        if (asset.containsKey('tvl')) ...[
          Expanded(child: _MetricCard(label: 'TVL',
              value: '\$${asset['tvl'] ?? '—'}',
              icon: Icons.lock_rounded, color: color,
              cardColor: cardColor, borderColor: borderColor,
              tooltip: 'Total Value Locked en DeFi')),
          const SizedBox(width: 10),
        ],
        Expanded(child: _MetricCard(label: 'Comunidad',
            value: '${asset['community_score'] ?? '—'}/100',
            icon: Icons.group_rounded, color: color,
            cardColor: cardColor, borderColor: borderColor,
            tooltip: 'Actividad y transparencia',
            valueColor: _scoreColor(asset['community_score'] ?? 0))),
      ]),
    ]);
  }

  Color _scoreColor(int s) {
    if (s >= 80) return const Color(0xFF69F0AE);
    if (s >= 60) return const Color(0xFFFFC107);
    return const Color(0xFFFF6B6B);
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

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Row(children: [
        _MetricCard(label: 'P/E Ratio',
            value: '${asset['pe_ratio'] ?? '—'}x',
            icon: Icons.show_chart_rounded, color: color,
            cardColor: cardColor, borderColor: borderColor,
            tooltip: 'Alto = sobrevaloración. Bajo = oportunidad',
            valueColor: _peColor((asset['pe_ratio'] as num?)?.toDouble() ?? 0)),
        const SizedBox(width: 10),
        _MetricCard(label: 'EPS', value: '\$${asset['eps'] ?? '—'}',
            icon: Icons.trending_up_rounded, color: color,
            cardColor: cardColor, borderColor: borderColor,
            tooltip: 'Ganancias por acción'),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        _MetricCard(label: 'ROE', value: '${asset['roe'] ?? '—'}%',
            icon: Icons.percent_rounded, color: color,
            cardColor: cardColor, borderColor: borderColor,
            tooltip: 'Retorno sobre el patrimonio',
            valueColor: const Color(0xFF69F0AE)),
        const SizedBox(width: 10),
        _MetricCard(label: 'Deuda/Capital',
            value: '${asset['debt_equity'] ?? '—'}',
            icon: Icons.account_balance_rounded, color: color,
            cardColor: cardColor, borderColor: borderColor,
            tooltip: 'Ratio alto = mayor riesgo',
            valueColor: _debtColor(
                (asset['debt_equity'] as num?)?.toDouble() ?? 0)),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        _MetricCard(label: 'Div. Yield',
            value: '${asset['dividend_yield'] ?? 0}%',
            icon: Icons.savings_rounded, color: color,
            cardColor: cardColor, borderColor: borderColor,
            tooltip: 'Rentabilidad por dividendos'),
        const SizedBox(width: 10),
        _MetricCard(label: 'Flujo de caja',
            value: asset['free_cash_flow'] ?? '—',
            icon: Icons.water_drop_rounded, color: color,
            cardColor: cardColor, borderColor: borderColor,
            tooltip: 'Dinero disponible tras gastos',
            valueColor: const Color(0xFF69F0AE)),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        _MetricCard(label: 'Market Cap',
            value: asset['market_cap'] ?? '—',
            icon: Icons.corporate_fare_rounded, color: color,
            cardColor: cardColor, borderColor: borderColor,
            tooltip: 'Capitalización bursátil total'),
        const SizedBox(width: 10),
        _MetricCard(label: 'Sector',
            value: asset['sector'] ?? '—',
            icon: Icons.category_rounded, color: color,
            cardColor: cardColor, borderColor: borderColor,
            tooltip: 'Sector de actividad'),
      ]),
    ]);
  }

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
}

// ── MÉTRICAS ETF ──────────────────────────────────────────────────────────────
class _EtfMetrics extends StatelessWidget {
  final Map<String, dynamic> asset;
  final Color color;
  final Color cardColor;
  final Color borderColor;
  const _EtfMetrics({required this.asset, required this.color,
      required this.cardColor, required this.borderColor});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Row(children: [
        _MetricCard(label: 'Expense Ratio',
            value: '${asset['expense_ratio'] ?? '—'}%',
            icon: Icons.receipt_long_rounded, color: color,
            cardColor: cardColor, borderColor: borderColor,
            tooltip: 'Comisión anual. Menor = mejor',
            valueColor: _expenseColor(
                (asset['expense_ratio'] as num?)?.toDouble() ?? 0)),
        const SizedBox(width: 10),
        _MetricCard(label: 'Tracking Error',
            value: '${asset['tracking_error'] ?? '—'}%',
            icon: Icons.track_changes_rounded, color: color,
            cardColor: cardColor, borderColor: borderColor,
            tooltip: 'Desviación vs índice. Menor = más fiel'),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        _MetricCard(label: 'Índice',
            value: asset['index'] ?? '—',
            icon: Icons.list_alt_rounded, color: color,
            cardColor: cardColor, borderColor: borderColor,
            tooltip: 'Índice que replica el ETF'),
        const SizedBox(width: 10),
        _MetricCard(label: 'Estructura',
            value: asset['structure'] ?? '—',
            icon: Icons.account_tree_rounded, color: color,
            cardColor: cardColor, borderColor: borderColor,
            tooltip: 'Réplica total = compra física'),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        _MetricCard(label: 'AUM',
            value: '\$${asset['aum'] ?? '—'}',
            icon: Icons.account_balance_wallet_rounded, color: color,
            cardColor: cardColor, borderColor: borderColor,
            tooltip: 'Activos bajo gestión'),
        const SizedBox(width: 10),
        _MetricCard(label: 'Div. Yield',
            value: '${asset['dividend_yield'] ?? 0}%',
            icon: Icons.savings_rounded, color: color,
            cardColor: cardColor, borderColor: borderColor,
            tooltip: 'Rentabilidad por dividendos'),
      ]),
    ]);
  }

  Color _expenseColor(double e) {
    if (e < 0.2) return const Color(0xFF69F0AE);
    if (e < 0.5) return const Color(0xFFFFC107);
    return const Color(0xFFFF6B6B);
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
    return Expanded(
      child: Tooltip(
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

class _Divider extends StatelessWidget {
  const _Divider({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Divider(height: 1, color: color, indent: 56, endIndent: 16);
  }
}