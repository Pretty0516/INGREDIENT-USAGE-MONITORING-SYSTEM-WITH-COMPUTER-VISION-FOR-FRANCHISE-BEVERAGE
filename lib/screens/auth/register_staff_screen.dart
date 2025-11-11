import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import '../../services/auth_service.dart';
import '../../widgets/app_shell.dart';

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

  // Dropdown labels
  String _roleLabel = 'Staff';
  String _statusLabel = 'Pending';

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
                  'Register Staff',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                // Back button styled like cancel
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
                const SizedBox(height: 16),
                Container(
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Photo + Reupload
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Stack(
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
                              if (_isUploadingPhoto)
                                Positioned.fill(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.25),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Center(
                                      child: SizedBox(
                                        width: 28,
                                        height: 28,
                                        child: CircularProgressIndicator(strokeWidth: 3),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              OutlinedButton(
                                onPressed: _isUploadingPhoto ? null : _reuploadPhoto,
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.orange),
                                  foregroundColor: Colors.orange,
                                ),
                                child: const Text('REUPLOAD PHOTO'),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Form fields similar to edit
                      _buildTable(wide),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange[600],
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.person_add),
                              SizedBox(width: 8),
                              Text('REGISTER STAFF'),
                            ],
                          ),
                        ),
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

  Widget _buildTable(bool wide) {
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
            _tableLabel('Name'),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              child: _textField(controller: _nameController, errorText: _nameError),
            ),
            _tableLabel('Contact Number'),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              child: _textField(
                controller: _phoneController,
                errorText: _phoneError,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ),
          ],
        ),
        TableRow(
          children: [
            _tableLabel('Email'),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              child: _textField(
                controller: _emailController,
                errorText: _emailError,
                keyboardType: TextInputType.emailAddress,
              ),
            ),
            _tableLabel('Roles'),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _roleLabel,
                      items: const [
                        DropdownMenuItem(value: 'Staff', child: Text('Staff')),
                        DropdownMenuItem(value: 'Supervisor', child: Text('Supervisor')),
                      ],
                      onChanged: (v) => setState(() => _roleLabel = v ?? 'Staff'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        TableRow(
          children: [
            _tableLabel('Status'),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _statusLabel,
                      items: const [
                        DropdownMenuItem(value: 'Active', child: Text('Active')),
                        DropdownMenuItem(value: 'Pending', child: Text('Pending')),
                        DropdownMenuItem(value: 'Suspended', child: Text('Suspended')),
                      ],
                      onChanged: (v) => setState(() => _statusLabel = v ?? 'Pending'),
                    ),
                  ),
                ],
              ),
            ),
            _tableLabel('Salary'),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              child: _textField(
                controller: _salaryController,
                errorText: _salaryError,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ),
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
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        errorText: errorText,
      ),
    );
  }

  Future<void> _reuploadPhoto() async {
    try {
      Uint8List? bytes;
      String ext = 'jpg';

      if (kIsWeb) {
        final input = html.FileUploadInputElement()..accept = 'image/*';
        input.click();
        await input.onChange.first;
        final html.File? webFile = input.files?.first;
        if (webFile == null) return;
        final reader = html.FileReader();
        reader.readAsArrayBuffer(webFile);
        await reader.onLoad.first;
        final result = reader.result;
        if (result is ByteBuffer) {
          bytes = Uint8List.view(result);
        } else if (result is Uint8List) {
          bytes = result;
        } else {
          throw StateError('Unexpected reader result: ${result.runtimeType}');
        }
        final name = webFile.name;
        final dot = name.lastIndexOf('.');
        ext = (dot != -1 ? name.substring(dot + 1) : 'jpg').toLowerCase();
      } else {
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
      }

      final filename = 'new_${DateTime.now().millisecondsSinceEpoch}.$ext';
      setState(() {
        _pendingPhotoBytes = bytes;
        _isUploadingPhoto = true;
      });

      final storage = FirebaseStorage.instance;
      final storagePath = 'images/$filename';
      final ref = storage.ref().child(storagePath);
      final metadata = SettableMetadata(contentType: 'image/${ext == 'jpg' ? 'jpeg' : ext}');
      await ref.putData(bytes!, metadata);
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

  Future<void> _submit() async {
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
      } else if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
        _emailError = 'invalid email address (e.g. example@domain.com)';
      }
      if (phone.isEmpty) {
        _phoneError = 'Please enter the contact number';
      } else if (!RegExp(r'^01\d{8,9}$').hasMatch(phone)) {
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

      setState(() => _isSubmitting = true);

      // Split name
      String firstName = name;
      String lastName = '';
      final idx = name.indexOf(' ');
      if (idx > 0) {
        firstName = name.substring(0, idx).trim();
        lastName = name.substring(idx + 1).trim();
      }

      final ownerId = AuthService.currentUser?.uid;
      if (ownerId == null) {
        throw Exception('User not authenticated');
      }

      // Create staff basic record
      final resp = await AuthService.registerStaff(
        franchiseId: widget.franchiseId,
        email: email,
        firstName: firstName,
        lastName: lastName,
        franchiseOwnerId: ownerId,
      );

      if (!resp.success) {
        throw Exception(resp.message ?? 'Registration failed');
      }

      final staffId = (resp.data?['staffId'] as String?) ?? '';
      if (staffId.isEmpty) {
        throw Exception('Registration returned empty staffId');
      }

      // Update additional fields
      final mappedRole = _roleLabel.toLowerCase(); // staff or supervisor
      final mappedStatus = {
        'Active': 'active',
        'Pending': 'pending',
        'Suspended': 'suspended',
      }[_statusLabel] ?? 'pending';

      final updates = <String, dynamic>{
        'phoneNumber': phone,
        'salary': num.tryParse(salaryText) ?? salaryText,
        'role': mappedRole,
        'status': mappedStatus,
        if (_pendingPhotoUrl != null) 'metadata.photoUrl': _pendingPhotoUrl,
        if (_pendingPhotoPath != null) 'metadata.photoName': _pendingPhotoPath,
      };

      await FirebaseFirestore.instance.collection('users').doc(staffId).update(updates);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Staff registered successfully')), 
        );
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
}