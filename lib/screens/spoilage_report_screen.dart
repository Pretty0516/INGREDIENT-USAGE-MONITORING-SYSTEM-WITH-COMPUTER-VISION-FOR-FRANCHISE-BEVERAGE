import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../widgets/app_shell.dart';
import '../providers/auth_provider.dart';
import '../routes/app_routes.dart';

class SpoilageReportScreen extends StatefulWidget {
  const SpoilageReportScreen({super.key});
  @override
  State<SpoilageReportScreen> createState() => _SpoilageReportScreenState();
}

class _SpoilageReportScreenState extends State<SpoilageReportScreen> {
  final _ingredientCtrl = TextEditingController();
  final _expiryDateCtrl = TextEditingController();
  final _amountCtrl = TextEditingController(text: '1');
  final _reasonCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  TimeOfDay _time = TimeOfDay.now();
  String? _unit;
  String? _selectedIngredientId;
  List<Map<String, String>> _ingredientOptions = [];
  bool _loading = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadIngredients();
  }

  @override
  void dispose() {
    _ingredientCtrl.dispose();
    _expiryDateCtrl.dispose();
    _amountCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadIngredients() async {
    setState(() => _loading = true);
    try {
      final snap = await FirebaseFirestore.instance.collection('ingredients').orderBy('name').get();
      final opts = <Map<String, String>>[];
      for (final d in snap.docs) {
        final m = d.data();
        final id = d.id;
        final name = (m['name'] ?? '').toString();
        final unit = (m['unit'] ?? '').toString();
        if (name.isNotEmpty) {
          opts.add({'id': id, 'name': name, 'unit': unit});
        }
      }
      setState(() => _ingredientOptions = opts);
    } finally {
      setState(() => _loading = false);
    }
  }

  void _increment() {
    final v = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    final next = (v + 1).clamp(0, 999999).toStringAsFixed(0);
    setState(() => _amountCtrl.text = next);
  }

  void _decrement() {
    final v = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    final next = math.max(0, v - 1).toStringAsFixed(0);
    setState(() => _amountCtrl.text = next);
  }

  Future<void> _pickExpiry() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _expiryDateCtrl.text = '${picked.day.toString().padLeft(2, '0')} / ${picked.month.toString().padLeft(2, '0')} / ${picked.year}');
    }
  }

  void _setNow() {
    setState(() {
      _date = DateTime.now();
      _time = TimeOfDay.now();
    });
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final ingredientId = _selectedIngredientId;
    final ingredientName = _ingredientCtrl.text.trim();
    final unit = _unit ?? '';
    final quantity = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    final expiry = _expiryDateCtrl.text.trim();
    final reason = _reasonCtrl.text.trim();
    if (ingredientId == null || ingredientName.isEmpty || quantity <= 0 || expiry.isEmpty || reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all required fields')));
      return;
    }

    final auth = context.read<AuthProvider>();
    final franchiseId = auth.currentUser?.franchiseId;
    final staffId = auth.currentUser?.id;

    try {
      setState(() => _submitting = true);
      await FirebaseFirestore.instance.collection('spoilage_reports').add({
        'ingredientId': ingredientId,
        'ingredientName': ingredientName,
        'unit': unit,
        'quantity': quantity,
        'reason': _reasonCtrl.text.trim(),
        'expiryDate': _expiryDateCtrl.text.trim(),
        'date': _date.toIso8601String(),
        'time': '${_time.hour}:${_time.minute}',
        'franchiseId': franchiseId,
        'staffId': staffId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      final doc = await FirebaseFirestore.instance.collection('ingredients').doc(ingredientId).get();
      final m = doc.data() ?? {};
      final current = (m['stockQuantity'] is num) ? (m['stockQuantity'] as num).toDouble() : double.tryParse((m['stockQuantity'] ?? '0').toString()) ?? 0.0;
      final next = math.max(0, current - quantity);
      await FirebaseFirestore.instance.collection('ingredients').doc(ingredientId).update({'stockQuantity': next});

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Spoilage reported')));
      context.go(AppRoutes.inventory);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = '${_date.day.toString().padLeft(2, '0')} / ${_date.month.toString().padLeft(2, '0')} / ${_date.year}';
    final hour = _time.hourOfPeriod == 0 ? 12 : _time.hourOfPeriod;
    final ampm = _time.period == DayPeriod.am ? 'AM' : 'PM';
    final timeStr = '${hour.toString().padLeft(2, '0')} : ${_time.minute.toString().padLeft(2, '0')} $ampm';

    return AppShell(
      activeItem: 'Inventory',
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 940),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => context.go(AppRoutes.inventory),
                      icon: const Icon(Icons.chevron_left, color: Colors.orange),
                      label: const Text('BACK', style: TextStyle(color: Colors.orange)),
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.orange), padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    ),
                    const Spacer(),
                    const Text('REPORT WASTAGE', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 8, offset: const Offset(0, 2))]),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(child: Text('STEP 1 : PLEASE SCAN THE BARCODE ON THE PRODUCT LABEL', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
                          SizedBox(
                            width: 140,
                            height: 40,
                            child: ElevatedButton(
                              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Capture coming soon'))),
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC711F), foregroundColor: Colors.white),
                              child: const Text('CAPTURE'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: _labelValue('DATE', dateStr)),
                          const SizedBox(width: 16),
                          Expanded(child: _labelValue('TIME', timeStr)),
                          const SizedBox(width: 16),
                          SizedBox(
                            width: 120,
                            child: OutlinedButton(
                              onPressed: _setNow,
                              style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.orange), foregroundColor: Colors.orange),
                              child: const Text('NOW'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _field(label: 'Ingredient Name', child: _ingredientInput()),
                      const SizedBox(height: 12),
                      _field(
                        label: 'Expiry Date',
                        child: GestureDetector(
                          onTap: _pickExpiry,
                          child: AbsorbPointer(
                            child: TextField(
                              controller: _expiryDateCtrl,
                              decoration: _inputDecoration(),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _field(
                              label: 'Amount',
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 44,
                                    height: 44,
                                    child: Center(
                                      child: IconButton(
                                        onPressed: _increment,
                                        icon: const Icon(Icons.add, color: Colors.orange),
                                        iconSize: 28,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextField(
                                      controller: _amountCtrl,
                                      keyboardType: TextInputType.number,
                                      decoration: _inputDecoration(),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    width: 44,
                                    height: 44,
                                    child: Center(
                                      child: IconButton(
                                        onPressed: _decrement,
                                        icon: const Icon(Icons.remove, color: Colors.orange),
                                        iconSize: 28,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _field(
                              label: 'UNIT :',
                              child: Container(
                                height: 44,
                                decoration: BoxDecoration(color: const Color(0xFFF6EDDF), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.orange)),
                                alignment: Alignment.centerLeft,
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Text(_unit ?? '-', style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.orange)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _field(
                        label: 'Reason',
                        child: TextField(
                          controller: _reasonCtrl,
                          decoration: _inputDecoration(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 44,
                              child: OutlinedButton(
                                onPressed: () => context.go(AppRoutes.inventory),
                                style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.orange), foregroundColor: Colors.orange, textStyle: const TextStyle(fontSize: 18)),
                                child: const Text('BACK'),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SizedBox(
                              height: 44,
                              child: ElevatedButton(
                                onPressed: _submitting ? null : _submit,
                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC711F), foregroundColor: Colors.white, textStyle: const TextStyle(fontSize: 18)),
                                child: const Text('SUBMIT'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _labelValue(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 8, offset: const Offset(0, 2))]),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(width: 16),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _field({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        child,
      ],
    );
  }

  InputDecoration _inputDecoration() {
    return const InputDecoration(
      isDense: true,
      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8)), borderSide: BorderSide(color: Color(0xFFDC711F))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8)), borderSide: BorderSide(color: Color(0xFFDC711F))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8)), borderSide: BorderSide(color: Color(0xFFDC711F), width: 2)),
      fillColor: Color(0xFFF6EDDF),
      filled: true,
    );
  }

  Widget _ingredientInput() {
    if (_loading) {
      return Container(height: 44, alignment: Alignment.centerLeft, padding: const EdgeInsets.symmetric(horizontal: 12), decoration: BoxDecoration(color: const Color(0xFFF6EDDF), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.orange)), child: const Text('Loading...'));
    }
    return DropdownButtonFormField<Map<String, String>>(
      value: _selectedIngredientId == null ? null : {'id': _selectedIngredientId!, 'name': _ingredientCtrl.text, 'unit': _unit ?? ''},
      items: _ingredientOptions.map((e) => DropdownMenuItem<Map<String, String>>(value: e, child: Text(e['name'] ?? ''))).toList(),
      onChanged: (v) {
        if (v == null) return;
        setState(() {
          _selectedIngredientId = v['id'];
          _ingredientCtrl.text = v['name'] ?? '';
          _unit = v['unit'] ?? '';
        });
      },
      decoration: _inputDecoration(),
    );
  }
}