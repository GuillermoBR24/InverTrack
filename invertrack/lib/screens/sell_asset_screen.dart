import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:invertrack/providers/currency_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/market_service.dart';

class SellAssetScreen extends StatefulWidget {
  final Map<String, dynamic> asset;
  const SellAssetScreen({super.key, required this.asset});

  @override
  State<SellAssetScreen> createState() => _SellAssetScreenState();
}

enum _SellMode  { parcial, total }
enum _InputMode { dinero, cantidad }
enum _PriceMode { actual, manual }

class _SellAssetScreenState extends State<SellAssetScreen> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  final _sellPriceController = TextEditingController();
  final _inputController     = TextEditingController();

  bool _isSaving     = false;
  bool _loadingPrice = false;

  _SellMode  _sellMode  = _SellMode.parcial;
  _InputMode _inputMode = _InputMode.dinero;
  _PriceMode _priceMode = _PriceMode.actual;

  double _livePrice = 0.0;

  static const Map<String, Color> _typeColors = {
    'crypto': Color(0xFFF7931A),
    'stock':  Color(0xFF4FC3F7),
    'etf':    Color(0xFF69F0AE),
  };

  Color  get _color    => _typeColors[widget.asset['type']] ?? const Color(0xFF4FC3F7);
  double get _buyPrice => (widget.asset['buy_price'] as num?)?.toDouble() ?? 0;
  double get _quantity => (widget.asset['quantity']  as num?)?.toDouble() ?? 0;
  double get _invested => (widget.asset['value']     as num?)?.toDouble() ?? 0;

  // Precio de venta siempre en USD internamente
  double get _sellPriceUsd {
    if (_priceMode == _PriceMode.actual) return _livePrice;
    final cp = _cpOrNull;
    final raw = double.tryParse(
            _sellPriceController.text.replaceAll(',', '.')) ?? 0;
    // Si el usuario escribió en la moneda local, convertir a USD
    if (cp != null && cp.rate != 1.0 && raw > 0) return raw / cp.rate;
    return raw > 0 ? raw : _livePrice;
  }

  double get _inputValue =>
      double.tryParse(_inputController.text.replaceAll(',', '.')) ?? 0;

  // Cantidad a vender (siempre en unidades del activo)
  double get _quantityToSell {
    if (_sellMode == _SellMode.total) return _quantity;
    if (_inputMode == _InputMode.cantidad) return _inputValue;
    // inputValue está en moneda local → convertir a USD para calcular unidades
    final cp = _cpOrNull;
    final inputUsd = (cp != null && cp.rate != 1.0)
        ? _inputValue / cp.rate
        : _inputValue;
    return _sellPriceUsd > 0 ? inputUsd / _sellPriceUsd : 0;
  }

  double get _totalReceivedUsd => _quantityToSell * _sellPriceUsd;
  double get _costBasisUsd {
    if (_quantity <= 0) return 0;
    return (_quantityToSell / _quantity) * _invested;
  }
  double get _gainLossUsd     => _totalReceivedUsd - _costBasisUsd;
  double get _gainLossPct =>
      _costBasisUsd > 0 ? (_gainLossUsd / _costBasisUsd) * 100 : 0;

  bool get _hasValidInput =>
      _sellMode == _SellMode.total
          ? _sellPriceUsd > 0
          : _inputValue > 0 && _sellPriceUsd > 0;

  CurrencyProvider? get _cpOrNull {
    try {
      return Provider.of<CurrencyProvider>(context, listen: false);
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _livePrice = (widget.asset['price'] as num?)?.toDouble() ?? 0;
    _refreshPrice();
  }

  @override
  void dispose() {
    _sellPriceController.dispose();
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _refreshPrice() async {
    setState(() => _loadingPrice = true);
    try {
      final live = await MarketService.fetchAsset(
        widget.asset['symbol'] as String,
        widget.asset['type']   as String,
      );
      if (live != null && mounted) {
        setState(() =>
            _livePrice = (live['price'] as num?)?.toDouble() ?? _livePrice);
      }
    } finally {
      if (mounted) setState(() => _loadingPrice = false);
    }
  }

  Future<void> _confirmSell() async {
    if (!_formKey.currentState!.validate()) return;

    if (_quantityToSell > _quantity + 0.000001) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No puedes vender más de lo que tienes'),
        backgroundColor: Color(0xFFFF6B6B),
      ));
      return;
    }

    final cp = context.read<CurrencyProvider>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Confirmar venta',
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ConfirmRow(
                label: 'Activo',
                value:
                    '${widget.asset['name']} (${widget.asset['symbol']})'),
            _ConfirmRow(
                label: 'Cantidad a vender',
                value: _quantityToSell < 0.001
                    ? _quantityToSell.toStringAsFixed(8)
                    : _quantityToSell.toStringAsFixed(6)),
            _ConfirmRow(
                label: 'Precio de venta',
                value: cp.format(_sellPriceUsd)),
            _ConfirmRow(
                label: 'Recibirás',
                value: cp.format(_totalReceivedUsd)),
            const SizedBox(height: 8),
            _ConfirmRow(
              label: 'Ganancia / Pérdida',
              value:
                  '${_gainLossUsd >= 0 ? '+' : ''}${cp.format(_gainLossUsd)} (${_gainLossPct.toStringAsFixed(2)}%)',
              valueColor: _gainLossUsd >= 0
                  ? const Color(0xFF69F0AE)
                  : const Color(0xFFFF6B6B),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Confirmar venta',
                style: TextStyle(
                    color: _color, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isSaving = true);
    try {
      final uid         = supabase.auth.currentUser!.id;
      final assetId     = widget.asset['id'] as String?;
      final newQuantity = _quantity - _quantityToSell;
      final newInvested = _invested - _costBasisUsd;

      // Guardamos siempre en USD en la BD
      await supabase.from('sales').insert({
        'user_id':        uid,
        'asset_id':       assetId,
        'name':           widget.asset['name'],
        'symbol':         widget.asset['symbol'],
        'type':           widget.asset['type'],
        'icon':           widget.asset['icon'],
        'quantity_sold':  _quantityToSell,
        'sell_price':     _sellPriceUsd,
        'buy_price':      _buyPrice,
        'total_sold':     _totalReceivedUsd,
        'total_invested': _costBasisUsd,
        'gain_loss':      _gainLossUsd,
        'gain_loss_pct':  _gainLossPct,
        'sold_at':        DateTime.now().toIso8601String(),
      });

      if (newQuantity <= 0.000001 || _sellMode == _SellMode.total) {
        if (assetId != null) {
          await supabase.from('assets').delete().eq('id', assetId);
        }
      } else {
        if (assetId != null) {
          await supabase.from('assets').update({
            'quantity': newQuantity,
            'value':    newInvested > 0 ? newInvested : 0,
          }).eq('id', assetId);
        }
      }

      if (mounted) Navigator.pop(context, 'sold');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error al registrar la venta: $e'),
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

    const cardColor   = Color(0xFF1E2D3D);
    const borderColor = Color(0xFF1E3A5F);

    final gainIsPos = _gainLossUsd >= 0;
    final gainColor = gainIsPos
        ? const Color(0xFF69F0AE)
        : const Color(0xFFFF6B6B);

    // Precio actual mostrado en moneda seleccionada
    final livePriceFmt = _livePrice > 0
        ? cp.format(_livePrice)
        : '—';

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Text('Vender ',
                style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
            Text(widget.asset['symbol'] as String? ?? '',
                style: tt.bodyLarge
                    ?.copyWith(fontWeight: FontWeight.w600, color: _color)),
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

            // ── RESUMEN DEL ACTIVO ─────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _color.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      color: _color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    alignment: Alignment.center,
                    child: () {
                      final thumb = widget.asset['thumb'] as String?;
                      if (thumb != null && thumb.isNotEmpty) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(thumb,
                              width: 30, height: 30,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => Text(
                                widget.asset['icon'] as String? ?? '?',
                                style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: _color),
                              )),
                        );
                      }
                      return Text(widget.asset['icon'] as String? ?? '?',
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: _color));
                    }(),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.asset['name'] as String? ?? '',
                            style: tt.bodyLarge
                                ?.copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(
                          'Tienes: ${_quantity < 0.001 ? _quantity.toStringAsFixed(8) : _quantity.toStringAsFixed(6)} ${widget.asset['symbol']}',
                          style: tt.bodyMedium?.copyWith(fontSize: 12),
                        ),
                        Text(
                          'Precio de compra: ${cp.format(_buyPrice)}',
                          style: tt.bodyMedium?.copyWith(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(livePriceFmt,
                          style: TextStyle(
                              color: _color,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                      Text('precio actual',
                          style: tt.bodyMedium?.copyWith(fontSize: 10)),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── PRECIO DE VENTA ────────────────────────────────────────
            _SectionLabel(label: 'Precio de venta'),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() {
                            _priceMode = _PriceMode.actual;
                            _sellPriceController.clear();
                          }),
                          child: _ModeButton(
                            label: 'Precio actual',
                            sublabel: livePriceFmt,
                            icon: Icons.bolt_rounded,
                            isSelected: _priceMode == _PriceMode.actual,
                            color: _color,
                            borderColor: borderColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(
                              () => _priceMode = _PriceMode.manual),
                          child: _ModeButton(
                            label: 'Precio manual',
                            sublabel:
                                'En ${cp.currency}',
                            icon: Icons.edit_rounded,
                            isSelected: _priceMode == _PriceMode.manual,
                            color: _color,
                            borderColor: borderColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_priceMode == _PriceMode.manual) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _sellPriceController,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        labelText:
                            'Precio al que vendiste (${cp.currency})',
                        prefixText: '${cp.symbol} ',
                        prefixStyle: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: _color),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        contentPadding: EdgeInsets.zero,
                      ),
                      validator: (v) {
                        if (_priceMode == _PriceMode.manual) {
                          if (v == null || v.isEmpty) {
                            return 'Ingresa el precio de venta';
                          }
                          final n =
                              double.tryParse(v.replaceAll(',', '.'));
                          if (n == null) return 'Número no válido';
                          if (n <= 0) return 'Debe ser mayor que 0';
                        }
                        return null;
                      },
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── CANTIDAD A VENDER ──────────────────────────────────────
            _SectionLabel(label: '¿Cuánto quieres vender?'),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() {
                            _sellMode = _SellMode.total;
                            _inputController.clear();
                          }),
                          child: _ModeButton(
                            label: 'Vender todo',
                            sublabel:
                                '${_quantity < 0.001 ? _quantity.toStringAsFixed(8) : _quantity.toStringAsFixed(4)} ${widget.asset['symbol']}',
                            icon: Icons.sell_rounded,
                            isSelected: _sellMode == _SellMode.total,
                            color: _color,
                            borderColor: borderColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(
                              () => _sellMode = _SellMode.parcial),
                          child: _ModeButton(
                            label: 'Vender parte',
                            sublabel: 'Indica cuánto',
                            icon: Icons.pie_chart_outline_rounded,
                            isSelected: _sellMode == _SellMode.parcial,
                            color: _color,
                            borderColor: borderColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_sellMode == _SellMode.parcial) ...[
                    const SizedBox(height: 16),
                    Divider(color: borderColor, height: 1),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() {
                              _inputMode = _InputMode.dinero;
                              _inputController.clear();
                            }),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 8),
                              decoration: BoxDecoration(
                                color: _inputMode == _InputMode.dinero
                                    ? _color.withOpacity(0.12)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _inputMode == _InputMode.dinero
                                      ? _color.withOpacity(0.5)
                                      : borderColor,
                                ),
                              ),
                              child: Text(
                                  'Por importe (${cp.symbol})',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: _inputMode == _InputMode.dinero
                                        ? _color
                                        : const Color(0xFF7BA7C2),
                                    fontSize: 12,
                                    fontWeight:
                                        _inputMode == _InputMode.dinero
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                  )),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() {
                              _inputMode = _InputMode.cantidad;
                              _inputController.clear();
                            }),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 8),
                              decoration: BoxDecoration(
                                color: _inputMode == _InputMode.cantidad
                                    ? _color.withOpacity(0.12)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _inputMode == _InputMode.cantidad
                                      ? _color.withOpacity(0.5)
                                      : borderColor,
                                ),
                              ),
                              child: Text('Por cantidad',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: _inputMode == _InputMode.cantidad
                                        ? _color
                                        : const Color(0xFF7BA7C2),
                                    fontSize: 12,
                                    fontWeight:
                                        _inputMode == _InputMode.cantidad
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                  )),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _inputController,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        labelText: _inputMode == _InputMode.dinero
                            ? 'Importe a vender (${cp.currency})'
                            : 'Cantidad a vender',
                        prefixText: _inputMode == _InputMode.dinero
                            ? '${cp.symbol} '
                            : '',
                        suffixText: _inputMode == _InputMode.cantidad
                            ? '  ${widget.asset['symbol']}'
                            : '',
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
                        if (_sellMode == _SellMode.parcial) {
                          if (v == null || v.isEmpty) {
                            return _inputMode == _InputMode.dinero
                                ? 'Ingresa el importe'
                                : 'Ingresa la cantidad';
                          }
                          final n =
                              double.tryParse(v.replaceAll(',', '.'));
                          if (n == null) return 'Número no válido';
                          if (n <= 0) return 'Debe ser mayor que 0';
                        }
                        return null;
                      },
                    ),
                  ],
                ],
              ),
            ),

            // ── RESUMEN DE LA VENTA ────────────────────────────────────
            if (_hasValidInput) ...[
              const SizedBox(height: 24),
              _SectionLabel(label: 'Resumen de la venta'),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border:
                      Border.all(color: gainColor.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    _SummaryRow(
                      label: 'Cantidad vendida',
                      value: _quantityToSell < 0.001
                          ? '${_quantityToSell.toStringAsFixed(8)} ${widget.asset['symbol']}'
                          : '${_quantityToSell.toStringAsFixed(6)} ${widget.asset['symbol']}',
                      tt: tt,
                    ),
                    Divider(height: 20, color: const Color(0xFF1E3A5F)),
                    _SummaryRow(
                      label: 'Precio de venta',
                      value: cp.format(_sellPriceUsd),
                      tt: tt,
                    ),
                    Divider(height: 20, color: const Color(0xFF1E3A5F)),
                    _SummaryRow(
                      label: 'Recibirás',
                      value: cp.format(_totalReceivedUsd),
                      tt: tt,
                      valueStyle: TextStyle(
                          color: _color,
                          fontSize: 16,
                          fontWeight: FontWeight.bold),
                    ),
                    Divider(height: 20, color: const Color(0xFF1E3A5F)),
                    _SummaryRow(
                      label: 'Coste de compra',
                      value: cp.format(_costBasisUsd),
                      tt: tt,
                    ),
                    Divider(height: 20, color: const Color(0xFF1E3A5F)),
                    _SummaryRow(
                      label:
                          gainIsPos ? 'Ganancia neta' : 'Pérdida neta',
                      value:
                          '${gainIsPos ? '+' : ''}${cp.format(_gainLossUsd)} (${gainIsPos ? '+' : ''}${_gainLossPct.toStringAsFixed(2)}%)',
                      tt: tt,
                      valueStyle: TextStyle(
                          color: gainColor,
                          fontSize: 15,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 32),

            // ── BOTÓN VENDER ───────────────────────────────────────────
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: (_isSaving || !_hasValidInput)
                    ? null
                    : _confirmSell,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _color,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5))
                    : Text(
                        _hasValidInput
                            ? 'Vender por ${cp.format(_totalReceivedUsd)}'
                            : 'Confirmar venta',
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

// ── WIDGETS AUXILIARES ────────────────────────────────────────────────────────

class _ModeButton extends StatelessWidget {
  final String label;
  final String sublabel;
  final IconData icon;
  final bool isSelected;
  final Color color;
  final Color borderColor;
  const _ModeButton({
    required this.label, required this.sublabel, required this.icon,
    required this.isSelected, required this.color, required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: isSelected
            ? color.withOpacity(0.12)
            : const Color(0xFF0A0E1A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isSelected ? color.withOpacity(0.6) : borderColor,
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          Icon(icon,
              color: isSelected ? color : const Color(0xFF7BA7C2),
              size: 18),
          const SizedBox(height: 5),
          Text(label,
              style: TextStyle(
                color: isSelected ? color : const Color(0xFF7BA7C2),
                fontSize: 12,
                fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.normal,
              )),
          const SizedBox(height: 2),
          Text(sublabel,
              style: tt.bodyMedium?.copyWith(fontSize: 10),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final TextTheme tt;
  final TextStyle? valueStyle;
  const _SummaryRow({
    required this.label, required this.value,
    required this.tt, this.valueStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: tt.bodyMedium?.copyWith(fontSize: 13)),
        Text(value,
            style: valueStyle ??
                tt.bodyLarge?.copyWith(
                    fontSize: 13, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _ConfirmRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _ConfirmRow(
      {required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: tt.bodyMedium?.copyWith(fontSize: 13)),
          Text(value,
              style: tt.bodyLarge?.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: valueColor)),
        ],
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