// view staff details for franchise owner
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'dart:typed_data';

import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../models/user_model.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_shell.dart';

class ViewStaffScreen extends StatefulWidget {
  final UserModel staff;
  final String? franchiseName;
  final bool startEditing;

  const ViewStaffScreen({
    super.key,
    required this.staff,
    this.franchiseName,
    this.startEditing = false,
  });

  @override
  State<ViewStaffScreen> createState() => _ViewStaffScreenState();
}

class _ViewStaffScreenState extends State<ViewStaffScreen> {
  bool _isSideNavOpen = true; // local toggle for wide screens
  bool _isEditing = false;
  late UserModel _staff;
  Uint8List? _pendingPhotoBytes;
  bool _isUploadingPhoto = false;

  // Controllers for editable fields
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _salaryController = TextEditingController();

  // Validation error messages per field
  String? _nameError;
  String? _emailError;
  String? _phoneError;
  String? _salaryError;

  // Live checklist state for email/contact validation (match verification screen style)
  bool _checkEmailHasAt = false;
  bool _checkEmailNoSpaces = true;
  bool _checkEmailHasDotCom = false;
  bool _checkStartsWith01 = false;
  bool _checkDigits = false;
  bool _checkLength = false; // 10 or 11 digits
  bool _checkNoHyphen = true;

  // Validators (mirroring verify_account_screen.dart)
  bool _isValidEmail(String input) {
    final emailReg = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    return emailReg.hasMatch(input);
  }

  bool _isValidPhone(String input) {
    // Must start with 01 and have total 10 or 11 digits (e.g., 01xxxxxxxx)
    final normalized = input.replaceAll(RegExp(r'[^0-9]'), '');
    final phoneReg = RegExp(r'^01\d{8,9}$');
    return phoneReg.hasMatch(normalized);
  }

  // Edit dropdown state for Role/Status/Outlet
  String _editRoleLabel = 'Staff';
  String _editStatusLabel = 'Pending';
  String _editOutletLabel = 'N/A';

  // Keys, links, and overlays for custom dropdowns
  final GlobalKey _roleEditKey = GlobalKey();
  final GlobalKey _statusEditKey = GlobalKey();
  final GlobalKey _outletEditKey = GlobalKey();
  final LayerLink _roleEditLink = LayerLink();
  final LayerLink _statusEditLink = LayerLink();
  final LayerLink _outletEditLink = LayerLink();
  OverlayEntry? _roleEditOverlay;
  OverlayEntry? _statusEditOverlay;
  OverlayEntry? _outletEditOverlay;

  @override
  void initState() {
    super.initState();
    _staff = widget.staff;
    _isEditing = widget.startEditing;
    _hydrateControllersFromStaff();
  }

  void _hydrateControllersFromStaff() {
    _nameController.text = _staff.fullName;
    _emailController.text = _staff.email;
    _phoneController.text = _staff.phoneNumber ?? '';
    _salaryController.text = _rawSalaryText(_staff);
    try {
      _editRoleLabel = _staff.role.toString().split('.').last == 'supervisor' ? 'Supervisor' : 'Staff';
    } catch (_) {
      _editRoleLabel = 'Staff';
    }
    try {
      final st = _staff.status.toString().split('.').last;
      _editStatusLabel = {
        'active': 'Active',
        'suspended': 'Suspended',
        'pending': 'Pending',
        'emailVerified': 'Pending',
        'phoneVerified': 'Pending',
      }[st] ?? 'Pending';
    } catch (_) {
      _editStatusLabel = 'Pending';
    }
    _editOutletLabel = widget.franchiseName ?? 'N/A';

    // Clear validation errors when hydrating
    _nameError = null;
    _emailError = null;
    _phoneError = null;
    _salaryError = null;

    // Initialize live checklist flags from current values
    final emailInput = _emailController.text.trim();
    _checkEmailHasAt = emailInput.contains('@');
    _checkEmailNoSpaces = !emailInput.contains(' ');
    _checkEmailHasDotCom = emailInput.toLowerCase().contains('.com');
    final phoneInput = _phoneController.text.trim();
    _checkStartsWith01 = phoneInput.startsWith('01');
    _checkDigits = RegExp(r'^\d+$').hasMatch(phoneInput);
    _checkLength = phoneInput.length == 10 || phoneInput.length == 11;
    _checkNoHyphen = !phoneInput.contains('-');
  }

  String _roleLabel(UserModel user) {
    final isSupervisor = (user.metadata?['isSupervisor'] == true);
    return isSupervisor ? 'Manager' : 'Staff';
  }

  @override
  Widget build(BuildContext context) {
    final isLaptop = MediaQuery.of(context).size.width >= 1024;
    final staff = _staff;
    final authProvider = context.watch<AuthProvider>();
    final currentUserModel = authProvider.currentUser;

    return AppShell(
      activeItem: 'Staff',
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 768;
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1080),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    const Text(
                      'Staff Profile',
                      style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    // Back button below the Staff Profile title, top-left aligned
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).maybePop(),
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
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x1A000000),
                            blurRadius: 12,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Align(
                            alignment: Alignment.topRight,
                            child: _isEditing
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      OutlinedButton(
                                        onPressed: _cancelEdit,
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.orange,
                                          side: BorderSide(color: Colors.orange),
                                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                        child: const Text(
                                          'CANCEL',
                                          style: TextStyle(letterSpacing: 0.5, fontSize: 18),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      ElevatedButton(
                                        onPressed: _saveEdits,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.orange,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                        child: const Text(
                                          'SAVE',
                                          style: TextStyle(letterSpacing: 0.5, fontSize: 18),
                                        ),
                                      ),
                                    ],
                                  )
                                : ElevatedButton(
                                    onPressed: () {
                                      setState(() => _isEditing = true);
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    child: const Text(
                                      'EDIT',
                                      style: TextStyle(letterSpacing: 0.5, fontSize: 18),
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Column(
                                children: [
                                  CircleAvatar(
                                    radius: wide ? 60 : 48,
                                    backgroundImage: (() {
                                      if (_pendingPhotoBytes != null) {
                                        return MemoryImage(_pendingPhotoBytes!);
                                      }
                                      final meta = _staff.metadata ?? {};
                                      final url = meta['photoUrl'];
                                      if (url is String && url.isNotEmpty) {
                                        return NetworkImage(url);
                                      }
                                      return const AssetImage('assets/images/person1.jpeg');
                                    })() as ImageProvider,
                                  ),
                                  if (_isEditing) ...[
                                    const SizedBox(height: 8),
                                    TextButton(
                                      onPressed: _reuploadPhoto,
                                      child: const Text(
                                        'REUPLOAD PHOTO',
                                        style: TextStyle(
                                          color: Color(0xFFDC711F),
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                    if (_isUploadingPhoto)
                                      const Padding(
                                        padding: EdgeInsets.only(top: 4),
                                        child: SizedBox(
                                          height: 16,
                                          width: 16,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        ),
                                      ),
                                  ],
                                ],
                              ),
                              const SizedBox(width: 28),
                              Expanded(
                                child: _detailsTable(staff),
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
          );
        },
      ),
    );
  }

  String _initials(String? first, String? last) {
    final f = (first ?? '').isNotEmpty ? first![0] : '';
    final l = (last ?? '').isNotEmpty ? last![0] : '';
    return '$f$l';
  }

  Widget _detailRow(String leftLabel, String leftValue, String rightLabel, String rightValue) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: _labelValue(leftLabel, leftValue),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: _labelValue(rightLabel, rightValue),
        ),
      ],
    );
  }

  Widget _labelValue(String label, String value) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
          ),
        ),
      ],
    );
  }

  Widget _detailsTable(UserModel staff) {
    final outlet = widget.franchiseName ?? 'N/A';
    String roleText;
    try {
      // Use raw firebase role attribute (enum -> last segment)
      roleText = staff.role.toString().split('.').last;
    } catch (_) {
      roleText = 'N/A';
    }
    String statusText;
    try {
      statusText = staff.status.toString().split('.').last;
    } catch (_) {
      statusText = 'N/A';
    }
    final salaryText = _salaryText(staff);
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(2), // left label
        1: FlexColumnWidth(5), // left value (wider to avoid wrapping)
        2: FlexColumnWidth(2), // right label
        3: FlexColumnWidth(5), // right value (wider to avoid wrapping)
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(
          children: [
            TableCell(
              verticalAlignment: TableCellVerticalAlignment.top,
              child: Padding(padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12), child: _tableLabel('Name')),
            ),
            TableCell(
              verticalAlignment: TableCellVerticalAlignment.top,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                child: _isEditing
                    ? _textField(controller: _nameController, errorText: _nameError)
                    : _tableValue(staff.fullName),
              ),
            ),
            TableCell(
              verticalAlignment: TableCellVerticalAlignment.top,
              child: Padding(padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12), child: _tableLabel('Outlet')),
            ),
            TableCell(
              verticalAlignment: TableCellVerticalAlignment.top,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                child: _isEditing
                    ? Row(
                        children: [
                          Expanded(
                            child: _editDropdown(
                              key: _outletEditKey,
                              link: _outletEditLink,
                              label: _editOutletLabel,
                              items: <String>[outlet],
                              onTap: _showOutletEditMenu,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: Icon(Icons.arrow_drop_down, color: Colors.orange),
                            onPressed: _showOutletEditMenu,
                          ),
                        ],
                      )
                    : _tableValue(outlet),
              ),
            ),
          ],
        ),
        TableRow(
          children: [
            TableCell(
              verticalAlignment: TableCellVerticalAlignment.top,
              child: Padding(padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12), child: _tableLabel('Contact')),
            ),
            TableCell(
              verticalAlignment: TableCellVerticalAlignment.top,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                child: _isEditing
                    ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _textField(
                          controller: _phoneController,
                          errorText: _phoneError,
                          keyboardType: TextInputType.phone,
                          onChanged: _onPhoneChanged,
                        ),
                        const SizedBox(height: 6),
                        Padding(
                          padding: const EdgeInsets.only(left: 12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _CriteriaRow(label: 'starts with 01', checked: _checkStartsWith01),
                              _CriteriaRow(label: 'digits', checked: _checkDigits),
                              _CriteriaRow(label: '10 or 11 digits in total', checked: _checkLength),
                              _CriteriaRow(label: 'without "-"', checked: _checkNoHyphen),
                            ],
                          ),
                        ),
                      ],
                    )
                    : _tableValue(staff.phoneNumber ?? 'N/A'),
              ),
            ),
            TableCell(
              verticalAlignment: TableCellVerticalAlignment.top,
              child: Padding(padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12), child: _tableLabel('Email')),
            ),
            TableCell(
              verticalAlignment: TableCellVerticalAlignment.top,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                child: _isEditing
                    ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _textField(
                          controller: _emailController,
                          errorText: _emailError,
                          keyboardType: TextInputType.emailAddress,
                          onChanged: _onEmailChanged,
                        ),
                        const SizedBox(height: 6),
                        Padding(
                          padding: const EdgeInsets.only(left: 12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _CriteriaRow(label: "contains '@'", checked: _checkEmailHasAt),
                              _CriteriaRow(label: 'no spaces', checked: _checkEmailNoSpaces),
                              _CriteriaRow(label: 'contains .com', checked: _checkEmailHasDotCom),
                            ],
                          ),
                        ),
                      ],
                    )
                    : _tableValue(staff.email),
              ),
            ),
          ],
        ),
        TableRow(
          children: [
            Padding(padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12), child: _tableLabel('Roles')),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              child: _isEditing
                  ? Row(
                      children: [
                        Expanded(
                          child: _editDropdown(
                            key: _roleEditKey,
                            link: _roleEditLink,
                            label: _editRoleLabel,
                            items: const ['Staff', 'Supervisor'],
                            onTap: _showRoleEditMenu,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: Icon(Icons.arrow_drop_down, color: Colors.orange),
                          onPressed: _showRoleEditMenu,
                        ),
                      ],
                    )
                  : _tableValue(roleText),
            ),
            Padding(padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12), child: _tableLabel('Status')),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              child: _isEditing
                  ? Row(
                      children: [
                        Expanded(
                          child: _editDropdown(
                            key: _statusEditKey,
                            link: _statusEditLink,
                            label: _editStatusLabel,
                            items: const ['Active', 'Pending', 'Suspended'],
                            onTap: _showStatusEditMenu,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: Icon(Icons.arrow_drop_down, color: Colors.orange),
                          onPressed: _showStatusEditMenu,
                        ),
                      ],
                    )
                  : _tableValue(statusText),
            ),
          ],
        ),
        TableRow(
          children: [
            Padding(padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12), child: _tableLabel('Salary')),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              child: _isEditing
                  ? Row(
                      children: [
                        Expanded(
                          child: _textField(
                            controller: _salaryController,
                            errorText: _salaryError,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Tooltip(
                          message: 'Only digits are allowed',
                          child: Icon(Icons.help_outline, color: Colors.orange[700] ?? Colors.orange),
                        ),
                      ],
                    )
                  : _tableValue(salaryText),
            ),
            const SizedBox.shrink(),
            const SizedBox.shrink(),
          ],
        ),
      ],
    );
  }

  TableRow _tableRow(String lLabel, String lValue, String rLabel, String rValue) {
    return TableRow(
      children: [
        Padding(padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12), child: _tableLabel(lLabel)),
        Padding(padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12), child: _tableValue(lValue)),
        Padding(padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12), child: _tableLabel(rLabel)),
        Padding(padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12), child: _tableValue(rValue)),
      ],
    );
  }

  Widget _tableLabel(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 18, color: Colors.grey),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      softWrap: false,
    );
  }

  Widget _tableValue(String text) {
    return Text(
      text,
      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      softWrap: false,
    );
  }

  // Styled text field with orange border and white background
  Widget _textField({
    required TextEditingController controller,
    String? errorText,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
      maxLines: 1,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        filled: true,
        fillColor: Colors.white,
        errorText: errorText,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.orange),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.orange.shade700),
        ),
      ),
    );
  }

  void _onEmailChanged(String v) {
    final input = v.trim();
    setState(() {
      _checkEmailHasAt = input.contains('@');
      _checkEmailNoSpaces = !input.contains(' ');
      _checkEmailHasDotCom = input.toLowerCase().contains('.com');
    });
  }

  void _onPhoneChanged(String v) {
    final input = v.trim();
    setState(() {
      _checkStartsWith01 = input.startsWith('01');
      _checkDigits = RegExp(r'^\d+$').hasMatch(input);
      _checkLength = input.length == 10 || input.length == 11;
      _checkNoHyphen = !input.contains('-');
    });
  }

  Future<void> _reuploadPhoto() async {
    try {
      Uint8List? bytes;
      String ext = 'jpg';

      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      bytes = file.bytes;
      if (bytes == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to read selected image bytes')),
        );
        return;
      }
      ext = (file.extension ?? 'jpg').toLowerCase();

      final filename = '${_staff.id}_${DateTime.now().millisecondsSinceEpoch}.$ext';
      setState(() {
        _pendingPhotoBytes = bytes;
        _isUploadingPhoto = true;
      });
      // Use default storage instance; bucket is provided via FirebaseOptions
      final storage = FirebaseStorage.instance;
      final storagePath = 'images/$filename';
      final ref = storage.ref().child(storagePath);
      final metadata = SettableMetadata(contentType: 'image/${ext == 'jpg' ? 'jpeg' : ext}');
      await ref.putData(bytes!, metadata);
      final url = await ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('users').doc(_staff.id).update({
        'metadata.photoName': storagePath,
        'metadata.photoUrl': url,
      });

      final updatedMeta = {
        ...(_staff.metadata ?? {}),
        'photoName': storagePath,
        'photoUrl': url,
      };
      setState(() {
        _staff = _staff.copyWith(metadata: updatedMeta);
        _pendingPhotoBytes = null;
        _isUploadingPhoto = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo updated')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload photo: $e')),
      );
    } finally {
      // Always clear the uploading indicator even if an exception bubble occurs asynchronously
      if (mounted) {
        setState(() {
          _isUploadingPhoto = false;
          // Ensure any temporary preview is cleared when upload finishes or fails
          _pendingPhotoBytes = null;
        });
      }
    }
  }


  String _salaryText(UserModel staff) {
    final meta = staff.metadata ?? {};
    final s = meta['salary'] ?? meta['salry'];
    if (s == null) return 'N/A';
    if (s is num) return 'RM $s';
    return 'RM $s';
  }

  String _rawSalaryText(UserModel staff) {
    final meta = staff.metadata ?? {};
    final s = meta['salary'] ?? meta['salry'];
    if (s == null) return '';
    return s is num ? s.toString() : (s as String);
  }

  void _cancelEdit() {
    setState(() {
      _isEditing = false;
      _hydrateControllersFromStaff();
      _nameError = null;
      _emailError = null;
      _phoneError = null;
      _salaryError = null;
      _hideRoleEditMenu();
      _hideStatusEditMenu();
      _hideOutletEditMenu();
    });
  }

  Future<void> _saveEdits() async {
    try {
      final name = _nameController.text.trim();
      final email = _emailController.text.trim();
      final phone = _phoneController.text.trim();
      final salaryText = _salaryController.text.trim();
      final salaryValue = num.tryParse(salaryText) ?? salaryText; // keep string if not numeric

      // Reset errors before validating
      _nameError = null;
      _emailError = null;
      _phoneError = null;
      _salaryError = null;

      // Validate fields per requirements
      if (name.isEmpty) {
        _nameError = 'Please enter the name';
      }
      if (email.isEmpty) {
        _emailError = 'Please enter the email';
      } else if (!_isValidEmail(email)) {
        _emailError = 'invalid email address (e.g. example@domain.com)';
      }
      if (phone.isEmpty) {
        _phoneError = 'Please enter the contact number';
      } else if (!_isValidPhone(phone)) {
        _phoneError = 'Invalid Contact Number (e.g. 01xxxxxxxx)';
      }
      if (salaryText.isEmpty) {
        _salaryError = 'Please enter the salary';
      } else if (!RegExp(r'^\d+$').hasMatch(salaryText)) {
        _salaryError = 'Please enter digit only';
      }

      // If any errors, show and stop
      if (_nameError != null || _emailError != null || _phoneError != null || _salaryError != null) {
        setState(() {});
        return;
      }

      // Ask for confirmation before saving
      final confirmed = await _showConfirmSaveDialog();
      if (!confirmed) return;
      // Split full name into first and last names
      String firstName = name;
      String lastName = '';
      final spaceIdx = name.indexOf(' ');
      if (spaceIdx > 0) {
        firstName = name.substring(0, spaceIdx).trim();
        lastName = name.substring(spaceIdx + 1).trim();
      }

      // Map role/status labels to Firestore strings
      final mappedRole = _editRoleLabel.toLowerCase(); // 'staff' or 'supervisor'
      final mappedStatus = {
        'Active': 'active',
        'Pending': 'pending',
        'Suspended': 'suspended',
      }[_editStatusLabel] ?? 'pending';

      // Prepare updates
      final updates = <String, dynamic>{
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'phoneNumber': phone,
        'salary': salaryValue,
        'role': mappedRole,
        'status': mappedStatus,
      };

      await FirebaseFirestore.instance.collection('users').doc(_staff.id).update(updates);

      // Update local model for immediate UI reflect
      final updatedMeta = {
        ...(_staff.metadata ?? {}),
        'salary': salaryValue,
        'isSupervisor': mappedRole == 'supervisor',
      };
      setState(() {
        _staff = _staff.copyWith(
          firstName: firstName,
          lastName: lastName,
          email: email,
          phoneNumber: phone.isEmpty ? null : phone,
          role: mappedRole == 'supervisor' ? UserRole.supervisor : UserRole.staff,
          status: {
            'active': UserStatus.active,
            'pending': UserStatus.pending,
            'suspended': UserStatus.suspended,
          }[mappedStatus] ?? UserStatus.pending,
          metadata: updatedMeta,
        );
        _isEditing = false;
      });
      await _showSuccessDialog('Profile updated successfully.');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update profile: $e')),
      );
    }
  }

  Future<bool> _showConfirmSaveDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFF6EDDF),
        title: const Text(
          'Confirm',
          style: TextStyle(color: Colors.black),
        ),
        content: const Text(
          'Do you want to save these changes?',
          style: TextStyle(color: Colors.black, fontSize: 18),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFDC711F),
              side: const BorderSide(color: Color(0xFFDC711F)),
              textStyle: const TextStyle(fontSize: 18),
            ),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC711F),
              foregroundColor: Colors.white,
              textStyle: const TextStyle(fontSize: 18),
            ),
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _showSuccessDialog(String message) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFF6EDDF),
        title: const Text(
          'Success',
          style: TextStyle(color: Colors.black),
        ),
        content: Text(
          message,
          style: const TextStyle(color: Colors.black, fontSize: 18),
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
  }

  // Reusable edit dropdown styled like filters
  Widget _editDropdown({
    required GlobalKey key,
    required LayerLink link,
    required String label,
    required List<String> items,
    required VoidCallback onTap,
  }) {
    final isDarkClosed = true; // in edit mode, keep orange bg
    final closedBg = Colors.orange[600];
    final arrowColor = Colors.orange[700] ?? Colors.orange;
    return GestureDetector(
      onTap: onTap,
      child: CompositedTransformTarget(
        link: link,
        child: Container(
          key: key,
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
                  label,
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
            ],
          ),
        ),
      ),
    );
  }

  void _showRoleEditMenu() {
    _hideRoleEditMenu();
    final ctx = _roleEditKey.currentContext;
    if (ctx == null) return;
    final renderObject = ctx.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return;
    final box = renderObject as RenderBox;
    final size = box.size;
    final baseItems = const ['Staff', 'Supervisor'];
    final items = [_editRoleLabel, ...baseItems.where((e) => e != _editRoleLabel)];
    _roleEditOverlay = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            Positioned.fill(child: GestureDetector(behavior: HitTestBehavior.translucent, onTap: _hideRoleEditMenu)),
            CompositedTransformFollower(
              link: _roleEditLink,
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
                      final isSelected = e == _editRoleLabel;
                      final rowColor = isSelected ? Colors.orange[600] : Colors.orange[50];
                      final textColor = isSelected ? Colors.white : (Colors.orange[700] ?? Colors.orange);
                      return InkWell(
                        onTap: () {
                          setState(() => _editRoleLabel = e);
                          _hideRoleEditMenu();
                        },
                        splashColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                        hoverColor: Colors.transparent,
                        child: Container(
                          color: rowColor,
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                          child: Text(e, style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontFamily: 'Arial')),
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
    Overlay.of(context).insert(_roleEditOverlay!);
  }

  void _hideRoleEditMenu() {
    _roleEditOverlay?.remove();
    _roleEditOverlay = null;
  }

  void _showStatusEditMenu() {
    _hideStatusEditMenu();
    final ctx = _statusEditKey.currentContext;
    if (ctx == null) return;
    final renderObject = ctx.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return;
    final box = renderObject as RenderBox;
    final size = box.size;
    final baseItems = const ['Active', 'Pending', 'Suspended'];
    final items = [_editStatusLabel, ...baseItems.where((e) => e != _editStatusLabel)];
    _statusEditOverlay = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            Positioned.fill(child: GestureDetector(behavior: HitTestBehavior.translucent, onTap: _hideStatusEditMenu)),
            CompositedTransformFollower(
              link: _statusEditLink,
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
                      final isSelected = e == _editStatusLabel;
                      final rowColor = isSelected ? Colors.orange[600] : Colors.orange[50];
                      final textColor = isSelected ? Colors.white : (Colors.orange[700] ?? Colors.orange);
                      return InkWell(
                        onTap: () {
                          setState(() => _editStatusLabel = e);
                          _hideStatusEditMenu();
                        },
                        splashColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                        hoverColor: Colors.transparent,
                        child: Container(
                          color: rowColor,
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                          child: Text(e, style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontFamily: 'Arial')),
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
    Overlay.of(context).insert(_statusEditOverlay!);
  }

  void _hideStatusEditMenu() {
    _statusEditOverlay?.remove();
    _statusEditOverlay = null;
  }

  void _showOutletEditMenu() {
    _hideOutletEditMenu();
    final ctx = _outletEditKey.currentContext;
    if (ctx == null) return;
    final renderObject = ctx.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return;
    final box = renderObject as RenderBox;
    final size = box.size;
    final items = <String>[_editOutletLabel];
    _outletEditOverlay = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            Positioned.fill(child: GestureDetector(behavior: HitTestBehavior.translucent, onTap: _hideOutletEditMenu)),
            CompositedTransformFollower(
              link: _outletEditLink,
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
                      final isSelected = true;
                      final rowColor = isSelected ? Colors.orange[600] : Colors.orange[50];
                      final textColor = isSelected ? Colors.white : (Colors.orange[700] ?? Colors.orange);
                      return InkWell(
                        onTap: _hideOutletEditMenu,
                        splashColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                        hoverColor: Colors.transparent,
                        child: Container(
                          color: rowColor,
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                          child: Text(e, style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontFamily: 'Arial')),
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
    Overlay.of(context).insert(_outletEditOverlay!);
  }

  void _hideOutletEditMenu() {
    _outletEditOverlay?.remove();
    _outletEditOverlay = null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _salaryController.dispose();
    _hideRoleEditMenu();
    _hideStatusEditMenu();
    _hideOutletEditMenu();
    super.dispose();
  }
}

class _CriteriaRow extends StatelessWidget {
  final String label;
  final bool checked;
  const _CriteriaRow({super.key, required this.label, required this.checked});

  @override
  Widget build(BuildContext context) {
    const rememberMeColor = Color(0xFFDC711F);
    final color = rememberMeColor;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(checked ? Icons.check_box : Icons.check_box_outline_blank, size: 18, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 16,
                  color: Colors.black87,
                ),
          ),
        ],
      ),
    );
  }
}