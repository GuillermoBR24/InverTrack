import 'package:flutter/material.dart';
import 'package:invertrack/screens/profile_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:invertrack/screens/add_asset_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final supabase = Supabase.instance.client;

  // ── Datos de ejemplo (reemplaza con tus llamadas a Supabase / API de precios) ──
  final List<Map<String, dynamic>> _assets = [
    {
      'name': 'Bitcoin',
      'symbol': 'BTC',
      'type': 'crypto',
      'price': 67432.50,
      'change': 3.24,
      'value': 13486.50,
      'icon': '₿',
    },
    {
      'name': 'Ethereum',
      'symbol': 'ETH',
      'type': 'crypto',
      'price': 3512.80,
      'change': -1.47,
      'value': 7025.60,
      'icon': 'Ξ',
    },
    {
      'name': 'Apple Inc.',
      'symbol': 'AAPL',
      'type': 'stock',
      'price': 189.30,
      'change': 0.85,
      'value': 3786.00,
      'icon': 'A',
    },
    {
      'name': 'Tesla',
      'symbol': 'TSLA',
      'type': 'stock',
      'price': 242.10,
      'change': -2.13,
      'value': 2421.00,
      'icon': 'T',
    },
    {
      'name': 'S&P 500 ETF',
      'symbol': 'SPY',
      'type': 'etf',
      'price': 521.40,
      'change': 0.44,
      'value': 5214.00,
      'icon': 'S',
    },
  ];

  String get _userEmail => 
    supabase.auth.currentUser?.email ?? '';

  String _username = '';
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _loadProfile();
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

  double get _totalValue =>
      _assets.fold(0, (sum, a) => sum + (a['value'] as double));

  double get _totalChangePercent {
    final gains = _assets.where((a) => (a['change'] as double) > 0);
    final avg = gains.fold(0.0, (s, a) => s + (a['change'] as double));
    return avg / _assets.length;
  }


  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    const cardColor   = Color(0xFF1E2D3D);
    const borderColor = Color(0xFF1E3A5F);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            // Avatar
            GestureDetector(
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                );
                _loadProfile(); // refresca al volver del perfil
              },
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0D47A1), Color(0xFF0288D1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: _avatarUrl != null
                      ? Image.network(
                          _avatarUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _AvatarInitial(name: _username),
                        )
                      : _AvatarInitial(name: _username),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Nombre
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
              _loadProfile(); // refresca al volver del perfil
            },
          ),
          const SizedBox(width: 8),
        ],
      ),

      body: RefreshIndicator(
        color: scheme.primary,
        onRefresh: () async {
          // Aquí irá tu llamada para refrescar precios
          await Future.delayed(const Duration(seconds: 1));
          setState(() {});
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [

            // ── TARJETA TOTAL PORTFOLIO ──────────────────────────────────
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
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '\$${_totalValue.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Mini stats row
                  Row(
                    children: [
                      _MiniStat(
                        label: 'Activos',
                        value: '${_assets.length}',
                        icon: Icons.pie_chart_rounded,
                      ),
                      const SizedBox(width: 24),
                      _MiniStat(
                        label: 'Variación media',
                        value:
                            '${_totalChangePercent >= 0 ? '+' : ''}${_totalChangePercent.toStringAsFixed(2)}%',
                        icon: Icons.trending_up_rounded,
                        valueColor: _totalChangePercent >= 0
                            ? const Color(0xFF69F0AE)
                            : const Color(0xFFFF6B6B),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── RESUMEN POR TIPO ─────────────────────────────────────────
            Text(
              'Distribución',
              style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
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

            // ── LISTA DE ACTIVOS ─────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Tus activos',
                  style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                GestureDetector(
                  onTap: () async {
                    final newAsset = await Navigator.push<Map<String, dynamic>>(
                      context,
                      MaterialPageRoute(builder: (_) => const AddAssetScreen()),
                    );
                    if (newAsset != null) {
                      setState(() => _assets.add(newAsset));
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E2D3D),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF1E3A5F)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.add_rounded,
                            color: scheme.primary, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          'Añadir',
                          style: tt.bodyMedium?.copyWith(
                            color: scheme.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            ..._assets.map((asset) => _AssetTile(
                  asset: asset,
                  cardColor: cardColor,
                  borderColor: borderColor,
                )),
          ],
        ),
      ),
    );
  }
}

// ── WIDGETS AUXILIARES ────────────────────────────────────────────────────────

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
            Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
            Text(
              value,
              style: TextStyle(
                color: valueColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
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
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E2D3D),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF1E3A5F)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              '$count',
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontSize: 11),
            ),
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

  @override
  Widget build(BuildContext context) {
    final isPositive = (asset['change'] as double) >= 0;
    final changeColor =
        isPositive ? const Color(0xFF69F0AE) : const Color(0xFFFF6B6B);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          // Icono / símbolo
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF0A0E1A),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              asset['icon'] as String,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF4FC3F7),
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Nombre + símbolo
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  asset['name'] as String,
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  asset['symbol'] as String,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),

          // Precio + variación
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\$${(asset['price'] as double).toStringAsFixed(2)}',
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: changeColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${isPositive ? '+' : ''}${(asset['change'] as double).toStringAsFixed(2)}%',
                  style: TextStyle(
                    color: changeColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    
  }
}
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
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}