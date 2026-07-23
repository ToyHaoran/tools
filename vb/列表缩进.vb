Sub 列表缩进()
    Dim lt As ListTemplate
    Dim i As Integer
    Dim stepIndent As Single
    
    ' 设置基础缩进步长（单位：厘米）
    ' 这里定义每一级比上一级多缩进 0.40 厘米
    stepIndent = 0.4
    
    ' 检查当前光标是否在列表内
    If Selection.Range.ListFormat.ListTemplate Is Nothing Then
        MsgBox "请先将光标置于一个多级列表中！"
        Exit Sub
    End If
    
    ' 获取当前选中的列表模板
    Set lt = Selection.Range.ListFormat.ListTemplate
    
    For i = 1 To 9
        With lt.ListLevels(i)
            ' 1. 编号对齐位置 (左对齐距离)
            .NumberPosition = CentimetersToPoints((i - 1) * stepIndent)
            
            ' 2. 文本缩进位置 (如果文本换行后的起始位置)
            .TextPosition = CentimetersToPoints(i * stepIndent)
            
            ' 3. 制表位位置 (编号与文字之间的距离，通常与文本缩进保持一致)
            .TabPosition = CentimetersToPoints(i * stepIndent)
            
            ' 4. 编号之后的操作：可选 wdTrailingTab(制表符), wdTrailingSpace(空格), wdTrailingNone(无)
            .TrailingCharacter = wdTrailingTab
            
            ' 5. 对齐方式
            .Alignment = wdListLevelAlignLeft
        End With
    Next i
End Sub