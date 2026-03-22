import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:invertrack/providers/currency_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SalesHistoryScreen extends StatefulWidget {
  final VoidCallback? onSaleUndone;
  const SalesHistoryScreen({super.key, this.onSaleUndone});

  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _sales = [];
  bool _isLoading = true;

  static const Map<String, Color> _typeColors = {
    'crypto': Color(0xFFF7931A),
    'stock':  Color(0xFF4FC3F7),
    'etf':    Color(0xFF69F0AE),
  };

  // Total siempre en USD (lo que está en BD)
  double get _totalGainUsd => _sales.fold(
      0, (s, a) => s + ((a['gain_loss'] as num?)?.toDouble() ?? 0));

  @override
  void initState() {
    super.initState();
    _loadSales();
  }

  Future<void> _loadSales() async {
    setState(() => _isLoading = true);
    try {
      final uid  = supabase.auth.currentUser!.id;
      final data = await supabase
          .from('sales')
          .select()
          .eq('user_id', uid)
          .order('sold_at', ascending: false);
      if (mounted) {
        setState(() => _sales = List<Map<String, dynamic>>.from(data));
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

  Future<void> _undoSale(Map<String, dynamic> sale) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Text('Deshacer venta',
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(fontWeight: FontWeight.bold)),
        content: Text(
          'Se eliminará esta venta del historial y se restaurará '
          '${sale['name']} con la cantidad y precio de compra originales en tu portfolio.\n\n'
          '¿Confirmas?',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Deshacer venta',
                style: TextStyle(
                    color: Color(0xFF4FC3F7),
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final saleId = sale['id'] as String;

    try {
      final uid           = supabase.auth.currentUser!.id;
      final assetId       = sale['asset_id'] as String?;
      final qtySold       = (sale['quantity_sold']  as num).toDouble();
      final totalInvested = (sale['total_invested'] as num).toDouble();
      final buyPrice      = (sale['buy_price']      as num).toDouble();

      if (assetId != null) {
        final existing = await supabase
            .from('assets')
            .select()
            .eq('id', assetId)
            .maybeSingle();

        if (existing != null) {
          final currentQty      = (existing['quantity'] as num).toDouble();
          final currentInvested = (existing['value']    as num).toDouble();
          await supabase.from('assets').update({
            'quantity': currentQty + qtySold,
            'value':    currentInvested + totalInvested,
          }).eq('id', assetId);
        } else {
          await supabase.from('assets').insert({
            'id':         assetId,
            'user_id':    uid,
            'name':       sale['name'],
            'symbol':     sale['symbol'],
            'type':       sale['type'],
            'icon':       sale['icon'],
            'quantity':   qtySold,
            'buy_price':  buyPrice,
            'value':      totalInvested,
            'price':      buyPrice,
            'change':     0.0,
            'created_at': DateTime.now().toIso8601String(),
          });
        }
      } else {
        await supabase.from('assets').insert({
          'user_id':    uid,
          'name':       sale['name'],
          'symbol':     sale['symbol'],
          'type':       sale['type'],
          'icon':       sale['icon'],
          'quantity':   qtySold,
          'buy_price':  buyPrice,
          'value':      totalInvested,
          'price':      buyPrice,
          'change':     0.0,
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      final deleteResult = await supabase
          .from('sales')
          .delete()
          .eq('id', saleId)
          .select();
      print('Venta eliminada de BD: $deleteResult');

      if (mounted) {
        setState(() => _sales.removeWhere((s) => s['id'] == saleId));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Venta deshecha correctamente')),
        );
        widget.onSaleUndone?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error al deshacer: $e'),
          backgroundColor: const Color(0xFFFF6B6B),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt     = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final cp     = context.watch<CurrencyProvider>();

    const cardColor   = Color(0xFF1E2D3D);
    const borderColor = Color(0xFF1E3A5F);

    final totalGain  = cp.convert(_totalGainUsd);
    final totalIsPos = totalGain >= 0;
    final totalColor = totalIsPos
        ? const Color(0xFF69F0AE)
        : const Color(0xFFFF6B6B);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Historial de ventas',
            style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              color: scheme.primary,
              onRefresh: _loadSales,
              child: _sales.isEmpty
                  ? ListView(
                      children: [
                        SizedBox(
                            height:
                                MediaQuery.of(context).size.height * 0.35),
                        Center(
                          child: Column(
                            children: [
                              Icon(Icons.receipt_long_rounded,
                                  size: 52,
                                  color: const Color(0xFF7BA7C2)),
                              const SizedBox(height: 12),
                              Text('Aún no tienes ventas registradas',
                                  style: tt.bodyLarge?.copyWith(
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 6),
                              Text('Las ventas aparecerán aquí',
                                  style: tt.bodyMedium),
                            ],
                          ),
                        ),
                      ],
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                      children: [

                        // ── RESUMEN TOTAL ──────────────────────────────
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                totalColor.withOpacity(0.2),
                                totalColor.withOpacity(0.05),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: totalColor.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                totalIsPos
                                    ? Icons.trending_up_rounded
                                    : Icons.trending_down_rounded,
                                color: totalColor,
                                size: 36,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      totalIsPos
                                          ? 'Ganancia total realizada'
                                          : 'Pérdida total realizada',
                                      style: tt.bodyMedium
                                          ?.copyWith(fontSize: 12),
                                    ),
                                    Text(
                                      '${totalIsPos ? '+' : ''}${cp.format(_totalGainUsd)}',
                                      style: TextStyle(
                                        color: totalColor,
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                    Text(
                                      '${_sales.length} venta${_sales.length != 1 ? 's' : ''} registrada${_sales.length != 1 ? 's' : ''}',
                                      style: tt.bodyMedium
                                          ?.copyWith(fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        Text('VENTAS',
                            style: tt.bodyMedium?.copyWith(
                                fontSize: 11,
                                letterSpacing: 1.2,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 10),

                        // ── LISTA DE VENTAS ────────────────────────────
                        ..._sales.map((sale) {
                          final gainUsd = (sale['gain_loss'] as num?)
                                  ?.toDouble() ??
                              0;
                          final gainPct =
                              (sale['gain_loss_pct'] as num?)?.toDouble() ??
                                  0;
                          final gainPos = gainUsd >= 0;
                          final gainCol = gainPos
                              ? const Color(0xFF69F0AE)
                              : const Color(0xFFFF6B6B);
                          final typeCol = _typeColors[sale['type']] ??
                              const Color(0xFF4FC3F7);
                          final soldAt = DateTime.tryParse(
                              sale['sold_at'] as String? ?? '');
                          final dateStr = soldAt != null
                              ? '${soldAt.day.toString().padLeft(2, '0')}/${soldAt.month.toString().padLeft(2, '0')}/${soldAt.year}  ${soldAt.hour.toString().padLeft(2, '0')}:${soldAt.minute.toString().padLeft(2, '0')}'
                              : '—';

                          final totalSoldUsd =
                              (sale['total_sold'] as num?)?.toDouble() ?? 0;
                          final totalInvestedUsd =
                              (sale['total_invested'] as num?)?.toDouble() ??
                                  0;
                          final qtySold =
                              (sale['quantity_sold'] as num?)?.toDouble() ??
                                  0;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: gainCol.withOpacity(0.2)),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 42, height: 42,
                                      decoration: BoxDecoration(
                                        color: typeCol.withOpacity(0.1),
                                        borderRadius:
                                            BorderRadius.circular(11),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        sale['icon'] as String? ?? '?',
                                        style: TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.bold,
                                            color: typeCol),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            sale['name'] as String? ?? '',
                                            style: tt.bodyLarge?.copyWith(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14),
                                          ),
                                          Text(
                                            '${sale['symbol']}  ·  $dateStr',
                                            style: tt.bodyMedium
                                                ?.copyWith(fontSize: 11),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '${gainPos ? '+' : ''}${cp.format(gainUsd)}',
                                          style: TextStyle(
                                              color: gainCol,
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 7, vertical: 2),
                                          decoration: BoxDecoration(
                                            color:
                                                gainCol.withOpacity(0.12),
                                            borderRadius:
                                                BorderRadius.circular(5),
                                          ),
                                          child: Text(
                                            '${gainPos ? '+' : ''}${gainPct.toStringAsFixed(2)}%',
                                            style: TextStyle(
                                                color: gainCol,
                                                fontSize: 11,
                                                fontWeight:
                                                    FontWeight.w600),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 12),
                                Divider(height: 1, color: borderColor),
                                const SizedBox(height: 12),

                                Row(
                                  children: [
                                    _DetailChip(
                                      label: 'Vendido',
                                      value: cp.format(totalSoldUsd),
                                      color: typeCol,
                                    ),
                                    const SizedBox(width: 12),
                                    _DetailChip(
                                      label: 'Comprado',
                                      value: cp.format(totalInvestedUsd),
                                      color: const Color(0xFF7BA7C2),
                                    ),
                                    const SizedBox(width: 12),
                                    _DetailChip(
                                      label: 'Cantidad',
                                      value: qtySold < 0.001
                                          ? qtySold.toStringAsFixed(6)
                                          : qtySold.toStringAsFixed(4),
                                      color: const Color(0xFF7BA7C2),
                                    ),
                                    const Spacer(),
                                    GestureDetector(
                                      onTap: () => _undoSale(sale),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF0A0E1A),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                              color: borderColor),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(Icons.undo_rounded,
                                                size: 14,
                                                color: scheme.primary),
                                            const SizedBox(width: 4),
                                            Text('Deshacer',
                                                style: TextStyle(
                                                  color: scheme.primary,
                                                  fontSize: 11,
                                                  fontWeight:
                                                      FontWeight.w600,
                                                )),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
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

class _DetailChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _DetailChip(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: tt.bodyMedium?.copyWith(fontSize: 10)),
        Text(value,
            style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
      ],
    );
  }
}