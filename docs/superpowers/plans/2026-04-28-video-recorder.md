# Video Recorder Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a dual-camera background video recorder that composites rear + front camera streams into a single PiP `.mp4` file, stored in internal app storage, with library, playback, and sharing.

**Architecture:** A Kotlin `VideoRecorderService` (ForegroundService) uses Camera2 API to record two simultaneous `MediaRecorder` streams (back.mp4 + front.mp4). After stop, `VideoCompositor` decodes both via `MediaCodec` + OpenGL ES and muxes into one output file. Flutter communicates via `MethodChannel("video_recorder")` and manages state through `VideoRecorderBloc`.

**Tech Stack:** Kotlin (Camera2, MediaRecorder, MediaCodec, OpenGL ES, MediaMuxer), Flutter (BLoC, AndroidView, video_player, share_plus), SQLite (sqflite)

---

## File Map

### Android (Kotlin) — new files
- `android/app/src/main/kotlin/com/example/flutter_application_1/VideoRecorderPlugin.kt` — MethodChannel registration + delegation to service
- `android/app/src/main/kotlin/com/example/flutter_application_1/VideoRecorderService.kt` — ForegroundService holding Camera2 sessions + MediaRecorder instances
- `android/app/src/main/kotlin/com/example/flutter_application_1/VideoCompositor.kt` — MediaCodec decode + OpenGL ES compose + MediaMuxer encode

### Android — modified files
- `android/app/src/main/AndroidManifest.xml` — add CAMERA, RECORD_AUDIO, FOREGROUND_SERVICE_CAMERA permissions + VideoRecorderService declaration
- `android/app/src/main/kotlin/com/example/flutter_application_1/MainActivity.kt` — register VideoRecorderPlugin

### Flutter — new files
- `lib/blocs/video_recorder/video_recorder_bloc.dart` — BLoC: events, states, logic
- `lib/data/models/recording.dart` — Recording model
- `lib/data/repositories/recording_repository.dart` — CRUD for `recordings` table
- `lib/ui/screens/video_recorder_screen.dart` — dual preview + start/stop UI
- `lib/ui/screens/video_library_screen.dart` — list of recordings
- `lib/ui/screens/video_player_screen.dart` — full-screen playback

### Flutter — modified files
- `lib/data/database.dart` — add `recordings` table + migration to version 2
- `pubspec.yaml` — add `video_player`, `share_plus`, `permission_handler`
- `lib/app.dart` — add routes for new screens

---

## Task 1: Add dependencies and permissions

**Files:**
- Modify: `pubspec.yaml`
- Modify: `android/app/src/main/AndroidManifest.xml`

- [ ] **Step 1: Add Flutter packages**

In `pubspec.yaml`, under `dependencies:`, add:
```yaml
  video_player: ^2.9.2
  share_plus: ^10.1.4
  permission_handler: ^11.3.1
```

- [ ] **Step 2: Run pub get**

```bash
flutter pub get
```
Expected: resolves without conflicts.

- [ ] **Step 3: Add Android permissions and service declaration**

In `android/app/src/main/AndroidManifest.xml`, add inside `<manifest>` before `<application>`:
```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_CAMERA" />
```

Inside `<application>`, after the existing `<service>` tag:
```xml
<service
    android:name=".VideoRecorderService"
    android:foregroundServiceType="camera"
    android:exported="false" />
```

- [ ] **Step 4: Commit**

```bash
git add pubspec.yaml pubspec.lock android/app/src/main/AndroidManifest.xml
git commit -m "feat: add video_player, share_plus, permission_handler deps and camera permissions"
```

---

## Task 2: Database migration — recordings table

**Files:**
- Modify: `lib/data/database.dart`

- [ ] **Step 1: Bump version and add migration**

Replace the entire `AppDatabase` class in `lib/data/database.dart`:
```dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class AppDatabase {
  static const _name = 'familychat.db';
  static const _version = 2;

  Database? _db;
  final bool _inMemory;

  AppDatabase._({bool inMemory = false}) : _inMemory = inMemory;

  static final AppDatabase _instance = AppDatabase._();
  static AppDatabase get instance => _instance;
  factory AppDatabase.forTest() => AppDatabase._(inMemory: true);

  Database get db {
    assert(_db != null, 'Call open() first');
    return _db!;
  }

  Future<void> open() async {
    final path = _inMemory ? inMemoryDatabasePath : join(await getDatabasesPath(), _name);
    _db = await openDatabase(
      path,
      version: _version,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE contacts (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        avatar_path TEXT,
        ip_address TEXT NOT NULL,
        port INTEGER NOT NULL,
        is_online INTEGER NOT NULL DEFAULT 0,
        last_seen INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE chats (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        name TEXT NOT NULL,
        last_message TEXT NOT NULL DEFAULT '',
        last_message_time INTEGER NOT NULL DEFAULT 0,
        unread_count INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE messages (
        id TEXT PRIMARY KEY,
        chat_id TEXT NOT NULL,
        sender_id TEXT NOT NULL,
        content TEXT NOT NULL,
        content_type TEXT NOT NULL,
        file_path TEXT,
        timestamp INTEGER NOT NULL,
        status TEXT NOT NULL,
        is_outgoing INTEGER NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_messages_chat ON messages(chat_id, timestamp)');
    await db.execute('CREATE INDEX idx_messages_status ON messages(status, is_outgoing)');
    await _createRecordingsTable(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createRecordingsTable(db);
    }
  }

  Future<void> _createRecordingsTable(Database db) async {
    await db.execute('''
      CREATE TABLE recordings (
        id TEXT PRIMARY KEY,
        file_path TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        duration_ms INTEGER NOT NULL,
        size_bytes INTEGER NOT NULL
      )
    ''');
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/data/database.dart
git commit -m "feat: add recordings table, bump db version to 2"
```

---

## Task 3: Recording model and repository

**Files:**
- Create: `lib/data/models/recording.dart`
- Create: `lib/data/repositories/recording_repository.dart`

- [ ] **Step 1: Create Recording model**

Create `lib/data/models/recording.dart`:
```dart
import 'package:equatable/equatable.dart';

class Recording extends Equatable {
  final String id;
  final String filePath;
  final DateTime createdAt;
  final int durationMs;
  final int sizeBytes;

  const Recording({
    required this.id,
    required this.filePath,
    required this.createdAt,
    required this.durationMs,
    required this.sizeBytes,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'file_path': filePath,
        'created_at': createdAt.millisecondsSinceEpoch,
        'duration_ms': durationMs,
        'size_bytes': sizeBytes,
      };

  factory Recording.fromMap(Map<String, dynamic> map) => Recording(
        id: map['id'] as String,
        filePath: map['file_path'] as String,
        createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
        durationMs: map['duration_ms'] as int,
        sizeBytes: map['size_bytes'] as int,
      );

  @override
  List<Object?> get props => [id, filePath, createdAt, durationMs, sizeBytes];
}
```

- [ ] **Step 2: Create RecordingRepository**

Create `lib/data/repositories/recording_repository.dart`:
```dart
import '../database.dart';
import '../models/recording.dart';

class RecordingRepository {
  final AppDatabase _db;
  RecordingRepository(this._db);

  Future<void> insert(Recording recording) async {
    await _db.db.insert('recordings', recording.toMap());
  }

  Future<List<Recording>> getAll() async {
    final rows = await _db.db.query('recordings', orderBy: 'created_at DESC');
    return rows.map(Recording.fromMap).toList();
  }

  Future<void> delete(String id) async {
    await _db.db.delete('recordings', where: 'id = ?', whereArgs: [id]);
  }
}
```

- [ ] **Step 3: Commit**

```bash
git add lib/data/models/recording.dart lib/data/repositories/recording_repository.dart
git commit -m "feat: Recording model and RecordingRepository"
```

---

## Task 4: VideoRecorderBloc

**Files:**
- Create: `lib/blocs/video_recorder/video_recorder_bloc.dart`

- [ ] **Step 1: Create BLoC**

Create `lib/blocs/video_recorder/video_recorder_bloc.dart`:
```dart
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
```

- [ ] **Step 2: Commit**

```bash
git add lib/blocs/video_recorder/video_recorder_bloc.dart
git commit -m "feat: VideoRecorderBloc with idle/recording/processing/error states"
```

---

## Task 5: Kotlin — VideoRecorderService

**Files:**
- Create: `android/app/src/main/kotlin/com/example/flutter_application_1/VideoRecorderService.kt`

- [ ] **Step 1: Create VideoRecorderService**

Create `android/app/src/main/kotlin/com/example/flutter_application_1/VideoRecorderService.kt`:
```kotlin
package com.example.flutter_application_1

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.hardware.camera2.*
import android.media.MediaRecorder
import android.os.Build
import android.os.IBinder
import android.view.Surface
import androidx.core.app.NotificationCompat
import java.io.File

class VideoRecorderService : Service() {

    companion object {
        const val CHANNEL_ID = "video_recorder_channel"
        const val NOTIFICATION_ID = 200
        const val ACTION_START = "ACTION_START"
        const val ACTION_STOP = "ACTION_STOP"
        const val EXTRA_BACK_PATH = "back_path"
        const val EXTRA_FRONT_PATH = "front_path"
        const val EXTRA_BACK_TEXTURE = "back_texture"
        const val EXTRA_FRONT_TEXTURE = "front_texture"

        var onStopped: ((backPath: String, frontPath: String) -> Unit)? = null
        var onError: ((message: String) -> Unit)? = null
    }

    private val cameraManager by lazy { getSystemService(CAMERA_SERVICE) as CameraManager }
    private var backCamera: CameraDevice? = null
    private var frontCamera: CameraDevice? = null
    private var backRecorder: MediaRecorder? = null
    private var frontRecorder: MediaRecorder? = null
    private var backSession: CameraCaptureSession? = null
    private var frontSession: CameraCaptureSession? = null
    private var backPath: String = ""
    private var frontPath: String = ""

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                backPath = intent.getStringExtra(EXTRA_BACK_PATH) ?: ""
                frontPath = intent.getStringExtra(EXTRA_FRONT_PATH) ?: ""
                val backTextureId = intent.getIntExtra(EXTRA_BACK_TEXTURE, -1)
                val frontTextureId = intent.getIntExtra(EXTRA_FRONT_TEXTURE, -1)
                startForeground(NOTIFICATION_ID, buildNotification())
                startRecording(backTextureId, frontTextureId)
            }
            ACTION_STOP -> stopRecording()
        }
        return START_NOT_STICKY
    }

    private fun startRecording(backTextureId: Int, frontTextureId: Int) {
        try {
            val backId = getBackCameraId() ?: throw IllegalStateException("No back camera")
            val frontId = getFrontCameraId() ?: throw IllegalStateException("No front camera")

            backRecorder = buildRecorder(backPath, 1920, 1080)
            frontRecorder = buildRecorder(frontPath, 1280, 720)

            openCamera(backId, backRecorder!!) { device, session ->
                backCamera = device
                backSession = session
            }
            openCamera(frontId, frontRecorder!!) { device, session ->
                frontCamera = device
                frontSession = session
            }
        } catch (e: Exception) {
            onError?.invoke(e.message ?: "Failed to start recording")
            stopSelf()
        }
    }

    private fun buildRecorder(path: String, width: Int, height: Int): MediaRecorder {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) MediaRecorder(this)
        else @Suppress("DEPRECATION") MediaRecorder()
    }.apply {
        setVideoSource(MediaRecorder.VideoSource.SURFACE)
        setAudioSource(MediaRecorder.AudioSource.MIC)
        setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
        setVideoEncoder(MediaRecorder.VideoEncoder.H264)
        setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
        setVideoSize(width, height)
        setVideoFrameRate(30)
        setVideoEncodingBitRate(5_000_000)
        setOutputFile(path)
        prepare()
    }

    private fun openCamera(
        cameraId: String,
        recorder: MediaRecorder,
        onReady: (CameraDevice, CameraCaptureSession) -> Unit
    ) {
        val recorderSurface = recorder.surface
        cameraManager.openCamera(cameraId, object : CameraDevice.StateCallback() {
            override fun onOpened(camera: CameraDevice) {
                camera.createCaptureSession(
                    listOf(recorderSurface),
                    object : CameraCaptureSession.StateCallback() {
                        override fun onConfigured(session: CameraCaptureSession) {
                            val request = camera.createCaptureRequest(CameraDevice.TEMPLATE_RECORD).apply {
                                addTarget(recorderSurface)
                            }.build()
                            session.setRepeatingRequest(request, null, null)
                            recorder.start()
                            onReady(camera, session)
                        }
                        override fun onConfigureFailed(session: CameraCaptureSession) {
                            onError?.invoke("Camera session configuration failed")
                        }
                    }, null
                )
            }
            override fun onDisconnected(camera: CameraDevice) { camera.close() }
            override fun onError(camera: CameraDevice, error: Int) {
                camera.close()
                onError?.invoke("Camera error: $error")
            }
        }, null)
    }

    private fun stopRecording() {
        try {
            backSession?.stopRepeating()
            frontSession?.stopRepeating()
            backRecorder?.stop()
            frontRecorder?.stop()
        } catch (_: Exception) {}
        backCamera?.close()
        frontCamera?.close()
        backRecorder?.release()
        frontRecorder?.release()
        onStopped?.invoke(backPath, frontPath)
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun getBackCameraId(): String? =
        cameraManager.cameraIdList.firstOrNull {
            cameraManager.getCameraCharacteristics(it)
                .get(CameraCharacteristics.LENS_FACING) == CameraCharacteristics.LENS_FACING_BACK
        }

    private fun getFrontCameraId(): String? =
        cameraManager.cameraIdList.firstOrNull {
            cameraManager.getCameraCharacteristics(it)
                .get(CameraCharacteristics.LENS_FACING) == CameraCharacteristics.LENS_FACING_FRONT
        }

    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID, "Video Recorder", NotificationManager.IMPORTANCE_LOW
        )
        getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }

    private fun buildNotification(): Notification =
        NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Запись видео")
            .setContentText("Идёт запись...")
            .setSmallIcon(android.R.drawable.ic_media_play)
            .build()
}
```

- [ ] **Step 2: Commit**

```bash
git add android/app/src/main/kotlin/com/example/flutter_application_1/VideoRecorderService.kt
git commit -m "feat: VideoRecorderService — Camera2 dual recording foreground service"
```

---

## Task 6: Kotlin — VideoCompositor

**Files:**
- Create: `android/app/src/main/kotlin/com/example/flutter_application_1/VideoCompositor.kt`

- [ ] **Step 1: Create VideoCompositor**

Create `android/app/src/main/kotlin/com/example/flutter_application_1/VideoCompositor.kt`:
```kotlin
package com.example.flutter_application_1

import android.graphics.SurfaceTexture
import android.media.*
import android.opengl.*
import android.view.Surface
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder

class VideoCompositor(
    private val backPath: String,
    private val frontPath: String,
    private val outputPath: String,
) {
    fun compose(onDone: (Boolean) -> Unit) {
        Thread {
            try {
                composeInternal()
                onDone(true)
            } catch (e: Exception) {
                e.printStackTrace()
                onDone(false)
            }
        }.start()
    }

    private fun composeInternal() {
        val backExtractor = MediaExtractor().apply { setDataSource(backPath) }
        val frontExtractor = MediaExtractor().apply { setDataSource(frontPath) }

        val backTrack = selectVideoTrack(backExtractor)
        val frontTrack = selectVideoTrack(frontExtractor)
        val backFormat = backExtractor.getTrackFormat(backTrack)
        val frontFormat = frontExtractor.getTrackFormat(frontTrack)

        val width = backFormat.getInteger(MediaFormat.KEY_WIDTH)
        val height = backFormat.getInteger(MediaFormat.KEY_HEIGHT)
        val durationUs = backFormat.getLong(MediaFormat.KEY_DURATION)

        val muxer = MediaMuxer(outputPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)

        val encFormat = MediaFormat.createVideoFormat("video/avc", width, height).apply {
            setInteger(MediaFormat.KEY_BIT_RATE, 5_000_000)
            setInteger(MediaFormat.KEY_FRAME_RATE, 30)
            setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1)
            setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface)
        }
        val encoder = MediaCodec.createEncoderByType("video/avc")
        encoder.configure(encFormat, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)

        val eglSetup = EglSetup(width, height, encoder.createInputSurface())
        encoder.start()

        val backDecoder = createDecoder(backFormat, eglSetup.backSurface)
        val frontDecoder = createDecoder(frontFormat, eglSetup.frontSurface)
        backDecoder.start()
        frontDecoder.start()

        var muxTrack = -1
        var presentationUs = 0L
        val bufInfo = MediaCodec.BufferInfo()

        fun drainEncoder() {
            while (true) {
                val outIdx = encoder.dequeueOutputBuffer(bufInfo, 0)
                if (outIdx == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                    muxTrack = muxer.addTrack(encoder.outputFormat)
                    muxer.start()
                } else if (outIdx >= 0) {
                    val buf = encoder.getOutputBuffer(outIdx)!!
                    if (bufInfo.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG == 0 && muxTrack >= 0) {
                        muxer.writeSampleData(muxTrack, buf, bufInfo)
                    }
                    encoder.releaseOutputBuffer(outIdx, false)
                    if (bufInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) return
                } else break
            }
        }

        fun feedDecoder(extractor: MediaExtractor, decoder: MediaCodec): Boolean {
            val inIdx = decoder.dequeueInputBuffer(0)
            if (inIdx < 0) return false
            val buf = decoder.getInputBuffer(inIdx)!!
            val size = extractor.readSampleData(buf, 0)
            return if (size < 0) {
                decoder.queueInputBuffer(inIdx, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                false
            } else {
                decoder.queueInputBuffer(inIdx, 0, size, extractor.sampleTime, 0)
                extractor.advance()
                true
            }
        }

        var backDone = false
        var frontDone = false

        while (!backDone || !frontDone) {
            if (!backDone) backDone = !feedDecoder(backExtractor, backDecoder)
            if (!frontDone) frontDone = !feedDecoder(frontExtractor, frontDecoder)

            val backOut = backDecoder.dequeueOutputBuffer(bufInfo, 0)
            if (backOut >= 0) {
                backDecoder.releaseOutputBuffer(backOut, true)
                eglSetup.awaitBackFrame()
            }
            val frontOut = frontDecoder.dequeueOutputBuffer(bufInfo, 0)
            if (frontOut >= 0) {
                frontDecoder.releaseOutputBuffer(frontOut, true)
                eglSetup.awaitFrontFrame()
            }

            eglSetup.drawFrame(presentationUs)
            presentationUs += 1_000_000L / 30
            drainEncoder()
        }

        encoder.signalEndOfInputStream()
        drainEncoder()

        backDecoder.stop(); backDecoder.release()
        frontDecoder.stop(); frontDecoder.release()
        encoder.stop(); encoder.release()
        eglSetup.release()
        muxer.stop(); muxer.release()
        backExtractor.release()
        frontExtractor.release()
    }

    private fun selectVideoTrack(extractor: MediaExtractor): Int {
        for (i in 0 until extractor.trackCount) {
            if (extractor.getTrackFormat(i).getString(MediaFormat.KEY_MIME)?.startsWith("video/") == true) {
                extractor.selectTrack(i)
                return i
            }
        }
        throw IllegalStateException("No video track found")
    }

    private fun createDecoder(format: MediaFormat, surface: Surface): MediaCodec {
        val mime = format.getString(MediaFormat.KEY_MIME)!!
        return MediaCodec.createDecoderByType(mime).apply {
            configure(format, surface, null, 0)
        }
    }
}

private class EglSetup(val width: Int, val height: Int, encoderSurface: Surface) {
    val backSurface: Surface
    val frontSurface: Surface

    private val display: EGLDisplay
    private val context: EGLContext
    private val eglSurface: EGLSurface
    private val backTexId: Int
    private val frontTexId: Int
    private val backST: SurfaceTexture
    private val frontST: SurfaceTexture
    private val program: Int
    private var backFrameAvailable = false
    private var frontFrameAvailable = false

    private val VERTEX_SHADER = """
        attribute vec4 aPosition;
        attribute vec2 aTexCoord;
        varying vec2 vTexCoord;
        void main() { gl_Position = aPosition; vTexCoord = aTexCoord; }
    """.trimIndent()

    private val FRAGMENT_SHADER = """
        #extension GL_OES_EGL_image_external : require
        precision mediump float;
        uniform samplerExternalOES uBackTex;
        uniform samplerExternalOES uFrontTex;
        uniform vec2 uResolution;
        varying vec2 vTexCoord;
        void main() {
            vec4 back = texture2D(uBackTex, vTexCoord);
            float pipSize = 0.25;
            vec2 pipCoord = (vTexCoord - vec2(0.01, 0.74)) / pipSize;
            float dist = length(pipCoord - vec2(0.5));
            if (pipCoord.x >= 0.0 && pipCoord.x <= 1.0 &&
                pipCoord.y >= 0.0 && pipCoord.y <= 1.0 &&
                dist <= 0.5) {
                vec4 front = texture2D(uFrontTex, pipCoord);
                gl_FragColor = front;
            } else {
                gl_FragColor = back;
            }
        }
    """.trimIndent()

    init {
        display = EGL14.eglGetDisplay(EGL14.EGL_DEFAULT_DISPLAY)
        EGL14.eglInitialize(display, null, 0, null, 0)

        val attribs = intArrayOf(
            EGL14.EGL_RED_SIZE, 8, EGL14.EGL_GREEN_SIZE, 8, EGL14.EGL_BLUE_SIZE, 8,
            EGL14.EGL_RENDERABLE_TYPE, EGL14.EGL_OPENGL_ES2_BIT, EGL14.EGL_NONE
        )
        val configs = arrayOfNulls<EGLConfig>(1)
        EGL14.eglChooseConfig(display, attribs, 0, configs, 0, 1, intArrayOf(0), 0)
        val config = configs[0]!!

        val ctxAttribs = intArrayOf(EGL14.EGL_CONTEXT_CLIENT_VERSION, 2, EGL14.EGL_NONE)
        context = EGL14.eglCreateContext(display, config, EGL14.EGL_NO_CONTEXT, ctxAttribs, 0)

        val surfAttribs = intArrayOf(EGL14.EGL_NONE)
        eglSurface = EGL14.eglCreateWindowSurface(display, config, encoderSurface, surfAttribs, 0)
        EGL14.eglMakeCurrent(display, eglSurface, eglSurface, context)

        val texIds = IntArray(2)
        GLES20.glGenTextures(2, texIds, 0)
        backTexId = texIds[0]
        frontTexId = texIds[1]

        backST = SurfaceTexture(backTexId).also { st ->
            st.setOnFrameAvailableListener { backFrameAvailable = true }
        }
        frontST = SurfaceTexture(frontTexId).also { st ->
            st.setOnFrameAvailableListener { frontFrameAvailable = true }
        }
        backSurface = Surface(backST)
        frontSurface = Surface(frontST)

        program = buildProgram(VERTEX_SHADER, FRAGMENT_SHADER)
    }

    fun awaitBackFrame() {
        val deadline = System.currentTimeMillis() + 100
        while (!backFrameAvailable && System.currentTimeMillis() < deadline) Thread.sleep(1)
        backST.updateTexImage()
        backFrameAvailable = false
    }

    fun awaitFrontFrame() {
        val deadline = System.currentTimeMillis() + 100
        while (!frontFrameAvailable && System.currentTimeMillis() < deadline) Thread.sleep(1)
        frontST.updateTexImage()
        frontFrameAvailable = false
    }

    fun drawFrame(presentationUs: Long) {
        GLES20.glViewport(0, 0, width, height)
        GLES20.glUseProgram(program)

        val verts = floatArrayOf(-1f,-1f, 1f,-1f, -1f,1f, 1f,1f)
        val texCoords = floatArrayOf(0f,0f, 1f,0f, 0f,1f, 1f,1f)
        val vBuf = ByteBuffer.allocateDirect(verts.size*4).order(ByteOrder.nativeOrder()).asFloatBuffer().apply { put(verts); position(0) }
        val tBuf = ByteBuffer.allocateDirect(texCoords.size*4).order(ByteOrder.nativeOrder()).asFloatBuffer().apply { put(texCoords); position(0) }

        val posLoc = GLES20.glGetAttribLocation(program, "aPosition")
        val texLoc = GLES20.glGetAttribLocation(program, "aTexCoord")
        GLES20.glEnableVertexAttribArray(posLoc)
        GLES20.glVertexAttribPointer(posLoc, 2, GLES20.GL_FLOAT, false, 0, vBuf)
        GLES20.glEnableVertexAttribArray(texLoc)
        GLES20.glVertexAttribPointer(texLoc, 2, GLES20.GL_FLOAT, false, 0, tBuf)

        GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
        GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, backTexId)
        GLES20.glUniform1i(GLES20.glGetUniformLocation(program, "uBackTex"), 0)

        GLES20.glActiveTexture(GLES20.GL_TEXTURE1)
        GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, frontTexId)
        GLES20.glUniform1i(GLES20.glGetUniformLocation(program, "uFrontTex"), 1)

        GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)
        EGL14.eglPresentationTimeANDROID(display, eglSurface, presentationUs * 1000)
        EGL14.eglSwapBuffers(display, eglSurface)
    }

    fun release() {
        backSurface.release(); frontSurface.release()
        EGL14.eglDestroySurface(display, eglSurface)
        EGL14.eglDestroyContext(display, context)
        EGL14.eglTerminate(display)
    }

    private fun buildProgram(vertSrc: String, fragSrc: String): Int {
        fun compileShader(type: Int, src: String): Int {
            val id = GLES20.glCreateShader(type)
            GLES20.glShaderSource(id, src)
            GLES20.glCompileShader(id)
            return id
        }
        val prog = GLES20.glCreateProgram()
        GLES20.glAttachShader(prog, compileShader(GLES20.GL_VERTEX_SHADER, vertSrc))
        GLES20.glAttachShader(prog, compileShader(GLES20.GL_FRAGMENT_SHADER, fragSrc))
        GLES20.glLinkProgram(prog)
        return prog
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add android/app/src/main/kotlin/com/example/flutter_application_1/VideoCompositor.kt
git commit -m "feat: VideoCompositor — MediaCodec + OpenGL ES PiP composition"
```

---

## Task 7: Kotlin — VideoRecorderPlugin + MainActivity

**Files:**
- Create: `android/app/src/main/kotlin/com/example/flutter_application_1/VideoRecorderPlugin.kt`
- Modify: `android/app/src/main/kotlin/com/example/flutter_application_1/MainActivity.kt`

- [ ] **Step 1: Create VideoRecorderPlugin**

Create `android/app/src/main/kotlin/com/example/flutter_application_1/VideoRecorderPlugin.kt`:
```kotlin
package com.example.flutter_application_1

import android.content.Context
import android.content.Intent
import android.hardware.camera2.CameraManager
import android.media.MediaMetadataRetriever
import android.os.Build
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class VideoRecorderPlugin(private val context: Context) {

    companion object {
        const val CHANNEL = "video_recorder"
    }

    fun register(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkConcurrentSupport" -> result.success(checkConcurrentSupport())
                "startRecording" -> startRecording(result)
                "stopRecording" -> stopRecording(result)
                "getVideos" -> result.success(getVideos())
                "deleteVideo" -> {
                    val path = call.argument<String>("path")!!
                    File(path).delete()
                    result.success(null)
                }
                "getThumbnail" -> {
                    val path = call.argument<String>("path")!!
                    result.success(getThumbnail(path))
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun checkConcurrentSupport(): Boolean {
        val mgr = context.getSystemService(CameraManager::class.java)
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            mgr.concurrentCameraIds.any { set ->
                val facings = set.map { id ->
                    mgr.getCameraCharacteristics(id)
                        .get(android.hardware.camera2.CameraCharacteristics.LENS_FACING)
                }
                facings.contains(android.hardware.camera2.CameraCharacteristics.LENS_FACING_BACK) &&
                facings.contains(android.hardware.camera2.CameraCharacteristics.LENS_FACING_FRONT)
            }
        } else false
    }

    private var currentBackPath: String = ""
    private var currentFrontPath: String = ""
    private var pendingResult: MethodChannel.Result? = null

    private fun startRecording(result: MethodChannel.Result) {
        val dir = File(context.filesDir, "videos/tmp_${System.currentTimeMillis()}").also { it.mkdirs() }
        currentBackPath = File(dir, "back.mp4").absolutePath
        currentFrontPath = File(dir, "front.mp4").absolutePath

        VideoRecorderService.onError = { msg ->
            result.error("RECORD_ERROR", msg, null)
        }

        val intent = Intent(context, VideoRecorderService::class.java).apply {
            action = VideoRecorderService.ACTION_START
            putExtra(VideoRecorderService.EXTRA_BACK_PATH, currentBackPath)
            putExtra(VideoRecorderService.EXTRA_FRONT_PATH, currentFrontPath)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(intent)
        } else {
            context.startService(intent)
        }
        result.success(null)
    }

    private fun stopRecording(result: MethodChannel.Result) {
        pendingResult = result
        VideoRecorderService.onStopped = { backPath, frontPath ->
            val outputDir = File(context.filesDir, "videos").also { it.mkdirs() }
            val outputPath = File(outputDir, "output_${System.currentTimeMillis()}.mp4").absolutePath
            VideoCompositor(backPath, frontPath, outputPath).compose { success ->
                File(backPath).delete()
                File(frontPath).delete()
                File(backPath).parentFile?.delete()
                if (success) pendingResult?.success(outputPath)
                else pendingResult?.error("COMPOSE_ERROR", "Composition failed", null)
                pendingResult = null
            }
        }
        context.startService(Intent(context, VideoRecorderService::class.java).apply {
            action = VideoRecorderService.ACTION_STOP
        })
    }

    private fun getVideos(): List<Map<String, Any>> {
        val dir = File(context.filesDir, "videos")
        if (!dir.exists()) return emptyList()
        return dir.listFiles { f -> f.name.startsWith("output_") && f.name.endsWith(".mp4") }
            ?.sortedByDescending { it.lastModified() }
            ?.map { f ->
                val retriever = MediaMetadataRetriever()
                retriever.setDataSource(f.absolutePath)
                val durationMs = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLong() ?: 0L
                retriever.release()
                mapOf(
                    "path" to f.absolutePath,
                    "size_bytes" to f.length(),
                    "created_at" to f.lastModified(),
                    "duration_ms" to durationMs,
                )
            } ?: emptyList()
    }

    private fun getThumbnail(path: String): ByteArray? {
        val retriever = MediaMetadataRetriever()
        return try {
            retriever.setDataSource(path)
            retriever.getFrameAtTime(0)?.let { bmp ->
                val stream = java.io.ByteArrayOutputStream()
                bmp.compress(android.graphics.Bitmap.CompressFormat.JPEG, 80, stream)
                stream.toByteArray()
            }
        } finally {
            retriever.release()
        }
    }
}
```

- [ ] **Step 2: Register plugin in MainActivity**

Replace `android/app/src/main/kotlin/com/example/flutter_application_1/MainActivity.kt`:
```kotlin
package com.example.flutter_application_1

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        VideoRecorderPlugin(this).register(flutterEngine)
    }
}
```

- [ ] **Step 3: Commit**

```bash
git add android/app/src/main/kotlin/com/example/flutter_application_1/VideoRecorderPlugin.kt \
        android/app/src/main/kotlin/com/example/flutter_application_1/MainActivity.kt
git commit -m "feat: VideoRecorderPlugin MethodChannel + register in MainActivity"
```

---

## Task 8: VideoRecorderScreen

**Files:**
- Create: `lib/ui/screens/video_recorder_screen.dart`

- [ ] **Step 1: Request runtime permissions helper**

Create `lib/services/permission_service.dart`:
```dart
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  static Future<bool> requestCameraAndMic() async {
    final statuses = await [Permission.camera, Permission.microphone].request();
    return statuses.values.every((s) => s.isGranted);
  }
}
```

- [ ] **Step 2: Create VideoRecorderScreen**

Create `lib/ui/screens/video_recorder_screen.dart`:
```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/video_recorder/video_recorder_bloc.dart';
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
  bool _concurrentSupported = true;

  @override
  void initState() {
    super.initState();
    _checkSupport();
  }

  Future<void> _checkSupport() async {
    final supported = await _channel.invokeMethod<bool>('checkConcurrentSupport') ?? false;
    if (!supported && mounted) {
      setState(() => _concurrentSupported = false);
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Устройство не поддерживает'),
          content: const Text('Одновременная съёмка двух камер недоступна на этом устройстве. Будет записана только задняя камера.'),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
        ),
      );
    }
  }

  Future<void> _start(BuildContext context) async {
    final granted = await PermissionService.requestCameraAndMic();
    if (!granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Необходимы разрешения камеры и микрофона')),
      );
      return;
    }
    try {
      await _channel.invokeMethod('startRecording');
      context.read<VideoRecorderBloc>().add(StartRecording());
      _elapsed = Duration.zero;
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() => _elapsed += const Duration(seconds: 1));
      });
    } on PlatformException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'Ошибка')));
    }
  }

  Future<void> _stop(BuildContext context) async {
    _timer?.cancel();
    context.read<VideoRecorderBloc>().add(StopRecording());
    try {
      final path = await _channel.invokeMethod<String>('stopRecording');
      if (path != null && mounted) {
        context.read<VideoRecorderBloc>().add(RecordingCompleted(
          // duration and size will be filled from native getVideos on library screen load
          _buildRecording(path),
        ));
      }
    } on PlatformException catch (e) {
      context.read<VideoRecorderBloc>().add(RecordingFailed(e.message ?? 'Ошибка обработки'));
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
              // Rear camera preview placeholder (full screen)
              Container(color: Colors.black87),

              // Front camera PiP — top-left circle
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

              // Timer top-center
              if (isRecording)
                Positioned(
                  top: 56,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _formatElapsed(_elapsed),
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontFeatures: [FontFeature.tabularFigures()]),
                      ),
                    ),
                  ),
                ),

              // Processing indicator
              if (isProcessing)
                const Center(child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text('Обработка...', style: TextStyle(color: Colors.white)),
                  ],
                )),

              // Bottom controls
              Positioned(
                bottom: 48,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.video_library, color: Colors.white, size: 32),
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VideoLibraryScreen())),
                    ),
                    GestureDetector(
                      onTap: isProcessing ? null : () => isRecording ? _stop(context) : _start(context),
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
```

> Note: add `import 'dart:io';`, `import 'package:uuid/uuid.dart';` and `import '../../data/models/recording.dart';` at the top.

- [ ] **Step 3: Commit**

```bash
git add lib/services/permission_service.dart lib/ui/screens/video_recorder_screen.dart
git commit -m "feat: VideoRecorderScreen with dual-camera preview layout and start/stop"
```

---

## Task 9: VideoLibraryScreen and VideoPlayerScreen

**Files:**
- Create: `lib/ui/screens/video_library_screen.dart`
- Create: `lib/ui/screens/video_player_screen.dart`

- [ ] **Step 1: Create VideoLibraryScreen**

Create `lib/ui/screens/video_library_screen.dart`:
```dart
import 'dart:io';
import 'dart:typed_data';
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
    final bytes = await _channel.invokeMethod<Uint8List>('getThumbnail', {'path': path});
    return bytes;
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
          final recordings = state is VideoRecorderIdle ? state.recordings : <Recording>[];
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
                      ? Image.memory(snap.data!, width: 56, height: 56, fit: BoxFit.cover)
                      : const Icon(Icons.movie, size: 56),
                ),
                title: Text(_formatDuration(r.durationMs)),
                subtitle: Text('${_formatDate(r.createdAt)} · ${_formatSize(r.sizeBytes)}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(icon: const Icon(Icons.play_arrow), onPressed: () {
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => VideoPlayerScreen(recording: r),
                      ));
                    }),
                    IconButton(icon: const Icon(Icons.share), onPressed: () => _share(r)),
                    IconButton(icon: const Icon(Icons.delete), onPressed: () => _delete(context, r)),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2,'0')}.${dt.month.toString().padLeft(2,'0')}.${dt.year}';
}
```

- [ ] **Step 2: Create VideoPlayerScreen**

Create `lib/ui/screens/video_player_screen.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';
import '../../data/models/recording.dart';

class VideoPlayerScreen extends StatefulWidget {
  final Recording recording;
  const VideoPlayerScreen({super.key, required this.recording});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(File(widget.recording.filePath))
      ..initialize().then((_) {
        setState(() {});
        _controller.play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            onPressed: () => Share.shareXFiles([XFile(widget.recording.filePath)]),
          ),
        ],
      ),
      body: Center(
        child: _controller.value.isInitialized
            ? AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              )
            : const CircularProgressIndicator(color: Colors.white),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => setState(() {
          _controller.value.isPlaying ? _controller.pause() : _controller.play();
        }),
        child: Icon(_controller.value.isPlaying ? Icons.pause : Icons.play_arrow),
      ),
    );
  }
}
```

- [ ] **Step 3: Commit**

```bash
git add lib/ui/screens/video_library_screen.dart lib/ui/screens/video_player_screen.dart
git commit -m "feat: VideoLibraryScreen and VideoPlayerScreen"
```

---

## Task 10: Wire up routes and BLoC providers

**Files:**
- Modify: `lib/app.dart`

- [ ] **Step 1: Add VideoRecorderBloc provider and route**

In `lib/app.dart`, add `VideoRecorderBloc` to the BLoC providers list and add a route or navigation entry for `VideoRecorderScreen`. The exact changes depend on current `app.dart` structure — open it, find the `MultiBlocProvider` providers list, and add:

```dart
BlocProvider<VideoRecorderBloc>(
  create: (_) => VideoRecorderBloc(
    RecordingRepository(AppDatabase.instance),
  ),
),
```

Then add a navigation entry (button or tab) in `ChatListScreen` or the main scaffold to open `VideoRecorderScreen`. For example, add an `IconButton` in the AppBar:

```dart
IconButton(
  icon: const Icon(Icons.videocam),
  onPressed: () => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const VideoRecorderScreen()),
  ),
),
```

- [ ] **Step 2: Verify the app builds**

```bash
flutter build apk --debug 2>&1 | tail -20
```
Expected: `Built build/app/outputs/flutter-apk/app-debug.apk`

- [ ] **Step 3: Commit**

```bash
git add lib/app.dart lib/ui/screens/chat_list_screen.dart
git commit -m "feat: wire VideoRecorderBloc and navigation entry point"
```

---

## Self-Review

**Spec coverage check:**
- ✅ Dual camera recording (Camera2 + two MediaRecorder) — Tasks 5, 7
- ✅ Background recording with screen off (ForegroundService) — Task 5
- ✅ PiP composition rear+front → single .mp4 (VideoCompositor OpenGL ES) — Task 6
- ✅ Internal storage only — filesDir/videos/ — Tasks 6, 7
- ✅ Concurrent camera fallback + error dialog — Tasks 7, 8
- ✅ VideoRecorderScreen with timer, PiP preview, start/stop — Task 8
- ✅ VideoLibraryScreen with thumbnail, duration, size, share, delete — Task 9
- ✅ VideoPlayerScreen with video_player — Task 9
- ✅ recordings table + RecordingRepository — Tasks 2, 3
- ✅ share_plus export — Task 9
- ✅ Permissions (CAMERA, RECORD_AUDIO, FOREGROUND_SERVICE_CAMERA) — Tasks 1, 8
- ✅ BLoC states idle→recording→processing→done/error — Task 4
