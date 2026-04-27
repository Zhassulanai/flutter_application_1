import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

class AttachmentSheet extends StatelessWidget {
  final void Function(String path, String type) onFileSelected;

  const AttachmentSheet({super.key, required this.onFileSelected});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo),
            title: const Text('Фото'),
            onTap: () async {
              Navigator.pop(context);
              final file = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
              if (file != null) onFileSelected(file.path, 'image');
            },
          ),
          ListTile(
            leading: const Icon(Icons.videocam),
            title: const Text('Видео'),
            onTap: () async {
              Navigator.pop(context);
              final file = await ImagePicker().pickVideo(source: ImageSource.gallery);
              if (file != null) onFileSelected(file.path, 'video');
            },
          ),
          ListTile(
            leading: const Icon(Icons.attach_file),
            title: const Text('Файл'),
            onTap: () async {
              Navigator.pop(context);
              final result = await FilePicker.platform.pickFiles();
              if (result?.files.single.path != null) {
                onFileSelected(result!.files.single.path!, 'file');
              }
            },
          ),
        ],
      ),
    );
  }
}
