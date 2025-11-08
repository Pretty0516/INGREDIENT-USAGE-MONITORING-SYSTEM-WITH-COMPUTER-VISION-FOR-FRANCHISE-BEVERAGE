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
  final _formKey = GlobalKey<FormBuilderState>();
  bool _isAddingStaff = false;
  FranchiseModel? _franchise;
  List<UserModel> _staffMembers = [];
  // Filters & pagination
  String _searchQuery = '';
  String _selectedRole = 'Staff'; // Only Staff and Supervisor selectable
  String _selectedStatus = 'All Status'; // All Status, Active, Pending, Suspended
  int _currentPage = 1;
  final int _pageSize = 10;

  // Custom menu overlay for Status filter
  final GlobalKey _statusFilterKey = GlobalKey();
  OverlayEntry? _statusMenuOverlay;

  @override
  void initState() {
    super.initState();
    _loadFranchiseData();
    _loadStaffMembers();
  }

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

  Future<void> _loadStaffMembers() async {
    try {
      final users = FirebaseFirestore.instance.collection('users');

      // We support multiple possible schemas:
      // 1) Legacy string field: `franchiseId: <id>`
      // 2) Map field: `franchiseID.franchise: <id>` (string)
      // 3) Map field: `franchiseID.franchise: <DocumentReference>`
      // And we include both staff and supervisor roles.

      final List<QuerySnapshot<Map<String, dynamic>>> snapshots = [];

      // Legacy string franchiseId
      snapshots.add(
        await users
            .where('franchiseId', isEqualTo: widget.franchiseId)
            .where('role', whereIn: ['staff', 'supervisor'])
            .get(),
      );

      // Map with string id
      snapshots.add(
        await users
            .where('franchiseID.franchise', isEqualTo: widget.franchiseId)
            .where('role', whereIn: ['staff', 'supervisor'])
            .get(),
      );

      // Map with DocumentReference
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
    // Pre-compute filtered and paginated lists — avoid declarations inside widget lists
    final filtered = _getFilteredMembers();
    final displayed = _paginate(filtered);
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(72),
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                // Profile icon
                CircleAvatar(
                  radius: 22,
                  backgroundColor: Colors.green[100],
                  child: Text(
                    _initials(currentUserModel?.firstName, currentUserModel?.lastName),
                    style: TextStyle(
                      color: Colors.green[700],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Name and login time
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        currentUserModel?.fullName ?? 'User',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Logged in since: ${_formatLoginTime(currentUserModel?.lastLoginAt)}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                // Notifications icon
                Stack(
                  alignment: Alignment.topRight,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications_none),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Notifications coming soon')),
                        );
                      },
                    ),
                    // Optional badge (static for now)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                        child: const Text(' ', style: TextStyle(color: Colors.white, fontSize: 10)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Filters & Register Staff
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
                                hintText: 'Search',
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
                            onPressed: _showRegisterStaffDialog,
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
                    Row(
                      children: [
                        // Outlet (single franchise name shown)
                        _buildFilterDropdown<String>(
                          label: 'Outlet',
                          value: _franchise?.name ?? 'All Outlet',
                          items: [
                            _franchise?.name ?? 'All Outlet',
                          ],
                          onChanged: (_) {}, // Only display
                          labelStyle: Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
                          backgroundColor: (_franchise?.name ?? 'All Outlet') == 'All Outlet' ? Colors.orange[50] : Colors.orange[600],
                          textStyle: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
                          dropdownColor: Colors.orange[600],
                          selectedColor: Colors.orange[600],
                          unselectedColor: Colors.orange[50],
                          darkClosedBackground: (_franchise?.name ?? 'All Outlet') != 'All Outlet',
                          // Show count beside current value
                          getCountLabel: (val) => ' (${_staffMembers.length})',
                        ),
                        const SizedBox(width: 12),
                        // Roles
                        _buildFilterDropdown<String>(
                          label: 'Roles',
                          value: _selectedRole,
                          items: const ['Staff', 'Supervisor'],
                          onChanged: (val) => setState(() => _selectedRole = val ?? 'Staff'),
                          labelStyle: Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
                          backgroundColor: Colors.orange[600],
                          textStyle: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
                          dropdownColor: Colors.orange[600],
                          selectedColor: Colors.orange[600],
                          unselectedColor: Colors.orange[50],
                          darkClosedBackground: true,
                          getCountLabel: (val) => ' (${_countForRole(val ?? 'Staff')})',
                        ),
                        const SizedBox(width: 12),
                        // Status (custom full-width menu)
                        _buildStatusFilter(),
                        const SizedBox(width: 12),
                        SizedBox(
                          height: 40,
                          child: OutlinedButton.icon(
                            onPressed: () => setState(() => _currentPage = 1),
                            icon: Icon(Icons.filter_alt, color: Colors.orange[600]),
                            label: const Text('APPLY FILTER'),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Colors.orange[600]!),
                              foregroundColor: Colors.orange[600],
                              backgroundColor: Colors.white,
                              textStyle: const TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.5),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                        const Spacer(),
                        // Simple pagination control
                        Row(
                          children: [
                            _buildPageButton(1),
                            const SizedBox(width: 6),
                            _buildPageButton(2),
                            const SizedBox(width: 6),
                            _buildPageButton(3),
                            const SizedBox(width: 6),
                            _buildPageButton(4),
                          ],
                        ),
                      ],
                    ),
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

              // Add Staff Section
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
                        Icon(Icons.person_add, color: Colors.green[600], size: 28),
                        const SizedBox(width: 12),
                        Text(
                          'Add New Staff Member',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    FormBuilder(
                      key: _formKey,
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: FormBuilderTextField(
                                  name: 'firstName',
                                  decoration: InputDecoration(
                                    labelText: 'First Name',
                                    prefixIcon: const Icon(Icons.person),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    filled: true,
                                    fillColor: Colors.grey[50],
                                  ),
                                  validator: FormBuilderValidators.compose([
                                    FormBuilderValidators.required(),
                                    FormBuilderValidators.minLength(2),
                                  ]),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: FormBuilderTextField(
                                  name: 'lastName',
                                  decoration: InputDecoration(
                                    labelText: 'Last Name',
                                    prefixIcon: const Icon(Icons.person),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    filled: true,
                                    fillColor: Colors.grey[50],
                                  ),
                                  validator: FormBuilderValidators.compose([
                                    FormBuilderValidators.required(),
                                    FormBuilderValidators.minLength(2),
                                  ]),
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 16),
                          
                          FormBuilderTextField(
                            name: 'email',
                            decoration: InputDecoration(
                              labelText: 'Email Address',
                              prefixIcon: const Icon(Icons.email),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.grey[50],
                              helperText: 'Staff will receive login credentials via email',
                            ),
                            validator: FormBuilderValidators.compose([
                              FormBuilderValidators.required(),
                              FormBuilderValidators.email(),
                            ]),
                            keyboardType: TextInputType.emailAddress,
                          ),
                          
                          const SizedBox(height: 24),
                          
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed: _isAddingStaff ? null : _handleAddStaff,
                              icon: _isAddingStaff
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : const Icon(Icons.person_add),
                              label: Text(_isAddingStaff ? 'Adding Staff...' : 'Add Staff Member'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green[600],
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
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
                    const SizedBox(height: 16),
                    
                    if (filtered.isEmpty)
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
                              'Add your first staff member using the form above',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.grey[500],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    else
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
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

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
        child: Text(
          '${staff.firstName[0]}${staff.lastName[0]}',
          style: TextStyle(
            color: Colors.green[700],
            fontWeight: FontWeight.bold,
          ),
        ),
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

  // New table-style row to match design
  Widget _buildStaffRow(UserModel staff) {
    final isSupervisor = (staff.metadata?['isSupervisor'] == true);
    final roleLabel = isSupervisor ? 'Supervisor' : 'Staff';
    final years = _yearsSince(staff.createdAt);
    final outlet = _franchise?.name ?? 'Outlet';

    // Status pill color and dropdown items
    final statusItems = const [
      'Active', 'Pending', 'Suspended', 'Email Verified', 'Phone Verified'
    ];
    final statusLabel = _statusLabel(staff.status);
    final statusColor = _statusColor(staff.status);

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
                  child: Text(
                    '${staff.firstName.isNotEmpty ? staff.firstName[0] : ''}${staff.lastName.isNotEmpty ? staff.lastName[0] : ''}',
                    style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.bold),
                  ),
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
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: statusColor.withOpacity(0.2)),
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
                        dropdownColor: Colors.orange[600],
                        elevation: 0,
                        icon: Icon(
                          Icons.arrow_drop_down,
                          color: (Colors.orange[700] ?? Colors.orange[700]),
                        ),
                        items: statusItems.map((e) {
                          final isSelected = e == statusLabel;
                          return DropdownMenuItem<String>(
                            value: e,
                            child: isSelected
                                ? Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 0),
                                    color: Colors.orange[600],
                                    child: Text(
                                      e,
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                                    ),
                                  )
                                : Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 0),
                                    color: Colors.orange[50],
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      child: Text(
                                        e,
                                        style: TextStyle(
                                          color: (Colors.orange[700] ?? Colors.orange),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
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
          // Actions
          Expanded(
            flex: 2,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: 'Edit',
                  icon: const Icon(Icons.edit),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Edit coming soon')),
                    );
                  },
                ),
                const SizedBox(width: 6),
                IconButton(
                  tooltip: 'View',
                  icon: const Icon(Icons.remove_red_eye),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('View coming soon')),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
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

  List<UserModel> _paginate(List<UserModel> input) {
    final start = (_currentPage - 1) * _pageSize;
    final end = math.min(start + _pageSize, input.length);
    if (start >= input.length) return [];
    return input.sublist(start, end);
  }

  int _yearsSince(DateTime start) {
    final now = DateTime.now();
    int years = now.year - start.year;
    final anniversary = DateTime(start.year + years, start.month, start.day);
    if (anniversary.isAfter(now)) years -= 1;
    return years.clamp(0, 50);
  }

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

  int _countForStatus(String statusLabel) {
    if (statusLabel == 'All Status') return _staffMembers.length;
    final target = _statusFromLabel(statusLabel);
    return _staffMembers.where((u) => u.status == target).length;
  }

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
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
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

  // Custom Status filter with edge-to-edge menu items
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
            child: Container(
              key: _statusFilterKey,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: closedBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$_selectedStatus$countLabel',
                    style: TextStyle(
                      color: isDarkClosed ? Colors.white : (Colors.orange[700] ?? Colors.orange),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Icon(Icons.arrow_drop_down, color: arrowColor),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showStatusMenu() {
    _hideStatusMenu();

    final ctx = _statusFilterKey.currentContext;
    if (ctx == null) return;
    final renderBox = ctx.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);

    final items = const ['All Status', 'Active', 'Pending', 'Suspended', 'Email Verified', 'Phone Verified'];

    _statusMenuOverlay = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            // Dismiss area
            Positioned.fill(
              child: GestureDetector(onTap: _hideStatusMenu),
            ),
            Positioned(
              left: offset.dx,
              top: offset.dy + size.height + 4,
              width: size.width,
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
                            style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
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

    Overlay.of(context).insert(_statusMenuOverlay!);
  }

  void _hideStatusMenu() {
    _statusMenuOverlay?.remove();
    _statusMenuOverlay = null;
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

  // Bottom navigation
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

  Widget _navItem(IconData icon, String label, {bool active = false, required VoidCallback onTap}) {
    final color = active ? Colors.orange[700] : Colors.black87;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: color, fontSize: 12)),
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