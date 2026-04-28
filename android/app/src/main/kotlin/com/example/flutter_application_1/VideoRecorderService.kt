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
