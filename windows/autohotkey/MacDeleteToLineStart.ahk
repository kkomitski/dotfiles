A_MenuMaskKey := "vkE8"
#Requires AutoHotkey v2.0
#SingleInstance Force
$<^Backspace::{
    if IsWSLTerminal()
        Send "^u"
    else
        Send "+{Home}{Backspace}"
}

; UK Mac punctuation
$+sc003::SendText "@"
$+sc028::SendText Chr(34)
$<!sc004::SendInput "{Blind}{LAlt up}{U+0023}{LAlt down}"

; UK Mac pipe and tilde
$sc02B::SendText Chr(92)
$+sc02B::SendText Chr(124)
$sc056::SendText Chr(96)
$+sc056::SendText Chr(126)

; Mac-style screenshot toolbar
$<^+5::Send "#+s"

; Mac-style Chrome tab switching
#HotIf WinActive("ahk_exe chrome.exe")
$<^+[::Send "{Blind}{Tab}"
$<^+]::{
    leftHeld := GetKeyState("LShift", "P")
    rightHeld := GetKeyState("RShift", "P")
    Send "{Blind}{LShift up}{RShift up}{Tab}"
    if leftHeld
        Send "{Blind}{LShift down}"
    if rightHeld
        Send "{Blind}{RShift down}"
}
#HotIf


; Option+Backspace deletes previous word
$<!Backspace::{
    if IsWSLTerminal()
        SendInput "{Blind}{vkE8}{LAlt up}{Esc}{Backspace}{LAlt down}{vkE8}"
    else
        SendInput "{Blind}{vkE8}{LAlt up}^{Backspace}{LAlt down}{vkE8}"
}


; Shell editing applies only to the dedicated WSL Terminal profile.
IsWSLTerminal() {
    return WinActive("ahk_exe WindowsTerminal.exe") && InStr(WinGetTitle("A"), "WSL Terminal")
}
