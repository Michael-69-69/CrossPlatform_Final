// screens/student/student_profile_screen.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:image/image.dart' as img;
import '../../providers/auth_provider.dart';
import '../../models/user.dart';

class StudentProfileScreen extends ConsumerStatefulWidget {
  const StudentProfileScreen({super.key});

  @override
  ConsumerState<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends ConsumerState<StudentProfileScreen> {
  bool _isEditing = false;
  bool _isSaving = false;

  // Controllers for editable fields
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _bioController;
  DateTime? _selectedDateOfBirth;
  
  // Avatar handling
  String? _newAvatarBase64;
  Uint8List? _avatarPreview;
  bool _removeAvatar = false;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    final user = ref.read(authProvider);
    _phoneController = TextEditingController(text: user?.phone ?? '');
    _addressController = TextEditingController(text: user?.address ?? '');
    _bioController = TextEditingController(text: user?.bio ?? '');
    _selectedDateOfBirth = user?.dateOfBirth;
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _addressController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════
  // AVATAR HANDLING
  // ══════════════════════════════════════════════

  Future<void> _pickAvatar() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.bytes != null) {
          // Check file size (max 2MB before compression)
          if (file.bytes!.length > 2 * 1024 * 1024) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Ảnh quá lớn. Vui lòng chọn ảnh nhỏ hơn 2MB')),
              );
            }
            return;
          }

          // Resize and compress image
          final resizedBytes = await _resizeImage(file.bytes!);
          final base64 = base64Encode(resizedBytes);

          setState(() {
            _newAvatarBase64 = base64;
            _avatarPreview = resizedBytes;
            _removeAvatar = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi chọn ảnh: $e')),
        );
      }
    }
  }

  Future<Uint8List> _resizeImage(Uint8List bytes) async {
    try {
      final image = img.decodeImage(bytes);
      if (image == null) return bytes;

      // Resize to max 200x200 for avatar (square)
      int size = 200;
      img.Image resized;
      
      if (image.width > image.height) {
        // Landscape - crop to square first
        int startX = (image.width - image.height) ~/ 2;
        final cropped = img.copyCrop(image, x: startX, y: 0, width: image.height, height: image.height);
        resized = img.copyResize(cropped, width: size, height: size);
      } else if (image.height > image.width) {
        // Portrait - crop to square first
        int startY = (image.height - image.width) ~/ 2;
        final cropped = img.copyCrop(image, x: 0, y: startY, width: image.width, height: image.width);
        resized = img.copyResize(cropped, width: size, height: size);
      } else {
        // Already square
        resized = img.copyResize(image, width: size, height: size);
      }

      // Encode as JPEG with quality 85
      return Uint8List.fromList(img.encodeJpg(resized, quality: 85));
    } catch (e) {
      print('Error resizing image: $e');
      return bytes;
    }
  }

  void _removeCurrentAvatar() {
    setState(() {
      _newAvatarBase64 = null;
      _avatarPreview = null;
      _removeAvatar = true;
    });
  }

  // ══════════════════════════════════════════════
  // DATE PICKER
  // ══════════════════════════════════════════════

  Future<void> _selectDateOfBirth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDateOfBirth ?? DateTime(now.year - 20),
      firstDate: DateTime(1950),
      lastDate: DateTime(now.year - 10), // At least 10 years old
      helpText: 'Chọn ngày sinh',
      cancelText: 'Hủy',
      confirmText: 'Chọn',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).primaryColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _selectedDateOfBirth = picked);
    }
  }

  // ══════════════════════════════════════════════
  // SAVE / CANCEL
  // ══════════════════════════════════════════════

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);

    try {
      await ref.read(authProvider.notifier).updateProfile(
        phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        dateOfBirth: _selectedDateOfBirth,
        address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
        bio: _bioController.text.trim().isEmpty ? null : _bioController.text.trim(),
        avatarBase64: _newAvatarBase64,
        clearAvatar: _removeAvatar,
        clearPhone: _phoneController.text.trim().isEmpty,
        clearAddress: _addressController.text.trim().isEmpty,
        clearBio: _bioController.text.trim().isEmpty,
      );

      if (mounted) {
        setState(() {
          _isEditing = false;
          _newAvatarBase64 = null;
          _avatarPreview = null;
          _removeAvatar = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Đã cập nhật hồ sơ thành công'),
              ],
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Lỗi: $e')),
              ],
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _cancelEdit() {
    final user = ref.read(authProvider);
    setState(() {
      _isEditing = false;
      _phoneController.text = user?.phone ?? '';
      _addressController.text = user?.address ?? '';
      _bioController.text = user?.bio ?? '';
      _selectedDateOfBirth = user?.dateOfBirth;
      _newAvatarBase64 = null;
      _avatarPreview = null;
      _removeAvatar = false;
    });
  }

  // ══════════════════════════════════════════════
  // CHANGE PASSWORD DIALOG
  // ══════════════════════════════════════════════

  void _showChangePasswordDialog() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;
    bool isChanging = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.lock_outline),
                SizedBox(width: 8),
                Text('Đổi mật khẩu'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: currentPasswordController,
                    obscureText: obscureCurrent,
                    decoration: InputDecoration(
                      labelText: 'Mật khẩu hiện tại',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(obscureCurrent ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setDialogState(() => obscureCurrent = !obscureCurrent),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: newPasswordController,
                    obscureText: obscureNew,
                    decoration: InputDecoration(
                      labelText: 'Mật khẩu mới',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.lock_outline),
                      helperText: 'Tối thiểu 6 ký tự',
                      suffixIcon: IconButton(
                        icon: Icon(obscureNew ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: confirmPasswordController,
                    obscureText: obscureConfirm,
                    decoration: InputDecoration(
                      labelText: 'Xác nhận mật khẩu mới',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(obscureConfirm ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setDialogState(() => obscureConfirm = !obscureConfirm),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isChanging ? null : () => Navigator.pop(ctx),
                child: const Text('Hủy'),
              ),
              ElevatedButton(
                onPressed: isChanging
                    ? null
                    : () async {
                        // Validation
                        if (currentPasswordController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Vui lòng nhập mật khẩu hiện tại')),
                          );
                          return;
                        }

                        if (newPasswordController.text.length < 6) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Mật khẩu mới phải có ít nhất 6 ký tự')),
                          );
                          return;
                        }

                        if (newPasswordController.text != confirmPasswordController.text) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Mật khẩu xác nhận không khớp')),
                          );
                          return;
                        }

                        setDialogState(() => isChanging = true);

                        try {
                          final success = await ref.read(authProvider.notifier).changePassword(
                            currentPassword: currentPasswordController.text,
                            newPassword: newPasswordController.text,
                          );

                          if (mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    Icon(
                                      success ? Icons.check_circle : Icons.error,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(success
                                        ? 'Đã đổi mật khẩu thành công'
                                        : 'Mật khẩu hiện tại không đúng'),
                                  ],
                                ),
                                backgroundColor: success ? Colors.green : Colors.red,
                              ),
                            );
                          }
                        } catch (e) {
                          setDialogState(() => isChanging = false);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Lỗi: $e')),
                            );
                          }
                        }
                      },
                child: isChanging
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Đổi mật khẩu'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ══════════════════════════════════════════════
  // BUILD UI
  // ══════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Hồ sơ')),
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.person_off, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text('Vui lòng đăng nhập'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hồ sơ cá nhân'),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => _isEditing = true),
              tooltip: 'Chỉnh sửa hồ sơ',
            )
          else ...[
            if (_isSaving)
              const Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
              )
            else ...[
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: _cancelEdit,
                tooltip: 'Hủy thay đổi',
              ),
              IconButton(
                icon: const Icon(Icons.check),
                onPressed: _saveProfile,
                tooltip: 'Lưu thay đổi',
              ),
            ],
          ],
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ══════════════════════════════════════
            // AVATAR SECTION
            // ══════════════════════════════════════
            _buildAvatarSection(user),
            const SizedBox(height: 8),

            // Profile completion indicator
            if (!_isEditing && user.profileCompletionPercent < 100)
              _buildCompletionIndicator(user),

            const SizedBox(height: 24),

            // ══════════════════════════════════════
            // NON-EDITABLE INFO (Locked)
            // ══════════════════════════════════════
            _buildSectionCard(
              title: 'Thông tin cơ bản',
              icon: Icons.person,
              iconColor: Colors.blue,
              children: [
                _buildInfoTile(
                  icon: Icons.badge,
                  label: 'Họ và tên',
                  value: user.fullName,
                  locked: true,
                ),
                const Divider(height: 1),
                _buildInfoTile(
                  icon: Icons.numbers,
                  label: 'Mã số sinh viên',
                  value: user.code ?? 'Chưa có',
                  locked: true,
                ),
                const Divider(height: 1),
                _buildInfoTile(
                  icon: Icons.email,
                  label: 'Email',
                  value: user.email,
                  locked: true,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ══════════════════════════════════════
            // EDITABLE INFO
            // ══════════════════════════════════════
            _buildSectionCard(
              title: 'Thông tin liên hệ',
              icon: Icons.contact_phone,
              iconColor: Colors.green,
              children: [
                _buildEditableField(
                  icon: Icons.phone,
                  label: 'Số điện thoại',
                  controller: _phoneController,
                  value: user.phone,
                  keyboardType: TextInputType.phone,
                  hintText: 'Nhập số điện thoại',
                ),
                const Divider(height: 1),
                _buildDateField(
                  icon: Icons.cake,
                  label: 'Ngày sinh',
                  value: _selectedDateOfBirth,
                  displayValue: user.dateOfBirth,
                ),
                const Divider(height: 1),
                _buildEditableField(
                  icon: Icons.home,
                  label: 'Địa chỉ',
                  controller: _addressController,
                  value: user.address,
                  hintText: 'Nhập địa chỉ',
                  maxLines: 2,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ══════════════════════════════════════
            // BIO SECTION
            // ══════════════════════════════════════
            _buildSectionCard(
              title: 'Giới thiệu bản thân',
              icon: Icons.info_outline,
              iconColor: Colors.purple,
              children: [
                _buildEditableField(
                  icon: Icons.description,
                  label: 'Tiểu sử',
                  controller: _bioController,
                  value: user.bio,
                  hintText: 'Viết vài dòng giới thiệu về bản thân...',
                  maxLines: 4,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ══════════════════════════════════════
            // ACTION BUTTONS
            // ══════════════════════════════════════
            if (!_isEditing) ...[
              // Change Password Button
              OutlinedButton.icon(
                icon: const Icon(Icons.lock_outline),
                label: const Text('Đổi mật khẩu'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
                onPressed: _showChangePasswordDialog,
              ),
              const SizedBox(height: 12),

              // Logout Button
              ElevatedButton.icon(
                icon: const Icon(Icons.logout),
                label: const Text('Đăng xuất'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Đăng xuất'),
                      content: const Text('Bạn có chắc muốn đăng xuất?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Hủy'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            ref.read(authProvider.notifier).logout();
                            context.go('/');
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                          child: const Text('Đăng xuất'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════
  // WIDGET BUILDERS
  // ══════════════════════════════════════════════

  Widget _buildAvatarSection(AppUser user) {
    // Determine what avatar to show
    ImageProvider? avatarImage;
    
    if (_avatarPreview != null) {
      // Preview of newly selected image
      avatarImage = MemoryImage(_avatarPreview!);
    } else if (!_removeAvatar && user.avatarBase64 != null && user.avatarBase64!.isNotEmpty) {
      // Existing avatar from database
      try {
        avatarImage = MemoryImage(base64Decode(user.avatarBase64!));
      } catch (e) {
        print('Error decoding avatar: $e');
      }
    } else if (!_removeAvatar && user.avatarUrl != null && user.avatarUrl!.isNotEmpty) {
      // URL-based avatar
      avatarImage = NetworkImage(user.avatarUrl!);
    }

    return Column(
      children: [
        Stack(
          children: [
            // Avatar Circle
            CircleAvatar(
              radius: 60,
              backgroundColor: Colors.grey[300],
              backgroundImage: avatarImage,
              child: avatarImage == null
                  ? Text(
                      user.avatarInitial,
                      style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
                    )
                  : null,
            ),

            // Edit button (only in edit mode)
            if (_isEditing)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: PopupMenuButton<String>(
                    icon: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                    padding: EdgeInsets.zero,
                    onSelected: (value) {
                      if (value == 'pick') {
                        _pickAvatar();
                      } else if (value == 'remove') {
                        _removeCurrentAvatar();
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'pick',
                        child: Row(
                          children: [
                            Icon(Icons.photo_library),
                            SizedBox(width: 8),
                            Text('Chọn ảnh mới'),
                          ],
                        ),
                      ),
                      if (user.hasAvatar || _avatarPreview != null)
                        const PopupMenuItem(
                          value: 'remove',
                          child: Row(
                            children: [
                              Icon(Icons.delete, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Xóa ảnh', style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),

        // Name and role
        Text(
          user.fullName,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: user.role == UserRole.instructor ? Colors.orange[100] : Colors.blue[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            user.role == UserRole.instructor ? 'Giảng viên' : 'Sinh viên',
            style: TextStyle(
              color: user.role == UserRole.instructor ? Colors.orange[800] : Colors.blue[800],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompletionIndicator(AppUser user) {
    final percent = user.profileCompletionPercent;
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.amber[700]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hoàn thành hồ sơ: $percent%',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Colors.amber[900],
                  ),
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: percent / 100,
                  backgroundColor: Colors.amber[100],
                  valueColor: AlwaysStoppedAnimation(Colors.amber[700]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Content
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String label,
    required String value,
    bool locked = false,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey[600]),
      title: Text(
        label,
        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
      ),
      subtitle: Text(
        value.isEmpty ? 'Chưa có' : value,
        style: TextStyle(
          fontSize: 16,
          color: value.isEmpty ? Colors.grey : Colors.black87,
        ),
      ),
      trailing: locked
          ? Tooltip(
              message: 'Không thể thay đổi',
              child: Icon(Icons.lock, size: 16, color: Colors.grey[400]),
            )
          : null,
    );
  }

  Widget _buildEditableField({
    required IconData icon,
    required String label,
    required TextEditingController controller,
    required String? value,
    String? hintText,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    if (_isEditing) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          decoration: InputDecoration(
            labelText: label,
            hintText: hintText,
            prefixIcon: Icon(icon),
            border: const OutlineInputBorder(),
            filled: true,
            fillColor: Colors.grey[50],
          ),
        ),
      );
    } else {
      return ListTile(
        leading: Icon(icon, color: Colors.grey[600]),
        title: Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        subtitle: Text(
          value?.isNotEmpty == true ? value! : 'Chưa cập nhật',
          style: TextStyle(
            fontSize: 16,
            color: value?.isNotEmpty == true ? Colors.black87 : Colors.grey,
            fontStyle: value?.isNotEmpty == true ? FontStyle.normal : FontStyle.italic,
          ),
        ),
      );
    }
  }

  Widget _buildDateField({
    required IconData icon,
    required String label,
    required DateTime? value,
    required DateTime? displayValue,
  }) {
    final dateToShow = _isEditing ? value : displayValue;
    final formattedDate = dateToShow != null
        ? DateFormat('dd/MM/yyyy').format(dateToShow)
        : null;

    if (_isEditing) {
      return ListTile(
        leading: Icon(icon, color: Colors.grey[600]),
        title: Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        subtitle: Text(
          formattedDate ?? 'Chưa chọn',
          style: TextStyle(
            fontSize: 16,
            color: formattedDate != null ? Colors.black87 : Colors.grey,
            fontStyle: formattedDate != null ? FontStyle.normal : FontStyle.italic,
          ),
        ),
        trailing: ElevatedButton.icon(
          icon: const Icon(Icons.calendar_today, size: 16),
          label: const Text('Chọn'),
          onPressed: _selectDateOfBirth,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12),
          ),
        ),
      );
    } else {
      return ListTile(
        leading: Icon(icon, color: Colors.grey[600]),
        title: Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        subtitle: Text(
          formattedDate ?? 'Chưa cập nhật',
          style: TextStyle(
            fontSize: 16,
            color: formattedDate != null ? Colors.black87 : Colors.grey,
            fontStyle: formattedDate != null ? FontStyle.normal : FontStyle.italic,
          ),
        ),
      );
    }
  }
}