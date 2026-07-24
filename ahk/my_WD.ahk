#Requires AutoHotkey v2.0

; ===============================
; 全局键位互换（适用于所有程序）同时保留Shift组合键功能
; ===============================
PgUp::Send "{Home}"   ; Page Up → Home
PgDn::Send "{End}"    ; Page Down → End
Home::Send "{PgUp}"   ; Home → Page Up
End::Send "{PgDn}"    ; End → Page Down
; Shift + 按键
+PgUp::Send "+{Home}"   ; Shift+PgUp → Shift+Home
+PgDn::Send "+{End}"    ; Shift+PgDn → Shift+End


; Alt+M 自动打开欧路迷你查词窗口查询
#HotIf WinExist("迷你查词 ahk_exe eudic.exe")
Esc::Send "^+m"
#HotIf

!m::{
    A_Clipboard := ""          ; 清空旧内容
    Send "^c"                  ; 发出复制指令
    Sleep 100
    text := Trim(A_Clipboard)

    if (text = "") {
        Send "^+m"
        return
    }

    winTitle := "迷你查词 ahk_exe eudic.exe"

    ; 如果窗口已存在，就激活它
    if WinExist(winTitle) {
        WinActivate(winTitle)
        WinWaitActive(winTitle,, 1)
    } else {
        ; 不存在，调出迷你查词
        Send "^+m"
        if !WinWait(winTitle,, 1) {
            MsgBox "未检测到欧路迷你查词窗口"
            return
        }
        WinActivate(winTitle)
        WinWaitActive(winTitle,, 1)
    }
    Sleep 80
    ; 输入文本
    Send "^a"
    Sleep 50
    Send "^v"
    ; SendText text
    Sleep 50
    Send "{Enter}"
}

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

; ===============================
; 热键仅在 Excel 生效
; ===============================
#HotIf WinActive("ahk_exe EXCEL.EXE")

; Ctrl+Shift+H → 选择性粘贴格式（格式刷功能）
^+h:: {
    Send "^!v"     ; Ctrl+Alt+V
    Send "t"       ; T
    Send "{Enter}" ; Enter
}

#HotIf

; ===============================
; 仅在 Word 窗口生效
; ===============================
#HotIf WinActive("ahk_exe WINWORD.EXE")

^+/:: {  ; Ctrl+Shift+/ 热键
    CoordMode "Mouse", "Window"   ; 鼠标坐标相对当前活动窗口
    MouseMove(324, 595, 10)  ; 速度10
    MouseClick("right")
    Sleep 50  ; 延时，保证菜单弹出
    Send "h"
    Send "1"
}

; 默认Ctrl+Alt+H 设置红色字体的快捷键
; 等价FontColor字体颜色，但只能设置一种。
AllReleased(keys) {
    for k in keys {
        return !GetKeyState(k)  ; 任意一个键仍按下则返回 False
    }
    return true
}
OpenWordFontColor(){
    startTime := A_TickCount
    ; 等待释放所有修饰键，避免Alt键卡住
    Sleep 100
    while (A_TickCount - startTime < 3000) {
        if(AllReleased(["Ctrl", "Alt", "H", "J"])){
            break
        }else{
            Sleep 100  ; 
        }
    }
    ; 发送 Alt+H,F,C 进入字体颜色选择
    Send "!h"
    Send "f"
    Send "c"
}
^!h::
{
    OpenWordFontColor()
    ; 下方向键7次 标准颜色
    Loop 7 {
        Send "{Down}"
    }
    Loop 1 {
        Send "{Right}"
    }
    Send "{Enter}"
}
^!j::
{
    OpenWordFontColor()
    ; 下方向键7次 标准颜色
    Loop 7 {
        Send "{Down}"
    }
    Loop 5 {
        Send "{Right}"
    }
    Send "{Enter}"
}

#HotIf