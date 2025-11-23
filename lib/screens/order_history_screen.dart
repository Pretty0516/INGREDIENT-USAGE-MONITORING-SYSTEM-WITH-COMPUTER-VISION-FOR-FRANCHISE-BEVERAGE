// lib/screens/order_history_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/app_shell.dart';
import '../routes/app_routes.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});
  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  String _searchOrderNo = '';
  String _statusFilter = 'All';
  DateTime? _fromDate;
  DateTime? _toDate;
  DocumentSnapshot<Map<String, dynamic>>? _selected;
  final GlobalKey _statusFilterKey = GlobalKey();
  final LayerLink _statusLink = LayerLink();
  OverlayEntry? _statusOverlay;
  bool _isApplying = false;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _lastDocs = const [];

  bool _allCountActivated = false;

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _applyClientFilters(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> list = docs;
    final text = _searchOrderNo.trim();
    if (_statusFilter != 'All') {
      final s = _statusFilter.toUpperCase();
      list = list.where((d) {
        final v = (d.data()['status'] ?? '').toString().toUpperCase();
        final vv = v == 'PROCESSING' ? 'PREPARING' : v;
        return vv == s;
      });
    }
    if (_fromDate != null || _toDate != null) {
      final start = _fromDate != null ? DateTime(_fromDate!.year, _fromDate!.month, _fromDate!.day) : DateTime(1970);
      final end = _toDate != null ? DateTime(_toDate!.year, _toDate!.month, _toDate!.day, 23, 59, 59) : DateTime(3000);
      list = list.where((d) {
        final t = d.data()['createdAt'];
        final dt = t is Timestamp ? t.toDate() : DateTime.tryParse('$t') ?? DateTime(1970);
        return dt.isAfter(start.subtract(const Duration(milliseconds: 1))) && dt.isBefore(end.add(const Duration(milliseconds: 1)));
      });
    }
    final arr = list.toList();
    arr.sort((a, b) {
      final sa = (a.data()['status'] ?? '').toString().toUpperCase();
      final sb = (b.data()['status'] ?? '').toString().toUpperCase();
      final wa = sa == 'COMPLETED' ? 1 : 0;
      final wb = sb == 'COMPLETED' ? 1 : 0;
      if (wa != wb) return wa.compareTo(wb);
      final ta = a.data()['createdAt'];
      final tb = b.data()['createdAt'];
      final da = ta is Timestamp ? ta.toDate() : DateTime.tryParse('$ta') ?? DateTime(1970);
      final db = tb is Timestamp ? tb.toDate() : DateTime.tryParse('$tb') ?? DateTime(1970);
      return da.compareTo(db);
    });
    return arr;
  }

  Color _statusColor(String s) {
    switch (s.toUpperCase()) {
      case 'PENDING': return Colors.grey;
      case 'PREPARING': return Colors.orange;
      case 'COMPLETED': return Colors.green;
      case 'CANCELLED': return Colors.red;
      default: return Colors.grey;
    }
  }

  Widget _statusChip(String s) {
    final c = _statusColor(s);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: c.withOpacity(0.15), border: Border.all(color: c), borderRadius: BorderRadius.circular(16)),
      child: Text(s, style: TextStyle(color: c, fontWeight: FontWeight.w700)),
    );
  }

  void _hideStatusMenu() {
    _statusOverlay?.remove();
    _statusOverlay = null;
  }

  int _countForStatus(String s) {
    if (_lastDocs.isEmpty) return 0;
    if (s == 'All') return _lastDocs.length;
    final t = s.toUpperCase();
    return _lastDocs.where((d) {
      final v = (d.data()['status'] ?? '').toString().toUpperCase();
      final vv = v == 'PROCESSING' ? 'PREPARING' : v;
      return vv == t;
    }).length;
  }

  List<String> _statusOptions() {
    final set = <String>{};
    for (final d in _lastDocs) {
      var v = (d.data()['status'] ?? '').toString().toUpperCase();
      if (v == 'PROCESSING') v = 'PREPARING';
      if (v.isNotEmpty) set.add(v);
    }
    final list = set.toList()..sort();
    return ['All', ...list];
  }

  double _statusMenuWidth() {
    final items = _statusOptions();
    const style = TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Arial');
    double maxW = 0;
    for (final s in items) {
      final text = '$s (${_countForStatus(s)})';
      final tp = TextPainter(text: TextSpan(text: text, style: style), textDirection: TextDirection.ltr);
      tp.layout();
      if (tp.size.width > maxW) maxW = tp.size.width;
    }
    return maxW + 36;
  }

  void _showStatusMenu() {
    _hideStatusMenu();
    final rb = _statusFilterKey.currentContext?.findRenderObject() as RenderBox?;
    final overlay = Overlay.of(context);
    if (overlay == null || rb == null) return;
    final size = rb.size;
    _statusOverlay = OverlayEntry(builder: (_) {
      return Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _statusLink,
          offset: Offset(0, size.height + 4),
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.orange)),
              constraints: const BoxConstraints(maxHeight: 220),
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: (() {
                  final opts = _statusOptions();
                  final items = [_statusFilter, ...opts.where((e) => e != _statusFilter)];
                  return items.map((s) => InkWell(
                    onTap: () { setState(() { _statusFilter = s; }); _applyFiltersAction(); _hideStatusMenu(); },
                    splashColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                    hoverColor: Colors.transparent,
                    child: Container(
                      color: _statusFilter == s ? Colors.orange[600] : Colors.orange[50],
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      child: Text(
                        '$s (${_countForStatus(s)})',
                        style: TextStyle(color: _statusFilter == s ? Colors.white : (Colors.orange[700] ?? Colors.orange), fontWeight: FontWeight.w600, fontFamily: 'Arial'),
                      ),
                    ),
                  )).toList();
                })(),
              ),
            ),
          ),
        ),
      );
    });
    overlay.insert(_statusOverlay!);
  }

  String _formatDate(DateTime? d) {
    if (d == null) return '';
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yyyy = d.year.toString().padLeft(4, '0');
    return '$dd/$mm/$yyyy';
  }

  Future<void> _pickFromDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1),
      initialDate: _fromDate ?? now,
      builder: (ctx, child) {
        final orange = Colors.orange[600] ?? Colors.orange;
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: ColorScheme.light(primary: orange, onPrimary: Colors.white, onSurface: Colors.black),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _fromDate = picked);
  }

  Future<void> _pickToDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1),
      initialDate: _toDate ?? (_fromDate ?? now),
      builder: (ctx, child) {
        final orange = Colors.orange[600] ?? Colors.orange;
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: ColorScheme.light(primary: orange, onPrimary: Colors.white, onSurface: Colors.black),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _toDate = picked);
  }

  void _applyFiltersAction() {
    setState(() { _isApplying = true; });
    _hideStatusMenu();
    FocusScope.of(context).unfocus();
    Future.delayed(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      setState(() { _isApplying = false; });
    });
  }

  void _clearFilters() {
    setState(() {
      _searchOrderNo = '';
      _statusFilter = 'All';
      _fromDate = null;
      _toDate = null;
      _selected = null;
    });
    _hideStatusMenu();
    FocusScope.of(context).unfocus();
  }

  Future<void> _setStatus(String id, String status) async {
    await FirebaseFirestore.instance.collection('orders').doc(id).update({'status': status.toUpperCase()});
    if (_selected?.id == id) {
      final snap = await FirebaseFirestore.instance.collection('orders').doc(id).get();
      if (snap.exists) {
        setState(() => _selected = snap);
      }
    }
  }

  Future<void> _deleteOrder(String id) async {
    final reasonCtrl = TextEditingController();
    String? err;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) {
        return AlertDialog(
          backgroundColor: const Color(0xFFF6EDDF),
          title: const Text('Cancel Order'),
          content: SizedBox(
            width: 420,
            child: TextField(
              controller: reasonCtrl,
              style: const TextStyle(fontSize: 18),
              decoration: InputDecoration(
                border: OutlineInputBorder(borderSide: BorderSide(color: Colors.orange[600]!)),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.orange[600]!)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.orange[600]!, width: 2)),
                hintText: 'Reason',
                errorText: err,
              ),
            ),
          ),
          actions: [
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(ctx, false),
              label: const Text('Cancel', style: TextStyle(color: Colors.orange, letterSpacing: 0.5, fontSize: 20)),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.orange, side: const BorderSide(color: Colors.orange), padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            ),
            ElevatedButton(
              onPressed: () {
                if (reasonCtrl.text.trim().isEmpty) {
                  setLocal(() => err = 'Please enter reason');
                } else {
                  Navigator.pop(ctx, true);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC711F),
                foregroundColor: Colors.white,
                textStyle: const TextStyle(fontSize: 18),
                minimumSize: const Size(200, 44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Confirm'),
            ),
          ],
        );
      }),
    );
    if (ok == true && reasonCtrl.text.trim().isNotEmpty) {
      await FirebaseFirestore.instance.collection('orders').doc(id).update({'status': 'CANCELLED', 'cancelReason': reasonCtrl.text.trim()});
      final snap = await FirebaseFirestore.instance.collection('orders').doc(id).get();
      if (snap.exists) setState(() => _selected = snap);
    }
  }

  Widget _actionsFor(doc) {
    final id = doc.id;
    final m = doc.data() as Map<String, dynamic>;
    final status = (m['status'] ?? '').toString().toUpperCase();
    final paid = (m['received'] is num) ? (m['received'] as num).toDouble() : double.tryParse('${m['received']}') ?? 0.0;
    final total = (m['total'] is num) ? (m['total'] as num).toDouble() : double.tryParse('${m['total']}') ?? 0.0;
    final norm = status == 'PROCESSING' ? 'PREPARING' : status;
    final canEdit = norm == 'PENDING';
    final canCancel = norm == 'PENDING';
    final canComplete = norm == 'PREPARING';
    final showRefund = paid > total;

    final orange = Colors.orange[700] ?? Colors.orange;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 300),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          IconButton(
            tooltip: 'View',
            onPressed: () => setState(() => _selected = doc),
            icon: Icon(Icons.remove_red_eye, color: orange),
          ),
          IconButton(
            tooltip: 'Edit',
            onPressed: canEdit ? () => context.go(AppRoutes.orderList, extra: {'editOrderId': id}) : null,
            icon: Icon(Icons.edit, color: canEdit ? orange : Colors.grey),
          ),
          IconButton(
            tooltip: 'Delete',
            onPressed: canCancel ? () => _deleteOrder(id) : null,
            icon: Icon(Icons.delete, color: canCancel ? Colors.red : Colors.grey),
          ),
          IconButton(
            tooltip: 'Complete',
            onPressed: canComplete ? () => _setStatus(id, 'COMPLETED') : null,
            icon: Icon(Icons.check_circle, color: canComplete ? orange : Colors.grey),
          ),
          if (showRefund)
            Container(
              margin: const EdgeInsets.only(left: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.red)),
              child: Text('REFUND RM ${(paid - total).toStringAsFixed(2)}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );
  }

  Widget _detailPanel() {
    final m = _selected?.data();
    if (m == null) {
      return Container(
        width: 360,
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
          Text('Select an order', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        ]),
      );
    }
    final items = (m['items'] as List?) ?? const [];
    final ts = m['createdAt'];
    final dt = ts is Timestamp ? ts.toDate() : DateTime.tryParse('$ts') ?? DateTime.now();
    final received = (m['received'] is num) ? (m['received'] as num).toDouble() : double.tryParse('${m['received']}') ?? 0.0;
    final change = (m['change'] is num) ? (m['change'] as num).toDouble() : double.tryParse('${m['change']}') ?? 0.0;
    final subtotal = (m['subtotal'] is num) ? (m['subtotal'] as num).toDouble() : double.tryParse('${m['subtotal']}') ?? 0.0;
    final tax = (m['tax'] is num) ? (m['tax'] as num).toDouble() : double.tryParse('${m['tax']}') ?? 0.0;
    final total = (m['total'] is num) ? (m['total'] as num).toDouble() : double.tryParse('${m['total']}') ?? 0.0;

    return Container(
      width: 360,
      padding: const EdgeInsets.all(12),
      child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Order No : ', style: TextStyle(fontSize: 16)),
          Text('#${('${m['orderNo'] ?? ''}').toString().padLeft(4, '0')}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
        ]),
      
        const SizedBox(height: 6),
        Row(children: [
          Text('Date : ${dt.toString().split(' ').first}'),
          const SizedBox(width: 12),
          Text('Time : ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}')
        ]),
        const SizedBox(height: 8),
        Text('Type : ${(m['serviceType'] ?? '').toString()}'),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _statusColor((m['status'] ?? '').toString().toUpperCase() == 'PROCESSING' ? 'PREPARING' : (m['status'] ?? '').toString().toUpperCase()),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text((((m['status'] ?? '').toString().toUpperCase()) == 'PROCESSING') ? 'PREPARING' : (m['status'] ?? '').toString().toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
        ),
        const SizedBox(height: 10),
        const Text('ORDER LIST', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        ...items.map((it) {
          final mm = it as Map<String, dynamic>;
          final name = (mm['productName'] ?? '').toString();
          final qty = (mm['qty'] is num) ? (mm['qty'] as num).toInt() : int.tryParse('${mm['qty']}') ?? 1;
          final unit = (mm['unitPrice'] is num) ? (mm['unitPrice'] as num).toDouble() : double.tryParse('${mm['unitPrice']}') ?? 0.0;
          final extras = (mm['extras'] is List) ? (mm['extras'] as List).map((e) => '$e').toList() : <String>[];
          final temp = (mm['temperature'] ?? '').toString();
          final optionTags = [
            if (temp.isNotEmpty) temp,
            if ((mm['ice'] ?? '').toString().isNotEmpty) (mm['ice']).toString(),
            if ((mm['sugar'] ?? '').toString().isNotEmpty) (mm['sugar']).toString(),
            if ((mm['texture'] ?? '').toString().isNotEmpty) (mm['texture']).toString(),
            ...extras,
          ].where((e) => e.isNotEmpty).toList();
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                if (optionTags.isNotEmpty) Text(optionTags.join(' • '), style: const TextStyle(color: Colors.black54, fontSize: 18)),
              ])),
              Text('x $qty', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(width: 12),
              Text('RM ${(unit * qty).toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ]),
          );
        }).toList(),
        const SizedBox(height: 12),
        const Text('PAYMENT DETAILS', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Subtotal', style: TextStyle(fontSize: 14)), Text('RM ${subtotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14))]),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Tax (6%)', style: TextStyle(fontSize: 14)), Text('RM ${tax.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14))]),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Total', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)), Text('RM ${total.toStringAsFixed(2)}', style: const TextStyle(color: Colors.red, fontSize: 20, fontWeight: FontWeight.w900))]),
        const SizedBox(height: 6),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Paid', style: TextStyle(fontSize: 14)), Text('RM ${received.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14))]),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(change > 0 ? 'Refund' : 'Change', style: const TextStyle(fontSize: 14)),
          Text('RM ${change.toStringAsFixed(2)}', style: TextStyle(color: change > 0 ? Colors.red : Colors.black87, fontSize: 14)),
        ]),
        if (m['previousTotal'] is num) ...[
          const SizedBox(height: 6),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Adjustment (New - Previous)', style: TextStyle(fontSize: 14)),
            Text('RM ${(total - (m['previousTotal'] as num).toDouble()).toStringAsFixed(2)}', style: const TextStyle(fontSize: 14)),
          ]),
        ],
        const SizedBox(height: 10),
        const SizedBox(height: 12),
        if (((m['status'] ?? '').toString().toUpperCase() == 'PENDING')) ...[
          SizedBox(
            width: double.infinity,
            height: 40,
            child: ElevatedButton(
              onPressed: () => _setStatus(_selected!.id, 'PREPARING'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[600],
                foregroundColor: Colors.white,
                textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Preparing'),
            ),
          ),
        ],
        if ((() { final s = (m['status'] ?? '').toString().toUpperCase(); return s == 'PREPARING' || s == 'PROCESSING'; })()) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: ElevatedButton(
              onPressed: () => _setStatus(_selected!.id, 'COMPLETED'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[600],
                foregroundColor: Colors.white,
                textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('COMPLETE ORDER'),
            ),
          ),
        ],
      ])),
    );
  }

  Query<Map<String, dynamic>> _buildQuery(String? franchiseId) {
    Query<Map<String, dynamic>> q = FirebaseFirestore.instance.collection('orders');
    if (franchiseId != null) {
      q = q.where('franchiseId', isEqualTo: franchiseId);
    }
    final text = _searchOrderNo.trim();
    final digits = text.replaceAll(RegExp('[^0-9]'), '');
    final orderNo = int.tryParse(digits);
    if (orderNo != null) {
      q = q.where('orderNo', isEqualTo: orderNo);
    }
    return q;
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final franchiseId = auth.currentUser?.franchiseId;
    final Query<Map<String, dynamic>> q = _buildQuery(franchiseId);
    return AppShell(
      activeItem: 'Order History',
      body: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
                    height: 40,
                    child: Row(children: [
                      const Icon(Icons.search, size: 18, color: Colors.orange),
                      const SizedBox(width: 8),
                      Expanded(child: TextField(onChanged: (v) => setState(() => _searchOrderNo = v), decoration: const InputDecoration(border: InputBorder.none, hintText: 'Search Order No'))),
                    ]),
                  ),
                ),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: Row(children: [
                    Flexible(
                      flex: 2,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Status', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: 16, fontWeight: FontWeight.w600) ?? const TextStyle(fontSize: 12, color: Colors.orange)),
                        const SizedBox(height: 6),
                        CompositedTransformTarget(
                          link: _statusLink,
                          child: GestureDetector(
                            onTap: _showStatusMenu,
                            child: Container(
                              key: _statusFilterKey,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: _statusFilter == 'All' ? Colors.orange[50] : Colors.orange[600],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.orange),
                              ),
                              child: Row(children: [
                                Expanded(child: Text(
                                  '${_statusFilter} (${_countForStatus(_statusFilter)})',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  softWrap: false,
                                  style: TextStyle(
                                    color: _statusFilter == 'All' ? (Colors.orange[700] ?? Colors.orange) : Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'Arial',
                                    fontSize: 14,
                                  ),
                                )),
                                Icon(Icons.arrow_drop_down, color: Colors.orange[700] ?? Colors.orange, size: 20),
                              ]),
                            ),
                          ),
                        ),
                      ]),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      flex: 1,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('From Date', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: 16, fontWeight: FontWeight.w600) ?? const TextStyle(fontSize: 12, color: Colors.orange)),
                        const SizedBox(height: 6),
                        SizedBox(
                          width: double.infinity,
                          child: TextField(
                            controller: TextEditingController(text: _formatDate(_fromDate)),
                            readOnly: true,
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: const BorderRadius.all(Radius.circular(8)), borderSide: BorderSide(color: Colors.orange[600]!)),
                              enabledBorder: OutlineInputBorder(borderRadius: const BorderRadius.all(Radius.circular(8)), borderSide: BorderSide(color: Colors.orange[600]!)),
                              focusedBorder: OutlineInputBorder(borderRadius: const BorderRadius.all(Radius.circular(8)), borderSide: BorderSide(color: Colors.orange[600]!, width: 2)),
                              suffixIcon: IconButton(
                                icon: Icon(Icons.calendar_today, size: 18, color: Colors.orange[600]),
                                onPressed: _pickFromDate,
                              ),
                            ),
                          ),
                        ),
                      ]),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      flex: 1,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('To Date', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: 16, fontWeight: FontWeight.w600) ?? const TextStyle(fontSize: 12, color: Colors.orange)),
                        const SizedBox(height: 6),
                        SizedBox(
                          width: double.infinity,
                          child: TextField(
                            controller: TextEditingController(text: _formatDate(_toDate)),
                            readOnly: true,
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: const BorderRadius.all(Radius.circular(8)), borderSide: BorderSide(color: Colors.orange[600]!)),
                              enabledBorder: OutlineInputBorder(borderRadius: const BorderRadius.all(Radius.circular(8)), borderSide: BorderSide(color: Colors.orange[600]!)),
                              focusedBorder: OutlineInputBorder(borderRadius: const BorderRadius.all(Radius.circular(8)), borderSide: BorderSide(color: Colors.orange[600]!, width: 2)),
                              suffixIcon: IconButton(
                                icon: Icon(Icons.calendar_today, size: 18, color: Colors.orange[600]),
                                onPressed: _pickToDate,
                              ),
                            ),
                          ),
                        ),
                      ]),
                    ),
                  ]),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 140,
                  height: 40,
                  child: OutlinedButton.icon(
                    onPressed: _isApplying ? null : _applyFiltersAction,
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
              ]),
              const SizedBox(height: 12),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: q.snapshots(),
                  builder: (context, snap) {
                    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
                    if (snap.hasError) {
                      docs = _lastDocs;
                    } else {
                      docs = snap.data?.docs ?? const [];
                      if (snap.hasData) {
                        if (_lastDocs.isEmpty) {
                          Future.microtask(() { if (mounted) setState(() { _lastDocs = docs; }); });
                        } else {
                          _lastDocs = docs;
                        }
                      }
                    }
                    final rows = _applyClientFilters(docs);
                    return Column(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 8, offset: const Offset(0, 2))]),
                        child: Row(children: const [
                          Expanded(flex: 1, child: Text('Order No', style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w700, fontSize: 14))),
                          Expanded(flex: 2, child: Text('Staff In Charge', style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w700, fontSize: 14))),
                          Expanded(flex: 1, child: Text('Date', style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w700, fontSize: 14))),
                          Expanded(flex: 1, child: Text('Time', style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w700, fontSize: 14))),
                          Expanded(flex: 1, child: Text('Status', style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w700, fontSize: 14))),
                          SizedBox(width: 160, child: Text('Action', style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w700, fontSize: 14))),
                        ]),
                      ),
                      const SizedBox(height: 6),
                      Expanded(child: Container(
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 8, offset: const Offset(0, 2))]),
                        child: ListView.separated(
                          itemCount: rows.length,
                          separatorBuilder: (_, __) => Divider(color: Colors.grey[300], height: 1),
                          itemBuilder: (context, i) {
                            final d = rows[i];
                            final m = d.data();
                            final no = (m['orderNo'] ?? '').toString().padLeft(4, '0');
                            final staffName = (m['staffName'] ?? '').toString();
                            final ts = m['createdAt'];
                            final dt = ts is Timestamp ? ts.toDate() : DateTime.tryParse('$ts') ?? DateTime.now();
                            final st = (m['status'] ?? '').toString();
                            final timeStr = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              child: Row(children: [
                                Expanded(flex: 1, child: Text('#$no', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14))),
                                Expanded(flex: 2, child: Text(staffName.isEmpty ? '-' : staffName, style: const TextStyle(fontSize: 14))),
                                Expanded(flex: 1, child: Text(dt.toString().split(' ').first, style: const TextStyle(fontSize: 14))),
                                Expanded(flex: 1, child: Text(timeStr, style: const TextStyle(fontSize: 14))),
                                Expanded(flex: 1, child: Text(((st.toUpperCase() == 'PROCESSING') ? 'PREPARING' : st.toUpperCase()), style: TextStyle(color: _statusColor((st.toUpperCase() == 'PROCESSING') ? 'PREPARING' : st.toUpperCase()), fontWeight: FontWeight.w700, fontSize: 14))),
                                SizedBox(width: 160, child: _actionsFor(d)),
                              ]),
                            );
                          },
                        ),
                      )),
                    ]);
                  },
                ),
              ),
            ]),
          ),
        ),
        Container(width: 1, color: Colors.grey[300]),
        _detailPanel(),
      ]),
    );
  }
}