package com.impetus.impetus

import android.app.WallpaperManager
import android.graphics.BitmapFactory
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class MainActivity : FlutterActivity(), MethodCallHandler {

    private val channelName = "com.impetus.impetus/wallpaper"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName
        ).setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "setBitmap" -> handleSetBitmap(call, result)
            else -> result.notImplemented()
        }
    }

    private fun handleSetBitmap(call: MethodCall, result: Result) {
        val bytes = call.arguments as? ByteArray
        if (bytes == null) {
            result.error(
                "INVALID_ARGUMENT",
                "PNG bytes must not be null",
                null
            )
            return
        }
        val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
        if (bitmap == null) {
            result.error(
                "INVALID_BITMAP",
                "Failed to decode bitmap from provided bytes",
                null
            )
            return
        }
        try {
            val manager = WallpaperManager.getInstance(this)
            manager.setBitmap(
                bitmap,
                null,
                true,
                WallpaperManager.FLAG_LOCK or WallpaperManager.FLAG_SYSTEM
            )
            result.success(true)
        } catch (e: Exception) {
            result.error("SET_BITMAP_FAILED", e.message, null)
        }
    }
}
