// lib/screens/inventory_screen.dart
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../widgets/app_shell.dart';
import '../providers/auth_provider.dart';
import '../routes/app_routes.dart';

class InventoryItem {
  final String id;
  final String name;
  final String category;
  final String unit;
  final double stockQuantity;
  final double thresholdQuantity;
  final double restockQuantity;
  final String supplierName;
  final String supplierContact;
  final String? imageUrl;

  InventoryItem({
    required this.id,
    required this.name,
    required this.category,
    required this.unit,
    required this.stockQuantity,
    required this.thresholdQuantity,
    required this.restockQuantity,
    required this.supplierName,
    required this.supplierContact,
    this.imageUrl,
  });

  factory InventoryItem.fromMap(String id, Map<String, dynamic> m) {
    double _toD(v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0.0;
      return 0.0;
    }

    final img = (m['imageUrl'] ?? '').toString();
    return InventoryItem(
      id: id,
      name: (m['name'] ?? '').toString(),
      category: (m['category'] ?? 'Uncategorized').toString(),
      unit: (m['unit'] ?? '').toString(),
      stockQuantity: _toD(m['stockQuantity'] ?? 0),
      thresholdQuantity: _toD(m['thresholdQuantity'] ?? 0),
      restockQuantity: _toD(m['restockQuantity'] ?? 0),
      supplierName: (m['supplierName'] ?? '').toString(),
      supplierContact: (m['supplierContact'] ?? '').toString(),
      imageUrl: img.isEmpty ? null : img,
    );
  }
}

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});
  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final List<InventoryItem> _items = [];
  final Map<String, bool> _checklist = {};
  String _searchQuery = '';
  String _selectedCategory = 'All (0)';
  String _selectedUrgency = 'Urgent (0)';
  List<String> _categories = const ['All (0)'];
  bool _loading = false;
  bool _isApplying = false;
  final GlobalKey _categoryFilterKey = GlobalKey();
  final GlobalKey _urgencyFilterKey = GlobalKey();
  final LayerLink _categoryLink = LayerLink();
  final LayerLink _urgencyLink = LayerLink();
  OverlayEntry? _categoryMenuOverlay;
  OverlayEntry? _urgencyMenuOverlay;
  int _restockCurrentPage = 1;
  final int _restockPageSize = 3;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final snap = await FirebaseFirestore.instance.collection('ingredients').orderBy('name').get();
      final items = snap.docs.map((d) => InventoryItem.fromMap(d.id, d.data())).toList();
      setState(() {
        _items..clear()..addAll(items);
        _categories = _computeCategories(items);
        _selectedCategory = 'All (${items.length})';
        _selectedUrgency = 'Urgent (${_urgentCount(items)})';
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  List<String> _computeCategories(List<InventoryItem> items) {
    final set = <String>{};
    for (final i in items) {
      if (i.category.trim().isNotEmpty) set.add(i.category.trim());
    }
    final list = set.toList()..sort();
    return ['All (${items.length})', ...list.map((c) => '$c (${items.where((i) => i.category == c).length})')];
  }

  String _urgency(InventoryItem i) {
    final tq = i.thresholdQuantity;
    if (tq <= 0) return 'Scheduled';
    if (i.stockQuantity <= math.max(1, tq / 2)) return 'Emergency';
    if (i.stockQuantity <= tq) return 'Urgent';
    return 'Scheduled';
  }

  int _urgentCount(List<InventoryItem> items) => items.where((i) => _urgency(i) != 'Scheduled').length;

  List<InventoryItem> _filtered() {
    Iterable<InventoryItem> list = _items;
    final q = _searchQuery.trim().toLowerCase();
    if (q.isNotEmpty) list = list.where((i) => i.name.toLowerCase().contains(q));
    if (!_selectedCategory.startsWith('All')) {
      final cat = _selectedCategory.split('(').first.trim();
      list = list.where((i) => i.category == cat);
    }
    if (_selectedUrgency.startsWith('Urgent')) list = list.where((i) => _urgency(i) != 'Scheduled');
    return list.toList();
  }

  void _openSpoilageReport() async {
    final auth = context.read<AuthProvider>();
    final franchiseId = auth.currentUser?.franchiseId;
    final staffId = auth.currentUser?.id;
    final items = _items;
    InventoryItem? selected = items.isNotEmpty ? items.first : null;
    final qtyCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFF6EDDF),
          title: const Text('Report Spoilage'),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<InventoryItem>(
                  value: selected,
                  items: items.map((i) => DropdownMenuItem(value: i, child: Text(i.name))).toList(),
                  onChanged: (v) => selected = v,
                  decoration: const InputDecoration(labelText: 'Ingredient'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: qtyCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Quantity spoiled'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: reasonCtrl,
                  decoration: const InputDecoration(labelText: 'Reason'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: noteCtrl,
                  decoration: const InputDecoration(labelText: 'Notes'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC711F), foregroundColor: Colors.white),
              onPressed: () async {
                final s = selected;
                final qty = double.tryParse(qtyCtrl.text.trim()) ?? 0;
                if (s == null || qty <= 0) return;
                try {
                  await FirebaseFirestore.instance.collection('spoilage_reports').add({
                    'ingredientId': s.id,
                    'ingredientName': s.name,
                    'unit': s.unit,
                    'quantity': qty,
                    'reason': reasonCtrl.text.trim(),
                    'notes': noteCtrl.text.trim(),
                    'franchiseId': franchiseId,
                    'staffId': staffId,
                    'createdAt': FieldValue.serverTimestamp(),
                  });
                  await FirebaseFirestore.instance.collection('ingredients').doc(s.id).update({
                    'stockQuantity': math.max(0, s.stockQuantity - qty),
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Spoilage reported')));
                  _loadData();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
                }
              },
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );
  }

  Widget _statusPill(String status) {
    Color bg;
    Color dot;
    switch (status) {
      case 'Emergency':
        bg = Colors.red.shade50;
        dot = Colors.red;
        break;
      case 'Urgent':
        bg = Colors.orange.shade50;
        dot = Colors.orange;
        break;
      default:
        bg = Colors.green.shade50;
        dot = Colors.green;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, border: Border.all(color: dot), borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(status, style: TextStyle(color: dot, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered();
    return AppShell(
      activeItem: 'Inventory',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(24)),
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: 'Search',
                        prefixIcon: Icon(Icons.search),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                      ),
                      onChanged: (v) => setState(() => _searchQuery = v.trim()),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 160,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stock In – coming soon')));
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC711F), foregroundColor: Colors.white),
                    child: const Text('STOCK IN'),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 160,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: _showPacketFinishedDialog,
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC711F), foregroundColor: Colors.white),
                    child: const Text('STOCK OUT'),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 160,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: () => context.go(AppRoutes.spoilageReport),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC711F), foregroundColor: Colors.white),
                    child: const Text('REPORT'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 900;
                if (isWide) {
                  return Row(
                    children: [
                      Expanded(child: _promotionPanel()),
                      const SizedBox(width: 12),
                      Expanded(child: _restockPanel()),
                    ],
                  );
                }
                return Column(
                  children: [
                    _promotionPanel(),
                    const SizedBox(height: 12),
                    _restockPanel(),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCategoryFilter(),
                const SizedBox(width: 8),
                _buildUrgencyFilter(),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: SizedBox(
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
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: SizedBox(
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
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 8, offset: const Offset(0, 2))]),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                    child: Row(
                      children: [
                        const Expanded(child: Text('Ingredient Name', style: TextStyle(color: Colors.grey))),
                        SizedBox(width: 120, child: Center(child: Text('Quantity Restock', style: const TextStyle(color: Colors.grey)))),
                        SizedBox(width: 80, child: Center(child: Text('Stock Left', style: const TextStyle(color: Colors.grey)))),
                        SizedBox(width: 160, child: Center(child: Text('Urgency', style: const TextStyle(color: Colors.grey)))),
                        SizedBox(width: 60, child: Center(child: Text('Checklist', style: const TextStyle(color: Colors.grey)))),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  ...list.map((i) {
                    final status = _urgency(i);
                    final checked = _checklist[i.id] ?? false;
                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 50,
                                height: 50,
                                child: i.imageUrl != null && i.imageUrl!.isNotEmpty
                                    ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(i.imageUrl!, fit: BoxFit.cover))
                                    : Container(decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8))),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(i.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 2),
                                    Text('${i.supplierName}\n${i.supplierContact}', style: const TextStyle(color: Colors.grey)),
                                  ],
                                ),
                              ),
                              SizedBox(width: 120, child: Center(child: Text('${i.restockQuantity.toInt()}', style: const TextStyle(fontWeight: FontWeight.w700)))),
                              SizedBox(width: 80, child: Center(child: Text('${i.stockQuantity.toInt()}'))),
                              SizedBox(width: 160, child: Center(child: _statusPill(status))),
                              SizedBox(
                                width: 60,
                                child: Center(
                                  child: InkWell(
                                    onTap: () => setState(() => _checklist[i.id] = !checked),
                                    child: Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        border: Border.all(color: const Color(0xFFDC711F)),
                                        borderRadius: BorderRadius.circular(6),
                                        color: checked ? const Color(0xFFDC711F) : Colors.transparent,
                                      ),
                                      child: checked ? const Icon(Icons.check, size: 18, color: Colors.white) : null,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                      ],
                    );
                  }).toList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _panelShell({required String title, required List<List<String>> rows}) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 8, offset: const Offset(0, 2))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          ...rows.map((r) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0),
                child: Row(children: r.map((c) => Expanded(child: Text(c))).toList()),
              )),
        ],
      ),
    );
  }

  Widget _promotionPanel() {
    final items = [
      {'product': 'Carrot Juice', 'ingredient': 'Carrot', 'reason': 'Due to low usage', 'offer': '10% deduction of price'},
      {'product': 'Mocha', 'ingredient': 'Mocha powder', 'reason': 'Nearly expired', 'offer': '10% deduction of price'},
    ];
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 8, offset: const Offset(0, 2))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('SUGGESTED PROMOTION', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 700),
              child: Column(
                children: [
                  Row(
                    children: const [
                      SizedBox(width: 200, child: Text('Product Name')),
                      SizedBox(width: 140, child: Center(child: Text('Ingredient'))),
                      SizedBox(width: 220, child: Center(child: Text('Reason'))),
                      SizedBox(width: 200, child: Center(child: Text('Offer'))),
                      SizedBox(width: 80, child: Center(child: Text('Action'))),
                    ],
                  ),
                  const Divider(height: 1),
                  ...items.map((r) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0),
                        child: Row(
                          children: [
                            SizedBox(width: 200, child: Text(r['product']!)),
                            SizedBox(width: 140, child: Center(child: Text(r['ingredient']!))),
                            SizedBox(width: 220, child: Center(child: Text(r['reason']!))),
                            SizedBox(width: 200, child: Center(child: Text(r['offer']!))),
                            const SizedBox(width: 80, child: Center(child: Icon(Icons.check, color: Colors.green))),
                          ],
                        ),
                      )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _restockPanel() {
    final candidates = _items.where((i) => _urgency(i) != 'Scheduled').toList();
    final totalPages = ((candidates.length + _restockPageSize - 1) ~/ _restockPageSize).clamp(1, 9999);
    final start = (_restockCurrentPage - 1) * _restockPageSize;
    final end = math.min(start + _restockPageSize, candidates.length);
    final displayed = start >= candidates.length ? <InventoryItem>[] : candidates.sublist(start, end);

    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 8, offset: const Offset(0, 2))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: Text('SUGGESTED RESTOCK QUANTITY', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
              if (totalPages > 1)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(totalPages, (i) {
                      final page = i + 1;
                      final isActive = _restockCurrentPage == page;
                      return Row(
                        children: [
                          if (i != 0) const SizedBox(width: 6),
                          InkWell(
                            onTap: () => setState(() => _restockCurrentPage = page),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: isActive ? Colors.orange[600] : Colors.orange[50],
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text('$page', style: TextStyle(color: isActive ? Colors.white : Colors.black)),
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 700),
              child: Column(
                children: [
                  Row(
                    children: const [
                      SizedBox(width: 200, child: Center(child: Text('Ingredient'))),
                      SizedBox(width: 120, child: Center(child: Text('Reason'))),
                      SizedBox(width: 100, child: Center(child: Text('Current'))),
                      SizedBox(width: 120, child: Center(child: Text('Suggested'))),
                      SizedBox(width: 80, child: Center(child: Text('Action'))),
                    ],
                  ),
                  const Divider(height: 1),
                  ...displayed.map((i) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0),
                        child: Row(
                          children: [
                            SizedBox(width: 200, child: Text(i.name)),
                            SizedBox(width: 120, child: Center(child: Text(_urgency(i) == 'Emergency' ? 'Very low stock' : 'Low stock'))),
                            SizedBox(width: 100, child: Center(child: Text(i.stockQuantity.toInt().toString()))),
                            SizedBox(width: 120, child: Center(child: Text(i.restockQuantity.toInt().toString()))),
                            const SizedBox(width: 80, child: Center(child: Icon(Icons.check, color: Colors.green))),
                          ],
                        ),
                      )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter() {
    final closedBg = const Color(0xFFF6EDDF);
    final isDarkClosed = false;
    final labelStyle = Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: 16, fontWeight: FontWeight.w600);
    return Expanded(
      child: Column(
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
                decoration: BoxDecoration(color: closedBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.orange)),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _selectedCategory,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                        style: TextStyle(color: isDarkClosed ? Colors.white : (Colors.orange[700] ?? Colors.orange), fontWeight: FontWeight.w600, fontFamily: 'Arial'),
                      ),
                    ),
                    Icon(Icons.arrow_drop_down, color: Colors.orange[700] ?? Colors.orange),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUrgencyFilter() {
    final closedBg = const Color(0xFFF6EDDF);
    final labelStyle = Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: 16, fontWeight: FontWeight.w600);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Urgency', style: labelStyle ?? const TextStyle(fontSize: 12, color: Colors.orange)),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: _showUrgencyMenu,
            child: CompositedTransformTarget(
              link: _urgencyLink,
              child: Container(
                key: _urgencyFilterKey,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(color: closedBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.orange)),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _selectedUrgency,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                        style: TextStyle(color: (Colors.orange[700] ?? Colors.orange), fontWeight: FontWeight.w600, fontFamily: 'Arial'),
                      ),
                    ),
                    Icon(Icons.arrow_drop_down, color: Colors.orange[700] ?? Colors.orange),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCategoryMenu() {
    _hideCategoryMenu();
    final ctx = _categoryFilterKey.currentContext;
    if (ctx == null) return;
    final renderObject = ctx.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return;
    final size = renderObject.size;
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
                    children: _categories.map((e) {
                      final isSelected = _selectedCategory == e;
                      final rowColor = isSelected ? Colors.orange[600] : Colors.orange[50];
                      final textColor = isSelected ? Colors.white : (Colors.orange[700] ?? Colors.orange);
                      return InkWell(
                        onTap: () {
                          setState(() => _selectedCategory = e);
                          _hideCategoryMenu();
                        },
                        splashColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                        hoverColor: Colors.transparent,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          color: rowColor,
                          child: Text(e, style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
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
    Overlay.of(context).insert(_categoryMenuOverlay!);
  }

  void _hideCategoryMenu() {
    _categoryMenuOverlay?.remove();
    _categoryMenuOverlay = null;
  }

  void _showUrgencyMenu() {
    _hideUrgencyMenu();
    final ctx = _urgencyFilterKey.currentContext;
    if (ctx == null) return;
    final renderObject = ctx.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return;
    final size = renderObject.size;
    final items = ['Urgent (${_urgentCount(_items)})', 'All (${_items.length})'];
    _urgencyMenuOverlay = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            Positioned.fill(child: GestureDetector(behavior: HitTestBehavior.translucent, onTap: _hideUrgencyMenu)),
            CompositedTransformFollower(
              link: _urgencyLink,
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
                      final isSelected = _selectedUrgency == e;
                      final rowColor = isSelected ? Colors.orange[600] : Colors.orange[50];
                      final textColor = isSelected ? Colors.white : (Colors.orange[700] ?? Colors.orange);
                      return InkWell(
                        onTap: () {
                          setState(() => _selectedUrgency = e);
                          _hideUrgencyMenu();
                        },
                        splashColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                        hoverColor: Colors.transparent,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          color: rowColor,
                          child: Text(e, style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
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
    Overlay.of(context).insert(_urgencyMenuOverlay!);
  }

  void _hideUrgencyMenu() {
    _urgencyMenuOverlay?.remove();
    _urgencyMenuOverlay = null;
  }

  void _applyFilters() {
    if (_isApplying) return;
    setState(() => _isApplying = true);
    _hideCategoryMenu();
    _hideUrgencyMenu();
    FocusScope.of(context).unfocus();
    setState(() => _restockCurrentPage = 1);
    Future.delayed(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      setState(() => _isApplying = false);
    });
  }

  void _clearFilters() {
    setState(() {
      _selectedCategory = 'All (${_items.length})';
      _selectedUrgency = 'Urgent (${_urgentCount(_items)})';
      _restockCurrentPage = 1;
    });
    _hideCategoryMenu();
    _hideUrgencyMenu();
    FocusScope.of(context).unfocus();
  }

  Future<void> _showPacketFinishedDialog() async {
    final snap = await FirebaseFirestore.instance.collection('ingredients').orderBy('name').get();
    final items = snap.docs.map((d) => {'id': d.id, 'name': (d.data()['name'] ?? '').toString(), 'unit': (d.data()['unit'] ?? '').toString(), 'amountPerUnit': (d.data()['amountPerUnit'] is num) ? (d.data()['amountPerUnit'] as num).toDouble() : double.tryParse('${d.data()['amountPerUnit'] ?? 0}') ?? 0.0}).toList();
    String? ingredientId;
    Map<String, dynamic>? sel;
    int packets = 1;
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Mark Packet Finished'),
          content: StatefulBuilder(builder: (ctx, setLocal) {
            return Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButton<Map<String, dynamic>>(
                value: sel,
                isExpanded: true,
                items: items.map((e) => DropdownMenuItem(value: e, child: Text((e['name'] ?? '').toString()))).toList(),
                onChanged: (v) => setLocal(() { sel = v; ingredientId = v?['id']; }),
              ),
              const SizedBox(height: 8),
              Row(children: [
                const Text('Packets:'),
                const SizedBox(width: 8),
                SizedBox(width: 80, child: TextField(controller: TextEditingController(text: '$packets'), keyboardType: TextInputType.number, onChanged: (t) => packets = int.tryParse(t) ?? 1)),
              ]),
            ]);
          }),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(onPressed: (ingredientId == null) ? null : () async {
              Navigator.pop(ctx);
              await _finalizePacketFinished(sel!, packets);
            }, child: const Text('Submit')),
          ],
        );
      },
    );
  }

  Future<void> _finalizePacketFinished(Map<String, dynamic> ingredient, int packets) async {
    final auth = context.read<AuthProvider>();
    final franchiseId = auth.currentUser?.franchiseId;
    final ingredientId = ingredient['id'] as String;
    final name = (ingredient['name'] ?? '').toString();
    final unit = (ingredient['unit'] ?? '').toString();
    final perPacket = (ingredient['amountPerUnit'] as double);
    final totalAmount = perPacket * packets;

    try {
      await FirebaseFirestore.instance.collection('ingredients').doc(ingredientId).update({'stockQuantity': FieldValue.increment(-packets)});
    } catch (_) {}

    DateTime start = DateTime(2020);
    try {
      final prev = await FirebaseFirestore.instance.collection('ingredient_depletions').where('ingredientId', isEqualTo: ingredientId).orderBy('endedAt', descending: true).limit(1).get();
      if (prev.docs.isNotEmpty) {
        final m = prev.docs.first.data();
        if (m['endedAt'] is Timestamp) start = (m['endedAt'] as Timestamp).toDate();
      }
    } catch (_) {}

    final orders = await FirebaseFirestore.instance.collection('orders').where('franchiseId', isEqualTo: franchiseId).where('createdAt', isGreaterThan: Timestamp.fromDate(start)).where('createdAt', isLessThanOrEqualTo: Timestamp.now()).get();
    int totalQty = 0;
    final Map<String, int> productCounts = {};
    for (final d in orders.docs) {
      final m = d.data();
      final items = (m['items'] as List?) ?? const [];
      for (final it in items) {
        final ingr = (it['ingredients'] as List?)?.map((e) => '$e').toList() ?? const [];
        if (ingr.contains(name)) {
          final qty = (it['qty'] is num) ? (it['qty'] as num).toInt() : int.tryParse('${it['qty'] ?? 0}') ?? 0;
          totalQty += qty;
          final pid = (it['productId'] ?? '').toString();
          if (pid.isNotEmpty) productCounts[pid] = (productCounts[pid] ?? 0) + qty;
        }
      }
    }

    if (totalQty > 0) {
      final gramsPerItem = totalAmount / totalQty;
      await FirebaseFirestore.instance.collection('ingredient_usage_profiles').doc('$franchiseId:$ingredientId').set({
        'ingredientId': ingredientId,
        'ingredientName': name,
        'franchiseId': franchiseId,
        'unit': unit,
        'gramsPerItem': gramsPerItem,
        'updatedAt': FieldValue.serverTimestamp(),
        'perProduct': {for (final e in productCounts.entries) e.key: gramsPerItem},
      }, SetOptions(merge: true));
    }

    await FirebaseFirestore.instance.collection('ingredient_depletions').add({
      'ingredientId': ingredientId,
      'ingredientName': name,
      'franchiseId': franchiseId,
      'packets': packets,
      'unit': unit,
      'amountPerUnit': perPacket,
      'totalAmount': totalAmount,
      'endedAt': FieldValue.serverTimestamp(),
    });

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Recorded depletion for $name'), backgroundColor: Colors.orange[600]));
  }
}