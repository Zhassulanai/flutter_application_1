import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/identity_service.dart';
import 'chat_list_screen.dart';
import '../widgets/avatar_widget.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _nameController = TextEditingController();
  String? _avatarPath;
  bool _saving = false;

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file != null) setState(() => _avatarPath = file.path);
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    await IdentityService.instance.saveIdentity(name: name, avatarPath: _avatarPath);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const ChatListScreen()),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('FamilyChat', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Семейный мессенджер', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 48),
              GestureDetector(
                onTap: _pickAvatar,
                child: Stack(
                  children: [
                    AvatarWidget(
                      imagePath: _avatarPath,
                      name: _nameController.text.isEmpty ? '?' : _nameController.text,
                      radius: 48,
                    ),
                    const Positioned(
                      right: 0,
                      bottom: 0,
                      child: CircleAvatar(
                        radius: 14,
                        child: Icon(Icons.camera_alt, size: 14),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Ваше имя',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _nameController.text.trim().isEmpty || _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Начать'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
