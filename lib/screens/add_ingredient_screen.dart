import 'dart:typed_data';
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../widgets/app_shell.dart';
import '../providers/auth_provider.dart';
import '../routes/app_routes.dart';

class AddIngredientScreen extends StatefulWidget {
  final String? editIngredientId;
  final bool readOnly;
  const AddIngredientScreen({super.key, this.editIngredientId, this.readOnly = false});

  @override
  State<AddIngredientScreen> createState() => _AddIngredientScreenState();
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final upper = newValue.text.toUpperCase();
    return newValue.copyWith(text: upper, selection: TextSelection.collapsed(offset: upper.length));
  }
}

class _AddIngredientScreenState extends State<AddIngredientScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountPerUnitController = TextEditingController();
  final _unitController = TextEditingController();
  final _thresholdController = TextEditingController();
  final _restockController = TextEditingController();
  final _supplierNameController = TextEditingController();
  final _supplierContactController = TextEditingController();
  final _categoryTextController = TextEditingController();

  String? _selectedCategory;
  List<String> _categories = const [];

  Uint8List? _pendingImageBytes;
  String? _pendingImageExt;
  String? _uploadedImageUrl;
  String? _uploadedImagePath;
  bool _isUploadingImage = false;
  bool _isSubmitting = false;
  UploadTask? _currentUploadTask;

  String? _nameError;
  String? _categoryError;
  String? _amountError;
  String? _unitError;
  String? _thresholdError;
  String? _restockError;
  String? _supplierNameError;
  String? _supplierContactError;

  String _categoryLabel = '';
  final GlobalKey _categoryEditKey = GlobalKey();
  final LayerLink _categoryEditLink = LayerLink();
  OverlayEntry? _categoryOverlay;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    if (widget.editIngredientId != null) {
      _loadIngredientForEdit(widget.editIngredientId!);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountPerUnitController.dispose();
    _unitController.dispose();
    _thresholdController.dispose();
    _restockController.dispose();
    _supplierNameController.dispose();
    _supplierContactController.dispose();
    _categoryTextController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final query = FirebaseFirestore.instance.collection('category');
      final snap = await query.get();
      final set = <String>{};
      for (final d in snap.docs) {
        final m = d.data();
        final c = (m['name'] ?? m['category'] ?? '').toString().trim();
        if (c.isNotEmpty) set.add(c);
      }
      setState(() {
        _categories = set.toList()..sort();
      });
    } catch (_) {}
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
    final filename = 'ingredient_${DateTime.now().millisecondsSinceEpoch}.$ext';
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

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (widget.readOnly) return;
    final name = _nameController.text.trim();
    final categoryCandidate = _categoryLabel.trim().isNotEmpty
        ? _categoryLabel.trim()
        : _categoryTextController.text.trim();
    final amountText = _amountPerUnitController.text.trim();
    final unit = _unitController.text.trim();
    final thresholdText = _thresholdController.text.trim();
    final restockText = _restockController.text.trim();

    setState(() {
      _nameError = name.isEmpty ? 'Please enter the name' : null;
      _categoryError = categoryCandidate.isEmpty ? 'Please select a category' : null;
      final amountVal = double.tryParse(amountText);
      _amountError = (amountVal == null || amountVal <= 0) ? 'Please enter the amount per unit' : null;
      _unitError = unit.isEmpty ? 'Please enter the unit' : null;
      final thresholdVal = double.tryParse(thresholdText);
      _thresholdError = (thresholdVal == null || thresholdVal <= 0) ? 'Please enter the threshold quantity' : null;
      final restockVal = double.tryParse(restockText);
      _restockError = (restockVal == null || restockVal <= 0) ? 'Please enter the restock quantity' : null;
      _supplierNameError = _supplierNameController.text.trim().isEmpty ? 'Please enter the supplier name' : null;
      _supplierContactError = _supplierContactController.text.trim().isEmpty ? 'Please enter the supplier contact' : null;
    });

    final hasErrors = [_nameError, _categoryError, _amountError, _unitError, _thresholdError, _restockError, _supplierNameError, _supplierContactError].any((e) => e != null);
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

      final category = categoryCandidate;
      final amountPerUnit = double.tryParse(amountText) ?? 0.0;
      final thresholdQty = double.tryParse(thresholdText) ?? 0.0;
      final restockQty = double.tryParse(restockText) ?? 0.0;
      final supplierName = _supplierNameController.text.trim();
      final supplierContact = _supplierContactController.text.trim();

      try {
        final suppliersRef = FirebaseFirestore.instance.collection('suppliers');
        final exists = await suppliersRef.where('name', isEqualTo: supplierName).limit(1).get();
        if (exists.docs.isEmpty) {
          final doc = suppliersRef.doc();
          await doc.set({
            'id': doc.id,
            'name': supplierName,
            'contact': supplierContact,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      } catch (_) {}

      final authProvider = context.read<AuthProvider>();
      final col = FirebaseFirestore.instance.collection('ingredients');
      const colPathStr = 'ingredients';

      final data = <String, dynamic>{
        'name': name,
        'category': category,
        'amountPerUnit': amountPerUnit,
        'unit': unit,
        'stockQuantity': 0,
        'imageUrl': _uploadedImageUrl ?? '',
        'thresholdQuantity': thresholdQty,
        'restockQuantity': restockQty,
        'supplierName': supplierName,
        'supplierContact': supplierContact,
        'imageName': _uploadedImagePath ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      };
      if (widget.editIngredientId != null) {
        await col.doc(widget.editIngredientId).update(data);
      } else {
        final docRef = await col.add(data);
        (docRef); // silence unused warning if any
      }
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFFF6EDDF),
          title: const Text('Success', style: TextStyle(color: Colors.black)),
          content: Text(
            widget.editIngredientId != null ? 'Ingredient updated successfully' : 'Ingredient has add successfully',
            style: TextStyle(color: Colors.black, fontSize: 18),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC711F),
                foregroundColor: Colors.white,
                textStyle: const TextStyle(fontSize: 18),
              ),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      context.go(AppRoutes.ingredientManagement);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add ingredient: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _loadIngredientForEdit(String id) async {
    try {
      final snap = await FirebaseFirestore.instance.collection('ingredients').doc(id).get();
      final m = snap.data();
      if (m == null) return;
      setState(() {
        _nameController.text = (m['name'] ?? '').toString();
        _categoryLabel = (m['category'] ?? '').toString();
        _selectedCategory = _categoryLabel.isNotEmpty ? _categoryLabel : null;
        _amountPerUnitController.text = ((m['amountPerUnit'] ?? 0).toString());
        _unitController.text = (m['unit'] ?? '').toString();
        _thresholdController.text = ((m['thresholdQuantity'] ?? 0).toString());
        _restockController.text = ((m['restockQuantity'] ?? 0).toString());
        _supplierNameController.text = (m['supplierName'] ?? '').toString();
        _supplierContactController.text = (m['supplierContact'] ?? '').toString();
        _uploadedImageUrl = (m['imageUrl'] ?? '').toString();
        _uploadedImagePath = (m['imageName'] ?? '').toString();
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 900;
    return AppShell(
      activeItem: 'Ingredient',
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1080),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Text(widget.readOnly ? 'View Ingredient' : (widget.editIngredientId != null ? 'Edit Ingredient' : 'Add Ingredient'), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => context.go(AppRoutes.ingredientManagement),
                  icon: const Icon(
                    Icons.arrow_back,
                    color: Colors.orange,
                    size: 24,
                  ),
                  label: const Text(
                    'Back',
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
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
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
                              onPressed: _isSubmitting
                                  ? null
                                  : (widget.readOnly
                                      ? () {
                                          Navigator.of(context).pushReplacement(
                                            MaterialPageRoute(builder: (_) => AddIngredientScreen(editIngredientId: widget.editIngredientId)),
                                          );
                                        }
                                      : _submit),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange[600],
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.symmetric(horizontal: 24),
                              ),
                              child: Text(widget.readOnly ? 'EDIT' : (widget.editIngredientId != null ? 'UPDATE' : 'ADD')),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: wide ? 280 : 220,
                          height: wide ? 220 : 180,
                          child: Center(
                            child: InkWell(
                                  onTap: widget.readOnly || _isUploadingImage ? null : _pickImage,
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
                                        else if (_uploadedImageUrl != null && _uploadedImageUrl!.isNotEmpty)
                                          Positioned.fill(
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(12),
                                              child: Image.network(_uploadedImageUrl!, fit: BoxFit.cover),
                                            ),
                                          )
                                        else
                                          Center(child: Icon(Icons.image, size: 64, color: Colors.grey[600])),
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
                        const SizedBox(width: 24),
                        Expanded(
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
                              _rowFieldCompact(
                                label: 'Category',
                                child: _buildCategoryField(),
                                labelWidth: 180,
                                errorText: _categoryError,
                              ),
                              Row(
                                children: [
                                  Expanded(flex: 3,
                                    child: _rowFieldCompact(
                                      label: 'Amount Per Unit',
                                      child: widget.readOnly
                                          ? Text(_amountPerUnitController.text, textAlign: TextAlign.left, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18, color: Colors.black))
                                          : _textField(
                                              controller: _amountPerUnitController,
                                              errorText: _amountError,
                                              keyboardType: TextInputType.number,
                                              onChanged: (_) => setState(() => _amountError = null),
                                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                            ),
                                      labelWidth: 180,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(flex: 1,
                                    child: _rowFieldCompact(
                                      label: 'Unit',
                                      child: widget.readOnly
                                          ? Text(_unitController.text, textAlign: TextAlign.left, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18, color: Colors.black))
                                          : _textField(
                                              controller: _unitController,
                                              errorText: _unitError,
                                              onChanged: (_) => setState(() => _unitError = null),
                                            ),
                                      labelWidth: 50,
                                    ),
                                  ),
                                ],
                              ),
                              _rowField(
                                label: 'Threshold Quantity',
                                child: widget.readOnly
                                    ? Text(_thresholdController.text, textAlign: TextAlign.left, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18, color: Colors.black))
                                    : _textField(
                                        controller: _thresholdController,
                                        errorText: _thresholdError,
                                        keyboardType: TextInputType.number,
                                        onChanged: (_) => setState(() => _thresholdError = null),
                                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                      ),
                              ),
                              _rowField(
                                label: 'Restock Quantity',
                                child: widget.readOnly
                                    ? Text(_restockController.text, textAlign: TextAlign.left, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18, color: Colors.black))
                                    : _textField(
                                        controller: _restockController,
                                        errorText: _restockError,
                                        keyboardType: TextInputType.number,
                                        onChanged: (_) => setState(() => _restockError = null),
                                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                      ),
                              ),
                              _rowField(
                                label: 'Supplier Name',
                                child: widget.readOnly
                                    ? Text(_supplierNameController.text, textAlign: TextAlign.left, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18, color: Colors.black))
                                    : CompositedTransformTarget(
                                        link: _supplierNameFieldLink,
                                        child: Container(
                                          key: _supplierNameFieldKey,
                                          child: _textField(
                                            controller: _supplierNameController,
                                            errorText: _supplierNameError,
                                            onChanged: (val) {
                                              setState(() => _supplierNameError = null);
                                              _scheduleSupplierLookup(val);
                                            },
                                            inputFormatters: [UpperCaseTextFormatter()],
                                          ),
                                        ),
                                      ),
                              ),
                              _rowField(
                                label: 'Supplier Contact',
                                child: widget.readOnly
                                    ? Text(_supplierContactController.text, textAlign: TextAlign.left, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18, color: Colors.black))
                                    : _textField(controller: _supplierContactController, errorText: _supplierContactError, onChanged: (_) => setState(() => _supplierContactError = null)),
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

  InputDecoration _inputDecoration() {
    return InputDecoration(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      filled: true,
      fillColor: widget.readOnly ? Colors.transparent : Colors.white,
      enabledBorder: widget.readOnly ? InputBorder.none : OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.orange)),
      focusedBorder: widget.readOnly ? InputBorder.none : OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.orange.shade700)),
    );
  }

  Widget _rowField({required String label, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 180,
            child: _tableLabel(label),
          ),
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

  Widget _textField({required TextEditingController controller, String? errorText, TextInputType? keyboardType, ValueChanged<String>? onChanged, List<TextInputFormatter>? inputFormatters}) {
    return TextField(
      controller: controller,
      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
      maxLines: 1,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      decoration: _inputDecoration().copyWith(errorText: errorText),
    );
  }

  Widget _tableLabel(String text) {
    return Text(text, style: const TextStyle(fontSize: 18, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis, softWrap: false);
  }

  Timer? _supplierLookupDebounce;
  final GlobalKey _supplierNameFieldKey = GlobalKey();
  final LayerLink _supplierNameFieldLink = LayerLink();
  OverlayEntry? _supplierSuggestOverlay;
  List<Map<String, String>> _supplierSuggestions = const [];
  void _scheduleSupplierLookup(String name) {
    _supplierLookupDebounce?.cancel();
    if (name.trim().isEmpty) return;
    _supplierLookupDebounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final col = FirebaseFirestore.instance.collection('suppliers');
        final eq = await col.where('name', isEqualTo: name.trim()).limit(1).get();
        if (eq.docs.isNotEmpty) {
          final m = eq.docs.first.data();
          final contact = (m['contact'] ?? m['phone'] ?? '').toString();
          if (mounted) {
            setState(() {
              _supplierContactController.text = contact;
              _supplierContactError = contact.isEmpty ? _supplierContactError : null;
            });
          }
        }

        final prefix = name.trim().toUpperCase();
        final snap = await col.orderBy('name').limit(10).get();
        final sugg = <Map<String, String>>[];
        for (final d in snap.docs) {
          final m = d.data();
          final n = (m['name'] ?? '').toString();
          if (n.toUpperCase().startsWith(prefix) && n.isNotEmpty) {
            final c = (m['contact'] ?? m['phone'] ?? '').toString();
            sugg.add({'name': n, 'contact': c});
          }
        }
        if (mounted) {
          setState(() => _supplierSuggestions = sugg);
          if (sugg.isNotEmpty) {
            _showSupplierSuggestionMenu();
          } else {
            _hideSupplierSuggestionMenu();
          }
        }
      } catch (_) {}
    });
  }
  void _showSupplierSuggestionMenu() {
    _hideSupplierSuggestionMenu();
    final ctx = _supplierNameFieldKey.currentContext;
    if (ctx == null) return;
    final ro = ctx.findRenderObject();
    if (ro is! RenderBox || !ro.hasSize) return;
    final box = ro as RenderBox;
    final size = box.size;
    final items = _supplierSuggestions;
    _supplierSuggestOverlay = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            Positioned.fill(child: GestureDetector(behavior: HitTestBehavior.translucent, onTap: _hideSupplierSuggestionMenu)),
            CompositedTransformFollower(
              link: _supplierNameFieldLink,
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
                    children: items.map((m) {
                      return InkWell(
                        onTap: () {
                          final n = m['name'] ?? '';
                          final c = m['contact'] ?? '';
                          setState(() {
                            _supplierNameController.text = n.toUpperCase();
                            _supplierContactController.text = c;
                            _supplierNameError = null;
                            _supplierContactError = c.isEmpty ? _supplierContactError : null;
                          });
                          _hideSupplierSuggestionMenu();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(6)),
                          child: Text(m['name'] ?? '', style: TextStyle(color: Colors.orange[700] ?? Colors.orange, fontWeight: FontWeight.w600)),
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
    Overlay.of(context).insert(_supplierSuggestOverlay!);
  }
  void _hideSupplierSuggestionMenu() {
    _supplierSuggestOverlay?.remove();
    _supplierSuggestOverlay = null;
  }
  Widget _buildCategoryField() {
    if (_categories.isEmpty) {
      return Row(
        children: [
          Expanded(
            child: widget.readOnly
                ? Text(_categoryTextController.text, textAlign: TextAlign.left, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18, color: Colors.black))
                : _textField(
                    controller: _categoryTextController,
                    errorText: null,
                    onChanged: (_) => setState(() => _categoryError = null),
                  ),
          ),
          if (!widget.readOnly) ...[
            const SizedBox(width: 8),
            IconButton(icon: Icon(Icons.add_circle_outline, color: Colors.orange), onPressed: _promptAddCategory),
          ],
        ],
      );
    }
    return Row(
      children: [
        Expanded(
          child: CompositedTransformTarget(
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
        ),
        if (!widget.readOnly) ...[
          const SizedBox(width: 8),
          IconButton(icon: Icon(Icons.add_circle_outline, color: Colors.orange), onPressed: _promptAddCategory),
        ],
      ],
    );
  }

  void _showCategoryMenu() {
    _hideCategoryMenu();
    final ctx = _categoryEditKey.currentContext;
    if (ctx == null) return;
    final renderObject = ctx.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return;
    final box = renderObject as RenderBox;
    final size = box.size;
    final items = _categories;
    _categoryOverlay = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
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
          ],
        );
      },
    );
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
        return StatefulBuilder(
          builder: (context, setLocalState) {
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
          },
        );
      },
    );
    if (result == null || result.isEmpty) return;
    try {
      final name = result;
      final exists = await FirebaseFirestore.instance
          .collection('category')
          .where('name', isEqualTo: name)
          .limit(1)
          .get();
      if (exists.docs.isEmpty) {
        final doc = FirebaseFirestore.instance.collection('category').doc();
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
}