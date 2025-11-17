// staff management screen for franchise owner
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/user_model.dart';
import '../../models/franchise_model.dart';
import '../../services/auth_service.dart';
import 'view_staff_screen.dart';
import 'register_staff_screen.dart';
import '../../widgets/app_shell.dart';

class StaffManagementScreen extends StatefulWidget {
  final String franchiseId;

  const StaffManagementScreen({
    super.key,
    required this.franchiseId,
  });

  @override
  State<StaffManagementScreen> createState() => _StaffManagementScreenState();
}

class _StaffManagementScreenState extends State<StaffManagementScreen> {
  final _formKey = GlobalKey<FormBuilderState>(); // check form validation
  bool _isAddingStaff = false; // check if adding staff
  FranchiseModel? _franchise; // franchise data
  List<UserModel> _staffMembers = []; // staff members data

  // Filters & pagination
  String _searchQuery = '';
  String _selectedRole = 'All Roles'; // Default to All Roles
  String _selectedStatus = 'All Status'; // Default to All Status
  int _currentPage = 1;
  final int _pageSize = 10; // pagination set the record for 10 per page
  // toggle menu bar
  bool _isSideNavOpen = true;

  // Custom menu overlay for filter
  final GlobalKey _statusFilterKey = GlobalKey();
  OverlayEntry? _statusMenuOverlay;
  final GlobalKey _outletFilterKey = GlobalKey();
  OverlayEntry? _outletMenuOverlay;
  final GlobalKey _rolesFilterKey = GlobalKey();
  OverlayEntry? _rolesMenuOverlay;

  // Layer links to anchor overlays to filter widgets
  final LayerLink _statusLink = LayerLink();
  final LayerLink _outletLink = LayerLink();
  final LayerLink _rolesLink = LayerLink();
  bool _isApplying = false;

  @override
  void initState() {
    super.initState();
    final role = context.read<AuthProvider>().currentUser?.role;
    if (role == UserRole.supervisor) {
      _selectedRole = 'Staff';
    }
    _loadFranchiseData();
    _loadStaffMembers();
  }

  @override
  void dispose() {
    _statusMenuOverlay?.remove();
    _outletMenuOverlay?.remove();
    _rolesMenuOverlay?.remove();
    super.dispose();
  }

  // retrieve the franchise data from firebase
  Future<void> _loadFranchiseData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('franchises')
          .doc(widget.franchiseId)
          .get();
      
      if (doc.exists) {
        setState(() {
          _franchise = FranchiseModel.fromMap(doc.data()!);
        });
      }
    } catch (e) {
      print('Error loading franchise data: $e');
    }
  }

  // retrieve the members data from firebase
  Future<void> _loadStaffMembers() async {
    try {
      final users = FirebaseFirestore.instance.collection('users');
      final List<QuerySnapshot<Map<String, dynamic>>> snapshots = [];

      // franchiseId check
      snapshots.add(
        await users
            .where('franchiseId', isEqualTo: widget.franchiseId)
            .where('role', whereIn: ['staff', 'supervisor'])
            .get(),
      );

      // franchises for the franchise owner
      snapshots.add(
        await users
            .where('franchiseID.franchise', isEqualTo: widget.franchiseId)
            .where('role', whereIn: ['staff', 'supervisor'])
            .get(),
      );

      // check for franchises where member belongs to
      final franchiseRef = FirebaseFirestore.instance
          .collection('franchises')
          .doc(widget.franchiseId);
      snapshots.add(
        await users
            .where('franchiseID.franchise', isEqualTo: franchiseRef)
            .where('role', whereIn: ['staff', 'supervisor'])
            .get(),
      );

      // Merge and deduplicate by user id, while deriving a supervisor flag from role
      final Map<String, UserModel> unique = {};
      for (final snap in snapshots) {
        for (final doc in snap.docs) {
          final data = doc.data();
          var model = UserModel.fromMap(data);
          final roleStr = (data['role'] ?? '').toString();
          final isSupervisor = roleStr == 'supervisor' || (model.metadata?['isSupervisor'] == true);
          final mergedMeta = {
            ...(model.metadata ?? {}),
            'isSupervisor': isSupervisor,
          };
          model = model.copyWith(metadata: mergedMeta);
          unique[model.id] = model;
        }
      }

      setState(() {
        _staffMembers = unique.values.toList();
      });
    } catch (e) {
      print('Error loading staff members: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Access current user for header
    final authProvider = context.watch<AuthProvider>();
    final currentUserModel = authProvider.currentUser;
    // paginated lists
    final filtered = _getFilteredMembers();
    final displayed = _paginate(filtered);

    // check the screen size for responsive navigation bar
    final isLaptop = MediaQuery.of(context).size.width >= 1024;
    // computer the pagination total pages
    final totalPages = (filtered.length / _pageSize).ceil();

    return AppShell(
      activeItem: 'Staff',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Filters & Register Staff Button
            Container(
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
                children: [
                  Row(
                    children: [
                      // Search (light grey, borderless)
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: TextField(
                            decoration: const InputDecoration(
                              hintText: 'Search Staff Name',
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
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => RegisterStaffScreen(
                                  franchiseId: widget.franchiseId,
                                  franchiseName: _franchise?.name,
                                ),
                              ),
                            );
                          },
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
                              Text('REGISTER STAFF', style: TextStyle(letterSpacing: 0.5)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Filters + actions row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Outlet (custom menu)
                      _buildOutletFilter(),
                      const SizedBox(width: 8),
                      // Roles (custom menu)
                      _buildRolesFilter(),
                      const SizedBox(width: 8),
                      // Status (custom menu)
                      _buildStatusFilter(),
                      const SizedBox(width: 8),
                      // apply button
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
                      // clear button to reset filter
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
                  const SizedBox(height: 10),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Franchise Info Card
            if (_franchise != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.business, color: Colors.green[600], size: 32),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _franchise!.name,
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[800],
                                ),
                              ),
                              Text(
                                _franchise!.address,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // display total number of staff members, active, and pending
                    Row(
                      children: [
                        _buildInfoChip(
                          icon: Icons.people,
                          label: 'Staff Members',
                          value: '${_staffMembers.length}',
                          color: Colors.blue,
                        ),
                        const SizedBox(width: 12),
                        _buildInfoChip(
                          icon: Icons.check_circle,
                          label: 'Active',
                          value: '${_staffMembers.where((s) => s.status == UserStatus.active).length}',
                          color: Colors.green,
                        ),
                        const SizedBox(width: 12),
                        _buildInfoChip(
                          icon: Icons.pending,
                          label: 'Pending',
                          value: '${_staffMembers.where((s) => s.status != UserStatus.active).length}',
                          color: Colors.orange,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
            const SizedBox(height: 24),
            // Staff List Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 10,
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
                        child: Row(
                          children: [
                            Icon(Icons.people, color: Colors.green[600], size: 28),
                            const SizedBox(width: 12),
                            Text(
                              'Staff & Supervisors',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (totalPages > 1)
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
                  const SizedBox(height: 16),
                  if (displayed.isEmpty)
                    Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No staff members yet',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Add your first staff member using the "Register Staff" button',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[500],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTableHeader(),
                        const SizedBox(height: 8),
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: displayed.length,
                          separatorBuilder: (context, index) => const Divider(),
                          itemBuilder: (context, index) {
                            final staff = displayed[index];
                            return _buildStaffRow(staff);
                          },
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // for dashboard number of members, status chips
  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
  // for staff list tile filter by status
  Widget _buildStaffTile(UserModel staff) {
    Color statusColor;
    String statusText;
    IconData statusIcon;
    final isSupervisor = (staff.metadata?['isSupervisor'] == true);
    final roleLabel = isSupervisor ? 'Supervisor' : 'Staff';

    switch (staff.status) {
      case UserStatus.pending:
        statusColor = Colors.orange;
        statusText = 'Pending Setup';
        statusIcon = Icons.schedule;
        break;
      case UserStatus.emailVerified:
        statusColor = Colors.blue;
        statusText = 'Email Verified';
        statusIcon = Icons.email;
        break;
      case UserStatus.phoneVerified:
        statusColor = Colors.purple;
        statusText = 'Phone Verified';
        statusIcon = Icons.phone;
        break;
      case UserStatus.active:
        statusColor = Colors.green;
        statusText = 'Active';
        statusIcon = Icons.check_circle;
        break;
      case UserStatus.suspended:
        statusColor = Colors.red;
        statusText = 'Suspended';
        statusIcon = Icons.block;
        break;
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
      leading: CircleAvatar(
        backgroundColor: Colors.green[100],
        backgroundImage: (() {
          final meta = staff.metadata ?? {};
          final url = meta['photoUrl'];
          if (url is String && url.isNotEmpty) {
            return NetworkImage(url);
          }
          return null;
        })(),
        child: (() {
          final meta = staff.metadata ?? {};
          final url = meta['photoUrl'];
          if (url is String && url.isNotEmpty) {
            return null;
          }
          return Text(
            '${staff.firstName.isNotEmpty ? staff.firstName[0] : ''}${staff.lastName.isNotEmpty ? staff.lastName[0] : ''}',
            style: TextStyle(
              color: Colors.green[700],
              fontWeight: FontWeight.bold,
            ),
          );
        })(),
      ),
      title: Text(
        staff.fullName,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Role label
          Text(
            roleLabel,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(staff.email),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(statusIcon, size: 16, color: statusColor),
              const SizedBox(width: 4),
              Text(
                statusText,
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (value) => _handleStaffAction(value, staff),
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'resend_email',
            child: Row(
              children: [
                Icon(Icons.email, size: 18),
                SizedBox(width: 8),
                Text('Resend Email'),
              ],
            ),
          ),
          if (staff.status != UserStatus.suspended)
            const PopupMenuItem(
              value: 'suspend',
              child: Row(
                children: [
                  Icon(Icons.block, size: 18, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Suspend', style: TextStyle(color: Colors.red)),
                ],
              ),
            )
          else
            const PopupMenuItem(
              value: 'activate',
              child: Row(
                children: [
                  Icon(Icons.check_circle, size: 18, color: Colors.green),
                  SizedBox(width: 8),
                  Text('Activate', style: TextStyle(color: Colors.green)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // for staff list tile filter by status
  Widget _buildStaffRow(UserModel staff) {
    final isSupervisor = (staff.metadata?['isSupervisor'] == true);
    final roleLabel = isSupervisor ? 'Supervisor' : 'Staff';
    final years = _yearsSince(staff.createdAt);
    final outlet = _franchise?.name ?? 'Outlet';

    // Restrict status options to core statuses only
    final statusItems = const ['Active', 'Pending', 'Suspended'];
    // Canonicalize display for non-core statuses to 'Pending'
    final statusLabel = _canonicalStatusLabel(staff.status);
    final statusColor = _statusColor(_statusFromLabel(statusLabel));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          // Staff Name with avatar
          Expanded(
            flex: 3,
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.green[100],
                  backgroundImage: (() {
                    final meta = staff.metadata ?? {};
                    final url = meta['photoUrl'];
                    if (url is String && url.isNotEmpty) {
                      return NetworkImage(url);
                    }
                    return null;
                  })(),
                  child: (() {
                    final meta = staff.metadata ?? {};
                    final url = meta['photoUrl'];
                    if (url is String && url.isNotEmpty) {
                      return null;
                    }
                    return Text(
                      '${staff.firstName.isNotEmpty ? staff.firstName[0] : ''}${staff.lastName.isNotEmpty ? staff.lastName[0] : ''}',
                      style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.bold),
                    );
                  })(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(staff.fullName, style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text('$years Year(s)', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Roles
          Expanded(
            flex: 2,
            child: Text(roleLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          // Outlet
          Expanded(
            flex: 2,
            child: Text(outlet),
          ),
          // Status with pill and dropdown
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  DropdownButtonHideUnderline(
                    child: Theme(
                      data: Theme.of(context).copyWith(
                        splashColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                        hoverColor: Colors.transparent,
                        focusColor: Colors.transparent,
                        splashFactory: NoSplash.splashFactory,
                      ),
                      child: DropdownButton<String>(
                        value: statusLabel,
                        elevation: 0,
                        style: const TextStyle(fontFamily: 'Arial', fontWeight: FontWeight.w600, color: Colors.black87),
                        icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
                        items: statusItems.map((e) {
                          return DropdownMenuItem<String>(
                            value: e,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                              child: Text(e),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val == null) return;
                          final newStatus = _statusFromLabel(val);
                          _updateStaffStatus(staff, newStatus, successText: 'Status updated');
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Actions for edit and view button
          Expanded(
            flex: 2,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.orange),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ViewStaffScreen(
                          staff: staff,
                          franchiseName: _franchise?.name,
                          startEditing: true,
                        ),
                      ),
                    );
                  },
                  child: const Icon(Icons.edit, color: Colors.orange, size: 18),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.orange),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ViewStaffScreen(
                          staff: staff,
                          franchiseName: _franchise?.name,
                        ),
                      ),
                    );
                  },
                  child: const Icon(Icons.visibility, color: Colors.orange, size: 18),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Table header for Staff & Supervisor list
  Widget _buildTableHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            // Match flex with _buildStaffRow
            Expanded(flex: 3, child: Text('Staff Name', style: TextStyle(color: Colors.grey))),
            Expanded(flex: 2, child: Text('Roles', style: TextStyle(color: Colors.grey))),
            Expanded(flex: 2, child: Text('Outlet', style: TextStyle(color: Colors.grey))),
            Expanded(flex: 2, child: Text('Status', style: TextStyle(color: Colors.grey))),
            Expanded(flex: 2, child: Text('Action', style: TextStyle(color: Colors.grey))),
          ],
        ),
        const Divider(),
      ],
    );
  }

  // Helpers for filters/pagination/status
  List<UserModel> _getFilteredMembers() {
    Iterable<UserModel> list = _staffMembers;

    // Search by name or email
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((u) =>
          u.fullName.toLowerCase().contains(q) ||
          u.email.toLowerCase().contains(q));
    }

    // Role filter
    if (_selectedRole != 'All Roles') {
      list = list.where((u) {
        final isSupervisor = (u.metadata?['isSupervisor'] == true);
        final roleLabel = isSupervisor ? 'Supervisor' : 'Staff';
        return roleLabel == _selectedRole || (_selectedRole == 'Manager' && isSupervisor);
      });
    }

    // Status filter
    if (_selectedStatus != 'All Status') {
      list = list.where((u) => _statusLabel(u.status) == _selectedStatus);
    }

    return list.toList();
  }

  // pagination function to list the number of members
  List<UserModel> _paginate(List<UserModel> input) {
    final start = (_currentPage - 1) * _pageSize;
    final end = math.min(start + _pageSize, input.length);
    if (start >= input.length) return [];
    return input.sublist(start, end);
  }

  // compute the members years according to the createdAt TimeStamp
  int _yearsSince(DateTime start) {
    final now = DateTime.now();
    int years = now.year - start.year;
    final anniversary = DateTime(start.year + years, start.month, start.day);
    if (anniversary.isAfter(now)) years -= 1;
    return years.clamp(0, 50);
  }

  // function for status
  String _statusLabel(UserStatus status) {
    switch (status) {
      case UserStatus.active:
        return 'Active';
      case UserStatus.pending:
        return 'Pending';
      case UserStatus.suspended:
        return 'Suspended';
      case UserStatus.emailVerified:
        return 'Email Verified';
      case UserStatus.phoneVerified:
        return 'Phone Verified';
    }
  }

  // Canonical label for display
  String _canonicalStatusLabel(UserStatus status) {
    switch (status) {
      case UserStatus.active:
        return 'Active';
      case UserStatus.suspended:
        return 'Suspended';
      default:
        return 'Pending';
    }
  }

  // color for each status
  Color _statusColor(UserStatus status) {
    switch (status) {
      case UserStatus.active:
        return Colors.green;
      case UserStatus.pending:
        return Colors.orange;
      case UserStatus.suspended:
        return Colors.red;
      case UserStatus.emailVerified:
        return Colors.blue;
      case UserStatus.phoneVerified:
        return Colors.purple;
    }
  }

  // function to convert status label to status enum
  UserStatus _statusFromLabel(String label) {
    switch (label) {
      case 'Active':
        return UserStatus.active;
      case 'Pending':
        return UserStatus.pending;
      case 'Suspended':
        return UserStatus.suspended;
      case 'Email Verified':
        return UserStatus.emailVerified;
      case 'Phone Verified':
        return UserStatus.phoneVerified;
      default:
        return UserStatus.active;
    }
  }

  // function to count the number of members for each role
  int _countForRole(String role) {
    if (role == 'All Roles') return _staffMembers.length;
    return _staffMembers.where((u) {
      final isSupervisor = (u.metadata?['isSupervisor'] == true);
      final label = isSupervisor ? 'Supervisor' : 'Staff';
      if (role == 'Manager') {
        // Map Manager to Supervisor for now
        return isSupervisor;
      }
      return label == role;
    }).length;
  }

  // function to count the number of members for each status
  int _countForStatus(String statusLabel) {
    if (statusLabel == 'All Status') return _staffMembers.length;
    final target = _statusFromLabel(statusLabel);
    return _staffMembers.where((u) => u.status == target).length;
  }

  // function to build the filter dropdown
  Widget _buildFilterDropdown<T>({
    required String label,
    required T value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
    TextStyle? labelStyle,
    Color? backgroundColor,
    TextStyle? textStyle,
    Color? dropdownColor,
    Color? selectedColor,
    Color? unselectedColor,
    bool darkClosedBackground = false,
    String Function(T?)? getCountLabel,
  }) {
    return Expanded(
      flex: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: labelStyle ?? const TextStyle(fontSize: 12, color: Colors.orange)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: backgroundColor ?? Colors.orange[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange),
            ),
            child: DropdownButtonHideUnderline(
              child: Theme(
                data: Theme.of(context).copyWith(
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  hoverColor: Colors.transparent,
                  focusColor: Colors.transparent,
                  splashFactory: NoSplash.splashFactory,
                ),
                child: DropdownButton<T>(
                  isExpanded: true,
                  value: value,
                  style: textStyle,
                  dropdownColor: dropdownColor,
                  elevation: 0,
                icon: Icon(
                  Icons.arrow_drop_down,
                  // Use orange for the chevron instead of grey/white
                  color: (Colors.orange[700] ?? Colors.orange[700]),
                ),
                  selectedItemBuilder: (ctx) => items.map((e) {
                    final suffix = getCountLabel != null ? getCountLabel(e) : '';
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Text(
                          '${e}$suffix',
                          style: TextStyle(
                            color: darkClosedBackground ? Colors.white : (Colors.orange[700] ?? Colors.orange),
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Arial',
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                  items: items.map((e) {
                    final suffix = getCountLabel != null ? getCountLabel(e) : '';
                    final isSelected = e == value;
                    return DropdownMenuItem<T>(
                      value: e,
                      child: isSelected
                          ? Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 0),
                              color: selectedColor ?? Colors.orange[600],
                              child: Text(
                                '${e}$suffix',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Arial',
                                ),
                              ),
                            )
                          : Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 0),
                              color: unselectedColor ?? Colors.orange[50],
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                  '${e}$suffix',
                                  style: TextStyle(
                                    color: (Colors.orange[700] ?? Colors.orange),
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'Arial',
                                  ),
                                ),
                              ),
                            ),
                    );
                  }).toList(),
                  onChanged: onChanged,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // function to build the page button for pagination
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

  // Custom Status filter drop down list
  Widget _buildStatusFilter() {
    final labelStyle = Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: 16, fontWeight: FontWeight.w600);
    final isDarkClosed = _selectedStatus != 'All Status';
    final closedBg = _selectedStatus == 'All Status' ? Colors.orange[50] : Colors.orange[600];
    final arrowColor = Colors.orange[700] ?? Colors.orange;
    final countLabel = ' (${_countForStatus(_selectedStatus)})';

    return Expanded(
      child: Column(
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
              decoration: BoxDecoration(
                color: closedBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '$_selectedStatus$countLabel',
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
                  Icon(Icons.arrow_drop_down, color: arrowColor, size: 20),
                ],
              ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // function to show the status filter menu
  void _showStatusMenu() {
    _hideStatusMenu();

    final ctx = _statusFilterKey.currentContext;
    if (ctx == null) return;
    final renderObject = ctx.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return;
    final renderBox = renderObject as RenderBox;
    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);

    final baseItems = const ['All Status', 'Active', 'Pending', 'Suspended'];
    final items = [_selectedStatus, ...baseItems.where((e) => e != _selectedStatus)];

    _statusMenuOverlay = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            // Dismiss area
            Positioned.fill(
              child: GestureDetector(behavior: HitTestBehavior.translucent, onTap: _hideStatusMenu),
            ),
            CompositedTransformFollower(
              link: _statusLink,
              showWhenUnlinked: false,
              offset: Offset(0, size.height + 4),
              child: SizedBox(
                width: math.max(size.width, 1),
                child: Material(
                  elevation: 6,
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: items.map((e) {
                        final isSelected = e == _selectedStatus;
                        final rowColor = isSelected ? Colors.orange[600] : Colors.orange[50];
                        final textColor = isSelected ? Colors.white : (Colors.orange[700] ?? Colors.orange);
                        final count = ' (${_countForStatus(e)})';
                        return InkWell(
                          onTap: () {
                            setState(() => _selectedStatus = e);
                            _hideStatusMenu();
                          },
                          splashColor: Colors.transparent,
                          highlightColor: Colors.transparent,
                          hoverColor: Colors.transparent,
                          child: Container(
                            color: rowColor,
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                            child: Text(
                              '$e$count',
                              style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontFamily: 'Arial'),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
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

  // Custom Outlet filter drop down list
  Widget _buildOutletFilter() {
    final labelStyle = Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: 16, fontWeight: FontWeight.w600);
    final outletLabel = _franchise?.name ?? 'All Outlet';
    final isDarkClosed = outletLabel != 'All Outlet';
    final closedBg = outletLabel == 'All Outlet' ? Colors.orange[50] : Colors.orange[600];
    final arrowColor = Colors.orange[700] ?? Colors.orange;
    final countLabel = ' (${_staffMembers.length})';

    return Expanded(
      flex: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Outlet', style: labelStyle ?? const TextStyle(fontSize: 12, color: Colors.orange)),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () {
              final role = context.read<AuthProvider>().currentUser?.role;
              if (role == UserRole.supervisor) return;
              _showOutletMenu();
            },
            child: CompositedTransformTarget(
              link: _outletLink,
              child: Container(
              key: _outletFilterKey,
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
                      '$outletLabel$countLabel',
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
                  Icon(Icons.arrow_drop_down, color: arrowColor, size: 20),
                ],
              ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showOutletMenu() {
    _hideOutletMenu();

    final ctx = _outletFilterKey.currentContext;
    if (ctx == null) return;
    final renderObject = ctx.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return;
    final renderBox = renderObject as RenderBox;
    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);

    final items = <String>[_franchise?.name ?? 'All Outlet'];

    _outletMenuOverlay = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            Positioned.fill(child: GestureDetector(behavior: HitTestBehavior.translucent, onTap: _hideOutletMenu)),
            CompositedTransformFollower(
              link: _outletLink,
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
                      final isSelected = true; // Outlet is display-only
                      final rowColor = isSelected ? Colors.orange[600] : Colors.orange[50];
                      final textColor = isSelected ? Colors.white : (Colors.orange[700] ?? Colors.orange);
                      final count = ' (${_staffMembers.length})';
                      return InkWell(
                        onTap: _hideOutletMenu,
                        splashColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                        hoverColor: Colors.transparent,
                        child: Container(
                          color: rowColor,
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                          child: Text(
                            '$e$count',
                            style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontFamily: 'Arial'),
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

    Overlay.of(context).insert(_outletMenuOverlay!);
  }

  void _hideOutletMenu() {
    _outletMenuOverlay?.remove();
    _outletMenuOverlay = null;
  }

  // Custom Roles filter drop down list
  Widget _buildRolesFilter() {
    final labelStyle = Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: 16, fontWeight: FontWeight.w600);
    final isDarkClosed = _selectedRole != 'All Roles';
    final closedBg = _selectedRole == 'All Roles' ? Colors.orange[50] : Colors.orange[600];
    final arrowColor = Colors.orange[700] ?? Colors.orange;
    final countLabel = ' (${_countForRole(_selectedRole)})';

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Roles', style: labelStyle ?? const TextStyle(fontSize: 12, color: Colors.orange)),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () {
              final role = context.read<AuthProvider>().currentUser?.role;
              if (role == UserRole.supervisor) return;
              _showRolesMenu();
            },
            child: CompositedTransformTarget(
              link: _rolesLink,
              child: Container(
              key: _rolesFilterKey,
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
                      '$_selectedRole$countLabel',
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
                  Icon(Icons.arrow_drop_down, color: arrowColor, size: 20),
                ],
              ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showRolesMenu() {
    _hideRolesMenu();

    final ctx = _rolesFilterKey.currentContext;
    if (ctx == null) return;
    final renderObject = ctx.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return;
    final renderBox = renderObject as RenderBox;
    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);

    final baseItems = const ['All Roles', 'Staff', 'Supervisor'];
    final items = [_selectedRole, ...baseItems.where((e) => e != _selectedRole)];

    _rolesMenuOverlay = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            Positioned.fill(child: GestureDetector(behavior: HitTestBehavior.translucent, onTap: _hideRolesMenu)),
            CompositedTransformFollower(
              link: _rolesLink,
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
                      final isSelected = e == _selectedRole;
                      final rowColor = isSelected ? Colors.orange[600] : Colors.orange[50];
                      final textColor = isSelected ? Colors.white : (Colors.orange[700] ?? Colors.orange);
                      final count = ' (${_countForRole(e)})';
                      return InkWell(
                        onTap: () {
                          setState(() => _selectedRole = e);
                          _hideRolesMenu();
                        },
                        splashColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                        hoverColor: Colors.transparent,
                        child: Container(
                          color: rowColor,
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                          child: Text(
                            '$e$count',
                            style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontFamily: 'Arial'),
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

    Overlay.of(context).insert(_rolesMenuOverlay!);
  }

  void _hideRolesMenu() {
    _rolesMenuOverlay?.remove();
    _rolesMenuOverlay = null;
  }

  // Apply filters: close open menus, unfocus inputs, and reset to page 1
  void _applyFilters() {
    if (_isApplying) return;
    // mark applying to debounce and avoid stutter
    setState(() {
      _isApplying = true;
    });
    // Close overlays to avoid intercepting taps
    _hideStatusMenu();
    _hideRolesMenu();
    _hideOutletMenu();
    // Unfocus any active text fields 
    FocusScope.of(context).unfocus();
    // Trigger rebuild and ensure pagination starts from first page
    setState(() {
      _currentPage = 1;
    });
    // Release the button shortly after UI settles
    Future.delayed(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      setState(() {
        _isApplying = false;
      });
    });
  }

  // Clear filters: reset Roles and Status selections and pagination
  void _clearFilters() {
    setState(() {
      _selectedRole = 'All Roles';
      _selectedStatus = 'All Status';
      _currentPage = 1;
    });
    // Close any open overlays
    _hideStatusMenu();
    _hideRolesMenu();
    _hideOutletMenu();
  }

  // Register Staff dialog
  void _showRegisterStaffDialog() {
    final dialogFormKey = GlobalKey<FormBuilderState>();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Register Staff'),
          content: SizedBox(
            width: 500,
            child: FormBuilder(
              key: dialogFormKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FormBuilderTextField(
                    name: 'firstName',
                    decoration: const InputDecoration(labelText: 'First Name'),
                    validator: FormBuilderValidators.compose([
                      FormBuilderValidators.required(),
                      FormBuilderValidators.minLength(2),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  FormBuilderTextField(
                    name: 'lastName',
                    decoration: const InputDecoration(labelText: 'Last Name'),
                    validator: FormBuilderValidators.compose([
                      FormBuilderValidators.required(),
                      FormBuilderValidators.minLength(2),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  FormBuilderTextField(
                    name: 'email',
                    decoration: const InputDecoration(labelText: 'Email Address'),
                    validator: FormBuilderValidators.compose([
                      FormBuilderValidators.required(),
                      FormBuilderValidators.email(),
                    ]),
                    keyboardType: TextInputType.emailAddress,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (dialogFormKey.currentState?.saveAndValidate() != true) return;
                final values = dialogFormKey.currentState!.value;
                setState(() => _isAddingStaff = true);
                try {
                  final resp = await AuthService.registerStaff(
                    franchiseId: widget.franchiseId,
                    email: values['email'] as String,
                    firstName: values['firstName'] as String,
                    lastName: values['lastName'] as String,
                    franchiseOwnerId: AuthService.currentUser!.uid,
                  );
                  if (resp.success) {
                    if (mounted) {
                      Navigator.of(ctx).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Staff member registered')),
                      );
                      await _loadStaffMembers();
                    }
                  } else {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(resp.message ?? 'Registration failed'), backgroundColor: Colors.red),
                      );
                    }
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Registration failed: $e'), backgroundColor: Colors.red),
                    );
                  }
                } finally {
                  if (mounted) setState(() => _isAddingStaff = false);
                }
              },
              child: const Text('Register'),
            ),
          ],
        );
      },
    );
  }

  // Bottom navigation for tablet screen size
  Widget _buildBottomNav() {
    return BottomAppBar(
      color: Colors.orange[50],
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _navItem(Icons.menu, 'Menu', onTap: () {/* future route */}),
            _navItem(Icons.list_alt, 'Order List', onTap: () {/* future route */}),
            _navItem(Icons.people, 'Staff', active: true, onTap: () {}),
            _navItem(Icons.local_offer, 'Product', onTap: () {/* future route */}),
            _navItem(Icons.kitchen, 'Ingredient', onTap: () {/* future route */}),
            _navItem(Icons.inventory_2, 'Inventory', onTap: () {/* future route */}),
            _navItem(Icons.health_and_safety, 'Hygiene', onTap: () {/* future route */}),
            _navItem(Icons.bar_chart, 'Report', onTap: () {/* future route */}),
          ],
        ),
      ),
    );
  }

  // Navigation item for bottom navigation bar
  Widget _navItem(IconData icon, String label, {bool active = false, required VoidCallback onTap}) {
    final color = active ? Colors.orange[700] : Colors.black87;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: color, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  // Side navigation for wide screens
  Widget _buildSideNav() {
    return Container(
      width: 180,
      color: Colors.orange[50],
      child: Column(
        children: [
          const SizedBox(height: 12),
          _sideNavItem(Icons.menu, 'Menu', onTap: () {/* future route */}),
          _sideNavItem(Icons.list_alt, 'Order List', onTap: () {/* future route */}),
          _sideNavItem(Icons.people, 'Staff', active: true, onTap: () {}),
          _sideNavItem(Icons.local_offer, 'Product', onTap: () {/* future route */}),
          _sideNavItem(Icons.kitchen, 'Ingredient', onTap: () {/* future route */}),
          _sideNavItem(Icons.inventory_2, 'Inventory', onTap: () {/* future route */}),
          _sideNavItem(Icons.health_and_safety, 'Hygiene', onTap: () {/* future route */}),
          _sideNavItem(Icons.bar_chart, 'Report', onTap: () {/* future route */}),
        ],
      ),
    );
  }

  // Side navigation item for side navigation bar
  Widget _sideNavItem(IconData icon, String label, {bool active = false, required VoidCallback onTap}) {
    final color = active ? (Colors.orange[700] ?? Colors.orange) : Colors.black87;
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: active ? (Colors.orange[700] ?? Colors.orange) : Colors.transparent, width: 3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600))),
          ],
        ),
      ),
    );
  }

  // Header helpers
  String _initials(String? firstName, String? lastName) {
    final f = (firstName ?? '').trim();
    final l = (lastName ?? '').trim();
    String i1 = f.isNotEmpty ? f[0] : '';
    String i2 = l.isNotEmpty ? l[0] : '';
    return (i1 + i2).toUpperCase();
  }

  // Helper method to format login time
  String _formatLoginTime(DateTime? dt) {
    if (dt == null) return '-';
    // Format as DD/MM/YYYY hh:mm am/pm
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final year = dt.year.toString();
    int hour = dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = hour >= 12 ? 'pm' : 'am';
    hour = hour % 12;
    if (hour == 0) hour = 12;
    return '$day/$month/$year $hour:$minute $ampm';
  }

  // Helper method to handle adding staff member
  Future<void> _handleAddStaff() async {
    if (!_formKey.currentState!.saveAndValidate()) {
      return;
    }

    setState(() => _isAddingStaff = true);

    try {
      final formData = _formKey.currentState!.value;
      final currentUser = AuthService.currentUser;
      
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final response = await AuthService.registerStaff(
        franchiseId: widget.franchiseId,
        email: formData['email'],
        firstName: formData['firstName'],
        lastName: formData['lastName'],
        franchiseOwnerId: currentUser.uid,
      );

      if (response.success) {
        _formKey.currentState!.reset();
        await _loadStaffMembers();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.message ?? 'Staff member added successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.message ?? 'Failed to add staff member'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isAddingStaff = false);
      }
    }
  }

  // Helper method to handle staff actions
  void _handleStaffAction(String action, UserModel staff) {
    switch (action) {
      case 'resend_email':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Resend email functionality coming soon')),
        );
        break;
      case 'suspend':
        _updateStaffStatus(staff, UserStatus.suspended, successText: 'Staff account suspended');
        break;
      case 'activate':
        _updateStaffStatus(staff, UserStatus.active, successText: 'Staff account activated');
        break;
    }
  }

  // Helper method to update staff status
  Future<void> _updateStaffStatus(UserModel staff, UserStatus status, {required String successText}) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(staff.id).update({
        'status': status.toString().split('.').last,
      });
      // Refresh list to reflect changes
      await _loadStaffMembers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(successText)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e')),
        );
      }
    }
  }
}