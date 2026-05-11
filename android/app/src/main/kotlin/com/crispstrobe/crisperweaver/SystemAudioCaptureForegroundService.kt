// SystemAudioCaptureForegroundService — PLAN §5.1.1 Android side.
//
// Holds the MediaProjection token + an AudioRecord configured with
// AudioPlaybackCaptureConfiguration that captures whatever the system
// is currently playing (Spotify, YouTube, Zoom, the user's own
// playback in a different app). Runs as a foreground service because
// Android 14 requires that for the mediaProjection type.
//
// PCM frames flow OUT of this service via a static
// `FrameListener` callback that the plugin handler installs before
// starting us — keeps the IPC layer simple, no AIDL needed since
// the consumer (the plugin handler) lives in the same process.
//
// Cross-platform: this file is Android-only. The Linux subprocess
// approach (parec) and macOS native approach (ScreenCaptureKit)
// live in separate files; the Dart side picks per-platform inside
// SystemAudioCaptureService.start().

package com.crispstrobe.crisperweaver

import android.annotation.SuppressLint
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioPlaybackCaptureConfiguration
import android.media.AudioRecord
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.concurrent.thread

class SystemAudioCaptureForegroundService : Service() {

    companion object {
        const val ACTION_START = "SYSAUDIO_START"
        const val ACTION_STOP = "SYSAUDIO_STOP"
        const val EXTRA_RESULT_CODE = "resultCode"
        const val EXTRA_RESULT_DATA = "resultData"
        private const val CHANNEL_ID = "system_audio_capture"
        private const val NOTIFICATION_ID = 1331

        /// Callback the plugin handler registers BEFORE asking us to
        /// start, so PCM frames can flow out without an AIDL boundary.
        /// Cleared on stop so a stale callback from a previous capture
        /// doesn't receive frames from a new one.
        @Volatile
        var frameListener: ((FloatArray) -> Unit)? = null
    }

    private var mediaProjection: MediaProjection? = null
    private var audioRecord: AudioRecord? = null
    @Volatile
    private var capturing = false
    private var captureThread: Thread? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(
        intent: Intent?, flags: Int, startId: Int
    ): Int {
        when (intent?.action) {
            ACTION_START -> handleStart(intent)
            ACTION_STOP -> handleStop()
            else -> handleStop()
        }
        return START_NOT_STICKY
    }

    private fun handleStart(intent: Intent) {
        val resultCode = intent.getIntExtra(EXTRA_RESULT_CODE, 0)
        val resultData =
            intent.getParcelableExtra<Intent>(EXTRA_RESULT_DATA)
                ?: return stopSelf()

        startInForeground()

        val mpm = getSystemService(Context.MEDIA_PROJECTION_SERVICE)
                as MediaProjectionManager
        val proj = mpm.getMediaProjection(resultCode, resultData)
            ?: return stopSelf()
        mediaProjection = proj

        // Build the AudioPlaybackCaptureConfiguration. We grab the
        // common playback usages: media (music/videos), game, and
        // unknown (catch-all). Calls (USAGE_VOICE_COMMUNICATION) are
        // intentionally excluded — capturing Zoom audio that way
        // would also pick up Zoom's notifications, which is rarely
        // what the user wants. Users who specifically WANT Zoom
        // capture should turn the speaker output up + use the
        // default sink path on macOS/Linux/Windows (those don't
        // discriminate by usage).
        val cfg = AudioPlaybackCaptureConfiguration.Builder(proj)
            .addMatchingUsage(AudioAttributes.USAGE_MEDIA)
            .addMatchingUsage(AudioAttributes.USAGE_GAME)
            .addMatchingUsage(AudioAttributes.USAGE_UNKNOWN)
            .build()

        val sampleRate = 16000
        val channelMask = AudioFormat.CHANNEL_IN_MONO
        val encoding = AudioFormat.ENCODING_PCM_FLOAT
        val bufBytes = AudioRecord.getMinBufferSize(
            sampleRate, channelMask, encoding).coerceAtLeast(8192)

        @SuppressLint("MissingPermission")
        val ar = AudioRecord.Builder()
            .setAudioFormat(
                AudioFormat.Builder()
                    .setEncoding(encoding)
                    .setSampleRate(sampleRate)
                    .setChannelMask(channelMask)
                    .build()
            )
            .setBufferSizeInBytes(bufBytes)
            .setAudioPlaybackCaptureConfig(cfg)
            .build()
        audioRecord = ar

        try {
            ar.startRecording()
        } catch (e: Exception) {
            cleanup()
            return
        }

        capturing = true
        captureThread = thread(name = "sysaudio-capture", isDaemon = true) {
            val scratch = FloatArray(bufBytes / 4)
            while (capturing) {
                val n = ar.read(scratch, 0, scratch.size,
                    AudioRecord.READ_BLOCKING)
                if (n <= 0) {
                    // Sometimes AudioRecord returns 0 on transient
                    // buffer underruns. Don't spin.
                    if (n == 0) continue
                    break
                }
                val out = FloatArray(n)
                System.arraycopy(scratch, 0, out, 0, n)
                try {
                    frameListener?.invoke(out)
                } catch (_: Throwable) {
                    // Don't let listener exceptions kill the capture.
                }
            }
        }
    }

    private fun startInForeground() {
        val notifManager =
            getSystemService(Context.NOTIFICATION_SERVICE)
                    as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "CrisperWeaver system-audio capture",
                NotificationManager.IMPORTANCE_LOW
            )
            channel.description =
                "Indicates that CrisperWeaver is capturing system audio."
            notifManager.createNotificationChannel(channel)
        }
        val notif: Notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("CrisperWeaver — capturing system audio")
            .setContentText("Tap the Stop button in the app to end.")
            // Reuse the app icon; we don't ship a dedicated mic icon.
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notif,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION
            )
        } else {
            startForeground(NOTIFICATION_ID, notif)
        }
    }

    private fun handleStop() {
        cleanup()
        stopSelf()
    }

    private fun cleanup() {
        capturing = false
        try {
            captureThread?.join(500)
        } catch (_: InterruptedException) {}
        captureThread = null
        try {
            audioRecord?.stop()
            audioRecord?.release()
        } catch (_: Exception) {}
        audioRecord = null
        try {
            mediaProjection?.stop()
        } catch (_: Exception) {}
        mediaProjection = null
        frameListener = null
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
    }

    override fun onDestroy() {
        cleanup()
        super.onDestroy()
    }
}
