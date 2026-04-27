import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../data/database.dart';
import '../../data/models/contact.dart';
import '../../data/repositories/contact_repository.dart';
import '../../services/identity_service.dart';
import '../widgets/avatar_widget.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final TextEditingController _nameController;
  final _contactRepo = ContactRepository(AppDatabase.instance);

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: IdentityService.instance.name);
  }

  Future<void> _pickAvatar() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file != null) {
      await IdentityService.instance.updateAvatar(file.path);
      if (!mounted) return;
      setState(() {});
    }
  }

  Future<void> _saveName() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    await IdentityService.instance.updateName(name);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Сохранено')));
  }

  Future<void> _scanQr() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _QrScannerScreen(onScanned: _handleScannedContact)),
    );
  }

  Future<void> _handleScannedContact(String qrData) async {
    final parts = qrData.split(':');
    if (parts.length < 3 || parts[0] != 'familychat') return;
    final id = parts[1];
    final name = parts.sublist(2).join(':');
    final contact = Contact(
      id: id,
      name: name,
      ipAddress: '0.0.0.0',
      port: 8765,
      isOnline: false,
      lastSeen: 0,
    );
    await _contactRepo.upsert(contact);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Добавлен: $name')));
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final identity = IdentityService.instance;
    final qrData = 'familychat:${identity.ownId}:${identity.name}';

    return Scaffold(
      appBar: AppBar(title: const Text('Профиль')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickAvatar,
              child: Stack(
                children: [
                  AvatarWidget(imagePath: identity.avatarPath, name: identity.name, radius: 48),
                  const Positioned(
                    right: 0,
                    bottom: 0,
                    child: CircleAvatar(radius: 14, child: Icon(Icons.camera_alt, size: 14)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Имя', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(onPressed: _saveName, child: const Text('Сохранить')),
            ),
            const SizedBox(height: 32),
            const Text('Мой QR-код', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            QrImageView(data: qrData, size: 200),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Добавить по QR-коду'),
              onPressed: _scanQr,
            ),
          ],
        ),
      ),
    );
  }
}

class _QrScannerScreen extends StatefulWidget {
  final void Function(String) onScanned;
  const _QrScannerScreen({required this.onScanned});

  @override
  State<_QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<_QrScannerScreen> {
  bool _scanned = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Сканировать QR')),
      body: MobileScanner(
        onDetect: (capture) {
          if (_scanned) return;
          final barcode = capture.barcodes.firstOrNull;
          if (barcode?.rawValue != null) {
            _scanned = true;
            widget.onScanned(barcode!.rawValue!);
            Navigator.pop(context);
          }
        },
      ),
    );
  }
}
