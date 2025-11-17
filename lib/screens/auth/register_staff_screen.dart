import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';

import 'dart:math' as math;

import '../../services/auth_service.dart';
import '../../widgets/app_shell.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/user_model.dart';

class RegisterStaffScreen extends StatefulWidget {
  final String franchiseId;
  final String? franchiseName;

  const RegisterStaffScreen({
    Key? key,
    required this.franchiseId,
    this.franchiseName,
  }) : super(key: key);

  @override
  State<RegisterStaffScreen> createState() => _RegisterStaffScreenState();
}

class _RegisterStaffScreenState extends State<RegisterStaffScreen> {
  // Editing controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _salaryController = TextEditingController();

  // Validation errors
  String? _nameError;
  String? _emailError;
  String? _phoneError;
  String? _salaryError;

  // Live checklist state like edit page
  bool _checkEmailHasAt = false;
  bool _checkEmailNoSpaces = true;
  bool _checkEmailHasDotCom = false;
  bool _checkStartsWith01 = false;
  bool _checkDigits = false;
  bool _checkLength = false; // 10 or 11 digits
  bool _checkNoHyphen = true;

  // Edit dropdown state for Role/Status/Outlet (mirror edit page)
  String _editRoleLabel = 'Staff';
  String _editStatusLabel = 'Pending';
  String _editOutletLabel = 'N/A';
  final GlobalKey _roleEditKey = GlobalKey();
  final GlobalKey _statusEditKey = GlobalKey();
  final GlobalKey _outletEditKey = GlobalKey();
  final LayerLink _roleEditLink = LayerLink();
  final LayerLink _statusEditLink = LayerLink();
  final LayerLink _outletEditLink = LayerLink();
  OverlayEntry? _roleEditOverlay;
  OverlayEntry? _statusEditOverlay;
  OverlayEntry? _outletEditOverlay;

  // Photo upload state
  Uint8List? _pendingPhotoBytes;
  String? _pendingPhotoUrl;
  String? _pendingPhotoPath; // e.g., images/<filename>
  bool _isUploadingPhoto = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _salaryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 768;
    _editOutletLabel = widget.franchiseName ?? 'N/A';
    return AppShell(
      activeItem: 'Staff',
      body: SingleChildScrollView(
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
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                      children: [
                            ElevatedButton(
                              onPressed: _isSubmitting ? null : _saveEdits,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: const Text(
                                'REGISTER',
                                style: TextStyle(letterSpacing: 0.5, fontSize: 18),
                              ),
                            ),
                          ],
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
                                  return const AssetImage('assets/images/person1.jpeg');
                                })() as ImageProvider,
                              ),
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: _isUploadingPhoto ? null : _reuploadPhoto,
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
                          ),
                          const SizedBox(width: 28),
                          Expanded(
                            child: _detailsTable(),
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

  Widget _detailsTable() {
    final outlet = widget.franchiseName ?? 'N/A';
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(2),
        1: FlexColumnWidth(5),
        2: FlexColumnWidth(2),
        3: FlexColumnWidth(5),
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
                child: _textField(controller: _nameController, errorText: _nameError),
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
                child: Row(
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
                ),
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
                child: Column(
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
                ),
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
                child: Column(
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
                ),
              ),
            ),
          ],
        ),
        TableRow(
          children: [
            Padding(padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12), child: _tableLabel('Roles')),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              child: Row(
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
              ),
            ),
            Padding(padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12), child: _tableLabel('Status')),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              child: Row(
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
              ),
            ),
          ],
        ),
        TableRow(
          children: [
            Padding(padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12), child: _tableLabel('Salary')),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              child: Row(
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
              ),
            ),
            const SizedBox.shrink(),
            const SizedBox.shrink(),
          ],
        ),
      ],
    );
  }

  Widget _tableLabel(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      child: Text(
        text,
        style: const TextStyle(fontSize: 18, color: Colors.grey),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        softWrap: false,
      ),
    );
  }

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
          borderSide: const BorderSide(color: Colors.orange),
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

      final filename = 'new_${DateTime.now().millisecondsSinceEpoch}.$ext';
      setState(() {
        _pendingPhotoBytes = bytes;
        _isUploadingPhoto = true;
      });

      final storage = FirebaseStorage.instance;
      final storagePath = 'images/$filename';
      final ref = storage.ref().child(storagePath);
      final metadata = SettableMetadata(contentType: 'image/${ext == 'jpg' ? 'jpeg' : ext}');
      await ref.putData(bytes, metadata);
      final url = await ref.getDownloadURL();

      setState(() {
        _pendingPhotoUrl = url;
        _pendingPhotoPath = storagePath;
        _isUploadingPhoto = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo uploaded')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload photo: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingPhoto = false;
        });
      }
    }
  }

  Future<void> _saveEdits() async {
    try {
      // Validate
      final name = _nameController.text.trim();
      final email = _emailController.text.trim();
      final phone = _phoneController.text.trim();
      final salaryText = _salaryController.text.trim();

      _nameError = null; _emailError = null; _phoneError = null; _salaryError = null;

      if (name.isEmpty) _nameError = 'Please enter the name';
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

      if (_nameError != null || _emailError != null || _phoneError != null || _salaryError != null) {
        setState(() {});
        return;
      }
      // Ask for confirmation before saving (mirror edit page)
      final confirmed = await _showConfirmSaveDialog();
      if (!confirmed) return;
      setState(() => _isSubmitting = true);

      // Split name
      String firstName = name;
      String lastName = '';
      final idx = name.indexOf(' ');
      if (idx > 0) {
        firstName = name.substring(0, idx).trim();
        lastName = name.substring(idx + 1).trim();
      }

      // Use Firebase Auth UID to look up owner document reliably
      final ownerUid = AuthService.currentUser?.uid;
      if (ownerUid == null) {
        throw Exception('User not authenticated');
      }
      // Optional local guard for role (backend also validates)
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final currentUser = authProvider.currentUser;
      if (currentUser == null || currentUser.role != UserRole.franchiseOwner) {
        throw Exception('Only franchise owners can register staff');
      }

      // Create staff basic record
      final resp = await AuthService.registerStaff(
        franchiseId: widget.franchiseId,
        email: email,
        firstName: firstName,
        lastName: lastName,
        franchiseOwnerId: ownerUid,
      );

      if (!resp.success) {
        throw Exception(resp.message ?? 'Registration failed');
      }

      final staffId = (resp.data?['staffId'] as String?) ?? '';
      if (staffId.isEmpty) {
        throw Exception('Registration returned empty staffId');
      }

      // Update additional fields
      final mappedRole = _editRoleLabel.toLowerCase(); // staff or supervisor
      final mappedStatus = {
        'Active': 'active',
        'Pending': 'pending',
        'Suspended': 'suspended',
      }[_editStatusLabel] ?? 'pending';

      final updates = <String, dynamic>{
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'phoneNumber': phone,
        'salary': num.tryParse(salaryText) ?? salaryText,
        'role': mappedRole,
        'status': mappedStatus,
        if (_pendingPhotoUrl != null) 'metadata.photoUrl': _pendingPhotoUrl,
        if (_pendingPhotoPath != null) 'metadata.photoName': _pendingPhotoPath,
      };

      await FirebaseFirestore.instance.collection('users').doc(staffId).update(updates);

      if (mounted) {
        await _showSuccessDialog('Staff registered successfully.');
        Navigator.of(context).pop();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to register staff: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  bool _isValidEmail(String input) {
    final emailReg = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    return emailReg.hasMatch(input);
  }

  bool _isValidPhone(String input) {
    final normalized = input.replaceAll(RegExp(r'[^0-9]'), '');
    final phoneReg = RegExp(r'^01\d{8,9}$');
    return phoneReg.hasMatch(normalized);
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
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // Styled edit dropdown copied from edit page
  Widget _editDropdown({
    required GlobalKey key,
    required LayerLink link,
    required String label,
    required List<String> items,
    required VoidCallback onTap,
  }) {
    final arrowColor = Colors.orange[700] ?? Colors.orange;
    return GestureDetector(
      onTap: onTap,
      child: CompositedTransformTarget(
        link: link,
        child: Container(
          key: key,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.orange[600],
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
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Arial',
                  ),
                ),
              ),
              Icon(Icons.arrow_drop_down, color: arrowColor),
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
    final box = renderObject;
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
    final box = renderObject;
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
    final box = renderObject;
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
                      final rowColor = Colors.orange[600];
                      final textColor = Colors.white;
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

}

class _CriteriaRow extends StatelessWidget {
  final String label;
  final bool checked;
  const _CriteriaRow({required this.label, required this.checked});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(checked ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 16, color: const Color(0xFFDC711F)),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(color: Color(0xFFDC711F), fontSize: 14),
        ),
      ],
    );
  }
}