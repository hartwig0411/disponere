package com.steffen.disponere

import android.content.Context
import android.text.InputType
import android.view.View
import android.widget.EditText
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

class NativeTextView(context: Context) : PlatformView {
    private val editText: EditText = EditText(context)

    init {
        editText.hint = "Mit dem M-Pencil hier schreiben…"
        editText.textSize = 18f
        editText.isFocusable = true
        editText.isFocusableInTouchMode = true
        editText.inputType =
            InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_FLAG_MULTI_LINE
    }

    override fun getView(): View = editText

    override fun dispose() {}
}

class NativeTextFactory : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        return NativeTextView(context)
    }
}