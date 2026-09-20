package dev.localvoice.flutter_local_voice_agent_example

import android.os.StatFs
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "local_voice_example/storage",
        ).setMethodCallHandler { call, result ->
            try {
                val root = modelRoot()
                when (call.method) {
                    "getModelRoot" -> result.success(root.absolutePath)
                    "availableBytes" -> result.success(StatFs(root.absolutePath).availableBytes)
                    else -> result.notImplemented()
                }
            } catch (_: Exception) {
                result.error(
                    "storage_unavailable",
                    "Private model storage is unavailable.",
                    null,
                )
            }
        }
    }

    private fun modelRoot(): File {
        val root = File(noBackupFilesDir, "local-voice-models")
        if (!root.exists() && !root.mkdirs()) {
            throw IllegalStateException("Could not create private model storage.")
        }
        if (!root.isDirectory) {
            throw IllegalStateException("Private model storage is not a directory.")
        }
        return root
    }
}
