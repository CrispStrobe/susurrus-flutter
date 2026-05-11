package com.crispstrobe.crisperweaver

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.media.projection.MediaProjectionManager
import android.os.Build
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.nio.ByteBuffer
import java.nio.ByteOrder

class MainActivity : FlutterActivity() {

    // §5.1.1 system-audio capture
    // ------------------------------------------------------------
    private val controlChannelName = "crisperweaver/system_audio_capture"
    private val streamChannelName =
        "crisperweaver/system_audio_capture/stream"
    private val mediaProjectionRequestCode = 7311

    // The result from the most recent start() call. We hold the
    // pending Flutter MethodChannel result so we can complete it
    // asynchronously from onActivityResult — Flutter doesn't let
    // us block in the MethodCallHandler.
    private var pendingStartResult: MethodChannel.Result? = null
    // EventSink for streaming PCM frames back to Dart. Bound by
    // the EventChannel's onListen callback.
    private var sink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val messenger = flutterEngine.dartExecutor.binaryMessenger
        val control = MethodChannel(messenger, controlChannelName)
        val stream = EventChannel(messenger, streamChannelName)

        stream.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                sink = events
            }
            override fun onCancel(arguments: Any?) {
                sink = null
            }
        })

        control.setMethodCallHandler { call, result ->
            when (call.method) {
                "isSupported" -> {
                    // AudioPlaybackCaptureConfiguration needs API 29 (Android 10).
                    result.success(Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q)
                }
                "start" -> startSystemAudioCapture(result)
                "stop" -> {
                    stopSystemAudioCapture()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    /// Launches the MediaProjection permission intent and stashes
    /// the pending Flutter result. Completion happens in
    /// onActivityResult below.
    private fun startSystemAudioCapture(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            result.error(
                "os_too_old",
                "System audio capture requires Android 10 (API 29) or later",
                null
            )
            return
        }
        if (pendingStartResult != null) {
            result.error(
                "already_starting",
                "Another start() is already in flight",
                null
            )
            return
        }
        // Hook the foreground service's frame-listener so PCM
        // arrives at our event sink. Set BEFORE we ask the user
        // for permission so the service has it the moment the
        // foreground intent lands.
        // Kotlin: lambdas assigned to properties have no implicit
        // label, so `return@frameListener` won't compile. Use a
        // small lambda factory with an explicit name so we can
        // early-out cleanly.
        val listener: (FloatArray) -> Unit = inner@{ samples ->
            val sinkLocal = sink ?: return@inner
            // Float32 → bytes (little-endian) for the wire. The
            // Dart side reinterprets via Float32List.view, which
            // is zero-copy.
            val bb = ByteBuffer
                .allocate(samples.size * 4)
                .order(ByteOrder.LITTLE_ENDIAN)
            for (s in samples) bb.putFloat(s)
            val bytes = bb.array()
            runOnUiThread {
                try {
                    sinkLocal.success(bytes)
                } catch (_: Throwable) {
                    // Sink may be cancelled mid-frame; ignore.
                }
            }
        }
        SystemAudioCaptureForegroundService.frameListener = listener

        pendingStartResult = result
        val mpm = getSystemService(Context.MEDIA_PROJECTION_SERVICE)
                as MediaProjectionManager
        val permIntent = mpm.createScreenCaptureIntent()
        try {
            startActivityForResult(permIntent, mediaProjectionRequestCode)
        } catch (e: Exception) {
            pendingStartResult = null
            SystemAudioCaptureForegroundService.frameListener = null
            result.error("start_failed", e.message ?: "start failed", null)
        }
    }

    private fun stopSystemAudioCapture() {
        val svc = Intent(this, SystemAudioCaptureForegroundService::class.java)
            .apply {
                action = SystemAudioCaptureForegroundService.ACTION_STOP
            }
        try {
            stopService(svc)
        } catch (_: Exception) {}
        SystemAudioCaptureForegroundService.frameListener = null
    }

    @Deprecated("Use registerForActivityResult — kept for plugin parity")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != mediaProjectionRequestCode) return
        val pending = pendingStartResult
        pendingStartResult = null
        if (pending == null) return
        if (resultCode != Activity.RESULT_OK || data == null) {
            SystemAudioCaptureForegroundService.frameListener = null
            pending.error(
                "permission_denied",
                "User declined screen + audio capture",
                null
            )
            return
        }
        // Hand the token to the foreground service. The service is
        // what holds the MediaProjection + AudioRecord; the activity
        // would lose them on screen rotation otherwise.
        val svc = Intent(this, SystemAudioCaptureForegroundService::class.java)
            .apply {
                action = SystemAudioCaptureForegroundService.ACTION_START
                putExtra(
                    SystemAudioCaptureForegroundService.EXTRA_RESULT_CODE,
                    resultCode
                )
                putExtra(
                    SystemAudioCaptureForegroundService.EXTRA_RESULT_DATA,
                    data
                )
            }
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                ContextCompat.startForegroundService(this, svc)
            } else {
                startService(svc)
            }
            pending.success(true)
        } catch (e: Exception) {
            SystemAudioCaptureForegroundService.frameListener = null
            pending.error(
                "start_failed",
                e.message ?: "startForegroundService failed",
                null
            )
        }
    }
}
