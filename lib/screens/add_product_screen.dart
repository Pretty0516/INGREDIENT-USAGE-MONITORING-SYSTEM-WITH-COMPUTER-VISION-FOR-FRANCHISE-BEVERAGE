import 'dart:async';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../widgets/app_shell.dart';
import '../routes/app_routes.dart';

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final upper = newValue.text.toUpperCase();
    return newValue.copyWith(text: upper, selection: TextSelection.collapsed(offset: upper.length));
  }
}

class AddProductScreen extends StatefulWidget {
  final String? editProductId;
  final bool readOnly;
  const AddProductScreen({super.key, this.editProductId, this.readOnly = false});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _ingredientNameTextController = TextEditingController(text:"RM");
  final _ingredientRequiredController = TextEditingController();
  final _hotPriceController = TextEditingController();
  final _coldPriceController = TextEditingController();
  final _categoryTextController = TextEditingController();

  String? _nameError;
  String? _categoryError;
  String? _ingredientRequiredError;
  String? _hotPriceError;
  String? _coldPriceError;
  String? _iceError;
  String? _sugarError;
  String? _textureError;

  List<String> _categories = const [];
  String _categoryLabel = '';
  String? _selectedCategory;

  // Ingredient name dropdown
  List<String> _ingredientNames = const [];
  String _ingredientNameLabel = '';

  // Multiple ingredient name rows
  final List<String> _ingredientNameLabels = [];
  final List<String?> _ingredientNameSelecteds = [];
  final List<GlobalKey> _ingredientNameKeys = [];
  final List<LayerLink> _ingredientNameLinks = [];
  final List<OverlayEntry?> _ingredientNameOverlays = [];
  final List<TextEditingController> _ingredientNameTextCtrls = [];

  final GlobalKey _categoryEditKey = GlobalKey();
  final LayerLink _categoryEditLink = LayerLink();
  OverlayEntry? _categoryOverlay;

  bool _isSubmitting = false;

  // Image upload
  Uint8List? _pendingImageBytes;
  String? _pendingImageExt;
  String? _uploadedImageUrl;
  String? _uploadedImagePath;
  bool _isUploadingImage = false;
  UploadTask? _currentUploadTask;

  // Option chip groups
  final List<String> _iceOptions = const ['NO ICE', 'LESS ICE', 'NORMAL ICE'];
  final List<String> _sugarOptions = const ['NO SUGAR', 'LESS SUGAR', 'NORMAL SUGAR'];
  final List<String> _textureOptions = const ['SMOOTH', 'CREAMY', 'THICK'];
  final Set<String> _iceSelected = {};
  final Set<String> _sugarSelected = {};
  final Set<String> _textureSelected = {};

  // Extra requirements
  final List<TextEditingController> _extraLabelCtrls = [];
  final List<TextEditingController> _extraPriceCtrls = [];
  final List<Map<String, dynamic>> _extras = [];

  // initState moved below with edit prefill support

  @override
  void dispose() {
    _nameController.dispose();
    _ingredientNameTextController.dispose();
    _ingredientRequiredController.dispose();
    _hotPriceController.dispose();
    _coldPriceController.dispose();
    _categoryTextController.dispose();
    for (final c in _extraLabelCtrls) c.dispose();
    for (final c in _extraPriceCtrls) c.dispose();
    for (final c in _ingredientNameTextCtrls) c.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('productCategories').get();
      final set = <String>{};
      for (final d in snap.docs) {
        final m = d.data();
        final c = (m['name'] ?? m['category'] ?? '').toString().trim();
        if (c.isNotEmpty) set.add(c);
      }
      setState(() {
        _categories = set.toList()..sort();
        // Do not auto-select; keep empty to show 'Select' by default
      });
    } catch (_) {}
  }

  Future<void> _loadIngredientNames() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('ingredients').get();
      final set = <String>{};
      for (final d in snap.docs) {
        final m = d.data();
        final n = (m['name'] ?? m['ingredientName'] ?? '').toString().trim();
        if (n.isNotEmpty) set.add(n);
      }
      setState(() {
        _ingredientNames = set.toList()..sort();
        if (_ingredientNames.isNotEmpty) {
          if (_ingredientNameLabels.isEmpty) {
            _ingredientNameLabels.add('');
            _ingredientNameSelecteds.add(null);
            _ingredientNameKeys.add(GlobalKey());
            _ingredientNameLinks.add(LayerLink());
            _ingredientNameOverlays.add(null);
          }
        }
      });
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadIngredientNames();
    _addExtraRow();
    if (widget.editProductId != null) {
      _loadProductForEdit(widget.editProductId!);
    }
  }

  Future<void> _loadProductForEdit(String id) async {
    try {
      final snap = await FirebaseFirestore.instance.collection('products').doc(id).get();
      final m = snap.data();
      if (m == null) return;
      setState(() {
        _nameController.text = (m['name'] ?? '').toString();
        _uploadedImageUrl = (m['imageUrl'] ?? '').toString();
        _categoryLabel = (m['categoryName'] ?? '').toString();
        final hp = m['hotPrice'];
        _hotPriceController.text = hp == null ? '-' : _formatPrice(hp);
        _coldPriceController.text = _formatPrice(m['coldPrice']);
        final names = (m['ingredientNames'] is List)
            ? (m['ingredientNames'] as List).map((e) => '$e').toList()
            : <String>[];
        _ingredientNameLabels
          ..clear()
          ..addAll(names);
        _ingredientNameSelecteds
          ..clear()
          ..addAll(List<String?>.filled(names.length, null));
        _ingredientNameKeys
          ..clear()
          ..addAll(List.generate(names.length, (_) => GlobalKey()));
        _ingredientNameLinks
          ..clear()
          ..addAll(List.generate(names.length, (_) => LayerLink()));
        _ingredientNameOverlays
          ..clear()
          ..addAll(List<OverlayEntry?>.filled(names.length, null));
        _ingredientNameTextCtrls
          ..clear()
          ..addAll(List.generate(names.length, (_) => TextEditingController()));
        final opts = (m['options'] ?? {}) as Map<String, dynamic>;
        final ice = (opts['ice'] ?? {}) as Map<String, dynamic>;
        final sugar = (opts['sugar'] ?? {}) as Map<String, dynamic>;
        final texture = (opts['texture'] ?? {}) as Map<String, dynamic>;
        _iceSelected
          ..clear()
          ..addAll(ice.entries.where((e) => e.value == true).map((e) => e.key.toString()));
        _sugarSelected
          ..clear()
          ..addAll(sugar.entries.where((e) => e.value == true).map((e) => e.key.toString()));
        _textureSelected
          ..clear()
          ..addAll(texture.entries.where((e) => e.value == true).map((e) => e.key.toString()));
        final ex = (m['extras'] ?? {}) as Map<String, dynamic>;
        _extras
          ..clear()
          ..addAll(ex.entries.map((e) {
            final price = (e.value is Map && (e.value as Map)['price'] is num)
                ? ((e.value as Map)['price'] as num).toDouble()
                : 0.0;
            return {'label': e.key, 'price': price};
          }));
      });
    } catch (_) {}
  }

  String _formatPrice(dynamic v) {
    final d = (v is num) ? v.toDouble() : double.tryParse('$v') ?? 0.0;
    return d == 0.0 ? '' : d.toStringAsFixed(2);
  }

  InputDecoration _inputDecoration() {
    return InputDecoration(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      filled: true,
      fillColor: widget.readOnly ? Colors.transparent : Colors.white,
      enabledBorder: widget.readOnly ? InputBorder.none : OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.orange)),
      focusedBorder: widget.readOnly ? InputBorder.none : OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.orange)),
    );
  }

  Widget _rowField({required String label, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(width: 180, child: _tableLabel(label)),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _rowFieldCompact({required String label, required Widget child, double labelWidth = 120, String? errorText}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: labelWidth,
            child: Row(
              children: [
                Expanded(child: _tableLabel(label)),
                if (errorText != null) const Icon(Icons.error_outline, color: Colors.red, size: 18),
              ],
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _textField({required TextEditingController controller, String? errorText, TextInputType? keyboardType, ValueChanged<String>? onChanged, List<TextInputFormatter>? inputFormatters, ValueChanged<String>? onSubmitted, String? hintText, String? prefixText, bool enabled = true, bool readOnly = false}) {
    return TextField(
      controller: controller,
      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
      maxLines: 1,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      enabled: enabled && !widget.readOnly,
      readOnly: readOnly || widget.readOnly,
      decoration: _inputDecoration().copyWith(
        errorText: errorText,
        hintText: hintText,
        prefix: prefixText != null ? Padding(padding: const EdgeInsets.only(left: 8, right: 6), child: Text(prefixText, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18))) : null,
        suffixIcon: errorText != null ? const Icon(Icons.error_outline, color: Colors.red) : null,
      ),
    );
  }

  Widget _tableLabel(String text) {
    return Text(text, style: const TextStyle(fontSize: 18, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis, softWrap: false);
  }

  Widget _buildCategoryField() {
    if (_categories.isEmpty) {
      return SizedBox(
        width: 500,
        child: _textField(
          controller: _categoryTextController,
          errorText: null,
          onChanged: (_) => setState(() => _categoryError = null),
          keyboardType: TextInputType.text,
          onSubmitted: (_) {},
          hintText: 'Select',
        ),
      );
    }
    return Row(
      children: [
        Expanded(
          child: Stack(
            children: [
              CompositedTransformTarget(
                link: _categoryEditLink,
                child: InkWell(
                  key: _categoryEditKey,
                  onTap: widget.readOnly ? null : _showCategoryMenu,
                  child: Container(
                    padding: widget.readOnly ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: widget.readOnly ? null : Border.all(color: Colors.orange),
                      color: Colors.white,
                    ),
                    child: Row(
                      children: [
                        Expanded(child: Text(_categoryLabel.isEmpty ? 'Select' : _categoryLabel, textAlign: TextAlign.left, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18, color: Colors.black))),
                        if (!widget.readOnly) const Icon(Icons.arrow_drop_down, color: Colors.orange),
                      ],
                    ),
                  ),
                ),
              ),
              // error icon moved to title via _rowFieldCompact
            ],
          ),
        ),
        const SizedBox(width: 8),
        if (!widget.readOnly) IconButton(icon: const Icon(Icons.add_circle_outline, color: Colors.orange), onPressed: _promptAddCategory),
      ],
    );
  }

  Future<void> _addProductCategoryByName(String name) async {
    final v = name.trim();
    if (v.isEmpty) {
      setState(() => _categoryError = 'Please enter category name');
      return;
    }
    try {
      final exists = await FirebaseFirestore.instance.collection('productCategories').where('name', isEqualTo: v).limit(1).get();
      if (exists.docs.isEmpty) {
        final doc = FirebaseFirestore.instance.collection('productCategories').doc();
        await doc.set({'id': doc.id, 'name': v, 'createdAt': FieldValue.serverTimestamp()});
      }
      await _loadCategories();
      setState(() {
        _categoryLabel = v;
        _selectedCategory = v;
        _categoryError = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add category: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _addIngredientNameRow() {
    if (_ingredientNames.isEmpty) {
      _ingredientNameTextCtrls.add(TextEditingController());
      _ingredientNameLabels.add('');
      _ingredientNameSelecteds.add(null);
      _ingredientNameKeys.add(GlobalKey());
      _ingredientNameLinks.add(LayerLink());
      _ingredientNameOverlays.add(null);
    } else {
      _ingredientNameLabels.add('');
      _ingredientNameSelecteds.add(null);
      _ingredientNameKeys.add(GlobalKey());
      _ingredientNameLinks.add(LayerLink());
      _ingredientNameOverlays.add(null);
    }
    setState(() {});
  }

  void _showIngredientNameMenuAt(int index) {
    _hideIngredientNameMenuAt(index);
    final ctx = _ingredientNameKeys[index].currentContext;
    if (ctx == null) return;
    final ro = ctx.findRenderObject();
    if (ro is! RenderBox || !ro.hasSize) return;
    final box = ro as RenderBox;
    final size = box.size;
    final globalPos = box.localToGlobal(Offset.zero);
    final screenHeight = MediaQuery.of(context).size.height;
    final items = [_ingredientNameLabels[index], ..._ingredientNames.where((e) => e != _ingredientNameLabels[index])];
    final estimatedMenuHeight = (items.length.clamp(1, 8)) * 44.0 + 8.0;
    final openDown = globalPos.dy + size.height + estimatedMenuHeight < screenHeight - 16;
    _ingredientNameOverlays[index] = OverlayEntry(builder: (context) {
      return Stack(children: [
        Positioned.fill(child: GestureDetector(behavior: HitTestBehavior.translucent, onTap: () => _hideIngredientNameMenuAt(index))),
        CompositedTransformFollower(
          link: _ingredientNameLinks[index],
          showWhenUnlinked: false,
          offset: openDown ? Offset(0, size.height + 4) : Offset(0, -(estimatedMenuHeight + 4)),
          child: SizedBox(
            width: size.width,
            child: Material(
              elevation: 6,
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: items.map((e) {
                  final isSelected = e == _ingredientNameLabels[index];
                  final rowColor = isSelected ? Colors.orange[600] : Colors.orange[50];
                  final textColor = isSelected ? Colors.white : (Colors.orange[700] ?? Colors.orange);
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _ingredientNameLabels[index] = e;
                        _ingredientNameSelecteds[index] = e;
                      });
                      _hideIngredientNameMenuAt(index);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(color: rowColor, borderRadius: BorderRadius.circular(6)),
                      child: Text(e, style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ]);
    });
    Overlay.of(context).insert(_ingredientNameOverlays[index]!);
  }

  void _hideIngredientNameMenuAt(int index) {
    _ingredientNameOverlays[index]?.remove();
    _ingredientNameOverlays[index] = null;
  }

  void _showCategoryMenu() {
    _hideCategoryMenu();
    final ctx = _categoryEditKey.currentContext;
    if (ctx == null) return;
    final ro = ctx.findRenderObject();
    if (ro is! RenderBox || !ro.hasSize) return;
    final box = ro as RenderBox;
    final size = box.size;
    final items = _categories;
    _categoryOverlay = OverlayEntry(builder: (context) {
      return Stack(children: [
        Positioned.fill(child: GestureDetector(behavior: HitTestBehavior.translucent, onTap: _hideCategoryMenu)),
        CompositedTransformFollower(
          link: _categoryEditLink,
          showWhenUnlinked: false,
          offset: Offset(0, size.height + 4),
          child: SizedBox(
            width: size.width,
            child: Material(
              elevation: 6,
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: items.map((e) {
                  final isSelected = e == _categoryLabel;
                  final rowColor = isSelected ? Colors.orange[600] : Colors.orange[50];
                  final textColor = isSelected ? Colors.white : (Colors.orange[700] ?? Colors.orange);
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _categoryLabel = e;
                        _selectedCategory = e;
                        _categoryError = null;
                      });
                      _hideCategoryMenu();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(color: rowColor, borderRadius: BorderRadius.circular(6)),
                      child: Text(e, style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ]);
    });
    Overlay.of(context).insert(_categoryOverlay!);
  }

  void _hideCategoryMenu() {
    _categoryOverlay?.remove();
    _categoryOverlay = null;
  }

  Future<void> _promptAddCategory() async {
    final controller = TextEditingController();
    String? errorText;
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setLocalState) {
          return AlertDialog(
            backgroundColor: const Color(0xFFF6EDDF),
            title: const Text('Add Category', style: TextStyle(color: Colors.black)),
            content: SizedBox(
              width: 420,
              child: TextField(
                controller: controller,
                style: const TextStyle(fontSize: 18),
                decoration: _inputDecoration().copyWith(
                  hintText: 'Category name',
                  hintStyle: TextStyle(color: Colors.grey[500]),
                  errorText: errorText,
                ),
              ),
            ),
            actions: [
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                label: const Text(
                  'Cancel',
                  style: TextStyle(
                    color: Colors.orange,
                    letterSpacing: 0.5,
                    fontSize: 20,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.orange,
                  side: const BorderSide(color: Colors.orange),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  final v = controller.text.trim();
                  if (v.isEmpty) {
                    setLocalState(() => errorText = 'Please enter category name');
                  } else {
                    Navigator.of(context).pop(v);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC711F),
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(fontSize: 18),
                ),
                child: const Text('Add'),
              ),
            ],
          );
        });
      },
    );
    if (result == null || result.isEmpty) return;
    try {
      final name = result;
      final exists = await FirebaseFirestore.instance.collection('productCategories').where('name', isEqualTo: name).limit(1).get();
      if (exists.docs.isEmpty) {
        final doc = FirebaseFirestore.instance.collection('productCategories').doc();
        await doc.set({'id': doc.id, 'name': name, 'createdAt': FieldValue.serverTimestamp()});
      }
      await _loadCategories();
      setState(() {
        _categoryLabel = name;
        _selectedCategory = name;
        _categoryError = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add category: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (widget.readOnly) return;
    final name = _nameController.text.trim();
    final categoryCandidate = _categoryLabel.trim().isNotEmpty ? _categoryLabel.trim() : _categoryTextController.text.trim();
    final ingredientNameCandidate = _ingredientNameLabel.trim().isNotEmpty ? _ingredientNameLabel.trim() : _ingredientNameTextController.text.trim();
    final hotText = _hotPriceController.text.trim();
    final coldText = _coldPriceController.text.trim();

    final List<String> _rawIngredientValues = _ingredientNames.isEmpty
        ? _ingredientNameTextCtrls.map((c) => c.text.trim()).toList()
        : _ingredientNameLabels.map((e) => e.trim()).toList();
    final bool _ingredientInvalid = _rawIngredientValues.isEmpty || _rawIngredientValues.any((e) => e.isEmpty);

    setState(() {
      _nameError = name.isEmpty ? 'Required' : null;
      _categoryError = categoryCandidate.isEmpty ? 'Required' : null;
      _iceError = _iceSelected.isEmpty ? 'Required' : null;
      _sugarError = _sugarSelected.isEmpty ? 'Required' : null;
      _textureError = null;
      _ingredientRequiredError = _ingredientInvalid ? 'Required' : null;
      final hotVal = double.tryParse(hotText);
      _hotPriceError = (hotText == '-' || (hotVal != null && hotVal > 0)) ? null : 'Required';
      final coldVal = double.tryParse(coldText);
      _coldPriceError = (coldVal == null || coldVal <= 0) ? 'Required' : null;
    });

    final hasErrors = [_nameError, _categoryError, _ingredientRequiredError, _hotPriceError, _coldPriceError, _iceError, _sugarError, _textureError].any((e) => e != null);
    if (hasErrors) return;

    try {
      setState(() => _isSubmitting = true);
      if (_isUploadingImage && _currentUploadTask != null) {
        try {
          await _currentUploadTask!.timeout(const Duration(seconds: 60));
        } on TimeoutException {
          setState(() => _isUploadingImage = false);
        } catch (_) {
          setState(() => _isUploadingImage = false);
        }
      } else {
        await _uploadImageIfNeeded();
      }
      final doc = widget.editProductId != null
          ? FirebaseFirestore.instance.collection('products').doc(widget.editProductId)
          : FirebaseFirestore.instance.collection('products').doc();
      // Build option maps (Boolean per option)
      Map<String, bool> _toBoolMap(List<String> opts, Set<String> sel) => {
            for (final o in opts) o: sel.contains(o)
          };
      final extrasMap = {
        for (final e in _extras) (e['label'] as String): {
          'price': (e['price'] as num).toDouble(),
        }
      };
      // collect ingredient names (multiple rows)
      final List<String> ingredientNames = _rawIngredientValues.where((e) => e.isNotEmpty).toList();
      if (ingredientNames.isEmpty) {
        setState(() => _ingredientRequiredError = 'Required');
        return;
      }

      DocumentReference<Map<String, dynamic>>? categoryRef;
      try {
        final catQuery = await FirebaseFirestore.instance
            .collection('productCategories')
            .where('name', isEqualTo: categoryCandidate)
            .limit(1)
            .get();
        if (catQuery.docs.isEmpty) {
          final cdoc = FirebaseFirestore.instance.collection('productCategories').doc();
          await cdoc.set({'id': cdoc.id, 'name': categoryCandidate, 'createdAt': FieldValue.serverTimestamp()});
          categoryRef = cdoc;
        } else {
          categoryRef = catQuery.docs.first.reference;
        }
      } catch (_) {}

      final payload = {
        'id': doc.id,
        'name': name,
        'category': categoryRef,
        'categoryName': categoryCandidate,
        'ingredientNames': ingredientNames,
        'hotPrice': hotText == '-' ? null : double.tryParse(hotText) ?? 0.0,
        'coldPrice': double.tryParse(coldText) ?? 0.0,
        'imageUrl': _uploadedImageUrl ?? '',
        'options': {
          'ice': _toBoolMap(_iceOptions, _iceSelected),
          'sugar': _toBoolMap(_sugarOptions, _sugarSelected),
          'texture': _toBoolMap(_textureOptions, _textureSelected),
        },
        'extras': extrasMap,
      };
      if (widget.editProductId == null) {
        payload['createdAt'] = FieldValue.serverTimestamp();
        await doc.set(payload);
      } else {
        await doc.update(payload);
      }

      

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFFF6EDDF),
          title: const Text('Success', style: TextStyle(color: Colors.black)),
          content: const Text(
            'Product saved successfully',
            style: TextStyle(color: Colors.black, fontSize: 18),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                context.go(AppRoutes.productManagement);
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC711F), foregroundColor: Colors.white, textStyle: const TextStyle(fontSize: 18)),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add product: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
      if (result == null || result.files.isEmpty) return;
      final f = result.files.first;
      setState(() {
        _pendingImageBytes = f.bytes;
        _pendingImageExt = (f.extension ?? '').toLowerCase();
        if (_pendingImageExt == 'jpg') _pendingImageExt = 'jpeg';
        if (_pendingImageExt == null || _pendingImageExt!.isEmpty) _pendingImageExt = 'png';
      });
      unawaited(_uploadImageIfNeeded());
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick image: $e')),
      );
    }
  }

  Future<void> _uploadImageIfNeeded() async {
    if (_pendingImageBytes == null || _isUploadingImage) return;
    setState(() => _isUploadingImage = true);
    final ext = _pendingImageExt ?? 'png';
    final mime = 'image/$ext';
    final filename = 'product_${DateTime.now().millisecondsSinceEpoch}.$ext';
    try {
      final storage = FirebaseStorage.instance;
      final storagePath = 'images/$filename';
      final ref = storage.ref().child(storagePath);
      final metadata = SettableMetadata(contentType: mime);
      final task = ref.putData(_pendingImageBytes!, metadata);
      _currentUploadTask = task;
      await task.timeout(const Duration(seconds: 120));
      final url = await ref.getDownloadURL();
      if (!mounted) return;
      setState(() {
        _uploadedImageUrl = url;
        _uploadedImagePath = storagePath;
        _isUploadingImage = false;
        _currentUploadTask = null;
      });
    } on TimeoutException {
      if (!mounted) return;
      setState(() => _isUploadingImage = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image upload timed out. Please try again.'), backgroundColor: Colors.red),
      );
      _currentUploadTask = null;
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploadingImage = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload image: $e'), backgroundColor: Colors.red),
      );
      _currentUploadTask = null;
    }
  }

  Widget _optionRow(String label, List<String> options, Set<String> selected, void Function(String) onTap, {String? errorText}) {
    if (widget.readOnly && selected.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 180,
            child: Row(
              children: [
                Expanded(child: _tableLabel(label)),
                if (errorText != null) const Icon(Icons.error_outline, color: Colors.red, size: 18),
              ],
            ),
          ),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...(
                  widget.readOnly ? options.where((o) => selected.contains(o)) : options
                ).map((o) => widget.readOnly
                    ? Container(
                        padding: EdgeInsets.zero,
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          o,
                          textAlign: TextAlign.left,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18, color: Colors.black),
                        ),
                      )
                    : InkWell(
                        onTap: () => onTap(o),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: selected.contains(o) ? Colors.orange[600] : Colors.orange[50],
                            border: Border.all(color: Colors.orange),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(selected.contains(o) ? Icons.check_box : Icons.check_box_outline_blank, size: 18, color: selected.contains(o) ? Colors.white : (Colors.orange[700] ?? Colors.orange)),
                              const SizedBox(width: 6),
                              Text(
                                o,
                                style: TextStyle(color: selected.contains(o) ? Colors.white : (Colors.orange[700] ?? Colors.orange), fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                      )),
                if (!widget.readOnly)
                  InkWell(
                    onTap: () => setState(() {
                      if (selected.length == options.length) {
                        selected.clear();
                      } else {
                        selected
                          ..clear()
                          ..addAll(options);
                      }
                    }),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text('SELECT ALL', style: TextStyle(color: Colors.orange[700] ?? Colors.orange, fontWeight: FontWeight.w700)),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _addExtraRow() {
    _extraLabelCtrls.add(TextEditingController());
    _extraPriceCtrls.add(TextEditingController());
    setState(() {});
  }

  void _addExtraFromRow(int index) {
    final label = _extraLabelCtrls[index].text.trim();
    final price = double.tryParse(_extraPriceCtrls[index].text.trim());
    if (label.isEmpty || price == null || price <= 0) return;
    setState(() {
      _extras.add({'label': label, 'price': price});
      _extraLabelCtrls[index].clear();
      _extraPriceCtrls[index].clear();
    });
  }

  void _removeExtra(int index) {
    setState(() {
      if (index >= 0 && index < _extras.length) _extras.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      activeItem: 'Product',
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1080),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Text(widget.readOnly ? 'View Product' : (widget.editProductId != null ? 'Edit Product' : 'Add Product'), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => context.go(AppRoutes.productManagement),
                  icon: const Icon(Icons.arrow_back, color: Colors.orange, size: 24),
                  label: const Text('Back', style: TextStyle(color: Colors.orange, letterSpacing: 0.5, fontSize: 20)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange,
                    side: const BorderSide(color: Colors.orange),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 8),
                Form(
                  key: _formKey,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 8, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: Alignment.centerRight,
                          child: SizedBox(
                            height: 44,
                            child: ElevatedButton(
                              onPressed: _isSubmitting ? null : (widget.readOnly ? () {
                                Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => AddProductScreen(editProductId: widget.editProductId)));
                              } : _submit),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[600], foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), padding: const EdgeInsets.symmetric(horizontal: 16)),
                              child: Text(widget.readOnly ? 'EDIT' : (widget.editProductId != null ? 'UPDATE' : 'ADD'), style: const TextStyle(letterSpacing: 0.5, fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Left: Image upload box
                            Expanded(
                              flex: 1,
                              child: Center(
                                child: AspectRatio(
                                  aspectRatio: 1,
                                  child: InkWell(
                                    onTap: widget.readOnly ? null : (_isUploadingImage ? null : _pickImage),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.black87, width: 1.2),
                                      ),
                                      child: Stack(
                                        children: [
                                          if (_pendingImageBytes != null)
                                            Positioned.fill(
                                              child: ClipRRect(
                                                borderRadius: BorderRadius.circular(12),
                                                child: Image.memory(_pendingImageBytes!, fit: BoxFit.cover),
                                              ),
                                            )
                                          else
                                            Center(child: Icon(Icons.image, size: 30, color: Colors.grey[600])),
                                          if (_isUploadingImage)
                                            const Positioned(
                                              right: 12,
                                              top: 12,
                                              child: SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 24),
                            // Right: Form fields
                            Expanded(
                              flex: 2,
                              child: Column(
                                children: [
                                  _rowField(
                                    label: 'Name',
                                    child: widget.readOnly
                                        ? Text(_nameController.text, textAlign: TextAlign.left, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18, color: Colors.black))
                                        : _textField(
                                            controller: _nameController,
                                            errorText: _nameError,
                                            onChanged: (_) => setState(() => _nameError = null),
                                            inputFormatters: [UpperCaseTextFormatter()],
                                          ),
                                  ),
                                  _rowFieldCompact(label: 'Category', child: _buildCategoryField(), labelWidth: 180, errorText: _categoryError),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _rowFieldCompact(
                                          label: 'Hot Price (RM)',
                                          child: widget.readOnly
                                              ? Text(_hotPriceController.text == '-' ? '-' : 'RM ${_hotPriceController.text}', textAlign: TextAlign.left, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18, color: Colors.black))
                                              : _textField(
                                                  controller: _hotPriceController,
                                                  errorText: _hotPriceError,
                                                  keyboardType: TextInputType.number,
                                                  onChanged: (_) => setState(() => _hotPriceError = null),
                                                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9-]'))],
                                                ),
                                          labelWidth: 180,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: _rowFieldCompact(
                                          label: 'Cold Price (RM)',
                                          child: widget.readOnly
                                              ? Text('RM ${_coldPriceController.text}', textAlign: TextAlign.left, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18, color: Colors.black))
                                              : _textField(
                                                  controller: _coldPriceController,
                                                  errorText: _coldPriceError,
                                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                  onChanged: (_) => setState(() => _coldPriceError = null),
                                                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                                                ),
                                          labelWidth: 180,
                                        ),
                                      ),
                                    ],
                                  ),
                                  _optionRow('Ice Level', _iceOptions, _iceSelected, widget.readOnly ? (_) {} : (o) => setState(() {
                                        if (_iceSelected.contains(o)) {
                                          _iceSelected.remove(o);
                                        } else {
                                          _iceSelected.add(o);
                                        }
                                      }), errorText: _iceError),
                                  _optionRow('Sugar Level', _sugarOptions, _sugarSelected, widget.readOnly ? (_) {} : (o) => setState(() {
                                        if (_sugarSelected.contains(o)) {
                                          _sugarSelected.remove(o);
                                        } else {
                                          _sugarSelected.add(o);
                                        }
                                      }), errorText: _sugarError),
                                  _optionRow('Texture', _textureOptions, _textureSelected, widget.readOnly ? (_) {} : (o) => setState(() {
                                        if (_textureSelected.contains(o)) {
                                          _textureSelected.remove(o);
                                        } else {
                                          _textureSelected.add(o);
                                        }
                                      }), errorText: _textureError),
                                  if (!widget.readOnly)
                                    for (int i = 0; i < _extraLabelCtrls.length; i++)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          children: [
                                            SizedBox(width: 180, child: i == 0 ? _tableLabel('Extra Requirement') : const SizedBox.shrink()),
                                            Expanded(
                                              child: Row(
                                                children: [
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: _textField(
                                                      controller: _extraLabelCtrls[i],
                                                      onChanged: (_) {},
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  SizedBox(
                                                    width: 160,
                                                    child: _textField(
                                                      controller: _extraPriceCtrls[i],
                                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                                                      prefixText: 'RM ',
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  ElevatedButton(
                                                    onPressed: () => _addExtraFromRow(i),
                                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[600], foregroundColor: Colors.white),
                                                    child: const Text('Add'),
                                                  ),
                                                  const SizedBox(width: 8),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  if (_extras.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      child: Row(
                                        children: [
                                          SizedBox(width: 180, child: _tableLabel('Extra Requirement')),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                for (int i = 0; i < _extras.length; i++)
                                                  Padding(
                                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                                    child: Text(
                                                      '${_extras[i]['label']} (RM ${(_extras[i]['price'] as num).toStringAsFixed(2)})',
                                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    child: Row(
                                      children: [
                                        SizedBox(width: 180, child: _tableLabel('Ingredient Required')),
                                        const Expanded(child: SizedBox.shrink()),
                                      ],
                                    ),
                                  ),
                                  for (int i = 0; i < (_ingredientNames.isEmpty ? _ingredientNameTextCtrls.length : _ingredientNameLabels.length); i++)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      child: Row(
                                        children: [
                                          SizedBox(width: 180, child: i == 0 ? _tableLabel('Ingredient Name') : const SizedBox.shrink()),
                                          if (i == 0 && _ingredientRequiredError != null)
                                            const SizedBox(width: 6),
                                          if (i == 0 && _ingredientRequiredError != null)
                                            const Icon(Icons.error_outline, color: Colors.red, size: 18),
                                          Expanded(
                                            child: _ingredientNames.isEmpty
                                                ? _textField(controller: _ingredientNameTextCtrls[i])
                                                : (widget.readOnly
                                                    ? Text(
                                                        _ingredientNameLabels[i].isEmpty ? 'Select' : _ingredientNameLabels[i],
                                                        textAlign: TextAlign.left,
                                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18, color: Colors.black),
                                                      )
                                                    : Row(
                                                      children: [
                                                        Expanded(
                                                          child: CompositedTransformTarget(
                                                            link: _ingredientNameLinks[i],
                                                            child: Stack(
                                                            children: [
                                                              InkWell(
                                                                key: _ingredientNameKeys[i],
                                                                onTap: widget.readOnly ? null : () => _showIngredientNameMenuAt(i),
                                                          child: Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                                            decoration: BoxDecoration(
                                                              borderRadius: BorderRadius.circular(8),
                                                              border: widget.readOnly ? null : Border.all(color: Colors.orange),
                                                              color: Colors.white,
                                                            ),
                                                            child: Row(
                                                              children: [
                                                                Expanded(child: Text(_ingredientNameLabels[i].isEmpty ? 'Select' : _ingredientNameLabels[i], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18))),
                                                                if (!widget.readOnly) const Icon(Icons.arrow_drop_down, color: Colors.orange),
                                                              ],
                                                            ),
                                                          ),
                                                              ),
                                                              // ingredient error icon appears beside the title, not inside the field
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                    ],
                                                  )),
                                          ),
                                                      const SizedBox(width: 8),
                                                      if (!widget.readOnly)
                                                        IconButton(icon: const Icon(Icons.add_circle_outline, color: Colors.orange), onPressed: _addIngredientNameRow),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}