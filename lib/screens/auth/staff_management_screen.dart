import 'package:flutter/material.dart';
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
      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('franchiseId', isEqualTo: widget.franchiseId)
          .where('role', isEqualTo: 'staff')
          .get();

      setState(() {
        _staffMembers = query.docs
            .map((doc) => UserModel.fromMap(doc.data()))
            .toList();
      });
    } catch (e) {
      print('Error loading staff members: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(_franchise?.name ?? 'Staff Management'),
        backgroundColor: Colors.green[600],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadFranchiseData();
              _loadStaffMembers();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                          'Staff Members',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    if (_staffMembers.isEmpty)
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
                        itemCount: _staffMembers.length,
                        separatorBuilder: (context, index) => const Divider(),
                        itemBuilder: (context, index) {
                          final staff = _staffMembers[index];
                          return _buildStaffTile(staff);
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
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