; Alt+M 自动翻译，自动复制并打开迷你查词窗口查询
winTitle := "迷你查词 ahk_exe eudic.exe"

#HotIf WinExist(winTitle)
Esc::Send "^+m"
#HotIf

!m::{
    A_Clipboard := ""          ; 清空旧内容
    Send "^c"                  ; 发出复制指令
    Sleep 100
    text := Trim(A_Clipboard)

    if (text = "")
        return

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