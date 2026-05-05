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
                "startRecording" -> startRecording(call, result)
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
    private var singleCameraMode: Boolean = false
    private var lastError: String? = null
    private var pendingResult: MethodChannel.Result? = null

    private fun startRecording(call: io.flutter.plugin.common.MethodCall, result: MethodChannel.Result) {
        val singleCamera = call.argument<Boolean>("singleCamera") ?: !checkConcurrentSupport()
        singleCameraMode = singleCamera
        lastError = null

        val dir = File(context.filesDir, "videos/tmp_${System.currentTimeMillis()}").also { it.mkdirs() }
        currentBackPath = File(dir, "back.mp4").absolutePath
        currentFrontPath = if (singleCamera) "" else File(dir, "front.mp4").absolutePath

        VideoRecorderService.onError = { msg -> lastError = msg }

        val intent = Intent(context, VideoRecorderService::class.java).apply {
            action = VideoRecorderService.ACTION_START
            putExtra(VideoRecorderService.EXTRA_BACK_PATH, currentBackPath)
            putExtra(VideoRecorderService.EXTRA_FRONT_PATH, currentFrontPath)
            putExtra(VideoRecorderService.EXTRA_SINGLE_CAMERA, singleCamera)
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

            val err = lastError
            if (err != null) {
                File(backPath).delete()
                if (frontPath.isNotEmpty()) File(frontPath).delete()
                File(backPath).parentFile?.delete()
                pendingResult?.error("RECORD_ERROR", err, null)
                pendingResult = null
            } else if (singleCameraMode || frontPath.isEmpty()) {
                val outputPath = File(outputDir, "output_${System.currentTimeMillis()}.mp4").absolutePath
                File(backPath).copyTo(File(outputPath), overwrite = true)
                File(backPath).delete()
                File(backPath).parentFile?.delete()
                pendingResult?.success(outputPath)
                pendingResult = null
            } else {
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
