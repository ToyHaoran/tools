#Requires AutoHotkey v2.0

; ==============================
; 文件分割 & 合并工具 (AHK v2) - Buffer二进制安全版
; 更推荐FileMenu tool工具
; ==============================

SplitFile(filePath, chunkSizeMB) {
    chunkSize := chunkSizeMB * 1024 * 1024
    f := FileOpen(filePath, "r")
    if !f
        throw Error("无法打开文件: " filePath)

    part := 1
    loop {
        buf := Buffer(chunkSize)  ; 创建缓冲区
        bytesRead := f.RawRead(buf, chunkSize)
        if bytesRead = 0
            break

        outPath := filePath "_" part ".bin"
        fout := FileOpen(outPath, "w")
        if !fout {
            f.Close()
            throw Error("无法创建分块: " outPath)
        }
        wrote := fout.RawWrite(buf, bytesRead)
        fout.Close()

        if wrote != bytesRead {
            f.Close()
            MsgBox "写入字节数不匹配！分割中断。"
            return
        }
        part++
    }
    f.Close()
    MsgBox "分割完成！共生成 " (part-1) " 个文件。"
}

MergeFiles(firstPartPath) {
    if !RegExMatch(firstPartPath, "^(.*)_\d+\.bin$", &m) {
        MsgBox "文件名格式不对，应为 xxx_1.bin"
        return
    }
    basePath := m[1]

    outFile := basePath "_merge"
    fout := FileOpen(outFile, "w")
    if !fout {
        MsgBox "无法创建输出文件: " outFile
        return
    }

    part := 1
    loop {
        partPath := basePath "_" part ".bin"
        if !FileExist(partPath)
            break

        fpart := FileOpen(partPath, "r")
        if !fpart {
            fout.Close()
            MsgBox "无法打开分块: " partPath
            return
        }

        buf := Buffer(fpart.Length)  ; 创建缓冲区
        bytesRead := fpart.RawRead(buf)
        fpart.Close()

        if bytesRead = 0
            break

        wrote := fout.RawWrite(buf, bytesRead)
        if wrote != bytesRead {
            fout.Close()
            MsgBox "写入失败：分块 " part " 未能全部写入。"
            return
        }
        part++
    }

    fout.Close()
    MsgBox "合并完成！输出文件: " outFile
}

; ==============================
; GUI 界面 (mygui)
; ==============================
mygui := Gui("+Resize", "文件分割 & 合并工具 (Buffer版)")

mygui.Add("Text",, "选择文件：")
fileEdit := mygui.Add("Edit", "w300")
btnBrowse := mygui.Add("Button", "x+5", "浏览...")

mygui.Add("Text", "xm y+10", "分割大小 (MB)：")
sizeEdit := mygui.Add("Edit", "w100", "10")

btnSplit := mygui.Add("Button", "xm y+10 w150", "分割文件")
btnMerge := mygui.Add("Button", "x+10 w150", "合并文件")

; ==============================
; 事件处理函数
; ==============================
BrowseFile(*) {
    global fileEdit
    f := FileSelect(3, , "选择文件")
    if f
        fileEdit.Value := f
}

DoSplit(*) {
    global fileEdit, sizeEdit
    path := fileEdit.Value
    if !FileExist(path) {
        MsgBox "请选择一个有效的文件！"
        return
    }
    size := sizeEdit.Value + 0
    if size <= 0 {
        MsgBox "请输入正确的分割大小（MB）！"
        return
    }
    SplitFile(path, size)
}

DoMerge(*) {
    f := FileSelect(3, , "选择第一个分块文件 (xxx_1.bin)")
    if f
        MergeFiles(f)
}

btnBrowse.OnEvent("Click", BrowseFile)
btnSplit.OnEvent("Click", DoSplit)
btnMerge.OnEvent("Click", DoMerge)

mygui.Show()
