#CS
File: asciipaintviewer.au3
This AutoIT script wraps a consoul (consoul.net) window
in an AutoIT GUI Window.
The contents of the console window comes from a vt100 (consoul subset)
file which *must* be encoded in UTF 16 LE with BOM (which is VBA encoding
for text files, and produced by the AsciiPaint application).
A background picture can be displayed under the console window, which
can itself be transparent.

Version notes

01.00.00
- All the script input parameters come from an ini file.
  The name of the ini file is fixed and specified in the const $INI_FILE.
- Only alpha transparency is supported in this version. Color transparency,
  which is also supported by consoul console windows will be added later.

AutoIT: v3.3.6.1
Platform: Win7+
Author: Francesco Foti (francesco.foti@devinfo.net)
Copyright (C) 2021 Francesco Foti

This source file is UTF-8 encoded.

When       | Who |Ver     | What
-----------+-----+----------+------------------------------
18.07.2021 | FFO |01.00.00| First version
           |     |        |
#CE
#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>
#include <WinAPI.au3>
#include <MsgBoxConstants.au3>
#include <GDIPlus.au3>
;https://www.autoitscript.com/forum/topic/100167-_guiresourcepicau3-udf-supports-gif-animation-using-gdi/
#include "GIFAnimation.au3"

const $INI_FILE = "asciipaint-gif-viewer.ini"
const $SECTION_OPTIONS = "options"
const $INIPARAM_INPUTFILE = "inputfile"
const $INIPARAM_FONTNAME = "fontname"
const $INIPARAM_FONTSIZE = "fontsize"
const $INIPARAM_QUEUESIZE = "qsize"
const $INIPARAM_BACKCOLOR = "backcolor"
const $INIPARAM_FORECOLOR = "forecolor"
const $INIPARAM_WINDOWTITLE = "windowtitle"
const $INIPARAM_WINDOWWIDTH = "windowwidth"
const $INIPARAM_WINDOWHEIGHT = "windowheight"
const $INIPARAM_BKGNDIMAGE = "backgroundimage"
const $INIPARAM_ALPHAPERCENT = "alphapercent"
const $DEFAULT_FONTNAME = "Lucida Console"
const $DEFAULT_FONTSIZE = 8
const $DEFAULT_QUEUESIZE = 500
const $DEFAULT_BACKCOLOR = 0
const $DEFAULT_FORECOLOR = 16777215
const $DEFAULT_WINDOWTITLE = "AsciiPaint Viewer"
const $DEFAULT_WINDOWWIDTH = 640
const $DEFAULT_WINDOWHEIGHT = 480
const $DEFAULT_ALPHAPERCENT = 65

;Set AutoIT options
AutoItSetOption("MustDeclareVars", 1)
AutoItSetOption("TrayIconHide", 1)
Opt("GUIOnEventMode", 1)  ;Defines on event mode
Opt("GUICloseOnESC", 0)   ;Can't let Esc terminate the script execution

;Trap error globally
Global $goError = ObjEvent("AutoIt.Error", "_ErrFunc")

;Consoul's dll and output window
Global $ghConsole = 0
Global $gsConsoulDLL = "consoul_010203_32.dll"
Global $ghConsoulLibrary
;viewer globals
Global $gsConFontName
Global $giConX = 0, $giConY = 0, $giConWidth = 100, $giConHeight = 100
Global $glConBackColor
Global $glConForeColor
Global $giConFontSize
Global $giConQueueSize
Global $gsMainWindowTitle
Global $gsInputFile
Global $ghInputFile = 0
;UI
Global $ghWndMain, $gfMainClosed, $gfCanClose = 0
Global $giInitialWinWidth
Global $giInitialWinHeight
;Background picture
Global $giBackgroundPictureID = 0
Global $gsBackgroundPictureFile = ""
Global $gbAlphaPercent = 0

;handle on loaded GIF/Animated image
Global $hGIF

;----------------------------------------------------------------
; Main
;----------------------------------------------------------------

;Read ini file parameters
$gsInputFile = IniRead($INI_FILE, $SECTION_OPTIONS, $INIPARAM_INPUTFILE, "")
If $gsInputFile="" Then
  MsgBox(16+$MB_SYSTEMMODAL, "Missing vt100 file", "No vt100 (UTF 16 BOM LE) specified in ini file")
  Exit
EndIf
If Not FileExists($gsInputFile) Then
  MsgBox(16+$MB_SYSTEMMODAL, "Missing file", "Can't find input file [" & $gsInputFile & "]")
  Exit
EndIf
$giConFontSize = Number(IniRead($INI_FILE, $SECTION_OPTIONS, $INIPARAM_FONTSIZE, $DEFAULT_FONTSIZE), $NUMBER_32BIT)
If $giConFontSize<=0 Then
  $giConFontSize = $DEFAULT_FONTSIZE
EndIf
$giConQueueSize = Number(IniRead($INI_FILE, $SECTION_OPTIONS, $INIPARAM_QUEUESIZE, $DEFAULT_QUEUESIZE), $NUMBER_32BIT)
If ($giConQueueSize<=0) Or ($giConQueueSize>32767) Then
  $giConQueueSize = $DEFAULT_QUEUESIZE
EndIf
$gsConFontName = IniRead($INI_FILE, $SECTION_OPTIONS, $INIPARAM_FONTNAME, $DEFAULT_FONTNAME)
$glConBackColor = Number(IniRead($INI_FILE, $SECTION_OPTIONS, $INIPARAM_BACKCOLOR, $DEFAULT_BACKCOLOR), $NUMBER_32BIT)
If ($glConBackColor<0) Then
  $glConBackColor = $DEFAULT_BACKCOLOR
EndIf
$glConForeColor = Number(IniRead($INI_FILE, $SECTION_OPTIONS, $INIPARAM_FORECOLOR, $DEFAULT_FORECOLOR), $NUMBER_32BIT)
If ($glConForeColor<0) Then
  $glConForeColor = $DEFAULT_FORECOLOR
EndIf
$gsMainWindowTitle = IniRead($INI_FILE, $SECTION_OPTIONS, $INIPARAM_WINDOWTITLE, $DEFAULT_WINDOWTITLE)
If $gsMainWindowTitle="" Then
  $gsMainWindowTitle = $DEFAULT_WINDOWTITLE
EndIf
$giInitialWinWidth = Number(IniRead($INI_FILE, $SECTION_OPTIONS, $INIPARAM_WINDOWWIDTH, $DEFAULT_WINDOWWIDTH), $NUMBER_32BIT)
If ($giInitialWinWidth<=0) Or ($giInitialWinWidth>@DesktopWidth) Then
  $giInitialWinWidth = $DEFAULT_WINDOWWIDTH
EndIf
$giInitialWinHeight = Number(IniRead($INI_FILE, $SECTION_OPTIONS, $INIPARAM_WINDOWHEIGHT, $DEFAULT_WINDOWHEIGHT), $NUMBER_32BIT)
If ($giInitialWinHeight<=0) Or ($giInitialWinHeight>@DesktopHeight) Then
  $giInitialWinHeight = $DEFAULT_WINDOWHEIGHT
EndIf
$gsBackgroundPictureFile = IniRead($INI_FILE, $SECTION_OPTIONS, $INIPARAM_BKGNDIMAGE, "")
$gbAlphaPercent = Number(IniRead($INI_FILE, $SECTION_OPTIONS, $INIPARAM_ALPHAPERCENT, $DEFAULT_ALPHAPERCENT), $NUMBER_32BIT)
If ($gbAlphaPercent<0) Or ($gbAlphaPercent>100) Then
  $gbAlphaPercent = $DEFAULT_ALPHAPERCENT
EndIf

; load consoul library dll and exit if any problem
$ghConsoulLibrary = _WinAPI_LoadLibrary($gsConsoulDLL)
If $ghConsoulLibrary=0 Then
  MsgBox(16+$MB_SYSTEMMODAL, "Missing library", "Failed to load consoul library " & $gsConsoulDLL & ". Please check that the dll is in the current directory or in your PATH")
  Exit
EndIf

; temp variables used in the main body of the script
Dim $iRet, $fOK, $i, $msg
Dim $iWinLeft=-1, $iWinTop=-1, $iWinWidth=-1, $iWinHeight=-1

; create main UI window (just a container for the consoul window)
$iWinWidth = $giInitialWinWidth
If $iWinWidth > @DesktopWidth Then
  $iWinWidth = @DesktopWidth
  $iWinLeft = 0
EndIf
$iWinHeight = $giInitialWinHeight
If $iWinHeight > @DesktopHeight Then
  $iWinHeight = @DesktopHeight
  $iWinTop = 0
EndIf
;Resize hack*
;We leave one pixel out of height and we'll adjust height after console creation.
;We do this as for a (at this time) unknown reason, the console doesn't show the
;vertical scrollbar automatically otherwise.
$ghWndMain = GUICreate($gsMainWindowTitle, $iWinWidth, $iWinHeight-1, $iWinLeft, $iWinTop, BitOr(BitAnd($WS_OVERLAPPEDWINDOW, Not $WS_MAXIMIZEBOX), $WS_SYSMENU, $WS_SIZEBOX))
$iRet = CreateConsole($ghWndMain)
If $iRet = 0 Then
  Exit
EndIf
GUISetOnEvent($GUI_EVENT_CLOSE, "OnMainMessage", $ghWndMain)
GUISetOnEvent($GUI_EVENT_RESIZED, "OnMainMessage", $ghWndMain)
GUIRegisterMsg($WM_SIZE, "OnConsoleResize")
GUIRegisterMsg($WM_MOUSEWHEEL, "OnMouseWheel")
GUIRegisterMsg($WM_PAINT, "_ValidateGIF")

GUISetState(@SW_SHOW)

;----------------------------------------------------------------
; Load background picture if any
;----------------------------------------------------------------
If $gsBackgroundPictureFile <> "" Then
  Dim $hImage, $aDim
  If FileExists($gsBackgroundPictureFile) Then
    _GDIPlus_Startup()
    $hImage = _GDIPlus_ImageLoadFromFile($gsBackgroundPictureFile)
    $aDim = _GDIPlus_ImageGetDimension($hImage)
    _GDIPlus_ImageDispose($hImage)
    _GDIPlus_Shutdown()
    ;$giBackgroundPictureID = GUICtrlCreatePic($gsBackgroundPictureFile, 0, 0, $aDim[0], $aDim[1])
    $hGIF = _GUICtrlCreateGIF($gsBackgroundPictureFile, "", 0, 0, $aDim[0], $aDim[1])
    #CS This is the Visual Basic DLL declare statement:
      Private Declare PtrSafe Function CSSetAlphaTransparency Lib "consoul_010203_32.dll" (ByVal hWnd As LongPtr, ByVal pbPercent As Byte) As Integer
    #CE
    DllCall( _
              $gsConsoulDLL, "short", _
              "CSSetAlphaTransparency", "hwnd", $ghConsole, _
              "byte", $gbAlphaPercent _
           )  
  Else
    MsgBox($MB_ICONSTOP, "Background picture", "File [" & $gsBackgroundPictureFile & "] not found.")
  EndIf
EndIf

;----------------------------------------------------------------
; Call the function that generates the console output
; Note: this is the function name specified in the code
;       generation dialog in AsciiPaint
;----------------------------------------------------------------
DisplayAsciiPaintImage()
ShowConsole(True)
;Resize hack*
_WinAPI_MoveWindow($ghConsole, $iWinWidth, $iWinHeight+1, $iWinLeft, $iWinTop)
OnConsoleResize()
$gfCanClose = 1

;----------------------------------------------------------------
; Main script event loop
;----------------------------------------------------------------
$gfCanClose = 1
While $gfMainClosed=0
  $msg = GUIGetMsg()
  Sleep(1)
WEnd

_GIF_DeleteGIF($hGIF)
GUIDelete()
_WinAPI_FreeLibrary($ghConsoulLibrary)

Exit

;----------------------------------------------------------------
; AutoIT script error management
;----------------------------------------------------------------
Func DisplayFail($psText)
  OutputLn("FAILED: " & $psText)
EndFunc

Func _ErrFunc()
	Local $sMsg
	$sMsg = "AutoIT script error" & @CRLF & @CRLF & _
	        "Number: " & $goError.number & @CRLF & _
			    "Description: " & @CRLF & $goError.description
	DisplayFail($sMsg)
EndFunc

;----------------------------------------------------------------
; Consoul console output support
;----------------------------------------------------------------
Func CreateConsole($phWndParent)
  const $LW_RENDERMODEBYLINE = 8  ;console creation attribute
  Dim $return
  #CS This is the Visual Basic DLL declare statement:
   Private Declare PtrSafe Function CSCreateLogWindow Lib "consoul_010203_32.dll" _
    (ByVal hWndParent As LongPtr, _
     ByVal x As Long, ByVal y As Long, ByVal Width As Long, ByVal Height As Long, _
     ByVal lBackColor As Long, ByVal lForeColor As Long, _
     ByVal sFontName As LongPtr, ByVal iFontSize As Integer, _
     ByVal iQueueSize As Integer, ByVal pwCreateAttribs As Integer) As LongPtr
  #CE
  $return = DllCall( _
              $gsConsoulDLL, "hwnd", _
              "CSCreateLogWindow", "hwnd", $phWndParent, _
              "int", $giConX, "int", $giConY, _
              "int", $giConWidth, "int", $giConHeight, _
              "int", $glConBackColor, _
              "int", $glConForeColor, _
              "wstr", $gsConFontName, _
              "short", $giConFontSize, _
              "short", $giConQueueSize, _
              "short", $LW_RENDERMODEBYLINE _
            )
  $ghConsole = $return[0]
  If $ghConsole = 0 Then
    MsgBox(16+$MB_SYSTEMMODAL, "Consoul window", "Failed to create consoul's console window")
    Return 0
  EndIf
  Return 1
EndFunc

Func ShowConsole($pfVisible)
  If $pfVisible Then
    _WinAPI_ShowWindow($ghConsole)
  Else
    _WinAPI_ShowWindow($ghConsole, 0)
  EndIf
EndFunc

Func DestroyConsole()
  If $ghConsole > 0 Then
    DllCall($gsConsoulDLL, "LONG", "CSDestroyLogWindow", "LONG", $ghConsole)
  EndIf
  $ghConsole = 0
EndFunc

Func OutputLn($psText)
  ;Local $msg
  If $ghConsole > 0 Then
    DllCall($gsConsoulDLL, "LONG", "CSPushLine", "LONG", $ghConsole, "WSTR", $psText, "SHORT", 0)
  EndIf
  ;Note: Uncomment declaration and following line if for any reason
  ;      you do need to let main window message processing between
  ;      console output.
  ;$msg = GUIGetMsg()
EndFunc

Func OnConsoleResize()
  Local $aClient
  $aClient = WinGetClientSize($ghWndMain)
  If $giBackgroundPictureID <> 0 Then
    ;Resize picture control to full client area
    GUICtrlSetPos($giBackgroundPictureID, 0, 0, $aClient[0], $aClient[1])
  EndIf
  If $ghConsole <> 0 Then
    ;The console window occupies the full client area
    _WinAPI_MoveWindow($ghConsole, 0, 0, $aClient[0], $aClient[1])
  EndIf
  If $giBackgroundPictureID <> 0 Then
    ;the console window must be on top
    _WinAPI_SetWindowPos($ghConsole, 0, 0, 0, 0, 0, $SWP_NOSIZE+$SWP_NOMOVE+$HWND_TOP)
  EndIf
EndFunc

;Repeat a wide char ascii code $piAscW, $piCount times
;(This function is used by the AsciiPaint generated code)
Func StringW($piAscW, $piCount)
  Local $i, $sRet
  For $i=1 To $piCount
    $sRet = $sRet & ChrW($piAscW)
  Next
  Return $sRet
EndFunc

;----------------------------------------------------------------
; Main message event loop
;----------------------------------------------------------------
Func OnMainMessage()
  Switch @GUI_CtrlId
    Case $GUI_EVENT_CLOSE
      If $gfCanClose Then
        DestroyConsole()
        $gfMainClosed = True
      EndIf
    case $GUI_EVENT_RESIZED
      OnConsoleResize()
  EndSwitch
EndFunc

;----------------------------------------------------------------
; Mousewheel support needs a separate event procedure
;----------------------------------------------------------------
Func OnMouseWheel($hWnd, $iMsg, $wParam, $lParam)
  Dim $iDelta = 0
  Dim $i = 0
  Const $WHEEL_DELTA = 120
  Const $SB_LINEDOWN = 1
  Const $SB_LINEUP = 0
  
  if $ghConsole<>0 Then
    $iDelta = _WinAPI_HiWord($wParam) / $WHEEL_DELTA
    $wParam = $SB_LINEUP
    If $iDelta < 0 Then
      $iDelta = -$iDelta
      $wParam = $SB_LINEDOWN
    EndIf
    For $i=1 To $iDelta
      _WinAPI_PostMessage($ghConsole, $WM_VSCROLL, $wParam, 0)
    Next
  EndIf
EndFunc

;----------------------------------------------------------------
; Open input file and send it to the console
;----------------------------------------------------------------
Func DisplayAsciiPaintImage()
  Dim $sLine = ""
  Dim $iLineCt = 0
  
  $ghInputFile = FileOpen($gsInputFile, $FO_UTF16_LE)
  If $ghInputFile = -1 Then
    MsgBox(16+$MB_SYSTEMMODAL, "Read file error", "Failed to read input file [" & $gsInputFile & "]")
    Return 0
  EndIf
  
  Do
    $sLine = FileReadLine($ghInputFile)
    OutputLn($sLine)
    $iLineCt += 1
  Until (@error = -1) Or ($iLineCt>$giConQueueSize)
  
  FileClose($ghInputFile)
  Return 1
EndFunc

;----------------------------------------------------------------
; GIF/Animated related methods
;----------------------------------------------------------------

;$WM_PAINT callback
Func _ValidateGIFs($hWnd, $iMsg, $wParam, $lParam)
	#forceref $hWnd, $iMsg, $wParam, $lParam
	_GIF_ValidateGIF($hGIF)
EndFunc   ;==>_ValidateGIFs
