#Requires AutoHotkey v2.0

; Ctrl+Shift+V → 逐字打出剪贴板内容
^+v:: {
    if !ClipWait(1) {
        MsgBox "剪贴板为空!"
        return
    }
    text := A_Clipboard

    ; 每个字符间隔 120ms，按下-松开间隔 50ms
    SetKeyDelay 400, 50

    for char in StrSplit(text, "")
        SendInput char
}
