import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/app_shell.dart';
import '../providers/auth_provider.dart';

class ReportDashboardScreen extends StatelessWidget {
  const ReportDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final franchiseId = auth.currentUser?.franchiseId;

    Query<Map<String, dynamic>> ordersQuery = FirebaseFirestore.instance.collection('orders');
    if (franchiseId != null && franchiseId.isNotEmpty) {
      ordersQuery = ordersQuery.where('franchiseId', isEqualTo: franchiseId);
    }

    return AppShell(
      activeItem: 'Report',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Report', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: ordersQuery.snapshots(),
              builder: (context, snap) {
                final docs = snap.data?.docs ?? const [];
                int totalOrder = docs.length;
                int totalProductSold = 0;
                double totalSales = 0;

                // Build ingredient price lookup (by name)
                // Fields supported: pricePerUnit, unitPrice, costPerUnit, price
                final Future<Map<String, double>> priceLookupFuture = FirebaseFirestore.instance
                    .collection('ingredients')
                    .get()
                    .then((r) {
                  final map = <String, double>{};
                  for (final d in r.docs) {
                    final m = d.data();
                    final name = (m['name'] ?? m['ingredientName'] ?? '').toString().trim();
                    final price = (m['pricePerUnit'] ?? m['unitPrice'] ?? m['costPerUnit'] ?? m['price']);
                    final v = (price is num) ? price.toDouble() : double.tryParse('$price') ?? 0.0;
                    if (name.isNotEmpty) map[name] = v;
                  }
                  return map;
                });

                return FutureBuilder<Map<String, double>>(
                  future: priceLookupFuture,
                  builder: (context, priceSnap) {
                    final priceMap = priceSnap.data ?? const {};

                    double totalIngredientCost = 0.0;

                    for (final d in docs) {
                      final m = d.data();
                      final items = m['items'] is List ? (m['items'] as List) : const [];
                      final total = (m['total'] is num) ? (m['total'] as num).toDouble() : double.tryParse((m['total'] ?? '0').toString()) ?? 0;
                      totalSales += total;

                      for (final it in items) {
                        final item = it as Map<String, dynamic>;
                        final qty = (item['qty'] is num) ? (item['qty'] as num).toDouble() : double.tryParse('${item['qty']}') ?? 1.0;
                        final ingredients = (item['ingredients'] is List) ? (item['ingredients'] as List).map((e) => '$e').toList() : const <String>[];

                        // Optional recipe map: {'ingredientName': usageUnits}
                        final recipe = (item['recipe'] is Map) ? (item['recipe'] as Map<String, dynamic>) : const <String, dynamic>{};

                        double itemCost = 0.0;
                        for (final ingName in ingredients) {
                          final unitCost = priceMap[ingName] ?? 0.0;
                          final usageUnits = (recipe[ingName] is num)
                              ? (recipe[ingName] as num).toDouble()
                              : 1.0; // assume 1 unit if not provided
                          itemCost += unitCost * usageUnits;
                        }
                        totalIngredientCost += itemCost * qty;
                        totalProductSold += qty.toInt();
                      }
                    }

                    final totalProfit = (totalSales - totalIngredientCost).clamp(-9999999.0, 9999999.0);
                    String rm(double v) => 'RM ${v.toStringAsFixed(2)}';

                    return Column(
                      children: [
                        Row(
                          children: [
                            _metricCard('Total Product Sold', '$totalProductSold', Colors.yellow[400]!),
                            const SizedBox(width: 12),
                            _metricCard('Total Order', '$totalOrder', Colors.pink[300]!),
                            const SizedBox(width: 12),
                            _metricCard('Total Profit', rm(totalProfit), Colors.lightBlue[300]!),
                            const SizedBox(width: 12),
                            _metricCard('Total Sales', rm(totalSales), Colors.orange[300]!),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _chartCard(title: 'Sales Trend 2025')),
                            const SizedBox(width: 12),
                            Expanded(child: _chartCard(title: 'Staff Activity for September 2025')),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _chartCard(title: 'Top 3 Ingredient Usage (2025)')),
                            const SizedBox(width: 12),
                            Expanded(child: _chartCard(title: 'Number of Violated of Hygiene Compliance (2025)')),
                          ],
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricCard(String title, String value, Color bg) {
    return Expanded(
      child: Container(
        height: 90,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black)),
            const Spacer(),
            Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.black)),
          ],
        ),
      ),
    );
  }

  Widget _chartCard({required String title}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 8, spreadRadius: 1, offset: const Offset(0, 2))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
            const Text('Tap to view details', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ]),
          const SizedBox(height: 8),
          Container(
            height: 220,
            decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[300]!)),
            child: const Center(child: Text('Chart Placeholder')),
          ),
        ],
      ),
    );
  }
}