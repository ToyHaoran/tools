#Requires AutoHotkey v2.0

; Ctrl+Alt+[ 窗口置顶
^![:: {
    win := WinGetID("A")
    ; 检测当前窗口是否置顶
    isTop := WinGetExStyle("ahk_id " win) & 0x8  ; WS_EX_TOPMOST = 0x8
    if (!isTop)
        WinSetAlwaysOnTop(true, "ahk_id " win)
    else
        WinSetAlwaysOnTop(false, "ahk_id " win)
    SoundPlay("*-1")
}
