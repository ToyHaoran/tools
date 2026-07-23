#Requires AutoHotkey v2.0

; ==============================================================
; 仅在 Word 窗口生效 
; 快捷键设置：文件--选项--自定义功能区--键盘快捷方式 自定义--类别--所有命令；
; PasteTextOnly 只保留文本粘贴，设置为Ctrl+Shift+V
; ==============================================================
#HotIf WinActive("ahk_exe WINWORD.EXE")
; Ctrl+Shift+/ 目录对其到一级标题。
^+/:: {  
    CoordMode "Mouse", "Window"   ; 鼠标坐标相对当前活动窗口
    MouseMove(324, 595, 10)  ; 速度10  适配大屏
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
    ; 红色
    Loop 1 {
        Send "{Right}"
    }
    Send "{Enter}"
}
; Ctrl+Alt+j 第二种颜色，要么^!h&j
^!j::
{
    OpenWordFontColor()
    ; 下方向键7次 标准颜色
    Loop 7 {
        Send "{Down}"
    }
    ; 绿色
    Loop 5 {
        Send "{Right}"
    }
    Send "{Enter}"
}

#HotIf