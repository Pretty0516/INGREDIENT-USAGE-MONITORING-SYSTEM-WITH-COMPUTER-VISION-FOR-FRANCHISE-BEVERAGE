import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../widgets/app_shell.dart';
import '../providers/auth_provider.dart';

class IngredientItem {
  final String id;
  final String name;
  final String category;
  final String unit;
  final double stockQuantity;
  final double amountPerUnit;
  final String? imageUrl;

  IngredientItem({
    required this.id,
    required this.name,
    required this.category,
    required this.unit,
    required this.stockQuantity,
    required this.amountPerUnit,
    this.imageUrl,
  });

  factory IngredientItem.fromMap(String id, Map<String, dynamic> m) {
    double _toD(v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0.0;
      return 0.0;
    }

    return IngredientItem(
      id: id,
      name: (m['name'] ?? m['ingredientName'] ?? 'Unnamed') as String,
      category: (m['category'] ?? 'Uncategorized') as String,
      unit: (m['unit'] ?? m['uom'] ?? 'unit') as String,
      stockQuantity: _toD(m['stockQuantity'] ?? m['stock'] ?? 0.0),
      amountPerUnit: _toD(m['amountPerUnit'] ?? m['amount'] ?? 0.0),
      imageUrl: m['imageUrl'] as String?,
    );
  }
}

class IngredientManagementScreen extends StatefulWidget {
  const IngredientManagementScreen({super.key});

  @override
  State<IngredientManagementScreen> createState() => _IngredientManagementScreenState();
}

class _IngredientManagementScreenState extends State<IngredientManagementScreen> {
  final List<IngredientItem> _ingredients = [];
  String _searchQuery = '';
  String _selectedCategory = 'All Category';
  bool _loading = false;
  bool _isApplying = false;
  bool _seeding = false;
  int _currentPage = 1;
  int _pageSize = 8;

  // Custom dropdown infra for Category filter
  final GlobalKey _categoryFilterKey = GlobalKey();
  OverlayEntry? _categoryMenuOverlay;
  final LayerLink _categoryLink = LayerLink();

  @override
  void initState() {
    super.initState();
    _loadIngredients();
  }

  Future<void> _seedDemoIngredients() async {
    if (_seeding) return;
    setState(() => _seeding = true);
    try {
      final authProvider = context.read<AuthProvider>();
      final fid = authProvider.currentUser?.franchiseId;
      CollectionReference<Map<String, dynamic>> col;
      if (fid != null && fid.isNotEmpty) {
        col = FirebaseFirestore.instance
            .collection('franchises')
            .doc(fid)
            .collection('ingredients');
      } else {
        col = FirebaseFirestore.instance.collection('ingredients');
      }

      final demo = [
        {
          'id': 'i1',
          'name': 'Sugar',
          'category': 'Basic',
          'unit': 'g',
          'stockQuantity': 10000,
          'amountPerUnit': 10,
          'imageUrl': null,
        },
        {
          'id': 'i2',
          'name': 'Coffee Powder',
          'category': 'Coffee',
          'unit': 'g',
          'stockQuantity': 5000,
          'amountPerUnit': 10,
          'imageUrl': null,
        },
        {
          'id': 'i3',
          'name': 'Condensed Milk',
          'category': 'Dairy',
          'unit': 'ml',
          'stockQuantity': 8000,
          'amountPerUnit': 30,
          'imageUrl': null,
        },
        {
          'id': 'i4',
          'name': 'Evaporated Milk',
          'category': 'Dairy',
          'unit': 'ml',
          'stockQuantity': 7000,
          'amountPerUnit': 30,
          'imageUrl': null,
        },
      ];

      for (final m in demo) {
        final id = m['id'] as String;
        final data = Map<String, dynamic>.from(m)..remove('id');
        await col.doc(id).set(data, SetOptions(merge: true));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Seeded demo ingredients to Firestore')),
        );
      }
      await _loadIngredients();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to seed ingredients: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _seeding = false);
    }
  }

  Future<void> _loadIngredients() async {
    setState(() => _loading = true);
    try {
      final authProvider = context.read<AuthProvider>();
      final fid = authProvider.currentUser?.franchiseId;
      Query<Map<String, dynamic>> query;
      if (fid != null && fid.isNotEmpty) {
        query = FirebaseFirestore.instance
            .collection('franchises')
            .doc(fid)
            .collection('ingredients')
            .orderBy('name');
      } else {
        query = FirebaseFirestore.instance
            .collection('ingredients')
            .orderBy('name');
      }

      final snap = await query.get();
      final items = snap.docs.map((d) => IngredientItem.fromMap(d.id, d.data())).toList();

      setState(() {
        _ingredients
          ..clear()
          ..addAll(items);
      });
    } catch (e) {
      // Demo data fallback
      setState(() {
        _ingredients
          ..clear()
          ..addAll([
            IngredientItem(id: 'i1', name: 'Sugar', category: 'Basic', unit: 'g', stockQuantity: 10000, amountPerUnit: 10, imageUrl: null),
            IngredientItem(id: 'i2', name: 'Coffee Powder', category: 'Coffee', unit: 'g', stockQuantity: 5000, amountPerUnit: 10, imageUrl: null),
            IngredientItem(id: 'i3', name: 'Condensed Milk', category: 'Dairy', unit: 'ml', stockQuantity: 8000, amountPerUnit: 30, imageUrl: null),
            IngredientItem(id: 'i4', name: 'Evaporated Milk', category: 'Dairy', unit: 'ml', stockQuantity: 7000, amountPerUnit: 30, imageUrl: null),
          ]);
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  List<String> get _categories {
    final set = <String>{};
    for (final i in _ingredients) {
      set.add(i.category);
    }
    final list = set.toList()..sort();
    return ['All Category', ...list];
  }

  List<IngredientItem> _filtered() {
    Iterable<IngredientItem> list = _ingredients;
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((i) => i.name.toLowerCase().contains(q));
    }
    if (_selectedCategory != 'All Category') {
      list = list.where((i) => i.category == _selectedCategory);
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
      activeItem: 'Ingredient',
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
                              Icon(Icons.kitchen, color: Colors.green[600], size: 28),
                              const SizedBox(width: 12),
                              Text(
                                'Ingredients',
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
                  else ...displayed.map(_buildIngredientRow),
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
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search Ingredient Name',
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
                  onPressed: _onAddIngredient,
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
                      Text('ADD INGREDIENT', style: TextStyle(letterSpacing: 0.5)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: _seeding ? null : _seedDemoIngredients,
                  icon: const Icon(Icons.cloud_upload, size: 20, color: Colors.orange),
                  label: Text(_seeding ? 'SEEDING...' : 'SEED DEMO INGREDIENTS'),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.orange),
                    foregroundColor: Colors.orange,
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
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
              Expanded(flex: 3, child: Text('Ingredient Name', style: TextStyle(color: Colors.grey))),
              Expanded(flex: 2, child: Text('Stock Qty', style: TextStyle(color: Colors.grey))),
              Expanded(flex: 2, child: Text('Category', style: TextStyle(color: Colors.grey))),
              Expanded(flex: 2, child: Text('Amount Per Unit', style: TextStyle(color: Colors.grey))),
              Expanded(flex: 2, child: Text('Unit', style: TextStyle(color: Colors.grey))),
              Expanded(flex: 2, child: Text('Action', style: TextStyle(color: Colors.grey))),
            ],
          ),
        ),
        Divider(),
      ],
    );
  }

  Widget _buildIngredientRow(IngredientItem i) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.grey.shade200,
                  backgroundImage: i.imageUrl != null && i.imageUrl!.isNotEmpty
                      ? NetworkImage(i.imageUrl!)
                      : const AssetImage('assets/images/ingredient_icon.png') as ImageProvider,
                ),
                const SizedBox(width: 12),
                Flexible(child: Text(i.name, overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
          Expanded(flex: 2, child: Text(i.stockQuantity.toStringAsFixed(0))),
          Expanded(flex: 2, child: Text(i.category)),
          Expanded(flex: 2, child: Text(i.amountPerUnit.toStringAsFixed(0))),
          Expanded(flex: 2, child: Text(i.unit)),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.orange),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                  onPressed: () => _onEdit(i),
                  child: const Icon(Icons.edit, color: Colors.orange, size: 18),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.orange),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                  onPressed: () => _onView(i),
                  child: const Icon(Icons.visibility, color: Colors.orange, size: 18),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _onEdit(IngredientItem i) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Edit ${i.name} coming soon')),
    );
  }

  void _onView(IngredientItem i) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('View ${i.name} coming soon')),
    );
  }

  void _onAddIngredient() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Add Ingredient flow coming soon')),
    );
  }

  // Pagination helpers
  List<IngredientItem> _paginate(List<IngredientItem> input) {
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

  // Category filter UI and overlay
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
    if (label == 'All Category') return _ingredients.length;
    return _ingredients.where((i) => i.category == label).length;
  }

  void _applyFilters() {
    if (_isApplying) return;
    setState(() {
      _isApplying = true;
    });
    _hideCategoryMenu();
    FocusScope.of(context).unfocus();
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