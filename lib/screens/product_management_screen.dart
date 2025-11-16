import 'dart:math' as math;
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'add_product_screen.dart';
import 'package:go_router/go_router.dart';
import '../routes/app_routes.dart';

import '../widgets/app_shell.dart';
import '../providers/auth_provider.dart';

class ProductItem {
  final String id;
  final String name;
  final String category;
  final String? categoryName;
  final int ingredientRequired;
  final double hotPrice;
  final double coldPrice;
  final String? imageUrl;
  final Map<String, bool> optionsIce;
  final Map<String, bool> optionsSugar;
  final Map<String, bool> optionsTexture;
  final List<String> ingredientNames;
  final Map<String, dynamic> extras;
  final bool hasHot;

  ProductItem({
    required this.id,
    required this.name,
    required this.category,
    this.categoryName,
    required this.ingredientRequired,
    required this.hotPrice,
    required this.coldPrice,
    this.imageUrl,
    required this.optionsIce,
    required this.optionsSugar,
    required this.optionsTexture,
    required this.ingredientNames,
    required this.extras,
    required this.hasHot,
  });

  factory ProductItem.fromMap(String id, Map<String, dynamic> m) {
    double _toD(v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0.0;
      return 0.0;
    }
    String _toCategory(dynamic v, Map<String, dynamic> m) {
      final cn = (m['categoryName'] ?? '').toString();
      if (cn.isNotEmpty) return cn;
      if (v is String) return v;
      if (v is DocumentReference) return v.id;
      return 'Uncategorized';
    }

    return ProductItem(
      id: id,
      name: (m['name'] ?? m['productName'] ?? 'Unnamed') as String,
      category: _toCategory(m['category'] ?? 'Uncategorized', m),
      categoryName: (m['categoryName'] ?? '') as String?,
      ingredientRequired: (m['ingredientRequired'] ?? m['ingredients'] ?? 0) is int
          ? (m['ingredientRequired'] ?? m['ingredients'] ?? 0) as int
          : int.tryParse('${m['ingredientRequired'] ?? m['ingredients'] ?? 0}') ?? 0,
      hotPrice: _toD(m['hotPrice'] ?? m['hot'] ?? 0.0),
      coldPrice: _toD(m['coldPrice'] ?? m['cold'] ?? 0.0),
      imageUrl: m['imageUrl'] as String?,
      optionsIce: ((m['options'] ?? {}) as Map<String, dynamic>)['ice']?.map((k, v) => MapEntry('$k', v == true))?.cast<String, bool>() ?? <String, bool>{},
      optionsSugar: ((m['options'] ?? {}) as Map<String, dynamic>)['sugar']?.map((k, v) => MapEntry('$k', v == true))?.cast<String, bool>() ?? <String, bool>{},
      optionsTexture: ((m['options'] ?? {}) as Map<String, dynamic>)['texture']?.map((k, v) => MapEntry('$k', v == true))?.cast<String, bool>() ?? <String, bool>{},
      ingredientNames: (m['ingredientNames'] is List) ? (m['ingredientNames'] as List).map((e) => '$e').toList() : <String>[],
      extras: (m['extras'] is Map) ? (m['extras'] as Map<String, dynamic>) : <String, dynamic>{},
      hasHot: m.containsKey('hotPrice') && m['hotPrice'] != null,
    );
  }
}

class ProductManagementScreen extends StatefulWidget {
  const ProductManagementScreen({super.key});

  @override
  State<ProductManagementScreen> createState() => _ProductManagementScreenState();
}

class _ProductManagementScreenState extends State<ProductManagementScreen> {
  final List<ProductItem> _products = [];
  String _searchQuery = '';
  String _selectedCategory = 'All Category';
  bool _loading = false;
  bool _isApplying = false;
  int _currentPage = 1;
  int _pageSize = 8;
  // Custom dropdown infra for Category filter
  final GlobalKey _categoryFilterKey = GlobalKey();
  OverlayEntry? _categoryMenuOverlay;
  final LayerLink _categoryLink = LayerLink();
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _productsSub;

  @override
  void initState() {
    super.initState();
    _subscribeProducts();
  }

  @override
  void dispose() {
    _productsSub?.cancel();
    super.dispose();
  }

  void _subscribeProducts() {
    setState(() => _loading = true);
    final query = FirebaseFirestore.instance
        .collection('products')
        .orderBy('name');
    _productsSub?.cancel();
    _productsSub = query.snapshots().listen((snap) {
      final items = snap.docs
          .map((d) => ProductItem.fromMap(d.id, d.data()))
          .toList();
      setState(() {
        _products
          ..clear()
          ..addAll(items);
        _loading = false;
      });
    }, onError: (e) {
      setState(() {
        _products.clear();
        _loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load products: $e')),
      );
    });
  }

  List<String> get _categories {
    final set = <String>{};
    for (final p in _products) {
      set.add(p.category);
    }
    final list = set.toList()..sort();
    return ['All Category', ...list];
  }

  List<ProductItem> _filtered() {
    Iterable<ProductItem> list = _products;
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((p) => p.name.toLowerCase().contains(q));
    }
    if (_selectedCategory != 'All Category') {
      list = list.where((p) => p.category == _selectedCategory);
    }
    return list.toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered();
    final total = filtered.length;
    final totalPages = ((total + _pageSize - 1) ~/ _pageSize).clamp(1, 9999);
    final displayed = _paginate(filtered);
    return AppShell(
      activeItem: 'Product',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFilters(total),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Icon(Icons.local_cafe, color: Colors.green[600], size: 28),
                              const SizedBox(width: 12),
                              Text(
                                'Products',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[800],
                                ),
                              ),
                            ],
                          ),
                        ),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(totalPages, (i) {
                              final page = i + 1;
                              return Row(
                                children: [
                                  if (i != 0) const SizedBox(width: 6),
                                  _buildPageButton(page),
                                ],
                              );
                            }),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildTableHeader(),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else ...displayed.map(_buildProductRow),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters(int total) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Search
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search Product Name',
                      prefixIcon: Icon(Icons.search),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v.trim()),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 44,
                child: ElevatedButton(
                  onPressed: _onAddProduct,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[600],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text('+', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      SizedBox(width: 8),
                      Text('ADD PRODUCT', style: TextStyle(letterSpacing: 0.5)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
          const SizedBox(height: 12),
          // Category filter styled like staff management custom dropdown + actions
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: _buildCategoryFilter()),
              const SizedBox(width: 8),
              SizedBox(
                width: 140,
                height: 40,
                child: OutlinedButton.icon(
                  onPressed: _isApplying ? null : _applyFilters,
                  icon: Icon(Icons.filter_alt, color: Colors.orange[600], size: 20),
                  label: const Text('APPLY'),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.orange[600]!),
                    foregroundColor: Colors.orange[600],
                    backgroundColor: Colors.white,
                    textStyle: const TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.5, fontFamily: 'Arial'),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 140,
                height: 40,
                child: OutlinedButton.icon(
                  onPressed: _clearFilters,
                  icon: Icon(Icons.refresh, color: Colors.orange[600], size: 20),
                  label: const Text('CLEAR'),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.orange[600]!),
                    foregroundColor: Colors.orange[600],
                    backgroundColor: Colors.white,
                    textStyle: const TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.5, fontFamily: 'Arial'),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('Total $total records', style: const TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        SizedBox(height: 12),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              Expanded(flex: 3, child: Text('Product Name', style: TextStyle(color: Colors.grey))),
              Expanded(flex: 2, child: Text('Ingredient Required', style: TextStyle(color: Colors.grey))),
              Expanded(flex: 2, child: Text('Category', style: TextStyle(color: Colors.grey))),
              Expanded(flex: 2, child: Text('Hot Price (RM)', style: TextStyle(color: Colors.grey))),
              Expanded(flex: 2, child: Text('Cold Price (RM)', style: TextStyle(color: Colors.grey))),
              Expanded(flex: 2, child: Text('Action', style: TextStyle(color: Colors.grey))),
            ],
          ),
        ),
        Divider(),
      ],
    );
  }

  Widget _buildProductRow(ProductItem p) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        children: [
          // Product cell (image + name)
          Expanded(
            flex: 3,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.grey.shade200,
                  backgroundImage: p.imageUrl != null && p.imageUrl!.isNotEmpty
                      ? NetworkImage(p.imageUrl!)
                      : const AssetImage('assets/images/drink.png') as ImageProvider,
                ),
                const SizedBox(width: 12),
                Flexible(child: Text(p.name, overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
          Expanded(flex: 2, child: Text('${p.ingredientNames.length}')),
          Expanded(flex: 2, child: Text(p.category)),
          Expanded(flex: 2, child: Text(p.hasHot ? p.hotPrice.toStringAsFixed(2) : '-')),
          Expanded(flex: 2, child: Text(p.coldPrice.toStringAsFixed(2))),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.orange),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                  onPressed: () => _onEdit(p),
                  child: const Icon(Icons.edit, color: Colors.orange, size: 18),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.orange),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                  onPressed: () => _onView(p),
                  child: const Icon(Icons.visibility, color: Colors.orange, size: 18),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _onEdit(ProductItem p) {
    context.go(AppRoutes.addProduct, extra: {'editProductId': p.id});
  }

  void _onView(ProductItem p) {
    context.go(AppRoutes.addProduct, extra: {'editProductId': p.id, 'readOnly': true});
  }

  InputDecoration _pmInputDecoration() {
    return InputDecoration(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      filled: true,
      fillColor: Colors.white,
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.orange)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.orange)),
    );
  }

  Widget _pmLabel(String text) {
    return Text(text, style: const TextStyle(fontSize: 18, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis, softWrap: false);
  }

  void _showViewDialog(ProductItem p) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFF6EDDF),
          title: const Text('Product Details', style: TextStyle(color: Colors.black)),
          content: SizedBox(
            width: 900,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 1,
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Container(
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.black87, width: 1.2)),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: p.imageUrl != null && p.imageUrl!.isNotEmpty
                              ? Image.network(p.imageUrl!, fit: BoxFit.cover)
                              : const Icon(Icons.image, size: 30, color: Colors.grey),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(children: [SizedBox(width: 180, child: _pmLabel('Name')), Expanded(child: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18)))]),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(children: [SizedBox(width: 180, child: _pmLabel('Category')), Expanded(child: Text(p.category, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18)))]),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(children: [SizedBox(width: 180, child: _pmLabel('Ingredient Required')), Expanded(child: Text('${p.ingredientNames.length}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18)))]),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(children: [SizedBox(width: 180, child: _pmLabel('Hot Price (RM)')), Expanded(child: Text(p.hotPrice.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18)))]),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(children: [SizedBox(width: 180, child: _pmLabel('Cold Price (RM)')), Expanded(child: Text(p.coldPrice.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18)))]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          ],
        );
      },
    );
  }

  void _showEditDialog(ProductItem p) {
    final nameCtrl = TextEditingController(text: p.name);
    final categoryCtrl = TextEditingController(text: p.category);
    final hotCtrl = TextEditingController(text: p.hotPrice == 0.0 ? '' : p.hotPrice.toStringAsFixed(2));
    final coldCtrl = TextEditingController(text: p.coldPrice.toStringAsFixed(2));
    String selectedCategory = p.category;
    final Set<String> iceSel = p.optionsIce.entries.where((e) => e.value).map((e) => e.key).toSet();
    final Set<String> sugarSel = p.optionsSugar.entries.where((e) => e.value).map((e) => e.key).toSet();
    final Set<String> textureSel = p.optionsTexture.entries.where((e) => e.value).map((e) => e.key).toSet();
    final List<String> ingredientNames = List<String>.from(p.ingredientNames);
    final List<Map<String, dynamic>> extras = p.extras.entries.map((e) {
      final price = (e.value is Map && (e.value as Map)['price'] is num) ? ((e.value as Map)['price'] as num).toDouble() : 0.0;
      return {'label': e.key, 'price': price};
    }).toList();
    final extraLabelCtrl = TextEditingController();
    final extraPriceCtrl = TextEditingController();
    String? nameErr;
    String? categoryErr;
    String? ingredientErr;
    String? hotErr;
    String? coldErr;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setLocal) {
          return AlertDialog(
            backgroundColor: const Color(0xFFF6EDDF),
            title: const Text('Edit Product', style: TextStyle(color: Colors.black)),
            content: SizedBox(
              width: 900,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 1,
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: Container(
                          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.black87, width: 1.2)),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: p.imageUrl != null && p.imageUrl!.isNotEmpty
                                ? Image.network(p.imageUrl!, fit: BoxFit.cover)
                                : const Icon(Icons.image, size: 30, color: Colors.grey),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    flex: 2,
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(children: [SizedBox(width: 180, child: _pmLabel('Name')), Expanded(child: TextField(controller: nameCtrl, decoration: _pmInputDecoration().copyWith(errorText: nameErr), onChanged: (_) => setLocal(() => nameErr = null)))]),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(children: [
                            SizedBox(width: 180, child: _pmLabel('Category')),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.orange), color: Colors.white),
                                child: Row(children: [
                                  Expanded(child: Text(selectedCategory.isEmpty ? 'Select' : selectedCategory, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18))),
                                  InkWell(onTap: () {
                                    final items = _categories.where((e) => e != 'All Category').toList();
                                    showDialog(context: context, builder: (ctx) {
                                      return SimpleDialog(children: items.map((e) => SimpleDialogOption(onPressed: () { Navigator.pop(ctx); setLocal(() { selectedCategory = e; categoryErr = null; }); }, child: Text(e))).toList());
                                    });
                                  }, child: const Icon(Icons.arrow_drop_down, color: Colors.orange)),
                                ]),
                              ),
                            ),
                          ]),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(children: [SizedBox(width: 180, child: _pmLabel('Ice Level')), Expanded(child: Wrap(spacing: 8, runSpacing: 8, children: ['NO ICE', 'LESS ICE', 'NORMAL ICE'].map((o) { final sel = iceSel.contains(o); return InkWell(onTap: () => setLocal(() { if (sel) iceSel.remove(o); else iceSel.add(o); }), child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: sel ? Colors.orange[600] : Colors.orange[50], border: Border.all(color: Colors.orange), borderRadius: BorderRadius.circular(20)), child: Text(o, style: TextStyle(color: sel ? Colors.white : (Colors.orange[700] ?? Colors.orange), fontWeight: FontWeight.w700)))); }).toList()))]),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(children: [SizedBox(width: 180, child: _pmLabel('Sugar Level')), Expanded(child: Wrap(spacing: 8, runSpacing: 8, children: ['NO SUGAR', 'LESS SUGAR', 'NORMAL SUGAR'].map((o) { final sel = sugarSel.contains(o); return InkWell(onTap: () => setLocal(() { if (sel) sugarSel.remove(o); else sugarSel.add(o); }), child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: sel ? Colors.orange[600] : Colors.orange[50], border: Border.all(color: Colors.orange), borderRadius: BorderRadius.circular(20)), child: Text(o, style: TextStyle(color: sel ? Colors.white : (Colors.orange[700] ?? Colors.orange), fontWeight: FontWeight.w700)))); }).toList()))]),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(children: [SizedBox(width: 180, child: _pmLabel('Texture')), Expanded(child: Wrap(spacing: 8, runSpacing: 8, children: ['SMOOTH', 'CREAMY', 'THICK'].map((o) { final sel = textureSel.contains(o); return InkWell(onTap: () => setLocal(() { if (sel) textureSel.remove(o); else textureSel.add(o); }), child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: sel ? Colors.orange[600] : Colors.orange[50], border: Border.all(color: Colors.orange), borderRadius: BorderRadius.circular(20)), child: Text(o, style: TextStyle(color: sel ? Colors.white : (Colors.orange[700] ?? Colors.orange), fontWeight: FontWeight.w700)))); }).toList()))]),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(children: [SizedBox(width: 180, child: _pmLabel('Ingredient Names')), Expanded(child: Wrap(spacing: 8, runSpacing: 8, children: [
                            ...ingredientNames.asMap().entries.map((e) => Chip(label: Text(e.value), onDeleted: () => setLocal(() { ingredientNames.removeAt(e.key); }), deleteIconColor: Colors.orange[800], backgroundColor: Colors.orange[50], shape: const StadiumBorder(side: BorderSide(color: Colors.transparent)))),
                            InkWell(onTap: () async {
                              final snap = await FirebaseFirestore.instance.collection('ingredients').get();
                              final items = snap.docs.map((d) => (d.data()['name'] ?? d.data()['ingredientName'] ?? '').toString()).where((v) => v.isNotEmpty).toList();
                              final picked = await showDialog<String>(context: context, builder: (ctx) {
                                return SimpleDialog(children: items.map((e) => SimpleDialogOption(onPressed: () => Navigator.pop(ctx, e), child: Text(e))).toList());
                              });
                              if (picked != null && picked.isNotEmpty) setLocal(() => ingredientNames.add(picked));
                            }, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text('ADD', style: TextStyle(color: Colors.orange[700] ?? Colors.orange, fontWeight: FontWeight.w700))))
                          ]))]),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              SizedBox(width: 180, child: _pmLabel('Extra Requirement')),
                              Expanded(
                                child: Row(
                                  children: [
                                    Expanded(child: TextField(controller: extraLabelCtrl, decoration: _pmInputDecoration())),
                                    const SizedBox(width: 8),
                                    SizedBox(
                                      width: 160,
                                      child: TextField(
                                        controller: extraPriceCtrl,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                                        decoration: _pmInputDecoration().copyWith(prefix: const Padding(padding: EdgeInsets.only(left: 8, right: 6), child: Text('RM ', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18))))
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton(
                                      onPressed: () {
                                        final label = extraLabelCtrl.text.trim();
                                        final price = double.tryParse(extraPriceCtrl.text.trim()) ?? 0.0;
                                        if (label.isEmpty || price <= 0) return;
                                        setLocal(() {
                                          extras.add({'label': label, 'price': price});
                                          extraLabelCtrl.clear();
                                          extraPriceCtrl.clear();
                                        });
                                      },
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[600], foregroundColor: Colors.white),
                                      child: const Text('Add'),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (extras.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(children: [SizedBox(width: 180, child: const SizedBox.shrink()), Expanded(child: Wrap(spacing: 8, runSpacing: 8, children: extras.asMap().entries.map((e) => Chip(label: Text('${e.value['label']} (RM ${(e.value['price'] as num).toStringAsFixed(2)})', style: TextStyle(color: Colors.orange[800])), onDeleted: () => setLocal(() { extras.removeAt(e.key); }), deleteIconColor: Colors.orange[800], backgroundColor: Colors.orange[50], shape: const StadiumBorder(side: BorderSide(color: Colors.transparent)))).toList()))]),
                          ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(children: [SizedBox(width: 180, child: _pmLabel('Hot Price (RM)')), Expanded(child: TextField(controller: hotCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.-]'))], decoration: _pmInputDecoration().copyWith(errorText: hotErr, prefix: const Padding(padding: EdgeInsets.only(left: 8, right: 6), child: Text('RM ', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18)))), onChanged: (_) => setLocal(() => hotErr = null)))]),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(children: [SizedBox(width: 180, child: _pmLabel('Cold Price (RM)')), Expanded(child: TextField(controller: coldCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))], decoration: _pmInputDecoration().copyWith(errorText: coldErr, prefix: const Padding(padding: EdgeInsets.only(left: 8, right: 6), child: Text('RM ', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18)))), onChanged: (_) => setLocal(() => coldErr = null)))]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  final name = nameCtrl.text.trim();
                  final category = selectedCategory.trim().isNotEmpty ? selectedCategory.trim() : categoryCtrl.text.trim();
                  final hotText = hotCtrl.text.trim();
                  final coldText = coldCtrl.text.trim();
                  setLocal(() {
                    nameErr = name.isEmpty ? 'Required' : null;
                    categoryErr = category.isEmpty ? 'Required' : null;
                    final hotVal = double.tryParse(hotText);
                    hotErr = (hotText == '-' || (hotVal != null && hotVal > 0)) ? null : 'Required';
                    final coldVal = double.tryParse(coldText);
                    coldErr = (coldVal == null || coldVal <= 0) ? 'Required' : null;
                  });
                  if ([nameErr, categoryErr, hotErr, coldErr].any((e) => e != null)) return;
                  try {
                    DocumentReference<Map<String, dynamic>>? categoryRef;
                    try {
                      final catQuery = await FirebaseFirestore.instance.collection('productCategories').where('name', isEqualTo: category).limit(1).get();
                      if (catQuery.docs.isEmpty) {
                        final cdoc = FirebaseFirestore.instance.collection('productCategories').doc();
                        await cdoc.set({'id': cdoc.id, 'name': category, 'createdAt': FieldValue.serverTimestamp()});
                        categoryRef = cdoc;
                      } else {
                        categoryRef = catQuery.docs.first.reference;
                      }
                    } catch (_) {}
                    await FirebaseFirestore.instance.collection('products').doc(p.id).update({
                      'name': name,
                      'category': categoryRef,
                      'categoryName': category,
                      'hotPrice': hotText == '-' ? null : double.tryParse(hotText) ?? 0.0,
                      'coldPrice': double.tryParse(coldText) ?? 0.0,
                      'options': {
                        'ice': {for (final o in ['NO ICE', 'LESS ICE', 'NORMAL ICE']) o: iceSel.contains(o)},
                        'sugar': {for (final o in ['NO SUGAR', 'LESS SUGAR', 'NORMAL SUGAR']) o: sugarSel.contains(o)},
                        'texture': {for (final o in ['SMOOTH', 'CREAMY', 'THICK']) o: textureSel.contains(o)},
                      },
                      'ingredientNames': ingredientNames,
                      'extras': {for (final e in extras) (e['label'] as String): {'price': (e['price'] as num).toDouble()}},
                    });
                    try {
                      final exists = await FirebaseFirestore.instance.collection('productCategories').where('name', isEqualTo: category).limit(1).get();
                      if (exists.docs.isEmpty) {
                        final cdoc = FirebaseFirestore.instance.collection('productCategories').doc();
                        await cdoc.set({'id': cdoc.id, 'name': category, 'createdAt': FieldValue.serverTimestamp()});
                      }
                    } catch (_) {}
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product updated')));
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update: $e')));
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC711F), foregroundColor: Colors.white),
                child: const Text('Save'),
              ),
            ],
          );
        });
      },
    );
  }

  void _onAddProduct() {
    context.go(AppRoutes.addProduct);
  }

  // Pagination helpers
  List<ProductItem> _paginate(List<ProductItem> input) {
    final start = (_currentPage - 1) * _pageSize;
    final end = math.min(start + _pageSize, input.length);
    if (start >= input.length) return [];
    return input.sublist(start, end);
  }

  Widget _buildPageButton(int page) {
    final isActive = _currentPage == page;
    return InkWell(
      onTap: () => setState(() => _currentPage = page),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? Colors.orange[600] : Colors.orange[50],
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text('$page', style: TextStyle(color: isActive ? Colors.white : Colors.black)),
      ),
    );
  }

  // Custom Category filter similar to Staff Management
  Widget _buildCategoryFilter() {
    final labelStyle = Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: 16, fontWeight: FontWeight.w600);
    final isDarkClosed = _selectedCategory != 'All Category';
    final closedBg = _selectedCategory == 'All Category' ? Colors.orange[50] : Colors.orange[600];
    final countLabel = ' (${_countForCategory(_selectedCategory)})';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Category', style: labelStyle ?? const TextStyle(fontSize: 12, color: Colors.orange)),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: _showCategoryMenu,
          child: CompositedTransformTarget(
            link: _categoryLink,
            child: Container(
              key: _categoryFilterKey,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: closedBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '$_selectedCategory$countLabel',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      style: TextStyle(
                        color: isDarkClosed ? Colors.white : (Colors.orange[700] ?? Colors.orange),
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Arial',
                      ),
                    ),
                  ),
                  Icon(Icons.arrow_drop_down, color: Colors.orange[700] ?? Colors.orange),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showCategoryMenu() {
    _hideCategoryMenu();

    final ctx = _categoryFilterKey.currentContext;
    if (ctx == null) return;
    final renderObject = ctx.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return;
    final renderBox = renderObject as RenderBox;
    final size = renderBox.size;

    final items = _categories;

    _categoryMenuOverlay = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            Positioned.fill(child: GestureDetector(behavior: HitTestBehavior.translucent, onTap: _hideCategoryMenu)),
            CompositedTransformFollower(
              link: _categoryLink,
              showWhenUnlinked: false,
              offset: Offset(0, size.height + 4),
              child: SizedBox(
                width: math.max(size.width, 1),
                child: Material(
                  elevation: 6,
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: items.map((e) {
                      final isSelected = e == _selectedCategory;
                      final rowColor = isSelected ? Colors.orange[600] : Colors.orange[50];
                      final textColor = isSelected ? Colors.white : (Colors.orange[700] ?? Colors.orange);
                      final countLabel = ' (${_countForCategory(e)})';
                      return InkWell(
                        onTap: () {
                          setState(() => _selectedCategory = e);
                          _hideCategoryMenu();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: rowColor,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange),
                          ),
                          child: Text(
                            '$e$countLabel',
                            style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Arial',
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    Overlay.of(context, rootOverlay: true).insert(_categoryMenuOverlay!);
  }

  void _hideCategoryMenu() {
    _categoryMenuOverlay?.remove();
    _categoryMenuOverlay = null;
  }

  int _countForCategory(String label) {
    if (label == 'All Category') return _products.length;
    return _products.where((p) => p.category == label).length;
  }

  // Apply filters: close menu and unfocus inputs
  void _applyFilters() {
    if (_isApplying) return;
    setState(() {
      _isApplying = true;
    });
    _hideCategoryMenu();
    FocusScope.of(context).unfocus();
    // Reset pagination and rebuild
    setState(() {
      _currentPage = 1;
    });
    Future.delayed(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      setState(() {
        _isApplying = false;
      });
    });
  }

  // Clear filters: reset category and search
  void _clearFilters() {
    setState(() {
      _selectedCategory = 'All Category';
      _searchQuery = '';
      _currentPage = 1;
    });
    _hideCategoryMenu();
    FocusScope.of(context).unfocus();
  }
}