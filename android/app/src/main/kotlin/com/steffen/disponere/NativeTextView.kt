package com.steffen.disponere

import android.content.Context
import android.text.InputType
import android.view.View
import android.widget.EditText
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

class NativeTextView(
    context: Context,
    id: Int,
    messenger: BinaryMessenger,
) : PlatformView {
    private val editText: EditText = EditText(context)
    private val channel = MethodChannel(messenger, "disponere/native-text_$id")

    init {
        editText.hint = "Mit dem M-Pencil hier schreiben…"
        editText.textSize = 18f
        editText.isFocusable = true
        editText.isFocusableInTouchMode = true
        editText.inputType =
            InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_FLAG_MULTI_LINE

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getText" -> result.success(editText.text.toString())
                else -> result.notImplemented()
            }
        }
    }

    override fun getView(): View = editText
    override fun dispose() {}
}

class NativeTextFactory(
    private val messenger: BinaryMessenger,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        return NativeTextView(context, viewId, messenger)
    }
}