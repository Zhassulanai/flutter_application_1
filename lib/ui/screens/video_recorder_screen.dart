import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../blocs/video_recorder/video_recorder_bloc.dart';
import '../../data/models/recording.dart';
import '../../services/permission_service.dart';
import 'video_library_screen.dart';

class VideoRecorderScreen extends StatefulWidget {
  const VideoRecorderScreen({super.key});

  @override
  State<VideoRecorderScreen> createState() => _VideoRecorderScreenState();
}

class _VideoRecorderScreenState extends State<VideoRecorderScreen> {
  static const _channel = MethodChannel('video_recorder');
  Timer? _timer;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _checkSupport();
  }

  Future<void> _checkSupport() async {
    final supported = await _channel.invokeMethod<bool>('checkConcurrentSupport') ?? false;
    if (!supported && mounted) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Устройство не поддерживает'),
          content: const Text(
            'Одновременная съёмка двух камер недоступна на этом устройстве. '
            'Будет записана только задняя камера.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _start(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final bloc = context.read<VideoRecorderBloc>();

    final granted = await PermissionService.requestCameraAndMic();
    if (!granted) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Необходимы разрешения камеры и микрофона')),
      );
      return;
    }
    try {
      await _channel.invokeMethod('startRecording');
      bloc.add(StartRecording());
      _elapsed = Duration.zero;
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() => _elapsed += const Duration(seconds: 1));
      });
    } on PlatformException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message ?? 'Ошибка')));
    }
  }

  Future<void> _stop(BuildContext context) async {
    final bloc = context.read<VideoRecorderBloc>();

    _timer?.cancel();
    bloc.add(StopRecording());
    try {
      final path = await _channel.invokeMethod<String>('stopRecording');
      if (path != null && mounted) {
        bloc.add(RecordingCompleted(_buildRecording(path)));
      }
    } on PlatformException catch (e) {
      if (mounted) {
        bloc.add(RecordingFailed(e.message ?? 'Ошибка обработки'));
      }
    }
  }

  Recording _buildRecording(String path) {
    final file = File(path);
    return Recording(
      id: const Uuid().v4(),
      filePath: path,
      createdAt: DateTime.now(),
      durationMs: _elapsed.inMilliseconds,
      sizeBytes: file.existsSync() ? file.lengthSync() : 0,
    );
  }

  String _formatElapsed(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VideoRecorderBloc, VideoRecorderState>(
      builder: (context, state) {
        final isRecording = state is VideoRecorderRecording;
        final isProcessing = state is VideoRecorderProcessing;

        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              Container(color: Colors.black87),

              Positioned(
                top: 48,
                left: 16,
                child: ClipOval(
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.25,
                    height: MediaQuery.of(context).size.width * 0.25,
                    color: Colors.grey[800],
                    child: const Icon(Icons.person, color: Colors.white54, size: 40),
                  ),
                ),
              ),

              if (isRecording)
                Positioned(
                  top: 56,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _formatElapsed(_elapsed),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
                ),

              if (isProcessing)
                const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 16),
                      Text('Обработка...', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),

              Positioned(
                bottom: 48,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.video_library, color: Colors.white, size: 32),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const VideoLibraryScreen()),
                      ),
                    ),
                    GestureDetector(
                      onTap: isProcessing
                          ? null
                          : () => isRecording ? _stop(context) : _start(context),
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isRecording ? Colors.red : Colors.white,
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                        child: Icon(
                          isRecording ? Icons.stop : Icons.fiber_manual_record,
                          color: isRecording ? Colors.white : Colors.red,
                          size: 36,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
