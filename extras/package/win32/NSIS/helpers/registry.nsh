;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; 0. Registry writes                                                             ;
;                                                                                ;
; redesign: brand layer (redesign/INSTALLER_NOTES.md section 7). Every registry  ;
; write of the installer goes through these macros. In the vlc profile they are  ;
; the plain WriteRegStr / WriteRegDWORD VLC's script always had. In the public   ;
; profile the installer writes HKLM only (Software\Classes instead of HKCR's     ;
; merged view, so a user's own HKCU class keys are never written) and keeps a    ;
; record in $INSTDIR\uninstall-registry.log of what it added; the uninstaller    ;
; removes exactly that:                                                          ;
;   T<tab>key           a key only this app uses (named after it: Cone.<ext>,    ;
;                       Applications\Cone.exe, PlayWithCone, ConePlay*, ...):    ;
;                       recorded when the installer creates it, or when an       ;
;                       earlier install of this app made it (HKLM\${PRODUCT_DIR_REGKEY}
;                       exists); removed with everything in it                   ;
;   K<tab>depth<tab>key a shared key the installer created (it did not exist     ;
;                       before the write): removed, deepest first, only when it  ;
;                       is empty                                                 ;
;   V<tab>key<tab>name  a value the installer wrote into a shared key: removed   ;
; A shared key that existed before the install is never recorded, so never       ;
; removed, empty or not. The uninstaller also checks that every own key and      ;
; value it removes carries ${PRODUCT_PROGID} in its name. 64-bit installer: all  ;
; in the 64-bit view (SetRegView 64 in .onInit and un.onInit).                    ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

!if "${PRODUCT_PROGID}" != "VLC"

!define CONE_REG_RECORD "uninstall-registry.log"

Var ConeRegLog     ; the open record
Var ConeRegAdopt   ; 1: an earlier install of this app is present
Var ConeRegTree1   ; the last own keys already handled (they exist and are recorded)
Var ConeRegTree2
Var ConeRegTree3

;; Opens the record before the first registry write (keeps an earlier install's lines)
!macro ConeRegOpenRecord
  StrCpy $ConeRegAdopt 0
  ClearErrors
  EnumRegKey $0 HKLM "${PRODUCT_DIR_REGKEY}" 0
  ${IfNot} ${Errors}
    StrCpy $ConeRegAdopt 1
    ; an earlier install in another folder: its record carries over
    ReadRegStr $0 HKLM "${PRODUCT_DIR_REGKEY}" "InstallDir"
    ${If} $0 != ""
    ${AndIf} $0 != $INSTDIR
    ${AndIfNot} ${FileExists} "$INSTDIR\${CONE_REG_RECORD}"
    ${AndIf} ${FileExists} "$0\${CONE_REG_RECORD}"
      CopyFiles /SILENT "$0\${CONE_REG_RECORD}" "$INSTDIR\${CONE_REG_RECORD}"
    ${EndIf}
  ${ElseIf} ${FileExists} "$INSTDIR\${CONE_REG_RECORD}"
    ; no Cone install is registered: a record left in the folder (e.g. by an older uninstaller
    ; that did not know it) describes keys that are gone, so it starts anew
    SetFileAttributes "$INSTDIR\${CONE_REG_RECORD}" NORMAL
    Delete "$INSTDIR\${CONE_REG_RECORD}"
  ${EndIf}
  FileOpen $ConeRegLog "$INSTDIR\${CONE_REG_RECORD}" a
  FileSeek $ConeRegLog 0 END
!macroend

;; Closes the record after the last registry write
!macro ConeRegCloseRecord
  FileClose $ConeRegLog
  SetFileAttributes "$INSTDIR\${CONE_REG_RECORD}" HIDDEN
!macroend

;; $R9 = its parent key ("" for a top level key)
Function ConeRegParent
  Push $0
  Push $1
  StrLen $0 $R9
  loop:
    IntOp $0 $0 - 1
    IntCmp $0 0 none none
    StrCpy $1 $R9 1 $0
    StrCmp $1 "\" 0 loop
    StrCpy $R9 $R9 $0
    Goto done
  none:
    StrCpy $R9 ""
  done:
  Pop $1
  Pop $0
FunctionEnd

;; Records key $R9 and each of its parents that does not exist yet (K lines)
Function ConeRegNoteNewKeys
  Push $R9
  Push $0
  Push $1
  Push $2
  ; depth: the number of parts of the key
  StrCpy $0 1
  StrCpy $1 0
  depth:
    StrCpy $2 $R9 1 $1
    StrCmp $2 "" walk
    IntOp $1 $1 + 1
    StrCmp $2 "\" 0 depth
    IntOp $0 $0 + 1
    Goto depth
  walk:
    StrCmp $R9 "" done
    ClearErrors
    EnumRegKey $2 HKLM "$R9" 0
    IfErrors 0 done ; it exists, and so do its parents
    FileWrite $ConeRegLog "K$\t$0$\t$R9$\r$\n"
    IntOp $0 $0 - 1
    Call ConeRegParent
    Goto walk
  done:
  Pop $2
  Pop $1
  Pop $0
  Pop $R9
FunctionEnd

;; The installer is about to write into own key $R9: records it (T line) when it is new
;; (with the parents it needs, K lines) or when an earlier install of this app made it.
;; An own key that exists without an earlier install was either made by this install
;; already (recorded then) or by something else: then it is left alone
Function ConeRegOwnKey
  ${If} $R9 == $ConeRegTree1
  ${OrIf} $R9 == $ConeRegTree2
  ${OrIf} $R9 == $ConeRegTree3
    Return
  ${EndIf}
  Push $0
  ClearErrors
  EnumRegKey $0 HKLM "$R9" 0
  ${If} ${Errors}
    Push $R9
    Call ConeRegParent
    Call ConeRegNoteNewKeys
    Pop $R9
    FileWrite $ConeRegLog "T$\t$R9$\r$\n"
  ${ElseIf} $ConeRegAdopt == 1
    FileWrite $ConeRegLog "T$\t$R9$\r$\n"
  ${EndIf}
  StrCpy $ConeRegTree3 $ConeRegTree2
  StrCpy $ConeRegTree2 $ConeRegTree1
  StrCpy $ConeRegTree1 $R9
  Pop $0
FunctionEnd

;; An earlier install of this app is present: its own keys are recorded (T lines) whether or not
;; this install writes them again (fewer components, an older layout), so they all go on
;; uninstall. Cone.<ext> ProgIDs are rewritten for every type by every install
!macro _ConeRegAdoptKey KEY
  StrCpy $R9 "${KEY}"
  ClearErrors
  EnumRegKey $0 HKLM "$R9" 0
  ${IfNot} ${Errors}
    FileWrite $ConeRegLog "T$\t$R9$\r$\n"
  ${EndIf}
!macroend

Function ConeRegAdoptOwnKeys
  ${If} $ConeRegAdopt != 1
    Return
  ${EndIf}
  Push $R9
  Push $0
  !insertmacro _ConeRegAdoptKey "${PRODUCT_DIR_REGKEY}"
  !insertmacro _ConeRegAdoptKey "${PRODUCT_UNINST_KEY}"
  !insertmacro _ConeRegAdoptKey "Software\Microsoft\Windows\CurrentVersion\App Paths\${PRODUCT_EXE}"
  !insertmacro _ConeRegAdoptKey "Software\Clients\Media\${PRODUCT_PROGID}"
  !insertmacro _ConeRegAdoptKey "Software\Classes\Applications\${PRODUCT_EXE}"
  !insertmacro _ConeRegAdoptKey "Software\Classes\Directory\shell\PlayWith${PRODUCT_PROGID}"
  !insertmacro _ConeRegAdoptKey "Software\Classes\Directory\shell\AddToPlaylist${PRODUCT_PROGID}"
  !insertmacro _ConeRegAdoptKey "Software\Classes\AudioCD\shell\PlayWith${PRODUCT_PROGID}"
  !insertmacro _ConeRegAdoptKey "Software\Classes\DVD\shell\PlayWith${PRODUCT_PROGID}"
  !insertmacro _ConeRegAdoptKey "Software\Classes\${PRODUCT_PROGID}.DVDMovie"
  !insertmacro _ConeRegAdoptKey "Software\Classes\${PRODUCT_PROGID}.CDAudio"
  !insertmacro _ConeRegAdoptKey "Software\Classes\${PRODUCT_PROGID}.VCDMovie"
  !insertmacro _ConeRegAdoptKey "Software\Classes\${PRODUCT_PROGID}.SVCDMovie"
  !insertmacro _ConeRegAdoptKey "Software\Classes\${PRODUCT_PROGID}.OPENFolder"
  !insertmacro _ConeRegAdoptKey "Software\Classes\${PRODUCT_PROGID}.Bluray"
  !insertmacro _ConeRegAdoptKey "Software\Classes\${PRODUCT_PROGID}.MediaFile"
  !insertmacro _ConeRegAdoptKey "Software\Classes\${PRODUCT_PROGID}.vlt"
  !insertmacro _ConeRegAdoptKey "Software\Classes\${PRODUCT_PROGID}.wsz"
  !insertmacro _ConeRegAdoptKey "Software\Microsoft\Windows\CurrentVersion\Explorer\AutoplayHandlers\Handlers\${PRODUCT_PROGID}PlayDVDMovieOnArrival"
  !insertmacro _ConeRegAdoptKey "Software\Microsoft\Windows\CurrentVersion\Explorer\AutoplayHandlers\Handlers\${PRODUCT_PROGID}PlayCDAudioOnArrival"
  !insertmacro _ConeRegAdoptKey "Software\Microsoft\Windows\CurrentVersion\Explorer\AutoplayHandlers\Handlers\${PRODUCT_PROGID}PlayVCDMovieOnArrival"
  !insertmacro _ConeRegAdoptKey "Software\Microsoft\Windows\CurrentVersion\Explorer\AutoplayHandlers\Handlers\${PRODUCT_PROGID}PlaySVCDMovieOnArrival"
  !insertmacro _ConeRegAdoptKey "Software\Microsoft\Windows\CurrentVersion\Explorer\AutoplayHandlers\Handlers\${PRODUCT_PROGID}PlayDVDAudioOnArrival"
  !insertmacro _ConeRegAdoptKey "Software\Microsoft\Windows\CurrentVersion\Explorer\AutoplayHandlers\Handlers\${PRODUCT_PROGID}PlayVideoFilesOnArrival"
  !insertmacro _ConeRegAdoptKey "Software\Microsoft\Windows\CurrentVersion\Explorer\AutoplayHandlers\Handlers\${PRODUCT_PROGID}PlayMusicFilesOnArrival"
  !insertmacro _ConeRegAdoptKey "Software\Microsoft\Windows\CurrentVersion\Explorer\AutoplayHandlers\Handlers\${PRODUCT_PROGID}PlayBlurayOnArrival"
  Pop $0
  Pop $R9
FunctionEnd

!macro _ConeRegOwnKey TREE SUBKEY
  Push $R9
  StrCpy $R9 "${TREE}"
  Call ConeRegOwnKey
!if "${SUBKEY}" != ""
  StrCpy $R9 "${TREE}\${SUBKEY}"
!endif
!macroend

!macro _ConeRegSharedKey KEY
  Push $R9
  StrCpy $R9 "${KEY}"
  Call ConeRegNoteNewKeys
!macroend

!endif ; PRODUCT_PROGID != VLC

;; A value in an own key under HKLM: TREE is the own key, SUBKEY the path inside it ("" for TREE)
!macro RegOwnStr TREE SUBKEY NAME VALUE
!if "${PRODUCT_PROGID}" != "VLC"
  !insertmacro _ConeRegOwnKey "${TREE}" "${SUBKEY}"
  WriteRegStr HKLM "$R9" `${NAME}` `${VALUE}`
  Pop $R9
!else if "${SUBKEY}" == ""
  WriteRegStr HKLM "${TREE}" `${NAME}` `${VALUE}`
!else
  WriteRegStr HKLM "${TREE}\${SUBKEY}" `${NAME}` `${VALUE}`
!endif
!macroend

!macro RegOwnDWORD TREE SUBKEY NAME VALUE
!if "${PRODUCT_PROGID}" != "VLC"
  !insertmacro _ConeRegOwnKey "${TREE}" "${SUBKEY}"
  WriteRegDWORD HKLM "$R9" `${NAME}` `${VALUE}`
  Pop $R9
!else if "${SUBKEY}" == ""
  WriteRegDWORD HKLM "${TREE}" `${NAME}` `${VALUE}`
!else
  WriteRegDWORD HKLM "${TREE}\${SUBKEY}" `${NAME}` `${VALUE}`
!endif
!macroend

;; A value in an own class key (Software\Classes\TREE; the vlc profile: HKCR\TREE)
!macro RegClassesOwnStr TREE SUBKEY NAME VALUE
!if "${PRODUCT_PROGID}" != "VLC"
  !insertmacro RegOwnStr "Software\Classes\${TREE}" "${SUBKEY}" `${NAME}` `${VALUE}`
!else if "${SUBKEY}" == ""
  WriteRegStr HKCR "${TREE}" `${NAME}` `${VALUE}`
!else
  WriteRegStr HKCR "${TREE}\${SUBKEY}" `${NAME}` `${VALUE}`
!endif
!macroend

;; This app's value NAME in a shared key under HKLM
!macro RegSharedStr KEY NAME VALUE
!if "${PRODUCT_PROGID}" != "VLC"
  !insertmacro _ConeRegSharedKey "${KEY}"
  WriteRegStr HKLM "$R9" `${NAME}` `${VALUE}`
  FileWrite $ConeRegLog "V$\t$R9$\t${NAME}$\r$\n"
  Pop $R9
!else
  WriteRegStr HKLM "${KEY}" `${NAME}` `${VALUE}`
!endif
!macroend

;; This app's value NAME in a shared class key (Software\Classes\KEY; the vlc profile: HKCR\KEY)
!macro RegClassesSharedStr KEY NAME VALUE
!if "${PRODUCT_PROGID}" != "VLC"
  !insertmacro RegSharedStr "Software\Classes\${KEY}" `${NAME}` `${VALUE}`
!else
  WriteRegStr HKCR "${KEY}" `${NAME}` `${VALUE}`
!endif
!macroend

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Uninstall: removes what the record lists                                       ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

!if "${PRODUCT_PROGID}" != "VLC"

;; $1 = "a<tab>b": $3 = a, $1 = b ($1 = "" without a tab)
Function un.ConeRegCut
  Push $4
  Push $6
  StrCpy $4 0
  loop:
    StrCpy $6 $1 1 $4
    StrCmp $6 "" notab
    StrCmp $6 "$\t" found
    IntOp $4 $4 + 1
    Goto loop
  found:
    StrCpy $3 $1 $4
    IntOp $4 $4 + 1
    StrCpy $1 $1 "" $4
    Goto done
  notab:
    StrCpy $3 $1
    StrCpy $1 ""
  done:
  Pop $6
  Pop $4
FunctionEnd

;; $2 = 1 when key $1 is below a top level key and its own name carries ${PRODUCT_PROGID}
;; (Cone.mp4, Cone.exe, PlayWithCone, ConePlayDVDMovieOnArrival, Cone), else 0: a guard,
;; so even a damaged record can not remove a key that is not this app's own
Function un.ConeRegIsOwnName
  Push $3
  Push $4
  Push $6
  Push $7
  ; $6 = the last part of the key
  StrLen $3 $1
  leaf:
    IntOp $3 $3 - 1
    IntCmp $3 0 notown notown
    StrCpy $4 $1 1 $3
    StrCmp $4 "\" 0 leaf
    IntOp $3 $3 + 1
    StrCpy $6 $1 "" $3
  ; look for the name in it
  StrLen $3 "${PRODUCT_PROGID}"
  StrCpy $4 0
  find:
    StrCpy $7 $6 $3 $4
    StrCmp $7 "" notown
    StrCmp $7 "${PRODUCT_PROGID}" own
    IntOp $4 $4 + 1
    Goto find
  own:
    StrCpy $2 1
    Goto done
  notown:
    StrCpy $2 0
  done:
  Pop $7
  Pop $6
  Pop $4
  Pop $3
FunctionEnd

;; Deletes the HKLM key on the stack only when it has no value (not even a default one)
;; and no subkey
Function un.ConeRegDeleteKeyIfEmpty
  Exch $1
  Push $2
  ClearErrors
  EnumRegValue $2 HKLM "$1" 0
  ${If} ${Errors} ; no value (or no key)
    ClearErrors
    EnumRegKey $2 HKLM "$1" 0
    ${IfNot} ${Errors}
    ${AndIf} $2 == ""
      DeleteRegKey /ifempty HKLM "$1"
    ${EndIf}
  ${EndIf}
  Pop $2
  Pop $1
FunctionEnd

;; Removes the recorded values, own keys and created keys (deepest first, only when
;; empty), then the record. Without a record it removes no key
Function un.ConeRegRemove
  Push $0
  Push $1
  Push $2
  Push $3
  Push $5
  ClearErrors
  FileOpen $0 "$INSTDIR\${CONE_REG_RECORD}" r
  ${IfNot} ${Errors}
    ; values and own keys; the deepest created key
    StrCpy $5 0
    ${Do}
      ClearErrors
      FileRead $0 $1
      ${If} ${Errors}
        ${ExitDo}
      ${EndIf}
      Push $1
      Call un.TrimNewLines
      Pop $1
      StrCpy $2 $1 2
      StrCpy $1 $1 "" 2
      ${If} $2 == "V$\t"
        Call un.ConeRegCut
        ; the value's name carries the app's name too (Cone.mp4, ConePlay*OnArrival, Cone)
        Push $1
        StrCpy $1 "$3\$1"
        Call un.ConeRegIsOwnName
        Pop $1
        ${If} $2 == 1
          DeleteRegValue HKLM "$3" "$1"
        ${EndIf}
      ${ElseIf} $2 == "T$\t"
        Call un.ConeRegIsOwnName
        ${If} $2 == 1
          DeleteRegKey HKLM "$1"
        ${EndIf}
      ${ElseIf} $2 == "K$\t"
        Call un.ConeRegCut
        ${If} $3 > $5
          StrCpy $5 $3
        ${EndIf}
      ${EndIf}
    ${Loop}
    ; created keys, deepest first, each only when it is empty
    ${DoWhile} $5 > 0
      FileSeek $0 0 SET
      ${Do}
        ClearErrors
        FileRead $0 $1
        ${If} ${Errors}
          ${ExitDo}
        ${EndIf}
        Push $1
        Call un.TrimNewLines
        Pop $1
        StrCpy $2 $1 2
        ${If} $2 == "K$\t"
          StrCpy $1 $1 "" 2
          Call un.ConeRegCut
          ${If} $3 = $5
          ${AndIf} $1 != ""
            Push $1
            Call un.ConeRegDeleteKeyIfEmpty
          ${EndIf}
        ${EndIf}
      ${Loop}
      IntOp $5 $5 - 1
    ${Loop}
    FileClose $0
    Delete "$INSTDIR\${CONE_REG_RECORD}"
  ${EndIf}
  Pop $5
  Pop $3
  Pop $2
  Pop $1
  Pop $0
FunctionEnd

!endif ; PRODUCT_PROGID != VLC
