import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
                      child: ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, i) {
                          final p = filtered[i];
                          return InkWell(
                            onTap: () => setState(() {
                              _selectedProduct = p;
                              _selIce = null;
                              _selSugar = null;
                              _selTexture = null;
                              _selExtras
                                ..clear();
                              _selIsHot = false;
                            }),
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 8, offset: const Offset(0, 2))]),
                              child: Text(p.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
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
                  Row(children: [
                    Text('Order No : ', style: const TextStyle(fontSize: 16)),
                    Text('#${_orderCounters[_serviceType]!.toString().padLeft(4, '0')}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
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
                  if (isBottomNav && _selectedProduct != null) ...[
                    const SizedBox(height: 12),
                    _selectedProductDetails(),
                  ],
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: Text('ORDER LIST', style: const TextStyle(fontWeight: FontWeight.w700))),
                    TextButton(onPressed: _clearCart, style: TextButton.styleFrom(foregroundColor: Colors.orange[700] ?? Colors.orange), child: const Text('CLEAR ALL'))
                  ]),
                  const SizedBox(height: 6),
                  Expanded(child: Container(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 8, offset: const Offset(0, 2))]),
                    child: ListView.builder(
                      itemCount: _cart.length,
                      itemBuilder: (context, i) => _buildCartItem(i),
                    ),
                  )),
                  const SizedBox(height: 12),
                  _paymentDetails(),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 44,
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _cart.isEmpty
                          ? null
                          : () {
                              setState(() {
                                _orderCounters[_serviceType] = _orderCounters[_serviceType]! + 1;
                                _clearCart();
                              });
                            },
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC711F), foregroundColor: Colors.white, textStyle: const TextStyle(fontSize: 18)),
                      child: const Text('PAYMENT'),
                    ),
                  ),
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
                Container(height: 3, width: double.infinity, color: Colors.red),
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
                Wrap(spacing: 8, children: [
                  if (p.hotPrice > 0)
                    InkWell(
                      onTap: () => setLocal(() => isHot = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: Colors.transparent, border: Border.all(color: Colors.red, width: isHot ? 2 : 1.5), borderRadius: BorderRadius.circular(20)),
                        child: const Text('HOT', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  InkWell(
                    onTap: () => setLocal(() => isHot = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: Colors.transparent, border: Border.all(color: Colors.blue, width: !isHot ? 2 : 1.5), borderRadius: BorderRadius.circular(20)),
                      child: const Text('ICE', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w700)),
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
            title: Text('Edit ${p.name}'),
            content: SingleChildScrollView(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Wrap(spacing: 8, children: [
                  if (p.hotPrice > 0)
                    InkWell(
                      onTap: () => setLocal(() => isHot = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: Colors.transparent, border: Border.all(color: Colors.red, width: isHot ? 2 : 1.5), borderRadius: BorderRadius.circular(20)),
                        child: const Text('HOT', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  InkWell(
                    onTap: () => setLocal(() => isHot = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: Colors.transparent, border: Border.all(color: Colors.blue, width: !isHot ? 2 : 1.5), borderRadius: BorderRadius.circular(20)),
                      child: const Text('ICE', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                if (iceList.isNotEmpty) ...[
                  const Text('Ice Level', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  _chipsGroup(iceList, selIce, (v) => setLocal(() => selIce = v)),
                  const SizedBox(height: 12),
                ],
                if (sugarList.isNotEmpty) ...[
                  const Text('Sugar Level', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  _chipsGroup(sugarList, selSugar, (v) => setLocal(() => selSugar = v)),
                  const SizedBox(height: 12),
                ],
                if (textureList.isNotEmpty) ...[
                  const Text('Texture', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  _chipsGroup(textureList, selTexture, (v) => setLocal(() => selTexture = v)),
                  const SizedBox(height: 12),
                ],
                if (extrasList.isNotEmpty) ...[
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
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
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
        Container(height: 3, width: double.infinity, color: Colors.red),
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
        Wrap(spacing: 8, children: [
          if (p.hotPrice > 0)
            InkWell(
              onTap: () => setState(() => _selIsHot = true),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.transparent, border: Border.all(color: Colors.red, width: _selIsHot ? 2 : 1.5), borderRadius: BorderRadius.circular(20)),
                child: const Text('HOT', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
              ),
            ),
          InkWell(
            onTap: () => setState(() => _selIsHot = false),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: Colors.transparent, border: Border.all(color: Colors.blue, width: !_selIsHot ? 2 : 1.5), borderRadius: BorderRadius.circular(20)),
              child: const Text('ICE', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w700)),
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

  Widget _paymentDetails() {
    return Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('SUBTOTAL'), Text('RM ${_subtotal.toStringAsFixed(2)}')]),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('TAX (6%)'), Text('RM ${_tax.toStringAsFixed(2)}')]),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Total', style: TextStyle(fontWeight: FontWeight.w900)), Text('RM ${_total.toStringAsFixed(2)}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w900))]),
    ]);
  }
}