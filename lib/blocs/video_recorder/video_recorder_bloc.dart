import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../data/models/recording.dart';
import '../../data/repositories/recording_repository.dart';

// Events
abstract class VideoRecorderEvent extends Equatable {
  const VideoRecorderEvent();
  @override
  List<Object?> get props => [];
}

class StartRecording extends VideoRecorderEvent {}
class StopRecording extends VideoRecorderEvent {}

class RecordingCompleted extends VideoRecorderEvent {
  final Recording recording;
  const RecordingCompleted(this.recording);
  @override
  List<Object?> get props => [recording];
}

class RecordingFailed extends VideoRecorderEvent {
  final String message;
  const RecordingFailed(this.message);
  @override
  List<Object?> get props => [message];
}

class LoadRecordings extends VideoRecorderEvent {}

class DeleteRecording extends VideoRecorderEvent {
  final String id;
  final String filePath;
  const DeleteRecording(this.id, this.filePath);
  @override
  List<Object?> get props => [id, filePath];
}

// States
abstract class VideoRecorderState extends Equatable {
  const VideoRecorderState();
  @override
  List<Object?> get props => [];
}

class VideoRecorderIdle extends VideoRecorderState {
  final List<Recording> recordings;
  const VideoRecorderIdle(this.recordings);
  @override
  List<Object?> get props => [recordings];
}

class VideoRecorderRecording extends VideoRecorderState {
  final Duration elapsed;
  const VideoRecorderRecording(this.elapsed);
  @override
  List<Object?> get props => [elapsed];
}

class VideoRecorderProcessing extends VideoRecorderState {}

class VideoRecorderError extends VideoRecorderState {
  final String message;
  const VideoRecorderError(this.message);
  @override
  List<Object?> get props => [message];
}

// BLoC
class VideoRecorderBloc extends Bloc<VideoRecorderEvent, VideoRecorderState> {
  final RecordingRepository _repository;

  VideoRecorderBloc(this._repository) : super(const VideoRecorderIdle([])) {
    on<LoadRecordings>(_onLoad);
    on<StartRecording>(_onStart);
    on<StopRecording>(_onStop);
    on<RecordingCompleted>(_onCompleted);
    on<RecordingFailed>(_onFailed);
    on<DeleteRecording>(_onDelete);
  }

  Future<void> _onLoad(LoadRecordings event, Emitter<VideoRecorderState> emit) async {
    final recordings = await _repository.getAll();
    emit(VideoRecorderIdle(recordings));
  }

  void _onStart(StartRecording event, Emitter<VideoRecorderState> emit) {
    emit(const VideoRecorderRecording(Duration.zero));
  }

  void _onStop(StopRecording event, Emitter<VideoRecorderState> emit) {
    emit(VideoRecorderProcessing());
  }

  Future<void> _onCompleted(RecordingCompleted event, Emitter<VideoRecorderState> emit) async {
    await _repository.insert(event.recording);
    final recordings = await _repository.getAll();
    emit(VideoRecorderIdle(recordings));
  }

  void _onFailed(RecordingFailed event, Emitter<VideoRecorderState> emit) {
    emit(VideoRecorderError(event.message));
  }

  Future<void> _onDelete(DeleteRecording event, Emitter<VideoRecorderState> emit) async {
    await _repository.delete(event.id);
    final recordings = await _repository.getAll();
    emit(VideoRecorderIdle(recordings));
  }
}
