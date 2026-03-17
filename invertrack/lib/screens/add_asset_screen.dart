import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddAssetScreen extends StatefulWidget {
  const AddAssetScreen({super.key});

  @override
  State<AddAssetScreen> createState() => _AddAssetScreenState();
}

class _AddAssetScreenState extends State<AddAssetScreen> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  // ── Estado ───────────────────────────────────────────────────────────────────
  String _searchQuery      = '';
  Map<String, dynamic>? _selectedAsset;
  String _selectedType     = 'crypto';
  bool _isSaving           = false;

  final _quantityController = TextEditingController();
  final _buyPriceController = TextEditingController();
  final _searchController   = TextEditingController();

  // ── Lista de ejemplo — reemplazar por llamada a API en tiempo real ───────────
  final List<Map<String, dynamic>> _availableAssets = [
    {'name': 'Bitcoin',       'symbol': 'BTC',  'type': 'crypto', 'icon': '₿',  'price': 67432.50},
    {'name': 'Ethereum',      'symbol': 'ETH',  'type': 'crypto', 'icon': 'Ξ',  'price': 3512.80},
    {'name': 'Solana',        'symbol': 'SOL',  'type': 'crypto', 'icon': 'S',  'price': 178.40},
    {'name': 'BNB',           'symbol': 'BNB',  'type': 'crypto', 'icon': 'B',  'price': 605.30},
    {'name': 'XRP',           'symbol': 'XRP',  'type': 'crypto', 'icon': 'X',  'price': 0.62},
    {'name': 'Apple Inc.',    'symbol': 'AAPL', 'type': 'stock',  'icon': 'A',  'price': 189.30},
    {'name': 'Tesla',         'symbol': 'TSLA', 'type': 'stock',  'icon': 'T',  'price': 242.10},
    {'name': 'Microsoft',     'symbol': 'MSFT', 'type': 'stock',  'icon': 'M',  'price': 415.20},
    {'name': 'Nvidia',        'symbol': 'NVDA', 'type': 'stock',  'icon': 'N',  'price': 878.40},
    {'name': 'Amazon',        'symbol': 'AMZN', 'type': 'stock',  'icon': 'A',  'price': 192.50},
    {'name': 'S&P 500 ETF',   'symbol': 'SPY',  'type': 'etf',    'icon': 'S',  'price': 521.40},
    {'name': 'Nasdaq ETF',    'symbol': 'QQQ',  'type': 'etf',    'icon': 'Q',  'price': 448.70},
    {'name': 'Gold ETF',      'symbol': 'GLD',  'type': 'etf',    'icon': 'G',  'price': 213.80},
    {'name': 'iShares MSCI',  'symbol': 'EEM',  'type': 'etf',    'icon': 'I',  'price': 42.30},
  ];

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

  // ── Filtrado ─────────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> get _filtered {
    return _availableAssets.where((a) {
      final matchType  = a['type'] == _selectedType;
      final matchQuery = _searchQuery.isEmpty ||
          (a['name'] as String).toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (a['symbol'] as String).toLowerCase().contains(_searchQuery.toLowerCase());
      return matchType && matchQuery;
    }).toList();
  }

  double get _totalInvested {
    final qty   = double.tryParse(_quantityController.text) ?? 0;
    final price = double.tryParse(_buyPriceController.text) ?? 0;
    return qty * price;
  }

  // ── Guardar en Supabase ──────────────────────────────────────────────────────
  Future<void> _save() async {
    if (_selectedAsset == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona un activo de la lista'),
          backgroundColor: Color(0xFFFF6B6B),
        ),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final uid      = supabase.auth.currentUser!.id;
      final qty      = double.parse(_quantityController.text.trim());
      final buyPrice = double.parse(_buyPriceController.text.trim());

      await supabase.from('assets').insert({
        'user_id':    uid,
        'name':       _selectedAsset!['name'],
        'symbol':     _selectedAsset!['symbol'],
        'type':       _selectedAsset!['type'],
        'icon':       _selectedAsset!['icon'],
        'quantity':   qty,
        'buy_price':  buyPrice,
        'value':      qty * buyPrice,
        'price':      _selectedAsset!['price'],
        'change':     0.0,
        'created_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        // Devuelve el activo al home para añadirlo localmente también
        Navigator.pop(context, {
          'name':   _selectedAsset!['name'],
          'symbol': _selectedAsset!['symbol'],
          'type':   _selectedAsset!['type'],
          'icon':   _selectedAsset!['icon'],
          'price':  _selectedAsset!['price'],
          'change': 0.0,
          'value':  qty * buyPrice,
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: const Color(0xFFFF6B6B),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _buyPriceController.dispose();
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
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Color(0xFF4FC3F7)),
                  )
                : Text('Guardar',
                    style: TextStyle(
                      color: scheme.primary,
                      fontWeight: FontWeight.w600,
                    )),
          ),
          const SizedBox(width: 8),
        ],
      ),

      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          children: [

            // ── PASO 1: TIPO ─────────────────────────────────────────────
            _SectionLabel(label: '1. Tipo de activo'),
            const SizedBox(height: 10),
            Row(
              children: _typeLabels.entries.map((e) {
                final isSelected = _selectedType == e.key;
                final color      = _typeColors[e.key]!;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _selectedType  = e.key;
                      _selectedAsset = null;
                      _searchController.clear();
                      _searchQuery = '';
                    }),
                    child: Container(
                      margin: EdgeInsets.only(
                          right: e.key != 'etf' ? 10 : 0),
                      padding: const EdgeInsets.symmetric(vertical: 12),
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
                      child: Column(
                        children: [
                          Text(e.value,
                              style: TextStyle(
                                color: isSelected ? color : const Color(0xFF7BA7C2),
                                fontSize: 13,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              )),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 24),

            // ── PASO 2: BUSCAR Y SELECCIONAR ─────────────────────────────
            _SectionLabel(label: '2. Selecciona el activo'),
            const SizedBox(height: 10),

            // Buscador
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
            const SizedBox(height: 10),

            // Lista de activos filtrada
            Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor),
              ),
              child: _filtered.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Text('No se encontraron activos',
                            style: tt.bodyMedium),
                      ),
                    )
                  : Column(
                      children: _filtered.asMap().entries.map((entry) {
                        final i     = entry.key;
                        final asset = entry.value;
                        final isSelected = _selectedAsset?['symbol'] ==
                            asset['symbol'];
                        final color = _typeColors[asset['type']]!;
                        final isLast = i == _filtered.length - 1;

                        return Column(
                          children: [
                            InkWell(
                              onTap: () {
                                setState(() {
                                  _selectedAsset = asset;
                                  // Pre-rellena precio de compra con precio actual
                                  _buyPriceController.text =
                                      (asset['price'] as double)
                                          .toStringAsFixed(2);
                                });
                              },
                              borderRadius: BorderRadius.circular(14),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                child: Row(
                                  children: [
                                    // Icono
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0A0E1A),
                                        borderRadius:
                                            BorderRadius.circular(10),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        asset['icon'] as String,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: color,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),

                                    // Nombre + símbolo
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(asset['name'] as String,
                                              style: tt.bodyLarge?.copyWith(
                                                  fontSize: 14,
                                                  fontWeight:
                                                      FontWeight.w500)),
                                          Text(asset['symbol'] as String,
                                              style: tt.bodyMedium
                                                  ?.copyWith(fontSize: 12)),
                                        ],
                                      ),
                                    ),

                                    // Precio actual
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '\$${(asset['price'] as double).toStringAsFixed(2)}',
                                          style: tt.bodyLarge?.copyWith(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500),
                                        ),
                                        if (isSelected)
                                          Icon(Icons.check_circle_rounded,
                                              color: color, size: 16),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (!isLast)
                              Divider(
                                  height: 1,
                                  color: borderColor,
                                  indent: 68,
                                  endIndent: 16),
                          ],
                        );
                      }).toList(),
                    ),
            ),

            const SizedBox(height: 24),

            // ── PASO 3: DETALLES — solo si hay activo seleccionado ────────
            if (_selectedAsset != null) ...[
              _SectionLabel(label: '3. Detalles de la inversión'),
              const SizedBox(height: 10),

              // Resumen activo seleccionado
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _typeColors[_selectedAsset!['type']]!
                      .withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _typeColors[_selectedAsset!['type']]!
                        .withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0A0E1A),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _selectedAsset!['icon'] as String,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _typeColors[_selectedAsset!['type']],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_selectedAsset!['name'] as String,
                              style: tt.bodyLarge
                                  ?.copyWith(fontWeight: FontWeight.w600)),
                          Text(_selectedAsset!['symbol'] as String,
                              style: tt.bodyMedium?.copyWith(fontSize: 12)),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () =>
                          setState(() => _selectedAsset = null),
                      child: const Text('Cambiar',
                          style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Cantidad
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _quantityController,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Cantidad / unidades',
                        prefixIcon: Icon(Icons.numbers_rounded),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        contentPadding: EdgeInsets.zero,
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Ingresa la cantidad';
                        if (double.tryParse(v) == null) return 'Número no válido';
                        if (double.parse(v) <= 0) return 'Debe ser mayor que 0';
                        return null;
                      },
                    ),
                    Divider(height: 24, color: borderColor),
                    TextFormField(
                      controller: _buyPriceController,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Precio de compra (\$)',
                        prefixIcon: Icon(Icons.attach_money_rounded),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        contentPadding: EdgeInsets.zero,
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Ingresa el precio';
                        if (double.tryParse(v) == null) return 'Número no válido';
                        if (double.parse(v) <= 0) return 'Debe ser mayor que 0';
                        return null;
                      },
                    ),
                  ],
                ),
              ),

              // Total invertido
              if (_totalInvested > 0) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D47A1).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: const Color(0xFF0288D1).withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total invertido',
                          style: tt.bodyMedium?.copyWith(fontSize: 13)),
                      Text(
                        '\$${_totalInvested.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Color(0xFF4FC3F7),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 32),

              // Botón guardar
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5))
                      : const Text('Guardar inversión'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── WIDGETS AUXILIARES ────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w600),
    );
  }
}