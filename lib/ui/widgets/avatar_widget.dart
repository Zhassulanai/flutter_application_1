import 'dart:io';
import 'package:flutter/material.dart';

class AvatarWidget extends StatelessWidget {
  final String? imagePath;
  final String name;
  final double radius;

  const AvatarWidget({
    super.key,
    this.imagePath,
    required this.name,
    this.radius = 24,
  });

  @override
  Widget build(BuildContext context) {
    if (imagePath != null && File(imagePath!).existsSync()) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: FileImage(File(imagePath!)),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: Theme.of(context).colorScheme.primary,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(
          color: Colors.white,
          fontSize: radius * 0.8,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
