package com.steffen.disponere

import android.content.Intent
import android.net.Uri
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {

    // Kanal fuer geteilte Inhalte (ACTION_SEND). Gegenstueck: ShareReceiver
    // (lib/services/share_receiver.dart). Zwei parallele Inhaltsarten mit
    // gleicher Consume-once-Logik: Text und Bild.
    private val shareChannelName = "disponere/share"
    private var shareChannel: MethodChannel? = null

    // Geteilter Text aus einem KALTSTART-Intent. Wird beim Aufbau der Engine aus
    // getIntent() gefuellt und von Flutter genau EINMAL ueber
    // getInitialSharedText abgeholt (danach null — ein bloßer App-Wechsel
    // liefert ihn nicht erneut).
    private var initialSharedText: String? = null

    // Geteiltes Bild aus einem KALTSTART-Intent. Analog zum Text: einmal ueber
    // getInitialSharedImage abgeholt, danach null. Als Map<String, String?> mit
    // den Schluesseln "path" (Pfad zur nativ erstellten Temp-Datei), "mime"
    // (aufgeloester MIME-Typ) und "caption" (etwaige Bildunterschrift aus
    // EXTRA_TEXT/EXTRA_SUBJECT, sonst null).
    private var initialSharedImage: Map<String, String?>? = null

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

        // Teilen-Kanal: Flutter zieht beim Start Kaltstart-Text bzw. -Bild;
        // Laufzeit-Shares reichen wir per invokeMethod nach.
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
                "getInitialSharedImage" -> {
                    val image = initialSharedImage
                    initialSharedImage = null // genau einmal ausliefern
                    result.success(image)
                }
                else -> result.notImplemented()
            }
        }
        shareChannel = channel

        // Kaltstart: kam die App ueber ACTION_SEND nach vorn, Text bzw. Bild
        // puffern, damit Flutter es beim ersten Frame abholen kann. Ein Intent
        // ist entweder text/* oder image/*, also ist hoechstens einer der beiden
        // Puffer gesetzt.
        initialSharedText = extractSharedText(intent)
        initialSharedImage = extractSharedImage(intent)
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
            return
        }
        val image = extractSharedImage(intent)
        if (image != null) {
            shareChannel?.invokeMethod("onSharedImage", image)
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

    // Zieht bei ACTION_SEND mit image/* das geteilte Bild aus EXTRA_STREAM.
    // Der content://-URI wird ueber den ContentResolver in eine app-private
    // Temp-Datei (cacheDir) kopiert — genau wie image_picker Flutter einen
    // Dateipfad liefert, sodass der bestehende Import-Weg (AttachmentStore.
    // importImage) unveraendert weiterlaeuft. Eine etwaige Bildunterschrift in
    // EXTRA_TEXT/EXTRA_SUBJECT wird als "caption" mitgegeben. Bei Fehlern (kein
    // URI, kein lesbarer Strom) -> null.
    private fun extractSharedImage(intent: Intent?): Map<String, String?>? {
        if (intent == null) return null
        if (intent.action != Intent.ACTION_SEND) return null
        val type = intent.type ?: return null
        if (!type.startsWith("image/")) return null

        val uri = streamUri(intent) ?: return null
        val mime = contentResolver.getType(uri) ?: type
        val path = copyToCache(uri, mime) ?: return null

        val body = intent.getStringExtra(Intent.EXTRA_TEXT)?.trim()
        val subject = intent.getStringExtra(Intent.EXTRA_SUBJECT)?.trim()
        val captionParts = listOfNotNull(
            subject?.takeIf { it.isNotEmpty() },
            body?.takeIf { it.isNotEmpty() },
        )
        val caption = if (captionParts.isEmpty()) null else captionParts.joinToString("\n")

        return mapOf(
            "path" to path,
            "mime" to mime,
            "caption" to caption,
        )
    }

    // EXTRA_STREAM als Uri holen — ab API 33 typisiert, davor die (deprecated)
    // Variante.
    private fun streamUri(intent: Intent): Uri? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableExtra(Intent.EXTRA_STREAM)
        }
    }

    // Kopiert den Inhalt des URI in eine eindeutige Temp-Datei unter cacheDir und
    // gibt deren Pfad zurueck. Endung aus dem MIME-Typ, sonst .img. Android raeumt
    // den Cache selbst — kein manuelles Aufraeumen (wie bei image_picker).
    private fun copyToCache(uri: Uri, mime: String): String? {
        return try {
            val ext = extensionForMime(mime)
            val dest = File(cacheDir, "shared_${System.currentTimeMillis()}$ext")
            contentResolver.openInputStream(uri)?.use { input ->
                FileOutputStream(dest).use { output ->
                    input.copyTo(output)
                }
            } ?: return null
            dest.absolutePath
        } catch (e: Exception) {
            null
        }
    }

    private fun extensionForMime(mime: String): String {
        return when (mime) {
            "image/jpeg" -> ".jpg"
            "image/png" -> ".png"
            "image/webp" -> ".webp"
            "image/heic" -> ".heic"
            "image/heif" -> ".heif"
            "image/gif" -> ".gif"
            else -> ".img"
        }
    }
}
