import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/app_shell.dart';
import '../providers/auth_provider.dart';

class HygieneRecord {
  final String id;
  final String ingredient;
  final String storageMethod;
  final String staffName;
  final DateTime date;
  final String status;
  final int violations;
  HygieneRecord({
    required this.id,
    required this.ingredient,
    required this.storageMethod,
    required this.staffName,
    required this.date,
    required this.status,
    required this.violations,
  });
  factory HygieneRecord.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data();
    DateTime _toDate(v) {
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      final s = (v ?? '').toString();
      final dt = DateTime.tryParse(s);
      return dt ?? DateTime.now();
    }
    int _toI(v) {
      if (v is num) return v.toInt();
      return int.tryParse((v ?? '0').toString()) ?? 0;
    }
    return HygieneRecord(
      id: d.id,
      ingredient: (m['ingredient'] ?? m['ingredientName'] ?? '').toString(),
      storageMethod: (m['storageMethod'] ?? '').toString(),
      staffName: (m['staffName'] ?? m['staff'] ?? '').toString(),
      date: _toDate(m['date']),
      status: (m['status'] ?? '').toString(),
      violations: _toI(m['violations'] ?? m['violationsCount']),
    );
  }
}

class HygieneComplianceScreen extends StatefulWidget {
  const HygieneComplianceScreen({super.key});
  @override
  State<HygieneComplianceScreen> createState() => _HygieneComplianceScreenState();
}

class _HygieneComplianceScreenState extends State<HygieneComplianceScreen> {
  String _searchQuery = '';
  String _selectedStatus = 'All Status';
  DateTime? _fromDate;
  DateTime? _toDate;
  bool _isApplying = false;
  final GlobalKey _statusFilterKey = GlobalKey();
  final LayerLink _statusLink = LayerLink();
  OverlayEntry? _statusMenuOverlay;
  final List<String> _statusOptions = const ['All Status', 'Completed', 'Violated'];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final franchiseId = auth.currentUser?.franchiseId;
    Query<Map<String, dynamic>> q = FirebaseFirestore.instance.collection('hygiene');
    if (franchiseId != null && franchiseId.isNotEmpty) {
      q = q.where('franchiseId', isEqualTo: franchiseId);
    }
    return AppShell(
      activeItem: 'Hygiene',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hygiene Compliance', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: Colors.orange[600])),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 8, offset: const Offset(0, 2))]),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(24)),
                          child: TextField(
                            decoration: const InputDecoration(hintText: 'Search', prefixIcon: Icon(Icons.search), border: InputBorder.none, contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 12)),
                            onChanged: (v) => setState(() => _searchQuery = v.trim()),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      SizedBox(
                        width: 220,
                        child: _buildStatusFilter(),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _dateField(label: 'Date From', value: _fromDate, onPick: (d) => setState(() => _fromDate = d)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _dateField(label: 'To', value: _toDate, onPick: (d) => setState(() => _toDate = d)),
                      ),
                      const SizedBox(width: 12),
                      Padding(
                        padding: const EdgeInsets.only(top: 22),
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
                        padding: const EdgeInsets.only(top: 22),
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
                ],
              ),
            ),
            const SizedBox(height: 12),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: q.orderBy('date', descending: true).snapshots(),
              builder: (context, snap) {
                List<QueryDocumentSnapshot<Map<String, dynamic>>> docs = snap.data?.docs ?? const [];
                final records = docs.map((d) => HygieneRecord.fromDoc(d)).where((r) {
                  if (_searchQuery.isNotEmpty) {
                    final q = _searchQuery.toLowerCase();
                    if (!(r.ingredient.toLowerCase().contains(q) || r.staffName.toLowerCase().contains(q) || r.storageMethod.toLowerCase().contains(q))) return false;
                  }
                  if (_selectedStatus != 'All Status' && r.status != _selectedStatus) return false;
                  if (_fromDate != null) {
                    final s = DateTime(_fromDate!.year, _fromDate!.month, _fromDate!.day);
                    if (r.date.isBefore(s)) return false;
                  }
                  if (_toDate != null) {
                    final e = DateTime(_toDate!.year, _toDate!.month, _toDate!.day).add(const Duration(days: 1));
                    if (!r.date.isBefore(e)) return false;
                  }
                  return true;
                }).toList();
                final total = records.length;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total $total records', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 8, offset: const Offset(0, 2))]),
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                            child: Row(
                              children: const [
                                Expanded(child: Text('Ingredient Left', style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w700, fontSize: 14))),
                                SizedBox(width: 140, child: Center(child: Text('Storage Method', style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w700, fontSize: 14)))),
                                SizedBox(width: 120, child: Center(child: Text('Staff Name', style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w700, fontSize: 14)))),
                                SizedBox(width: 120, child: Center(child: Text('Date', style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w700, fontSize: 14)))),
                                SizedBox(width: 120, child: Center(child: Text('Status', style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w700, fontSize: 14)))),
                                SizedBox(width: 160, child: Center(child: Text('Number of Violated', style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w700, fontSize: 14)))),
                                SizedBox(width: 80, child: Center(child: Text('Action', style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w700, fontSize: 14)))),
                              ],
                            ),
                          ),
                          const Divider(height: 1),
                          ...records.map((r) {
                            final isViolated = r.status.toLowerCase() == 'violated';
                            final bg = isViolated ? Colors.red.shade50 : Colors.transparent;
                            final statusColor = Colors.orange[600];
                            final dateStr = '${r.date.day.toString().padLeft(2, '0')}/${r.date.month.toString().padLeft(2, '0')}/${r.date.year}';
                            return Container(
                              color: bg,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                                child: Row(
                                  children: [
                                    Expanded(child: Text(r.ingredient, style: const TextStyle(fontWeight: FontWeight.w600))),
                                    SizedBox(width: 140, child: Center(child: Text(r.storageMethod))),
                                    SizedBox(width: 120, child: Center(child: Text(r.staffName))),
                                    SizedBox(width: 120, child: Center(child: Text(dateStr))),
                                    SizedBox(
                                      width: 120,
                                      child: Center(child: Text(r.status, style: TextStyle(color: statusColor, fontWeight: FontWeight.w700))),
                                    ),
                                    SizedBox(width: 160, child: Center(child: Text('${r.violations}'))),
                                    SizedBox(
                                      width: 80,
                                      child: Center(
                                        child: SizedBox(
                                          width: 40,
                                          height: 28,
                                          child: OutlinedButton(
                                            onPressed: () => _showDetails(r),
                                            style: OutlinedButton.styleFrom(side: BorderSide(color: Colors.orange[600]!), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                                            child: Icon(Icons.remove_red_eye, color: Colors.orange[600], size: 18),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateField({required String label, required DateTime? value, required ValueChanged<DateTime?> onPick}) {
    final dateStr = value == null ? '' : '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: TextEditingController(text: dateStr),
          readOnly: true,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: const BorderRadius.all(Radius.circular(8)), borderSide: BorderSide(color: Colors.orange[600]!)),
            enabledBorder: OutlineInputBorder(borderRadius: const BorderRadius.all(Radius.circular(8)), borderSide: BorderSide(color: Colors.orange[600]!)),
            focusedBorder: OutlineInputBorder(borderRadius: const BorderRadius.all(Radius.circular(8)), borderSide: BorderSide(color: Colors.orange[600]!, width: 2)),
            suffixIcon: IconButton(
              icon: Icon(Icons.calendar_today, size: 18, color: Colors.orange[600]),
              onPressed: () async {
                final now = DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: value ?? now,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                  builder: (context, child) {
                    final base = Theme.of(context);
                    return Theme(
                      data: base.copyWith(
                        colorScheme: ColorScheme.light(
                          primary: Colors.orange[600]!,
                          onPrimary: Colors.white,
                          onSurface: Colors.black87,
                        ),
                      ),
                      child: child!,
                    );
                  },
                );
                onPick(picked);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusFilter() {
    final closedBg = const Color(0xFFF6EDDF);
    final labelStyle = Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.orange[600]);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Status', style: labelStyle ?? const TextStyle(fontSize: 12, color: Colors.orange)),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: _showStatusMenu,
          child: CompositedTransformTarget(
            link: _statusLink,
            child: Container(
              key: _statusFilterKey,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(color: closedBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.orange[600]!)),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _selectedStatus,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      style: TextStyle(color: Colors.orange[600], fontWeight: FontWeight.w600),
                    ),
                  ),
                  Icon(Icons.arrow_drop_down, color: Colors.orange[600]),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showStatusMenu() {
    _hideStatusMenu();
    final ctx = _statusFilterKey.currentContext;
    if (ctx == null) return;
    final renderObject = ctx.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return;
    final size = renderObject.size;
    _statusMenuOverlay = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            Positioned.fill(child: GestureDetector(behavior: HitTestBehavior.translucent, onTap: _hideStatusMenu)),
            CompositedTransformFollower(
              link: _statusLink,
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
                    children: _statusOptions.map((e) {
                      final isSelected = _selectedStatus == e;
                      final rowColor = isSelected ? Colors.orange[600] : Colors.orange[50];
                      final textColor = isSelected ? Colors.white : (Colors.orange[700] ?? Colors.orange);
                      return InkWell(
                        onTap: () {
                          setState(() => _selectedStatus = e);
                          _hideStatusMenu();
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
    Overlay.of(context).insert(_statusMenuOverlay!);
  }

  void _hideStatusMenu() {
    _statusMenuOverlay?.remove();
    _statusMenuOverlay = null;
  }

  void _applyFilters() {
    if (_isApplying) return;
    setState(() => _isApplying = true);
    _hideStatusMenu();
    FocusScope.of(context).unfocus();
    Future.delayed(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      setState(() => _isApplying = false);
    });
  }

  void _clearFilters() {
    setState(() {
      _selectedStatus = 'All Status';
      _fromDate = null;
      _toDate = null;
    });
    _hideStatusMenu();
    FocusScope.of(context).unfocus();
  }

  void _showDetails(HygieneRecord r) {
    showDialog<void>(
      context: context,
      builder: (context) {
        final dateStr = '${r.date.day.toString().padLeft(2, '0')}/${r.date.month.toString().padLeft(2, '0')}/${r.date.year}';
        return AlertDialog(
          title: const Text('Hygiene Record'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Ingredient: ${r.ingredient}'),
              Text('Storage: ${r.storageMethod}'),
              Text('Staff: ${r.staffName}'),
              Text('Date: $dateStr'),
              Text('Status: ${r.status}'),
              Text('Violations: ${r.violations}'),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          ],
        );
      },
    );
  }
}