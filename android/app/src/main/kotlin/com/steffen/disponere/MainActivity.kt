package com.steffen.disponere

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    // Kanal fuer geteilte Inhalte (ACTION_SEND). Gegenstueck: ShareReceiver
    // (lib/services/share_receiver.dart).
    private val shareChannelName = "disponere/share"
    private var shareChannel: MethodChannel? = null

    // Geteilter Text aus einem KALTSTART-Intent. Wird beim Aufbau der Engine aus
    // getIntent() gefuellt und von Flutter genau EINMAL ueber
    // getInitialSharedText abgeholt (danach null — ein bloßer App-Wechsel
    // liefert ihn nicht erneut).
    private var initialSharedText: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Bestehende PlatformView-Registrierung (FreeScript / native EditText).
        flutterEngine
            .platformViewsController
            .registry
            .registerViewFactory(
                "disponere/native-text",
                NativeTextFactory(flutterEngine.dartExecutor.binaryMessenger),
            )

        // Teilen-Kanal: Flutter zieht beim Start den Kaltstart-Text; Laufzeit-
        // Shares reichen wir per invokeMethod("onSharedText", ...) nach.
        val channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            shareChannelName,
        )
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialSharedText" -> {
                    val text = initialSharedText
                    initialSharedText = null // genau einmal ausliefern
                    result.success(text)
                }
                else -> result.notImplemented()
            }
        }
        shareChannel = channel

        // Kaltstart: kam die App ueber ACTION_SEND nach vorn, den Text puffern,
        // damit Flutter ihn beim ersten Frame abholen kann.
        initialSharedText = extractSharedText(intent)
    }

    // Laeuft die App bereits (launchMode singleTop), landet ein weiterer Share
    // hier. Direkt an Flutter durchreichen — nicht puffern, damit Kaltstart- und
    // Laufzeitweg sich nicht in die Quere kommen.
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val text = extractSharedText(intent)
        if (text != null) {
            shareChannel?.invokeMethod("onSharedText", text)
        }
    }

    // Zieht bei ACTION_SEND mit text/* den geteilten Text aus den Extras.
    // EXTRA_SUBJECT (z.B. Seitentitel beim Teilen einer URL) wird, falls
    // vorhanden, dem Text vorangestellt. Alles andere -> null.
    private fun extractSharedText(intent: Intent?): String? {
        if (intent == null) return null
        if (intent.action != Intent.ACTION_SEND) return null
        val type = intent.type ?: return null
        if (!type.startsWith("text/")) return null

        val body = intent.getStringExtra(Intent.EXTRA_TEXT)?.trim()
        val subject = intent.getStringExtra(Intent.EXTRA_SUBJECT)?.trim()

        val parts = listOfNotNull(
            subject?.takeIf { it.isNotEmpty() },
            body?.takeIf { it.isNotEmpty() },
        )
        if (parts.isEmpty()) return null
        return parts.joinToString("\n")
    }
}
