import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminProfileScreen extends StatefulWidget {
  const AdminProfileScreen({super.key});

  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen> {
  static const Color peach = Color(0xFFFBE3D5);
  static const Color orange = Color(0xFFE96B32);
  static const Color darkBrown = Color(0xFF3D3029);
  static const Color muted = Color(0xFF8A7B72);

  final SupabaseClient _supabase = Supabase.instance.client;

  Map<String, dynamic>? _userData;
  String? _profilePhotoUrl;

  bool _isLoading = true;
  bool _isUploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }

    try {
      final data = await _supabase
          .from('profiles')
          .select('name, email, photo_path')
          .eq('id', user.id)
          .maybeSingle();

      String? photoUrl;
      final photoPath = data?['photo_path']?.toString();

      if (photoPath != null && photoPath.isNotEmpty) {
        photoUrl = await _supabase.storage
            .from('avatars')
            .createSignedUrl(photoPath, 3600);
      }

      if (!mounted) return;

      setState(() {
        _userData = data;
        _profilePhotoUrl = photoUrl;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _isLoading = false);
      _showMessage('Failed to load CAVD profile: $e');
    }
  }

  Future<void> _pickProfilePhoto() async {
    if (_isUploadingPhoto) return;

    try {
      final pickedFile = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (pickedFile == null) return;

      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('Please log in again.');
      }

      final extension = pickedFile.name.split('.').last.toLowerCase();

      if (!['jpg', 'jpeg', 'png', 'webp'].contains(extension)) {
        throw Exception('Only JPG, PNG, and WebP images are allowed.');
      }

      final bytes = await pickedFile.readAsBytes();

      if (bytes.length > 2 * 1024 * 1024) {
        throw Exception('Profile picture must not exceed 2 MB.');
      }

      final normalizedExtension =
          extension == 'jpeg' ? 'jpg' : extension;

      final contentType = switch (normalizedExtension) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        _ => 'image/jpeg',
      };

      if (!mounted) return;

      setState(() => _isUploadingPhoto = true);

      final photoPath =
          '${user.id}/profile_${DateTime.now().microsecondsSinceEpoch}.$normalizedExtension';

      await _supabase.storage.from('avatars').uploadBinary(
        photoPath,
        bytes,
        fileOptions: FileOptions(
          contentType: contentType,
          upsert: false,
        ),
      );

      await _supabase
          .from('profiles')
          .update({'photo_path': photoPath})
          .eq('id', user.id);

      await _loadProfile();

      if (!mounted) return;
      _showMessage('Profile picture updated successfully!');
    } catch (e) {
      if (!mounted) return;
      _showMessage('Failed to upload profile picture: $e');
    } finally {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _profileAvatar() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: peach,
        border: Border.all(color: orange.withValues(alpha: 0.3), width: 3),
      ),
      child: ClipOval(
        child: _profilePhotoUrl != null
            ? Image.network(
                _profilePhotoUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.person,
                  size: 65,
                  color: orange,
                ),
              )
            : const Icon(
                Icons.person,
                size: 65,
                color: orange,
              ),
      ),
    );
  }

  Widget _informationCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF0E2DA)),
      ),
      child: Row(
        children: [
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color: peach,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: orange),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: muted,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 5),
                SelectableText(
                  value,
                  style: const TextStyle(
                    color: darkBrown,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _supabase.auth.currentUser;

    final name = _userData?['name']?.toString().trim() ?? '';
    final email = _userData?['email']?.toString().trim() ?? '';

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: orange),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Admin Profile',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: darkBrown,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'View and manage your CAVD administrator profile.',
            style: TextStyle(color: muted, fontSize: 14),
          ),
          const SizedBox(height: 30),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFF0E2DA)),
            ),
            child: Column(
              children: [
                _profileAvatar(),
                const SizedBox(height: 16),
                Text(
                  name.isNotEmpty ? name : 'CAVD Administrator',
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                    color: darkBrown,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  email.isNotEmpty
                      ? email
                      : (user?.email ?? 'No email available'),
                  style: const TextStyle(
                    color: muted,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed:
                      _isUploadingPhoto ? null : _pickProfilePhoto,
                  icon: _isUploadingPhoto
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: orange,
                          ),
                        )
                      : const Icon(Icons.camera_alt_outlined),
                  label: Text(
                    _isUploadingPhoto
                        ? 'Uploading...'
                        : 'Change Profile Photo',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: orange,
                    side: const BorderSide(color: orange),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'JPG, PNG, or WebP • Maximum size: 2 MB',
                  style: TextStyle(color: muted, fontSize: 12),
                ),
              ],
            ),
          ),

          const SizedBox(height: 25),
          const Text(
            'Account Information',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color: darkBrown,
            ),
          ),
          const SizedBox(height: 15),

          _informationCard(
            icon: Icons.person_outline,
            label: 'Full Name',
            value: name.isNotEmpty ? name : 'CAVD Administrator',
          ),
          const SizedBox(height: 12),
          _informationCard(
            icon: Icons.email_outlined,
            label: 'Email Address',
            value: email.isNotEmpty
                ? email
                : (user?.email ?? 'No email available'),
          ),
          const SizedBox(height: 12),
          _informationCard(
            icon: Icons.admin_panel_settings_outlined,
            label: 'Account Role',
            value: 'CAVD Administrator',
          ),
        ],
      ),
    );
  }
}