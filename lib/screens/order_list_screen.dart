import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/app_shell.dart';
import '../routes/app_routes.dart';

class OrderProduct {
  final String id;
  final String name;
  final String category;
  final double hotPrice;
  final double coldPrice;
  final String? imageUrl;
  final Map<String, bool> optionsIce;
  final Map<String, bool> optionsSugar;
  final Map<String, bool> optionsTexture;
  final Map<String, double> extras;
  final List<String> ingredientNames;
  final bool hasHot;
  OrderProduct({
    required this.id,
    required this.name,
    required this.category,
    required this.hotPrice,
    required this.coldPrice,
    this.imageUrl,
    required this.optionsIce,
    required this.optionsSugar,
    required this.optionsTexture,
    required this.extras,
    required this.ingredientNames,
    required this.hasHot,
  });
  factory OrderProduct.fromMap(String id, Map<String, dynamic> m) {
    double _toD(v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0.0;
      return 0.0;
    }
    final opts = (m['options'] ?? {}) as Map<String, dynamic>;
    Map<String, bool> _opt(String k) {
      final mm = (opts[k] ?? {}) as Map<String, dynamic>;
      return {for (final e in mm.entries) e.key: e.value == true};
    }
    final ex = (m['extras'] ?? {}) as Map<String, dynamic>;
    final extras = <String, double>{
      for (final e in ex.entries)
        e.key: (e.value is Map && (e.value as Map)['price'] is num)
            ? ((e.value as Map)['price'] as num).toDouble()
            : (e.value is num)
                ? (e.value as num).toDouble()
                : 0.0
    };
    return OrderProduct(
      id: id,
      name: (m['name'] ?? '').toString(),
      category: (m['categoryName'] ?? m['category'] ?? '').toString(),
      hotPrice: _toD(m['hotPrice'] ?? 0),
      coldPrice: _toD(m['coldPrice'] ?? 0),
      imageUrl: (m['imageUrl'] ?? '') as String?,
      optionsIce: _opt('ice'),
      optionsSugar: _opt('sugar'),
      optionsTexture: _opt('texture'),
      extras: extras,
      ingredientNames: (m['ingredientNames'] is List) ? (m['ingredientNames'] as List).map((e) => '$e').toList() : <String>[],
      hasHot: (m['hasHot'] == true),
    );

  }
}

class OrderItem {
  final OrderProduct product;
  final bool isHot;
  final String? ice;
  final String? sugar;
  final String? texture;
  final List<String> extras;
  int qty;
  OrderItem({required this.product, required this.isHot, this.ice, this.sugar, this.texture, this.extras = const [], this.qty = 1});
  double get unitPrice {
    final base = isHot ? (product.hotPrice > 0 ? product.hotPrice : product.coldPrice) : product.coldPrice;
    double extraSum = 0.0;
    for (final e in extras) {
      extraSum += product.extras[e] ?? 0.0;
    }
    return base + extraSum;
  }
  double get total => unitPrice * qty;
}

class OrderListScreen extends StatefulWidget {
  const OrderListScreen({super.key});
  @override
  State<OrderListScreen> createState() => _OrderListScreenState();
}

class _OrderListScreenState extends State<OrderListScreen> {
  final List<OrderProduct> _products = [];
  String _searchQuery = '';
  String _selectedCategory = 'All';
  String _temperature = 'ALL';
  bool _loading = false;
  final Map<String, List<OrderItem>> _carts = {
    'DINE IN': [],
    'TAKE AWAY': [],
  };
  String _serviceType = 'DINE IN';
  int _currentPage = 1;
  final int _pageSize = 8;
  final Map<String, int> _orderCounters = {
    'DINE IN': 1,
    'TAKE AWAY': 1,
  };

  List<OrderItem> get _cart => _carts[_serviceType] ?? [];

  @override
  void initState() {
    super.initState();
    _subscribeProducts();
    _refreshOrderNo();
  }

  void _subscribeProducts() {
    setState(() => _loading = true);
    FirebaseFirestore.instance.collection('products').snapshots().listen((snap) {
      final items = snap.docs.map((d) => OrderProduct.fromMap(d.id, d.data())).toList();
      setState(() {
        _products
          ..clear()
          ..addAll(items);
        _loading = false;
      });
    }, onError: (_) {
      setState(() => _loading = false);
    });
  }

  List<String> get _categories {
    final set = <String>{};
    for (final p in _products) {
      final c = p.category.isEmpty ? 'Uncategorized' : p.category;
      set.add(c);
    }
    final list = set.toList()..sort();
    return ['All', ...list];
  }

  List<OrderProduct> _filtered() {
    Iterable<OrderProduct> list = _products;
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((p) => p.name.toLowerCase().contains(q));
    }
    if (_selectedCategory != 'All') {
      list = list.where((p) => p.category == _selectedCategory);
    }
    if (_temperature == 'HOT') {
      list = list.where((p) => p.hotPrice > 0);
    } else if (_temperature == 'ICE') {
      list = list.where((p) => p.coldPrice > 0);
    }
    return list.toList();
  }

  List<OrderProduct> _paginate(List<OrderProduct> input) {
    final start = (_currentPage - 1) * _pageSize;
    final end = math.min(start + _pageSize, input.length);
    if (start >= input.length) return [];
    return input.sublist(start, end);
  }

  void _addToCart(OrderProduct p, {required bool isHot, String? ice, String? sugar, String? texture, List<String>? extras}) {
    final cart = _carts[_serviceType]!;
    final existingIndex = cart.indexWhere((e) {
      if (e.product.id != p.id || e.isHot != isHot || e.ice != ice || e.sugar != sugar || e.texture != texture) return false;
      final a = Set<String>.from(e.extras);
      final b = Set<String>.from(extras ?? const []);
      return a.length == b.length && a.containsAll(b);
    });
    setState(() {
      if (existingIndex >= 0) {
        cart[existingIndex].qty += 1;
      } else {
        cart.add(OrderItem(product: p, isHot: isHot, ice: ice, sugar: sugar, texture: texture, extras: extras ?? const []));
      }
    });
  }

  void _incQty(int i) => setState(() => _cart[i].qty++);
  void _decQty(int i) => setState(() {
        if (_cart[i].qty > 1) {
          _cart[i].qty--;
        } else {
          _cart.removeAt(i);
        }
      });
  void _clearCart() => setState(() => _cart.clear());

  double get _subtotal => _cart.fold(0.0, (sum, e) => sum + e.total);
  double get _tax => _subtotal * 0.06;
  double get _total => _subtotal + _tax;

  OrderProduct? _selectedProduct;
  String? _selIce;
  String? _selSugar;
  String? _selTexture;
  final Set<String> _selExtras = {};
  bool _selIsHot = false;
  bool _isPaymentPanel = false;
  String _paymentMethod = 'CASH';
  bool _isPaid = false;
  bool _orderSaved = false;
  int _orderNo = 1;
  final TextEditingController _receivedCtr = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered();
    final total = filtered.length;
    final pages = ((total + _pageSize - 1) ~/ _pageSize).clamp(1, 9999);
    final displayed = _paginate(filtered);
    final isBottomNav = MediaQuery.of(context).size.width < 1024;
    return AppShell(
      activeItem: 'Order List',
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 240,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [                  
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
                    height: 40,
                    child: Row(children: [const Icon(Icons.search, size: 18), const SizedBox(width: 8), Expanded(child: TextField(onChanged: (v) => setState(() => _searchQuery = v), decoration: const InputDecoration(border: InputBorder.none, hintText: 'Search')))]),
                  ),
                  const SizedBox(height: 12),
                  Text('CATEGORY', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Wrap(spacing: 8, runSpacing: 8, children: _categories.map((c) {
                    final active = _selectedCategory == c;
                    return InkWell(
                      onTap: () => setState(() {
                        _selectedCategory = c;
                        _currentPage = 1;
                      }),
                      child: Container(
                        width: 100,
                        height: 60,
                        decoration: BoxDecoration(color: active ? Colors.orange[50] : Colors.white, border: Border.all(color: active ? (Colors.orange[600] ?? Colors.orange) : Colors.orange), borderRadius: BorderRadius.circular(12)),
                        alignment: Alignment.center,
                        child: Text(c.toUpperCase(), style: TextStyle(color: active ? (Colors.orange[700] ?? Colors.orange) : Colors.black87, fontWeight: FontWeight.w700)),
                      ),
                    );
                  }).toList()),
                  const SizedBox(height: 12),
                  Text('TEMPERATURE', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Wrap(spacing: 8, children: ['ICE', 'HOT'].map((t) {
                    final active = _temperature == t;
                    return InkWell(
                      onTap: () => setState(() {
                        _temperature = active ? 'ALL' : t;
                        _currentPage = 1;
                      }),
                      child: Container(
                        width: 80,
                        height: 60,
                        decoration: BoxDecoration(color: active ? Colors.orange[50] : Colors.white, border: Border.all(color: active ? (Colors.orange[600] ?? Colors.orange) : Colors.orange), borderRadius: BorderRadius.circular(12)),
                        alignment: Alignment.center,
                        child: Text(t, style: TextStyle(color: active ? (Colors.orange[700] ?? Colors.orange) : Colors.black87, fontWeight: FontWeight.w700)),
                      ),
                    );
                  }).toList()),
                ],
              ),
            ),
          ),
          Container(width: 1, color: Colors.grey[300]),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(child: Text('Products', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700))),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(children: List.generate(pages, (i) {
                        final page = i + 1;
                        final isActive = _currentPage == page;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: InkWell(
                            onTap: () => setState(() => _currentPage = page),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(color: isActive ? (Colors.orange[600] ?? Colors.orange) : Colors.orange[50], borderRadius: BorderRadius.circular(6)),
                              child: Text('$page', style: TextStyle(color: isActive ? Colors.white : Colors.black)),
                            ),
                          ),
                        );
                      })),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  if (_loading)
                    const Center(child: CircularProgressIndicator(strokeWidth: 2))
                  else if (isBottomNav)
                    Expanded(
                      child: GridView.builder(
                        padding: EdgeInsets.zero,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 1,
                        ),
                        itemCount: filtered.length,
                        itemBuilder: (context, i) {
                          final p = filtered[i];
                          return InkWell(
                            onTap: () => _showProductSelectDialog(p),
                            child: Container(
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 8, offset: const Offset(0, 2))], border: Border.all(color: Colors.orange)),
                              alignment: Alignment.center,
                              padding: const EdgeInsets.all(8),
                              child: Text(p.name, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                            ),
                          );
                        },
                      ),
                    )
                  else
                    Expanded(
                      child: ListView(children: displayed.map(_buildProductCard).toList()),
                    ),
                ],
              ),
            ),
          ),
          Container(width: 1, color: Colors.grey[300]),
          SizedBox(
            width: 320,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  if (!_isPaymentPanel) ...[
                    Row(children: [
                      Text('Order No : ', style: const TextStyle(fontSize: 16)),
                      Text('#${_orderNo.toString().padLeft(4, '0')}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                    ]),
                    Builder(builder: (context) {
                      final now = DateTime.now();
                      final dt = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(dt, style: const TextStyle(color: Colors.black54)),
                      );
                    }),
                    const SizedBox(height: 6),
                    Row(children: [
                      Expanded(child: _serviceToggle('DINE IN')),
                      const SizedBox(width: 8),
                      Expanded(child: _serviceToggle('TAKE AWAY')),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: Text('ORDER LIST', style: const TextStyle(fontWeight: FontWeight.w700))),
                      TextButton(onPressed: _clearCart, style: TextButton.styleFrom(foregroundColor: Colors.orange[700] ?? Colors.orange), child: const Text('CLEAR ALL'))
                    ]),
                    const Divider(color: Colors.black, thickness: 1),
                    const SizedBox(height: 6),
                  ],
                  if (!_isPaymentPanel) ...[
                    (isBottomNav
                      ? Container(
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 8, offset: const Offset(0, 2))]),
                          child: ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _cart.length,
                            itemBuilder: (context, i) => _buildCartItem(i),
                          ),
                        )
                      : Expanded(child: Container(
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 8, offset: const Offset(0, 2))]),
                          child: ListView.builder(
                            physics: const ClampingScrollPhysics(),
                            itemCount: _cart.length,
                            itemBuilder: (context, i) => _buildCartItem(i),
                          ),
                        ))
                    ),
                    const SizedBox(height: 12),
                    _paymentDetails(),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 44,
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _cart.isEmpty ? null : () { setState(() { _isPaymentPanel = true; _isPaid = false; }); _refreshOrderNo(); },
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC711F), foregroundColor: Colors.white, textStyle: const TextStyle(fontSize: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        child: const Text('PAYMENT'),
                      ),
                    ),
                  ] else ...[
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: _paymentPanel(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _serviceToggle(String label) {
    final active = _serviceType == label;
    return InkWell(
      onTap: () => setState(() => _serviceType = label),
      child: Container(
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: active ? (Colors.orange[50]) : Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: active ? (Colors.orange[600] ?? Colors.orange) : Colors.orange)),
        child: Text(label, style: TextStyle(color: active ? (Colors.orange[700] ?? Colors.orange) : Colors.black87, fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildProductCard(OrderProduct p) {
    final iceList = p.optionsIce.entries.where((e) => e.value).map((e) => e.key).toList();
    final sugarList = p.optionsSugar.entries.where((e) => e.value).map((e) => e.key).toList();
    final textureList = p.optionsTexture.entries.where((e) => e.value).map((e) => e.key).toList();
    final extrasList = p.extras.keys.toList();
    String? selIce;
    String? selSugar;
    String? selTexture;
    final Set<String> selExtras = {};
    bool isHot = false;
    return StatefulBuilder(builder: (context, setLocal) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 8, offset: const Offset(0, 2))]),
        child: Row(
          children: [
            SizedBox(width: 80, height: 60, child: p.imageUrl != null && p.imageUrl!.isNotEmpty ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(p.imageUrl!, fit: BoxFit.cover)) : Center(child: Icon(Icons.local_cafe, size: 32, color: Colors.grey[600]))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
        
                const SizedBox(height: 6),
                Row(children: [
                  Expanded(child: iceList.isNotEmpty ? const Center(child: Text('Ice Level', style: TextStyle(fontWeight: FontWeight.w700))) : const SizedBox.shrink()),
                  Expanded(child: sugarList.isNotEmpty ? const Center(child: Text('Sugar Level', style: TextStyle(fontWeight: FontWeight.w700))) : const SizedBox.shrink()),
                  Expanded(child: textureList.isNotEmpty ? const Center(child: Text('Texture', style: TextStyle(fontWeight: FontWeight.w700))) : const SizedBox.shrink()),
                ]),
                const SizedBox(height: 6),
                Row(children: [
                  Expanded(child: _chipsGroup(iceList, selIce, (v) => setLocal(() => selIce = v))),
                  Expanded(child: _chipsGroup(sugarList, selSugar, (v) => setLocal(() => selSugar = v))),
                  Expanded(child: _chipsGroup(textureList, selTexture, (v) => setLocal(() => selTexture = v))),
                ]),
                if (extrasList.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text('Extra Requirement', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: extrasList.map((o) {
                      final isSel = selExtras.contains(o);
                      final price = p.extras[o] ?? 0.0;
                      return InkWell(
                        onTap: () => setLocal(() {
                          if (isSel) {
                            selExtras.remove(o);
                          } else {
                            selExtras.add(o);
                          }
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(color: isSel ? (Colors.orange[600] ?? Colors.orange) : Colors.orange[50], border: Border.all(color: Colors.orange), borderRadius: BorderRadius.circular(20)),
                          child: Text('$o (RM ${price.toStringAsFixed(2)})', style: TextStyle(color: isSel ? Colors.white : (Colors.orange[700] ?? Colors.orange), fontWeight: FontWeight.w700)),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ]),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 80,
              child: Column(children: [
                Column(children: [
                  if (p.hotPrice > 0)
                    SizedBox(
                      width: double.infinity,
                      height: 36,
                      child: InkWell(
                        onTap: () => setLocal(() => isHot = true),
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: isHot ? Colors.red[50] : Colors.transparent, border: Border.all(color: Colors.red, width: 1.5), borderRadius: BorderRadius.circular(12)),
                          child: const Text('HOT', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ),
                  if (p.hotPrice > 0) const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 36,
                    child: InkWell(
                      onTap: () => setLocal(() => isHot = false),
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: !isHot ? Colors.blue[50] : Colors.transparent, border: Border.all(color: Colors.blue, width: 1.5), borderRadius: BorderRadius.circular(12)),
                        child: const Text('ICE', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                SizedBox(
                  height: 36,
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _addToCart(p, isHot: isHot, ice: selIce, sugar: selSugar, texture: selTexture, extras: selExtras.toList()),
                    style: ElevatedButton.styleFrom(backgroundColor: (Colors.orange[600] ?? Colors.orange), foregroundColor: Colors.white),
                    child: const Text('ADD'),
                  ),
                ),
              ]),
            ),
          ],
        ),
      );
    });
  }

  Widget _optionGroup(String title, List<String> options, String? selected, ValueChanged<String> onSelect) {
    if (options.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Wrap(spacing: 8, runSpacing: 8, children: options.map((o) {
        final isSel = selected == o;
        return InkWell(
          onTap: () => onSelect(o),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: isSel ? (Colors.orange[600] ?? Colors.orange) : Colors.orange[50], border: Border.all(color: Colors.orange), borderRadius: BorderRadius.circular(20)),
            child: Text(o, style: TextStyle(color: isSel ? Colors.white : (Colors.orange[700] ?? Colors.orange), fontWeight: FontWeight.w700)),
          ),
        );
      }).toList()),
    ]);
  }

  Widget _chipsGroup(List<String> options, String? selected, ValueChanged<String> onSelect) {
    if (options.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 8, runSpacing: 8, children: options.map((o) {
      final isSel = selected == o;
      return InkWell(
        onTap: () => onSelect(o),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: isSel ? (Colors.orange[600] ?? Colors.orange) : Colors.orange[50], border: Border.all(color: Colors.orange), borderRadius: BorderRadius.circular(20)),
          child: Text(o, style: TextStyle(color: isSel ? Colors.white : (Colors.orange[700] ?? Colors.orange), fontWeight: FontWeight.w700)),
        ),
      );
    }).toList());
  }

  Widget _buildCartItem(int i) {
    final it = _cart[i];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Row(children: [
            Expanded(child: Text('${it.product.name} ${it.isHot ? '* Hot' : '* Ice'}', style: const TextStyle(fontWeight: FontWeight.w800))),
            IconButton(onPressed: () => _editCartItem(i), icon: const Icon(Icons.edit, color: Colors.orange), tooltip: 'Edit'),
          ])),
          InkWell(onTap: () => _decQty(i), child: Container(width: 28, height: 28, decoration: BoxDecoration(border: Border.all(color: Colors.black87), borderRadius: BorderRadius.circular(14)), alignment: Alignment.center, child: const Text('-'))),
          const SizedBox(width: 6),
          Text('${it.qty}', style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(width: 6),
          InkWell(onTap: () => _incQty(i), child: Container(width: 28, height: 28, decoration: BoxDecoration(border: Border.all(color: Colors.black87), borderRadius: BorderRadius.circular(14)), alignment: Alignment.center, child: const Text('+'))),
          const SizedBox(width: 12),
          Text('RM ${it.unitPrice.toStringAsFixed(2)}'),
        ]),
        const SizedBox(height: 4),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (it.sugar != null) Row(children: [const Icon(Icons.circle, size: 8, color: Colors.red), const SizedBox(width: 6), Text(it.sugar!)]),
          if (it.ice != null) Row(children: [const Icon(Icons.circle, size: 8, color: Colors.red), const SizedBox(width: 6), Text(it.ice!)]),
          if (it.texture != null) Row(children: [const Icon(Icons.circle, size: 8, color: Colors.red), const SizedBox(width: 6), Text(it.texture!)]),
          for (final e in it.extras) Row(children: [const Icon(Icons.circle, size: 8, color: Colors.red), const SizedBox(width: 6), Text('$e (+RM ${(it.product.extras[e] ?? 0).toStringAsFixed(2)})')]),
        ]),
        const Divider(),
      ]),
    );
  }

  void _editCartItem(int i) {
    final it = _cart[i];
    final p = it.product;
    String? selIce = it.ice;
    String? selSugar = it.sugar;
    String? selTexture = it.texture;
    final Set<String> selExtras = {...it.extras};
    bool isHot = it.isHot;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setLocal) {
          final iceList = p.optionsIce.entries.where((e) => e.value).map((e) => e.key).toList();
          final sugarList = p.optionsSugar.entries.where((e) => e.value).map((e) => e.key).toList();
          final textureList = p.optionsTexture.entries.where((e) => e.value).map((e) => e.key).toList();
          final extrasList = p.extras.keys.toList();
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.orange),
            ),
            title: Text('Edit ${p.name}'),
            content: SingleChildScrollView(
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(border: Border.all(color: Colors.orange), borderRadius: BorderRadius.circular(8)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    if (p.hotPrice > 0)
                      Expanded(
                        child: InkWell(
                          onTap: () => setLocal(() => isHot = true),
                          child: Container(
                            height: 40,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(color: isHot ? Colors.red[50] : Colors.transparent, border: Border.all(color: Colors.red, width: isHot ? 2 : 1.5), borderRadius: BorderRadius.circular(12)),
                            child: const Text('HOT', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ),
                    if (p.hotPrice > 0) const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: () => setLocal(() => isHot = false),
                        child: Container(
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: !isHot ? Colors.blue[50] : Colors.transparent, border: Border.all(color: Colors.blue, width: !isHot ? 2 : 1.5), borderRadius: BorderRadius.circular(12)),
                          child: const Text('ICE', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: _chipsGroup(iceList, selIce, (v) => setLocal(() => selIce = v))),
                    Expanded(child: _chipsGroup(sugarList, selSugar, (v) => setLocal(() => selSugar = v))),
                    Expanded(child: _chipsGroup(textureList, selTexture, (v) => setLocal(() => selTexture = v))),
                  ]),
                  if (extrasList.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const Text('Extra Requirement', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: extrasList.map((o) {
                        final isSel = selExtras.contains(o);
                        final price = p.extras[o] ?? 0.0;
                        return InkWell(
                          onTap: () => setLocal(() {
                            if (isSel) {
                              selExtras.remove(o);
                            } else {
                              selExtras.add(o);
                            }
                          }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(color: isSel ? (Colors.orange[600] ?? Colors.orange) : Colors.orange[50], border: Border.all(color: Colors.orange), borderRadius: BorderRadius.circular(20)),
                            child: Text('$o (RM ${price.toStringAsFixed(2)})', style: TextStyle(color: isSel ? Colors.white : (Colors.orange[700] ?? Colors.orange), fontWeight: FontWeight.w700)),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ]),
              ),
            ),
            actions: [
              OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.orange,
                  side: const BorderSide(color: Colors.orange),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('CANCEL', style: TextStyle(letterSpacing: 0.5)),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _cart[i] = OrderItem(product: p, isHot: isHot, ice: selIce, sugar: selSugar, texture: selTexture, extras: selExtras.toList(), qty: it.qty);
                    _mergeCartSimilar(i);
                  });
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(backgroundColor: (Colors.orange[600] ?? Colors.orange), foregroundColor: Colors.white),
                child: const Text('Save'),
              ),
            ],
          );
        });
      },
    );
  }

  void _mergeCartSimilar(int i) {
    final current = _cart[i];
    final existingIndex = _cart.indexWhere((e) {
      if (identical(e, current)) return false;
      if (e.product.id != current.product.id || e.isHot != current.isHot || e.ice != current.ice || e.sugar != current.sugar || e.texture != current.texture) return false;
      final a = Set<String>.from(e.extras);
      final b = Set<String>.from(current.extras);
      return a.length == b.length && a.containsAll(b);
    });
    if (existingIndex >= 0) {
      _cart[existingIndex].qty += current.qty;
      _cart.removeAt(i);
    }
  }

  Widget _selectedProductDetails() {
    final p = _selectedProduct!;
    final iceList = p.optionsIce.entries.where((e) => e.value).map((e) => e.key).toList();
    final sugarList = p.optionsSugar.entries.where((e) => e.value).map((e) => e.key).toList();
    final textureList = p.optionsTexture.entries.where((e) => e.value).map((e) => e.key).toList();
    final extrasList = p.extras.keys.toList();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 8, offset: const Offset(0, 2))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(p.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(child: iceList.isNotEmpty ? const Center(child: Text('Ice Level', style: TextStyle(fontWeight: FontWeight.w700))) : const SizedBox.shrink()),
          Expanded(child: sugarList.isNotEmpty ? const Center(child: Text('Sugar Level', style: TextStyle(fontWeight: FontWeight.w700))) : const SizedBox.shrink()),
          Expanded(child: textureList.isNotEmpty ? const Center(child: Text('Texture', style: TextStyle(fontWeight: FontWeight.w700))) : const SizedBox.shrink()),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(child: _chipsGroup(iceList, _selIce, (v) => setState(() => _selIce = v))),
          Expanded(child: _chipsGroup(sugarList, _selSugar, (v) => setState(() => _selSugar = v))),
          Expanded(child: _chipsGroup(textureList, _selTexture, (v) => setState(() => _selTexture = v))),
        ]),
        if (extrasList.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text('Extra Requirement', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: extrasList.map((o) {
              final isSel = _selExtras.contains(o);
              final price = p.extras[o] ?? 0.0;
              return InkWell(
                onTap: () => setState(() {
                  if (isSel) {
                    _selExtras.remove(o);
                  } else {
                    _selExtras.add(o);
                  }
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: isSel ? (Colors.orange[600] ?? Colors.orange) : Colors.orange[50], border: Border.all(color: Colors.orange), borderRadius: BorderRadius.circular(20)),
                  child: Text('$o (RM ${price.toStringAsFixed(2)})', style: TextStyle(color: isSel ? Colors.white : (Colors.orange[700] ?? Colors.orange), fontWeight: FontWeight.w700)),
                ),
              );
            }).toList(),
          ),
        ],
        const SizedBox(height: 8),
        Column(children: [
          if (p.hotPrice > 0)
            SizedBox(
              width: double.infinity,
              height: 36,
              child: InkWell(
                onTap: () => setState(() => _selIsHot = true),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: _selIsHot ? Colors.red[50] : Colors.transparent, border: Border.all(color: Colors.red, width: _selIsHot ? 2 : 1.5), borderRadius: BorderRadius.circular(12)),
                  child: const Text('HOT', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          if (p.hotPrice > 0) const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 36,
            child: InkWell(
              onTap: () => setState(() => _selIsHot = false),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(color: !_selIsHot ? Colors.blue[50] : Colors.transparent, border: Border.all(color: Colors.blue, width: !_selIsHot ? 2 : 1.5), borderRadius: BorderRadius.circular(12)),
                child: const Text('ICE', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        SizedBox(
          height: 36,
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => _addToCart(p, isHot: _selIsHot, ice: _selIce, sugar: _selSugar, texture: _selTexture, extras: _selExtras.toList()),
            style: ElevatedButton.styleFrom(backgroundColor: (Colors.orange[600] ?? Colors.orange), foregroundColor: Colors.white),
            child: const Text('ADD'),
          ),
        ),
      ]),
    );
  }

  void _showProductSelectDialog(OrderProduct p) {
    String? selIce;
    String? selSugar;
    String? selTexture;
    final Set<String> selExtras = {};
    bool isHot = false;
    showDialog(
      context: context,
      builder: (ctx) {
        final iceList = p.optionsIce.entries.where((e) => e.value).map((e) => e.key).toList();
        final sugarList = p.optionsSugar.entries.where((e) => e.value).map((e) => e.key).toList();
        final textureList = p.optionsTexture.entries.where((e) => e.value).map((e) => e.key).toList();
        final extrasList = p.extras.keys.toList();
        final width = MediaQuery.of(ctx).size.width;
        final dialogWidth = math.min(width * 0.9, 520.0);
        return StatefulBuilder(builder: (ctx, setLocal) {
          final extrasTotal = selExtras.fold(0.0, (sum, o) => sum + (p.extras[o] ?? 0.0));
          final basePrice = isHot ? p.hotPrice : p.coldPrice;
          final totalPrice = (basePrice + extrasTotal).toStringAsFixed(2);
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.orange),
            ),
            contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text('RM $totalPrice', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black87)),
            ]),
            content: SizedBox(
              width: dialogWidth,
              child: SingleChildScrollView(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(border: Border.all(color: Colors.orange), borderRadius: BorderRadius.circular(8)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                  Expanded(child: iceList.isNotEmpty ? const Center(child: Text('Ice Level', style: TextStyle(fontWeight: FontWeight.w700))) : const SizedBox.shrink()),
                  Expanded(child: sugarList.isNotEmpty ? const Center(child: Text('Sugar Level', style: TextStyle(fontWeight: FontWeight.w700))) : const SizedBox.shrink()),
                  Expanded(child: textureList.isNotEmpty ? const Center(child: Text('Texture', style: TextStyle(fontWeight: FontWeight.w700))) : const SizedBox.shrink()),
                ]),
                const SizedBox(height: 6),
                Row(children: [
                  Expanded(child: _chipsGroup(iceList, selIce, (v) => setLocal(() => selIce = v))),
                  Expanded(child: _chipsGroup(sugarList, selSugar, (v) => setLocal(() => selSugar = v))),
                  Expanded(child: _chipsGroup(textureList, selTexture, (v) => setLocal(() => selTexture = v))),
                ]),
                  if (extrasList.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text('Extra Requirement', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: extrasList.map((o) {
                      final isSel = selExtras.contains(o);
                      final price = p.extras[o] ?? 0.0;
                      return InkWell(
                        onTap: () => setLocal(() {
                          if (isSel) {
                            selExtras.remove(o);
                          } else {
                            selExtras.add(o);
                          }
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(color: isSel ? (Colors.orange[600] ?? Colors.orange) : Colors.orange[50], border: Border.all(color: Colors.orange), borderRadius: BorderRadius.circular(20)),
                          child: Text('$o (RM ${price.toStringAsFixed(2)})', style: TextStyle(color: isSel ? Colors.white : (Colors.orange[700] ?? Colors.orange), fontWeight: FontWeight.w700)),
                        ),
                      );
                    }).toList(),
                  ),
                ],
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(border: Border.all(color: Colors.orange), borderRadius: BorderRadius.circular(8)),
                    child: Row(children: [
                      if (p.hotPrice > 0)
                        Expanded(
                          child: InkWell(
                            onTap: () => setLocal(() => isHot = true),
                            child: Container(
                              height: 40,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(color: isHot ? Colors.red[50] : Colors.transparent, border: Border.all(color: Colors.red, width: isHot ? 2 : 1.5), borderRadius: BorderRadius.circular(12)),
                              child: const Text('HOT', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
                            ),
                          ),
                        ),
                      if (p.hotPrice > 0) const SizedBox(width: 8),
                      Expanded(
                        child: InkWell(
                          onTap: () => setLocal(() => isHot = false),
                          child: Container(
                            height: 40,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(color: !isHot ? Colors.blue[50] : Colors.transparent, border: Border.all(color: Colors.blue, width: !isHot ? 2 : 1.5), borderRadius: BorderRadius.circular(12)),
                              child: const Text('ICE', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ),
                    ]),
                  ),
                ]),
                ),
              ),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            actions: [
              OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.orange,
                  side: const BorderSide(color: Colors.orange),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('CANCEL', style: TextStyle(letterSpacing: 0.5)),
              ),
              SizedBox(
                height: 40,
                child: ElevatedButton(
                  onPressed: () {
                    _addToCart(p, isHot: isHot, ice: selIce, sugar: selSugar, texture: selTexture, extras: selExtras.toList());
                    Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: (Colors.orange[600] ?? Colors.orange), foregroundColor: Colors.white),
                  child: const Text('Add'),
                ),
              ),
            ],
          );
        });
      },
    );
  }

  Widget _paymentPanel() {
    final now = DateTime.now();
    final total = _total;
    double received = _paymentMethod == 'CASH'
        ? (double.tryParse(_receivedCtr.text.trim()) ?? 0.0)
        : _total;
    final changeRaw = (received - total).clamp(-999999.0, 999999.0);
    double changeDisplay = changeRaw;
    double roundDiff = 0.0;
    if (_paymentMethod == 'CASH' && changeRaw > 0) {
      final ip = changeRaw.floorToDouble();
      final frac = changeRaw - ip;
      final baseStart = (frac / 0.10).floor() * 0.10;
      final t = frac - baseStart;
      double tAdj = t;
      if (t > 0 && t <= 0.07) {
        tAdj = 0.05;
      } else if (t > 0.07 && t <= 0.09) {
        tAdj = 0.10;
      }
      double fracAdj = baseStart + tAdj;
      if (fracAdj >= 1.0) {
        changeDisplay = ip + 1.0;
      } else {
        changeDisplay = ip + fracAdj;
      }
      changeDisplay = double.parse(changeDisplay.toStringAsFixed(2));
      roundDiff = double.parse((changeDisplay - changeRaw).toStringAsFixed(2));
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 8, offset: const Offset(0, 2))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('Order No : ', style: TextStyle(fontSize: 16)),
          Text('#${_orderCounters[_serviceType]!.toString().padLeft(4, '0')}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          Text('Date : ${now.toString().split(' ').first}'),
          const SizedBox(width: 12),
          Text('Time : ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}')
        ]),
        const SizedBox(height: 8),
        Text('Type : $_serviceType'),
        const SizedBox(height: 8),
        const Text('Total Amount :'),
        Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 8, offset: const Offset(0, 2))]),
          child: Text('RM ${total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.red)),
        ),
        const Text('Payment Method :'),
        const SizedBox(height: 6),
        Column(children: [
          _pmOption('CASH', Icons.attach_money),
          const SizedBox(height: 6),
          _pmOption('CREDIT / DEBIT CARD', Icons.credit_card),
          const SizedBox(height: 6),
          _pmOption('E-WALLET', Icons.account_balance_wallet),
        ]),
        const SizedBox(height: 10),
        if (!_isPaid)
          SizedBox(
            height: 44,
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_paymentMethod == 'CASH' && changeDisplay <= 0)
                  ? null
                  : () async { await _saveOrderToFirestore(); setState(() => _isPaid = true); },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC711F), foregroundColor: Colors.white, textStyle: const TextStyle(fontSize: 18)),
              child: const Text('PAID'),
            ),
          ),
        if (_paymentMethod == 'CASH') ...[
          const SizedBox(height: 5),
          Row(children: [
            const Expanded(child: Text('Received :')),
            const Text('RM'),
            const SizedBox(width: 6),
            SizedBox(
              width: 120,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 8, offset: const Offset(0, 2))]),
                child: TextField(controller: _receivedCtr, keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))], style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700), decoration: const InputDecoration(border: InputBorder.none, hintText: '0.00'), onChanged: (_) => setState(() {})),
              ),
            ),
          ]),
          Row(children: [
            const Expanded(child: Text('Change :')),
            Container(
              width: 140,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 8, offset: const Offset(0, 2))]),
              child: Text('RM ${changeDisplay.toStringAsFixed(2)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.red)),
            ),
          ]),
          if (_paymentMethod == 'CASH' && roundDiff != 0.0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(children: [
                const Expanded(child: SizedBox()),
                Text(
                  '${roundDiff > 0 ? '+' : '-'} RM ${roundDiff.abs().toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ]),
            ),
        ],
        if (_isPaid) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 44,
            width: double.infinity,
            child: ElevatedButton(onPressed: () async => await _showReceiptGenerating(), style: ElevatedButton.styleFrom(backgroundColor: (Colors.orange[600] ?? Colors.orange), foregroundColor: Colors.white, textStyle: const TextStyle(fontSize: 16)), child: const Text('PRINT RECEIPT')),
          ),
          const SizedBox(height: 4),
        ],
        if (!_isPaid) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 44,
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => setState(() { _isPaymentPanel = false; }),
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.orange,
                side: const BorderSide(color: Colors.orange),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                textStyle: const TextStyle(fontSize: 18)
              ),
              child: const Text('BACK'),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _pmOption(String label, IconData icon) {
    final selected = _paymentMethod == label;
    return InkWell(
      onTap: _isPaid ? null : () => setState(() => _paymentMethod = label),
      child: Container(
        height: 44,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? Colors.orange[50] : Colors.white,
          border: Border.all(color: Colors.orange),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Row(children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.orange)),
            child: Icon(icon, color: Colors.orange),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700))),
        ]),
      ),
    );
  }

  Widget _paymentDetails() {
    return Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('SUBTOTAL'), Text('RM ${_subtotal.toStringAsFixed(2)}')]),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('TAX (6%)'), Text('RM ${_tax.toStringAsFixed(2)}')]),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Total', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)), Text('RM ${_total.toStringAsFixed(2)}', style: const TextStyle(color: Colors.red, fontSize: 22, fontWeight: FontWeight.w900))]),
    ]);
  }

  Future<void> _refreshOrderNo() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final franchiseId = auth.currentUser?.franchiseId;
    Query q = FirebaseFirestore.instance.collection('orders');
    if (franchiseId != null) {
      q = q.where('franchiseId', isEqualTo: franchiseId);
    }
    try {
      final snap = await q.get();
      setState(() { _orderNo = snap.size + 1; });
    } catch (_) {
      setState(() { _orderNo = _orderNo; });
    }
  }

  Future<void> _saveOrderToFirestore() async {
    if (_orderSaved) return;
    await _refreshOrderNo();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final staffId = auth.currentUser?.id;
    final staffName = auth.currentUser?.fullName;
    final franchiseId = auth.currentUser?.franchiseId;
    final received = double.tryParse(_receivedCtr.text.trim()) ?? 0.0;
    final changeRaw = (received - _total).clamp(-999999.0, 999999.0);
    double changeDisplay = changeRaw;
    if (_paymentMethod == 'CASH' && changeRaw > 0) {
      final ip = changeRaw.floorToDouble();
      final frac = changeRaw - ip;
      final baseStart = (frac / 0.10).floor() * 0.10;
      final t = frac - baseStart;
      double tAdj = t;
      if (t > 0 && t <= 0.07) {
        tAdj = 0.05;
      } else if (t > 0.07 && t <= 0.09) {
        tAdj = 0.10;
      }
      double fracAdj = baseStart + tAdj;
      if (fracAdj >= 1.0) {
        changeDisplay = ip + 1.0;
      } else {
        changeDisplay = ip + fracAdj;
      }
      changeDisplay = double.parse(changeDisplay.toStringAsFixed(2));
    }
    final items = _cart.map((it) => {
      'productId': it.product.id,
      'productName': it.product.name,
      'qty': it.qty,
      'temperature': it.isHot ? 'HOT' : 'ICE',
      'ice': it.ice,
      'sugar': it.sugar,
      'texture': it.texture,
      'extras': it.extras,
      'ingredients': it.product.ingredientNames,
      'unitPrice': it.unitPrice,
      'total': it.total,
    }).toList();
    final doc = {
      'orderNo': _orderNo,
      'serviceType': _serviceType,
      'status': 'PENDING',
      'createdAt': Timestamp.now(),
      'staffId': staffId,
      'staffName': staffName,
      'franchiseId': franchiseId,
      'paymentMethod': _paymentMethod,
      'received': received,
      'change': changeDisplay,
      'subtotal': _subtotal,
      'tax': _tax,
      'total': _total,
      'items': items,
    };
    await FirebaseFirestore.instance.collection('orders').add(doc);
    setState(() {
      _orderSaved = true;
      _orderCounters[_serviceType] = (_orderCounters[_serviceType] ?? 0) + 1;
    });
  }

  Future<void> _showReceiptGenerating() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final franchise = auth.currentFranchise;
    final staffName = auth.currentUser?.fullName ?? '';
    final orderNo = _orderNo.toString().padLeft(4, '0');
    final now = DateTime.now();
    final dateStr = now.toString().split(' ').first;
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    await _refreshOrderNo();
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (ctx, anim1, anim2) {
        return Stack(children: [
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
              child: Container(color: Colors.black.withOpacity(0.2)),
            ),
          ),
          Center(
            child: Container(
              width: 360,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 12, offset: const Offset(0, 4))]),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const SizedBox(height: 6),
                const CircularProgressIndicator(strokeWidth: 2),
                const SizedBox(height: 6),
                const Text('GENERATING RECEIPT ........', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black, backgroundColor: Colors.transparent, decoration: TextDecoration.none)),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 8, offset: const Offset(0, 2))]),
                  child: DefaultTextStyle.merge(
                    style: const TextStyle(color: Colors.black, backgroundColor: Colors.transparent, decoration: TextDecoration.none),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                    Row(children: [
                      Expanded(
                        child: ColorFiltered(
                          colorFilter: const ColorFilter.matrix([
                            0.2126, 0.7152, 0.0722, 0, 0,
                            0.2126, 0.7152, 0.0722, 0, 0,
                            0.2126, 0.7152, 0.0722, 0, 0,
                            0,      0,      0,      1, 0,
                          ]),
                          child: Image.asset('assets/images/logo.png', height: 36),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (franchise != null) ...[
                              Text(franchise.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                              if (franchise.contactPhone.isNotEmpty) Text(franchise.contactPhone, style: const TextStyle(fontSize: 12)),
                              if (franchise.address.isNotEmpty) Text(franchise.address, style: const TextStyle(fontSize: 12)),
                            ],
                          ],
                        ),
                      ),
                    ]),
                    const SizedBox(height: 6),
                    Row(children: [
                      Expanded(child: Row(children: [const Text('Order No :', style: TextStyle(fontSize: 12)), const SizedBox(width: 6), Text('#$orderNo', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900))])),
                      const Expanded(child: SizedBox()),
                    ]),
                    const Divider(color: Colors.black, thickness: 2),
                    const SizedBox(height: 6),
                    Row(children: [
                      Expanded(child: Text('Date : $dateStr', style: const TextStyle(fontSize: 12))),
                      Expanded(child: Text('Time : $timeStr', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12))),
                    ]),
                    const SizedBox(height: 4),
                    Row(children: [
                      Expanded(child: Row(children: [const Text('Type :', style: TextStyle(fontSize: 12)), const SizedBox(width: 6), Text(_serviceType, style: const TextStyle(fontSize: 12))])),
                      Expanded(child: Text('Staff : $staffName', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12))),
                    ]),
                    const SizedBox(height: 4),
                    Row(children: [
                      Expanded(child: Text('Payment : $_paymentMethod', style: const TextStyle(fontSize: 12))),
                      const Expanded(child: SizedBox()),
                    ]),
                    const SizedBox(height: 10),
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    Row(children: const [
                      Expanded(flex: 6, child: Text('Beverage Name', style: TextStyle(fontSize: 12))),
                      Expanded(flex: 2, child: Text('Qty', textAlign: TextAlign.center, style: TextStyle(fontSize: 12))),
                      Expanded(flex: 3, child: Text('amount (RM)', textAlign: TextAlign.end, style: TextStyle(fontSize: 12))),
                    ]),
                    const SizedBox(height: 6),
                    ..._cart.map((it) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(children: [
                          Row(children: [
                            Expanded(flex: 6, child: Text(it.product.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                            Expanded(flex: 2, child: Text('${it.qty}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12))),
                            Expanded(flex: 3, child: Text(it.total.toStringAsFixed(2), textAlign: TextAlign.end, style: const TextStyle(fontSize: 12))),
                          ]),
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            if (it.sugar != null) Text('• ${it.sugar!}', style: const TextStyle(fontSize: 11, color: Colors.black)),
                            if (it.ice != null) Text('• ${it.ice!}', style: const TextStyle(fontSize: 11, color: Colors.black)),
                            if (it.texture != null) Text('• ${it.texture!}', style: const TextStyle(fontSize: 11, color: Colors.black)),
                            for (final e in it.extras) Text('• $e', style: const TextStyle(fontSize: 11, color: Colors.black)),
                          ]),
                        ]),
                      );
                    }).toList(),
                    const SizedBox(height: 8),
                    const Divider(height: 1),
                    const SizedBox(height: 6),
                    Row(children: [const Expanded(child: Text('SUBTOTAL', style: TextStyle(fontSize: 12))), Text(_subtotal.toStringAsFixed(2), style: const TextStyle(fontSize: 12))]),
                    Row(children: [const Expanded(child: Text('TAX (6%)', style: TextStyle(fontSize: 12))), Text(_tax.toStringAsFixed(2), style: const TextStyle(fontSize: 12))]),
                    Row(children: [const Expanded(child: Text('TOTAL', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))), Text(_total.toStringAsFixed(2), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))]),
                    const SizedBox(height: 8),
                    const Center(child: Text('Thank you!', style: TextStyle(fontSize: 12))),
                  ],
                      ),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ]);
      },
    );
    Future.delayed(const Duration(seconds: 5), () {
      if (!mounted) return;
      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      setState(() { _clearCart(); _isPaymentPanel = false; _isPaid = false; });
      context.go(AppRoutes.orderList);
    });
  }
}