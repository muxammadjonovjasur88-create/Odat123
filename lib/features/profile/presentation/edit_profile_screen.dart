import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/services/auth_repository.dart';
import '../../../core/services/user_repository.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late final TextEditingController _displayNameController;
  late final TextEditingController _bioController;
  bool _saving = false;
  bool _uploadingImage = false;
  String? _selectedPhotoBase64;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(userProfileProvider).asData?.value;
    _displayNameController = TextEditingController(text: profile?.displayName ?? profile?.name ?? '');
    _bioController = TextEditingController(text: profile?.bio ?? '');
    _selectedPhotoBase64 = profile?.photoBase64;
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    try {
      final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (image == null) return;
      setState(() => _uploadingImage = true);

      final file = File(image.path);
      final fileSize = await file.length();
      if (fileSize > 900 * 1024) {
        if (!mounted) return;
        setState(() => _uploadingImage = false);
        _showMessage('Rasm hajmi katta, boshqasini tanlang');
        return;
      }

      final tempDir = Directory.systemTemp.createTempSync('flowa_profile');
      final targetPath = '${tempDir.path}/profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final compressedFile = await FlutterImageCompress.compressAndGetFile(
        image.path,
        targetPath,
        quality: 60,
        minWidth: 300,
        minHeight: 300,
        format: CompressFormat.jpeg,
      );

      if (compressedFile == null) {
        if (!mounted) return;
        setState(() => _uploadingImage = false);
        _showMessage('Rasm hajmi katta, boshqasini tanlang');
        return;
      }

      final compressedBytes = await compressedFile.readAsBytes();
      final compressedSize = compressedBytes.length;
      if (compressedSize > 900 * 1024) {
        if (!mounted) return;
        setState(() => _uploadingImage = false);
        _showMessage('Rasm hajmi katta, boshqasini tanlang');
        return;
      }

      final base64String = base64Encode(compressedBytes);
      if (!mounted) return;
      setState(() {
        _selectedPhotoBase64 = base64String;
        _uploadingImage = false;
      });
      _showMessage('Profil rasmi tayyorlandi.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploadingImage = false);
      _showMessage('Rasm hajmi katta, boshqasini tanlang');
    }
  }

  Future<void> _save() async {
    final uid = ref.read(authStateProvider).asData?.value?.uid;
    if (uid == null) return;

    setState(() => _saving = true);
    try {
      final displayName = _displayNameController.text.trim();
      final bio = _bioController.text.trim();
      await ref.read(userRepositoryProvider).updateProfile(
        uid,
        displayName: displayName.isEmpty ? null : displayName,
        bio: bio.isEmpty ? null : bio,
        photoBase64: _selectedPhotoBase64,
      );

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.updateDisplayName(displayName.isEmpty ? null : displayName);
      }

      if (!mounted) return;
      setState(() => _saving = false);
      _showMessage('Profile updated.');
      context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showMessage('Unable to save profile: ${e.toString()}');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final profile = ref.watch(userProfileProvider).asData?.value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit profile'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Stack(
                  children: [
                    Container(
                      width: 112,
                      height: 112,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: colors.border, width: 1.4),
                      ),
                      child: ClipOval(
                        child: _selectedPhotoBase64 != null && _selectedPhotoBase64!.isNotEmpty
                            ? Image.memory(
                                base64Decode(_selectedPhotoBase64!),
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => const Icon(Icons.person_outline_rounded, size: 48),
                              )
                            : AvatarCircle(avatarKey: profile?.avatar ?? 'leaf', size: 112),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: InkWell(
                        onTap: _uploadingImage ? null : _pickImage,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: colors.primary,
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: colors.shadow, blurRadius: 10, offset: const Offset(0, 4))],
                          ),
                          child: _uploadingImage
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 18),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              AppInput(
                label: 'Nickname',
                hint: 'Enter your nickname',
                controller: _displayNameController,
              ),
              const SizedBox(height: 16),
              AppInput(
                label: 'Bio',
                hint: 'Tell others a bit about yourself',
                controller: _bioController,
                maxLines: 4,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '${_bioController.text.length}/150',
                  style: AppTextStyles.caption.copyWith(color: colors.textSecondary),
                ),
              ),
              const SizedBox(height: 24),
              AppButton(
                label: 'Save',
                loading: _saving,
                expand: true,
                onPressed: _saving || _uploadingImage ? null : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
