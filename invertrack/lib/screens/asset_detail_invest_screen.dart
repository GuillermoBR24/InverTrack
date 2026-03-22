import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:invertrack/providers/currency_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/market_service.dart';

class AssetDetailInvestScreen extends StatefulWidget {
  final Map<String, dynamic> asset;
  const AssetDetailInvestScreen({super.key, required this.asset});

  @override
  State<AssetDetailInvestScreen> createState() =>
      _AssetDetailInvestScreenState();
}

enum _InputMode { dinero, cantidad }

class _AssetDetailInvestScreenState extends State<AssetDetailInvestScreen> {
  final supabase             = Supabase.instance.client;
  final _formKey             = GlobalKey<FormState>();
  final _buyPriceController  = TextEditingController();
  final _mainInputController = TextEditingController();
  bool       _isSaving     = false;
  bool       _loadingPrice = false;
  _InputMode _inputMode    = _InputMode.dinero;

  late Map<String, dynamic> _asset;

  @override
  void initState() {
    super.initState();
    _asset = Map<String, dynamic>.from(widget.asset);
    _refreshPrice();
  }

  @override
  void dispose() {
    _buyPriceController.dispose();
    _mainInputController.dispose();
    super.dispose();
  }

  Future<void> _refreshPrice() async {
    setState(() => _loadingPrice = true);
    try {
      final live = await MarketService.fetchAsset(
        _asset['symbol'] as String,
        _asset['type']   as String,
      );
      if (live != null && mounted) {
        final cp = context.read<CurrencyProvider>();
        setState(() {
          _asset = {..._asset, ...live};
          // Pre-rellenar precio en la moneda seleccionada si está vacío
          if (_buyPriceController.text.isEmpty && live['price'] != null) {
            final p = (live['price'] as num).toDouble();
            if (p > 0) {
              _buyPriceController.text =
                  cp.convert(p).toStringAsFixed(2);
            }
          }
        });
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

  Color  get _color        => _typeColors[_asset['type']] ?? const Color(0xFF4FC3F7);
  double get _currentPrice => (_asset['price'] as num?)?.toDouble() ?? 0.0;

  // Precio de compra introducido por el usuario (en moneda local)
  // → convertido a USD para guardar en BD
  double _buyPriceUsd(CurrencyProvider cp) {
    final raw = double.tryParse(
        _buyPriceController.text.replaceAll(',', '.')) ?? 0;
    final localPrice = raw > 0 ? raw : cp.convert(_currentPrice);
    // Si rate=1 (USD) no hace nada; si rate≠1 (EUR) divide para obtener USD
    return cp.rate > 0 ? localPrice / cp.rate : localPrice;
  }

  double get _mainValue =>
      double.tryParse(_mainInputController.text.replaceAll(',', '.')) ?? 0;

  // Cantidad comprada en unidades del activo
  double _quantityCalc(CurrencyProvider cp) {
    if (_inputMode == _InputMode.dinero) {
      final buyUsd = _buyPriceUsd(cp);
      // mainValue está en moneda local → convertir a USD
      final mainUsd = cp.rate > 0 ? _mainValue / cp.rate : _mainValue;
      return buyUsd > 0 ? mainUsd / buyUsd : 0;
    } else {
      return _mainValue;
    }
  }

  // Total invertido en USD (lo que se guarda en BD)
  double _totalInvestedUsd(CurrencyProvider cp) {
    if (_inputMode == _InputMode.dinero) {
      return cp.rate > 0 ? _mainValue / cp.rate : _mainValue;
    } else {
      return _mainValue * _buyPriceUsd(cp);
    }
  }

  Future<void> _save(CurrencyProvider cp) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final uid      = supabase.auth.currentUser!.id;
      final qty      = _quantityCalc(cp);
      final buyUsd   = _buyPriceUsd(cp);
      final totalUsd = _totalInvestedUsd(cp);

      await supabase.from('assets').insert({
        'user_id':    uid,
        'name':       _asset['name'],
        'symbol':     _asset['symbol'],
        'type':       _asset['type'],
        'icon':       _asset['icon'],
        'quantity':   qty,
        'buy_price':  buyUsd,   // siempre USD en BD
        'value':      totalUsd, // siempre USD en BD
        'price':      _currentPrice,
        'change':     (_asset['change'] as num?)?.toDouble() ?? 0.0,
        'created_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        Navigator.pop(context, {
          'name':   _asset['name'],
          'symbol': _asset['symbol'],
          'type':   _asset['type'],
          'icon':   _asset['icon'],
          'price':  _currentPrice,
          'change': (_asset['change'] as num?)?.toDouble() ?? 0.0,
          'value':  totalUsd,
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
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cp = context.watch<CurrencyProvider>();
    final type = _asset['type'] as String;

    const cardColor   = Color(0xFF1E2D3D);
    const borderColor = Color(0xFF1E3A5F);

    final change    = (_asset['change'] as num?)?.toDouble() ?? 0.0;
    final isPos     = change >= 0;
    final qty       = _quantityCalc(cp);
    final totalUsd  = _totalInvestedUsd(cp);
    final buyUsd    = _buyPriceUsd(cp);
    final hasValid  = _mainValue > 0 && buyUsd > 0;

    // Precio actual en moneda local para mostrar
    final currentPriceLocal = cp.convert(_currentPrice);

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

            // ── CABECERA PRECIO ACTUAL ─────────────────────────────────
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
                    child: () {
                      final thumb = _asset['thumb'] as String?;
                      if (thumb != null && thumb.isNotEmpty) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            thumb,
                            width: 34, height: 34,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => Text(
                              _asset['icon'] as String? ?? '?',
                              style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: _color),
                            ),
                          ),
                        );
                      }
                      return Text(
                        _asset['icon'] as String? ?? '?',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: _color),
                      );
                    }(),
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
                                _currentPrice > 0
                                    ? cp.format(_currentPrice)
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
                  if (!_loadingPrice && _currentPrice > 0)
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
            _SectionLabel(label: 'Registrar inversión'),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── PRECIO DE COMPRA ───────────────────────────────────
                  Text('Precio al que compraste (${cp.currency})',
                      style: tt.bodyMedium?.copyWith(fontSize: 12)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _buyPriceController,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: currentPriceLocal > 0
                          ? currentPriceLocal.toStringAsFixed(2)
                          : '0.00',
                      prefixText: '${cp.symbol} ',
                      prefixStyle: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: _color),
                      helperText: _currentPrice > 0
                          ? 'Precio actual: ${cp.format(_currentPrice)}'
                          : null,
                      helperStyle: tt.bodyMedium?.copyWith(fontSize: 11),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      contentPadding: EdgeInsets.zero,
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        if (_currentPrice <= 0) {
                          return 'Ingresa el precio de compra';
                        }
                        return null;
                      }
                      final n = double.tryParse(v.replaceAll(',', '.'));
                      if (n == null) return 'Número no válido';
                      if (n <= 0) return 'Debe ser mayor que 0';
                      return null;
                    },
                  ),

                  Divider(height: 28, color: borderColor),

                  // ── SELECTOR MODO ──────────────────────────────────────
                  Text('¿Cómo quieres indicar la compra?',
                      style: tt.bodyMedium?.copyWith(fontSize: 12)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() {
                            _inputMode = _InputMode.dinero;
                            _mainInputController.clear();
                          }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _inputMode == _InputMode.dinero
                                  ? _color.withOpacity(0.15)
                                  : const Color(0xFF0A0E1A),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _inputMode == _InputMode.dinero
                                    ? _color : borderColor,
                                width: _inputMode == _InputMode.dinero
                                    ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.attach_money_rounded,
                                    size: 16,
                                    color: _inputMode == _InputMode.dinero
                                        ? _color
                                        : const Color(0xFF7BA7C2)),
                                const SizedBox(width: 4),
                                Text('En dinero',
                                    style: TextStyle(
                                      color: _inputMode == _InputMode.dinero
                                          ? _color
                                          : const Color(0xFF7BA7C2),
                                      fontSize: 13,
                                      fontWeight: _inputMode == _InputMode.dinero
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
                          onTap: () => setState(() {
                            _inputMode = _InputMode.cantidad;
                            _mainInputController.clear();
                          }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _inputMode == _InputMode.cantidad
                                  ? _color.withOpacity(0.15)
                                  : const Color(0xFF0A0E1A),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _inputMode == _InputMode.cantidad
                                    ? _color : borderColor,
                                width: _inputMode == _InputMode.cantidad
                                    ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.numbers_rounded,
                                    size: 16,
                                    color: _inputMode == _InputMode.cantidad
                                        ? _color
                                        : const Color(0xFF7BA7C2)),
                                const SizedBox(width: 4),
                                Text('En cantidad',
                                    style: TextStyle(
                                      color: _inputMode == _InputMode.cantidad
                                          ? _color
                                          : const Color(0xFF7BA7C2),
                                      fontSize: 13,
                                      fontWeight: _inputMode == _InputMode.cantidad
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

                  // ── CAMPO PRINCIPAL ────────────────────────────────────
                  TextFormField(
                    controller: _mainInputController,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      labelText: _inputMode == _InputMode.dinero
                          ? 'Dinero invertido (${cp.currency})'
                          : 'Cantidad comprada',
                      prefixText: _inputMode == _InputMode.dinero
                          ? '${cp.symbol} ' : '',
                      suffixText: _inputMode == _InputMode.cantidad
                          ? '  ${_asset['symbol']}' : '',
                      prefixStyle: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: _color),
                      suffixStyle: TextStyle(
                          fontSize: 14,
                          color: _color.withOpacity(0.7)),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      contentPadding: EdgeInsets.zero,
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return _inputMode == _InputMode.dinero
                            ? 'Ingresa el dinero invertido'
                            : 'Ingresa la cantidad comprada';
                      }
                      final n = double.tryParse(v.replaceAll(',', '.'));
                      if (n == null) return 'Número no válido';
                      if (n <= 0) return 'Debe ser mayor que 0';
                      return null;
                    },
                  ),

                  // ── RESUMEN CALCULADO ──────────────────────────────────
                  if (hasValid) ...[
                    const SizedBox(height: 16),
                    Divider(color: borderColor, height: 1),
                    const SizedBox(height: 16),

                    if (_inputMode == _InputMode.dinero) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Unidades que compraste',
                              style: tt.bodyMedium?.copyWith(fontSize: 13)),
                          RichText(
                            text: TextSpan(children: [
                              TextSpan(
                                text: qty < 0.001
                                    ? qty.toStringAsFixed(8)
                                    : qty < 1
                                        ? qty.toStringAsFixed(6)
                                        : qty.toStringAsFixed(4),
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
                    ] else ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Total invertido',
                              style: tt.bodyMedium?.copyWith(fontSize: 13)),
                          Text(
                            cp.format(totalUsd),
                            style: TextStyle(
                                color: _color,
                                fontSize: 16,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 8),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Precio de compra usado',
                            style: tt.bodyMedium?.copyWith(fontSize: 13)),
                        Text(
                          cp.format(buyUsd),
                          style: tt.bodyLarge?.copyWith(
                              fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: _color.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _color.withOpacity(0.25)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Cantidad',
                                  style: tt.bodyMedium
                                      ?.copyWith(fontSize: 11)),
                              Text(
                                qty < 0.001
                                    ? qty.toStringAsFixed(8)
                                    : qty < 1
                                        ? qty.toStringAsFixed(6)
                                        : qty.toStringAsFixed(4),
                                style: TextStyle(
                                    color: _color,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          Icon(Icons.swap_horiz_rounded,
                              color: _color.withOpacity(0.5), size: 20),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('Invertido',
                                  style: tt.bodyMedium
                                      ?.copyWith(fontSize: 11)),
                              Text(
                                cp.format(totalUsd),
                                style: TextStyle(
                                    color: _color,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ],
                      ),
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
                onPressed:
                    (_isSaving || _currentPrice == 0) ? null : () => _save(cp),
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
                        hasValid
                            ? 'Guardar inversión de ${cp.format(totalUsd)}'
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

  String _fmt(dynamic v, {String suffix = '', String prefix = ''}) {
    if (v == null) return '—';
    return '$prefix$v$suffix';
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
            value: expense != null
                ? '${expense.toStringAsFixed(2)}%' : '—',
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