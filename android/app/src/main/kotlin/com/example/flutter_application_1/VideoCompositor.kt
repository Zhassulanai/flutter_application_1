package com.example.flutter_application_1

import android.graphics.SurfaceTexture
import android.media.*
import android.opengl.*
import android.view.Surface
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.concurrent.atomic.AtomicBoolean

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

        // drain any remaining buffered decoder output frames
        fun drainDecoder(decoder: MediaCodec, awaitFrame: () -> Unit) {
            var out = decoder.dequeueOutputBuffer(bufInfo, 10_000)
            while (out >= 0) {
                decoder.releaseOutputBuffer(out, true)
                awaitFrame()
                eglSetup.drawFrame(presentationUs)
                presentationUs += 1_000_000L / 30
                drainEncoder()
                out = decoder.dequeueOutputBuffer(bufInfo, 0)
            }
        }
        drainDecoder(backDecoder) { eglSetup.awaitBackFrame() }
        drainDecoder(frontDecoder) { eglSetup.awaitFrontFrame() }

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
    private val backFrameAvailable = AtomicBoolean(false)
    private val frontFrameAvailable = AtomicBoolean(false)

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
            st.setOnFrameAvailableListener { backFrameAvailable.set(true) }
        }
        frontST = SurfaceTexture(frontTexId).also { st ->
            st.setOnFrameAvailableListener { frontFrameAvailable.set(true) }
        }
        backSurface = Surface(backST)
        frontSurface = Surface(frontST)

        program = buildProgram(VERTEX_SHADER, FRAGMENT_SHADER)
    }

    fun awaitBackFrame() {
        val deadline = System.currentTimeMillis() + 100
        while (!backFrameAvailable.get() && System.currentTimeMillis() < deadline) Thread.sleep(1)
        backST.updateTexImage()
        backFrameAvailable.set(false)
    }

    fun awaitFrontFrame() {
        val deadline = System.currentTimeMillis() + 100
        while (!frontFrameAvailable.get() && System.currentTimeMillis() < deadline) Thread.sleep(1)
        frontST.updateTexImage()
        frontFrameAvailable.set(false)
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
