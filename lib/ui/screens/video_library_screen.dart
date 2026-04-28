import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';
import '../../blocs/video_recorder/video_recorder_bloc.dart';
import '../../data/models/recording.dart';
import 'video_player_screen.dart';

class VideoLibraryScreen extends StatefulWidget {
  const VideoLibraryScreen({super.key});

  @override
  State<VideoLibraryScreen> createState() => _VideoLibraryScreenState();
}

class _VideoLibraryScreenState extends State<VideoLibraryScreen> {
  static const _channel = MethodChannel('video_recorder');

  @override
  void initState() {
    super.initState();
    context.read<VideoRecorderBloc>().add(LoadRecordings());
  }

  Future<Uint8List?> _thumbnail(String path) async {
    return _channel.invokeMethod<Uint8List>('getThumbnail', {'path': path});
  }

  String _formatDuration(int ms) {
    final d = Duration(milliseconds: ms);
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _formatSize(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';

  void _delete(BuildContext context, Recording r) {
    context.read<VideoRecorderBloc>().add(DeleteRecording(r.id, r.filePath));
  }

  void _share(Recording r) {
    Share.shareXFiles([XFile(r.filePath)], text: 'Видеозапись');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Видеозаписи')),
      body: BlocBuilder<VideoRecorderBloc, VideoRecorderState>(
        builder: (context, state) {
          final recordings =
              state is VideoRecorderIdle ? state.recordings : <Recording>[];
          if (recordings.isEmpty) {
            return const Center(child: Text('Нет записей'));
          }
          return ListView.builder(
            itemCount: recordings.length,
            itemBuilder: (context, i) {
              final r = recordings[i];
              return ListTile(
                leading: FutureBuilder<Uint8List?>(
                  future: _thumbnail(r.filePath),
                  builder: (_, snap) => snap.data != null
                      ? Image.memory(snap.data!,
                          width: 56, height: 56, fit: BoxFit.cover)
                      : const Icon(Icons.movie, size: 56),
                ),
                title: Text(_formatDuration(r.durationMs)),
                subtitle: Text(
                    '${_formatDate(r.createdAt)} · ${_formatSize(r.sizeBytes)}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.play_arrow),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => VideoPlayerScreen(recording: r),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.share),
                      onPressed: () => _share(r),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => _delete(context, r),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
