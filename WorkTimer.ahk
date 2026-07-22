#Requires AutoHotkey v2.0
#SingleInstance Force
SetWinDelay(-1) ; 拖动时不等待窗口移动完成，避免移动指令堆积造成抖动
CoordMode("Mouse", "Screen") ; 拖动坐标始终相对屏幕，不能随活动窗口切换
CoordMode("Pixel", "Screen") ; 背景取色同样固定使用屏幕坐标

; 任务栏上的可见计时器。双击时间可重新开始，右键可退出。
configPath := A_ScriptDir "\WorkTimer.ini"
startTick := A_TickCount
notified := false
paused := false
pausedElapsed := 0
pauseMenuText := "暂停计时"
soundEndTick := 0
countdownActive := false
countdownEndTick := 0
countdownRemaining := 0
notifyAfterSeconds := Integer(IniRead(configPath, "Settings", "ReminderMinutes", "60")) * 60
reminderSound := IniRead(configPath, "Settings", "ReminderSound", "chimes.wav")
isCustomPosition := IniRead(configPath, "Window", "CustomPosition", "0") = "1"
isDragging := false
dragMouseX := 0
dragMouseY := 0
dragWindowX := 0
dragWindowY := 0
lastLeftClickTick := 0
savedX := Integer(IniRead(configPath, "Window", "X", "0"))
savedY := Integer(IniRead(configPath, "Window", "Y", "0"))
timerWidth := 100
timerHeight := 26
fontSize := 9
textColor := "000000"
mouseThrough := false
mouseMenuText := "启动鼠标穿透"
fullscreenHide := false
fullscreenMenuText := "启动全屏隐藏"
hiddenForFullscreen := false

timerGui := Gui("-Caption +ToolWindow +AlwaysOnTop")
timerGui.BackColor := "FF00FF" ; 使用洋红色作透明色，避免与黑/白文字冲突
timeText := timerGui.AddText("x4 y3 w92 h20 Center c000000 BackgroundFF00FF", "00:00:00")
timeText.SetFont("s9 Bold", "Segoe UI")
; 透明区域本身无法稳定接收鼠标事件，故仅在鼠标位于文字范围内时拦截按键。
HotIf(MouseIsOverTimer)
Hotkey("RButton", BeginDrag)
Hotkey("LButton", HandleLeftClick)
Hotkey("MButton", ShowTrayMenu)
HotIf()
OnMessage(0x0232, SavePosition) ; WM_EXITSIZEMOVE

; Windows 11 不支持第三方窗口可靠地嵌入任务栏内部，因此贴在任务栏边缘显示。
; 这样始终可见，也不会挡住任务栏按钮。
taskbar := WinExist("ahk_class Shell_TrayWnd")
if !taskbar
    throw Error("找不到 Windows 任务栏。")

PositionInTaskbar()
WinSetTransColor("FF00FF", "ahk_id " timerGui.Hwnd)

A_TrayMenu.Delete()
A_TrayMenu.Add("重新开始", ResetTimer)
A_TrayMenu.Add(pauseMenuText, TogglePause)
A_TrayMenu.Add(mouseMenuText, ToggleMouseThrough)
A_TrayMenu.Add(fullscreenMenuText, ToggleFullscreenHide)
reminderMenu := Menu()
reminderMenu.Add("第 30 分钟提醒", (*) => SetReminder(30))
reminderMenu.Add("第 60 分钟提醒", (*) => SetReminder(60))
reminderMenu.Add("第 90 分钟提醒", (*) => SetReminder(90))
reminderMenu.Add("自定义…", SetCustomReminder)
A_TrayMenu.Add("提醒时点", reminderMenu)
countdownMenu := Menu()
countdownMenu.Add("启动倒计时…", StartCountdown)
countdownMenu.Add("停止倒计时", StopCountdown)
A_TrayMenu.Add("倒计时", countdownMenu)
soundMenu := Menu()
soundMenu.Add("风铃（较长）", (*) => SetReminderSound("chimes.wav"))
soundMenu.Add("登场音", (*) => SetReminderSound("tada.wav"))
soundMenu.Add("系统通知", (*) => SetReminderSound("Windows Notify System Generic.wav"))
A_TrayMenu.Add("提醒声音", soundMenu)
sizeMenu := Menu()
sizeMenu.Add("小（90 × 24）", (*) => SetSize(90, 24, 8))
sizeMenu.Add("标准（100 × 26）", (*) => SetSize(100, 26, 9))
sizeMenu.Add("大（120 × 30）", (*) => SetSize(120, 30, 10))
sizeMenu.Add("自定义…", SetCustomSize)
A_TrayMenu.Add("显示大小", sizeMenu)
A_TrayMenu.Add("恢复自动停靠", ResetPosition)
A_TrayMenu.Add()
A_TrayMenu.Add("退出", (*) => ExitApp())

SetTimer(UpdateStatus, 1000)
SetTimer(PositionInTaskbar, 5000)
SetTimer(UpdateTextColor, 1000)
SetTimer(CheckFullscreen, 500)
UpdateStatus()
UpdateTextColor()

PositionInTaskbar(*) {
    global timerGui, taskbar, isCustomPosition, isDragging, savedX, savedY, hiddenForFullscreen
    if hiddenForFullscreen
        return
    if isDragging
        return
    if isCustomPosition {
        timerGui.Show("x" savedX " y" savedY " w" timerWidth " h" timerHeight " NA")
        return
    }
    WinGetPos(&taskbarX, &taskbarY, &taskbarW, &taskbarH, "ahk_id " taskbar)
    notifyArea := WinExist("ahk_class TrayNotifyWnd")
    if notifyArea {
        WinGetPos(&notifyX, &notifyY, &notifyW, &notifyH, "ahk_id " notifyArea)
    } else {
        notifyX := taskbarX + taskbarW
        notifyY := taskbarY
    }
    if taskbarW >= taskbarH { ; 顶部或底部任务栏
        timerX := Max(taskbarX, notifyX - timerWidth - 4)
        timerY := taskbarY > A_ScreenHeight // 2 ? taskbarY - timerHeight - 3 : taskbarY + taskbarH + 3
    } else { ; 左侧或右侧任务栏
        timerX := taskbarX > A_ScreenWidth // 2 ? taskbarX - timerWidth - 3 : taskbarX + taskbarW + 3
        timerY := Max(taskbarY, notifyY)
    }
    timerGui.Show("x" timerX " y" timerY " w" timerWidth " h" timerHeight " NA")
}

UpdateStatus(*) {
    global startTick, notified, paused, pausedElapsed, timeText, notifyAfterSeconds
    global countdownActive, countdownEndTick, countdownRemaining
    if countdownActive {
        remaining := paused ? countdownRemaining : Max(0, Ceil((countdownEndTick - A_TickCount) / 1000))
        hours := Floor(remaining / 3600)
        minutes := Floor(Mod(remaining, 3600) / 60)
        seconds := Mod(remaining, 60)
        timeText.Text := Format("{1:02}:{2:02}:{3:02}", hours, minutes, seconds)
        A_IconTip := "倒计时 " timeText.Text (paused ? "（已暂停）" : "") "`n右键托盘图标打开设置"
        if !paused && remaining = 0 {
            countdownActive := false
            TrayTip("倒计时已结束。", "久坐提醒", 17)
            StartReminderSound()
        }
        return
    }
    elapsed := paused ? pausedElapsed : Floor((A_TickCount - startTick) / 1000)
    hours := Floor(elapsed / 3600)
    minutes := Floor(Mod(elapsed, 3600) / 60)
    seconds := Mod(elapsed, 60)
    timeText.Text := Format("{1:02}:{2:02}:{3:02}", hours, minutes, seconds)
    A_IconTip := "已工作 " timeText.Text (paused ? "（已暂停）" : "") "`n右键托盘图标打开设置"

    if !paused && !notified && elapsed >= notifyAfterSeconds {
        notified := true
        TrayTip("已连续工作 " notifyAfterSeconds // 60 " 分钟，起来活动一下吧！", "久坐提醒", 17)
        StartReminderSound()
    }
}

UpdateTextColor(*) {
    global timerGui, timeText, textColor
    timerHwnd := timerGui.Hwnd
    if !WinExist("ahk_id " timerHwnd)
        return
    WinGetPos(&x, &y, &width, &height, "ahk_id " timerHwnd)
    ; 取透明边缘处的背景像素，按明暗自动选择反差最大的黑/白文字。
    backgroundColor := PixelGetColor(x + 1, y + 1, "RGB")
    red := (backgroundColor >> 16) & 0xFF
    green := (backgroundColor >> 8) & 0xFF
    blue := backgroundColor & 0xFF
    luminance := red * 0.299 + green * 0.587 + blue * 0.114
    newColor := luminance > 145 ? "000000" : "FFFFFF"
    if newColor != textColor {
        textColor := newColor
        timeText.Opt("c" textColor)
    }
}

ResetTimer(*) {
    global startTick, notified, paused, pausedElapsed, pauseMenuText, countdownActive
    startTick := A_TickCount
    notified := false
    countdownActive := false
    SetTimer(RepeatReminderSound, 0)
    pausedElapsed := 0
    if paused {
        A_TrayMenu.Rename(pauseMenuText, "暂停计时")
        pauseMenuText := "暂停计时"
        paused := false
    }
    UpdateStatus()
}

TogglePause(*) {
    global startTick, paused, pausedElapsed, pauseMenuText
    global countdownActive, countdownEndTick, countdownRemaining
    if paused {
        startTick := A_TickCount - pausedElapsed * 1000
        if countdownActive
            countdownEndTick := A_TickCount + countdownRemaining * 1000
        paused := false
        A_TrayMenu.Rename(pauseMenuText, "暂停计时")
        pauseMenuText := "暂停计时"
    } else {
        pausedElapsed := Floor((A_TickCount - startTick) / 1000)
        if countdownActive
            countdownRemaining := Max(0, Ceil((countdownEndTick - A_TickCount) / 1000))
        paused := true
        SetTimer(RepeatReminderSound, 0)
        A_TrayMenu.Rename(pauseMenuText, "继续计时")
        pauseMenuText := "继续计时"
    }
    UpdateStatus()
}

BeginDrag(*) {
    global timerGui, isCustomPosition, isDragging
    global dragMouseX, dragMouseY, dragWindowX, dragWindowY
    if isDragging
        return
    isCustomPosition := true
    isDragging := true
    MouseGetPos(&dragMouseX, &dragMouseY)
    WinGetPos(&dragWindowX, &dragWindowY, , , "ahk_id " timerGui.Hwnd)
    SetTimer(DragWindow, 16) ; 约 60 FPS，平滑且不会过度刷新
}

MouseIsOverTimer(*) {
    global timerGui, mouseThrough
    if mouseThrough
        return false
    timerHwnd := timerGui.Hwnd
    if !WinExist("ahk_id " timerHwnd)
        return false
    MouseGetPos(&mouseX, &mouseY)
    WinGetPos(&x, &y, &width, &height, "ahk_id " timerHwnd)
    return mouseX >= x && mouseX < x + width && mouseY >= y && mouseY < y + height
}

HandleLeftClick(*) {
    global lastLeftClickTick
    now := A_TickCount
    if now - lastLeftClickTick <= DllCall("GetDoubleClickTime") {
        lastLeftClickTick := 0
        ResetTimer()
    } else {
        lastLeftClickTick := now
    }
}

ToggleMouseThrough(*) {
    global timerGui, mouseThrough, mouseMenuText
    mouseThrough := !mouseThrough
    if mouseThrough {
        WinSetExStyle("+0x20", "ahk_id " timerGui.Hwnd) ; WS_EX_TRANSPARENT
        A_TrayMenu.Rename(mouseMenuText, "停止鼠标穿透")
        mouseMenuText := "停止鼠标穿透"
    } else {
        WinSetExStyle("-0x20", "ahk_id " timerGui.Hwnd)
        A_TrayMenu.Rename(mouseMenuText, "启动鼠标穿透")
        mouseMenuText := "启动鼠标穿透"
    }
}

ToggleFullscreenHide(*) {
    global fullscreenHide, fullscreenMenuText, hiddenForFullscreen
    fullscreenHide := !fullscreenHide
    if fullscreenHide {
        A_TrayMenu.Rename(fullscreenMenuText, "停止全屏隐藏")
        fullscreenMenuText := "停止全屏隐藏"
    } else {
        A_TrayMenu.Rename(fullscreenMenuText, "启动全屏隐藏")
        fullscreenMenuText := "启动全屏隐藏"
        if hiddenForFullscreen {
            hiddenForFullscreen := false
            PositionInTaskbar()
        }
    }
    CheckFullscreen()
}

CheckFullscreen(*) {
    global timerGui, fullscreenHide, hiddenForFullscreen
    if !fullscreenHide
        return
    activeWindow := WinExist("A")
    shouldHide := activeWindow && activeWindow != timerGui.Hwnd && IsFullscreenWindow(activeWindow)
    if shouldHide && !hiddenForFullscreen {
        timerGui.Hide()
        hiddenForFullscreen := true
    } else if !shouldHide && hiddenForFullscreen {
        hiddenForFullscreen := false
        PositionInTaskbar()
    }
}

IsFullscreenWindow(windowHwnd) {
    WinGetPos(&x, &y, &width, &height, "ahk_id " windowHwnd)
    if width <= 0 || height <= 0
        return false
    Loop MonitorGetCount() {
        MonitorGet(A_Index, &left, &top, &right, &bottom)
        if x <= left + 2 && y <= top + 2 && x + width >= right - 2 && y + height >= bottom - 2
            return true
    }
    return false
}

ShowTrayMenu(*) {
    A_TrayMenu.Show()
}

SavePosition(wParam, lParam, msg, hwnd) {
    global timerGui, isCustomPosition
    if hwnd != timerGui.Hwnd || !isCustomPosition
        return
    StorePosition()
}

DragWindow(*) {
    global timerGui, isDragging, dragMouseX, dragMouseY, dragWindowX, dragWindowY
    if !GetKeyState("RButton", "P") {
        SetTimer(DragWindow, 0)
        StorePosition()
        return
    }
    MouseGetPos(&mouseX, &mouseY)
    WinMove(dragWindowX + mouseX - dragMouseX, dragWindowY + mouseY - dragMouseY, , , "ahk_id " timerGui.Hwnd)
}

StorePosition() {
    global timerGui, isCustomPosition, isDragging, savedX, savedY, configPath
    if !isCustomPosition
        return
    isDragging := false
    WinGetPos(&savedX, &savedY, , , "ahk_id " timerGui.Hwnd)
    IniWrite("1", configPath, "Window", "CustomPosition")
    IniWrite(savedX, configPath, "Window", "X")
    IniWrite(savedY, configPath, "Window", "Y")
}

SetSize(width, height, newFontSize) {
    global timerGui, timeText, timerWidth, timerHeight, fontSize
    timerWidth := width
    timerHeight := height
    fontSize := newFontSize
    timeText.SetFont("s" fontSize " Bold", "Segoe UI")
    timeText.Move(4, 2, timerWidth - 8, timerHeight - 4)
    WinGetPos(&x, &y, , , "ahk_id " timerGui.Hwnd)
    timerGui.Show("x" x " y" y " w" timerWidth " h" timerHeight " NA")
}

SetCustomSize(*) {
    global timerWidth, timerHeight, fontSize
    defaultValue := timerWidth " × " timerHeight " × " fontSize
    answer := InputBox("请输入 宽度 × 高度 × 字号（例如：110 × 28 × 9）：", "自定义显示大小", "w360 h140", defaultValue)
    if answer.Result != "OK"
        return
    if !RegExMatch(answer.Value, "^\s*(\d+)\s*[xX×, ]\s*(\d+)\s*[xX×, ]\s*(\d+)\s*$", &match) {
        MsgBox("格式应为：宽度 × 高度 × 字号，例如：110 × 28 × 9。", "显示大小", 48)
        return
    }
    width := Integer(match[1])
    height := Integer(match[2])
    newFontSize := Integer(match[3])
    if width < 50 || width > 500 || height < 20 || height > 120 || newFontSize < 6 || newFontSize > 40 {
        MsgBox("宽度范围 50–500，高度范围 20–120，字号范围 6–40。", "显示大小", 48)
        return
    }
    SetSize(width, height, newFontSize)
}

ResetPosition(*) {
    global isCustomPosition, configPath
    isCustomPosition := false
    IniWrite("0", configPath, "Window", "CustomPosition")
    PositionInTaskbar()
}

SetReminder(minutes) {
    global notifyAfterSeconds, notified, configPath
    notifyAfterSeconds := minutes * 60
    notified := false
    IniWrite(minutes, configPath, "Settings", "ReminderMinutes")
    UpdateStatus()
}

StartCountdown(*) {
    global countdownActive, countdownEndTick, countdownRemaining, paused, pauseMenuText
    answer := InputBox("请输入秒数，或 分:秒（例如：90 或 25:30）：", "启动倒计时", "w350 h130", "25:00")
    if answer.Result != "OK"
        return
    value := Trim(answer.Value)
    if RegExMatch(value, "^\d+$") {
        totalSeconds := Integer(value)
    } else if RegExMatch(value, "^(\d+):([0-5]\d)$", &match) {
        totalSeconds := Integer(match[1]) * 60 + Integer(match[2])
    } else {
        MsgBox("请输入秒数（如 90），或 分:秒（如 25:30）。", "倒计时", 48)
        return
    }
    if totalSeconds < 1 {
        MsgBox("倒计时必须大于 0 秒。", "倒计时", 48)
        return
    }
    countdownRemaining := totalSeconds
    countdownEndTick := A_TickCount + countdownRemaining * 1000
    countdownActive := true
    if paused {
        A_TrayMenu.Rename(pauseMenuText, "暂停计时")
        pauseMenuText := "暂停计时"
    }
    paused := false
    UpdateStatus()
}

StopCountdown(*) {
    global countdownActive
    countdownActive := false
    UpdateStatus()
}

SetReminderSound(fileName) {
    global reminderSound, configPath
    reminderSound := fileName
    IniWrite(fileName, configPath, "Settings", "ReminderSound")
    PlayReminderSound() ; 选择后立即试听
}

StartReminderSound() {
    global soundEndTick
    soundEndTick := A_TickCount + 30000
    PlayReminderSound()
    SetTimer(RepeatReminderSound, 4000)
}

RepeatReminderSound(*) {
    global soundEndTick
    if A_TickCount >= soundEndTick {
        SetTimer(RepeatReminderSound, 0)
        return
    }
    PlayReminderSound()
}

PlayReminderSound() {
    global reminderSound
    try SoundPlay(A_WinDir "\Media\" reminderSound)
    catch
        SoundBeep(900, 500)
}

SetCustomReminder(*) {
    answer := InputBox("请输入要提醒的分钟数：", "设置久坐提醒", "w300 h130", "60")
    if answer.Result != "OK"
        return
    if !RegExMatch(answer.Value, "^\d+$") || Integer(answer.Value) < 1 {
        MsgBox("请输入大于 0 的整数分钟数。", "久坐提醒", 48)
        return
    }
    SetReminder(Integer(answer.Value))
}
