#Requires AutoHotkey v2.0

; ==============================================================
; 全局键位互换（适用于所有程序）同时保留Shift组合键功能， 如Home End等，适合PgUp在方向键上面的情况。
; ==============================================================
PgUp::Send "{Home}"   ; Page Up → Home
PgDn::Send "{End}"    ; Page Down → End
Home::Send "{PgUp}"   ; Home → Page Up
End::Send "{PgDn}"    ; End → Page Down
; Shift + 按键
+PgUp::Send "+{Home}"   ; Shift+PgUp → Shift+Home
+PgDn::Send "+{End}"    ; Shift+PgDn → Shift+End