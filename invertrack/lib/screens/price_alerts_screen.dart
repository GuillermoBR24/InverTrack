import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/currency_provider.dart';
import '../services/market_service.dart';

class PriceAlertsScreen extends StatefulWidget {
  const PriceAlertsScreen({super.key});

  @override
  State<PriceAlertsScreen> createState() => _PriceAlertsScreenState();
}

class _PriceAlertsScreenState extends State<PriceAlertsScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _alerts  = [];
  List<Map<String, dynamic>> _assets  = [];
  bool _isLoading = true;

  static const Map<String, Color> _typeColors = {
    'crypto': Color(0xFFF7931A),
    'stock':  Color(0xFF4FC3F7),
    'etf':    Color(0xFF69F0AE),
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final uid = supabase.auth.currentUser!.id;
      final results = await Future.wait([
        supabase.from('price_alerts').select()
            .eq('user_id', uid)
            .order('created_at', ascending: false),
        supabase.from('assets').select()
            .eq('user_id', uid)
            .order('name'),
      ]);
      if (mounted) {
        setState(() {
          _alerts = List<Map<String, dynamic>>.from(results[0]);
          _assets = List<Map<String, dynamic>>.from(results[1]);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: const Color(0xFFFF6B6B),
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteAlert(String alertId) async {
    try {
      await supabase.from('price_alerts').delete().eq('id', alertId);
      setState(() => _alerts.removeWhere((a) => a['id'] == alertId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Alerta eliminada')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: const Color(0xFFFF6B6B),
        ));
      }
    }
  }

  void _showCreateAlertDialog({Map<String, dynamic>? preselectedAsset}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateAlertSheet(
        assets: _assets,
        preselectedAsset: preselectedAsset,
        onCreated: (alert) {
          setState(() => _alerts.insert(0, alert));
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tt     = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final cp     = context.watch<CurrencyProvider>();

    const cardColor   = Color(0xFF1E2D3D);
    const borderColor = Color(0xFF1E3A5F);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Alertas de precio',
            style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Nueva alerta',
            onPressed: _showCreateAlertDialog,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              color: scheme.primary,
              onRefresh: _loadData,
              child: _alerts.isEmpty
                  ? ListView(
                      children: [
                        SizedBox(
                            height:
                                MediaQuery.of(context).size.height * 0.3),
                        Center(
                          child: Column(
                            children: [
                              Icon(Icons.notifications_none_rounded,
                                  size: 56,
                                  color: const Color(0xFF7BA7C2)),
                              const SizedBox(height: 12),
                              Text('Sin alertas activas',
                                  style: tt.bodyLarge?.copyWith(
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 6),
                              Text(
                                  'Pulsa + para crear una alerta de precio',
                                  style: tt.bodyMedium),
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                onPressed: _showCreateAlertDialog,
                                icon: const Icon(Icons.add_rounded, size: 18),
                                label: const Text('Crear alerta'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                      children: [
                        // Resumen
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: borderColor),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.notifications_active_rounded,
                                  color: scheme.primary, size: 28),
                              const SizedBox(width: 12),
                              Text(
                                '${_alerts.length} alerta${_alerts.length != 1 ? 's' : ''} activa${_alerts.length != 1 ? 's' : ''}',
                                style: tt.bodyLarge
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        Text('ALERTAS ACTIVAS',
                            style: tt.bodyMedium?.copyWith(
                                fontSize: 11,
                                letterSpacing: 1.2,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 10),

                        ..._alerts.map((alert) {
                          final typeColor =
                              _typeColors[alert['type']] ??
                                  const Color(0xFF4FC3F7);
                          final isAbove = alert['condition'] == 'above';
                          final condColor = isAbove
                              ? const Color(0xFF69F0AE)
                              : const Color(0xFFFF6B6B);
                          final targetPrice =
                              (alert['target_price'] as num).toDouble();

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: condColor.withOpacity(0.25)),
                            ),
                            child: Row(
                              children: [
                                // Icono
                                Container(
                                  width: 42, height: 42,
                                  decoration: BoxDecoration(
                                    color: typeColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(11),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    alert['icon'] as String? ?? '?',
                                    style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                        color: typeColor),
                                  ),
                                ),
                                const SizedBox(width: 12),

                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        alert['name'] as String? ?? '',
                                        style: tt.bodyLarge?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets
                                                .symmetric(
                                                horizontal: 7,
                                                vertical: 2),
                                            decoration: BoxDecoration(
                                              color: condColor
                                                  .withOpacity(0.12),
                                              borderRadius:
                                                  BorderRadius.circular(5),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  isAbove
                                                      ? Icons
                                                          .arrow_upward_rounded
                                                      : Icons
                                                          .arrow_downward_rounded,
                                                  size: 11,
                                                  color: condColor,
                                                ),
                                                const SizedBox(width: 3),
                                                Text(
                                                  isAbove
                                                      ? 'Por encima de'
                                                      : 'Por debajo de',
                                                  style: TextStyle(
                                                      color: condColor,
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w600),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            cp.format(targetPrice),
                                            style: tt.bodyLarge?.copyWith(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                // Botón eliminar
                                IconButton(
                                  onPressed: () =>
                                      _deleteAlert(alert['id'] as String),
                                  icon: const Icon(
                                      Icons.delete_outline_rounded,
                                      size: 20),
                                  color: const Color(0xFFFF6B6B),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
            ),
    );
  }
}

// ── BOTTOM SHEET CREAR ALERTA ─────────────────────────────────────────────────

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