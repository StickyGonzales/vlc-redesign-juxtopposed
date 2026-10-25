!include "StrFunc.nsh"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; 1. File type associations ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; "Initialize" string functions
${StrRep}
${StrCase}

;; Function that associates one extension with VLC
Function AssociateExtension
!if "${PRODUCT_PROGID}" != "VLC"
  ; redesign: brand layer (INSTALLER_NOTES.md): the app is offered for the type in Open with and
  ; Default apps; it never takes the type over, the user picks the default in Windows. Written to
  ; HKLM\Software\Classes and recorded (registry.nsh), never to the user's own HKCU key
  !insertmacro RegClassesSharedStr "$R0\OpenWithProgids" "${PRODUCT_PROGID}$R0" ""
!else
  ; back up old value for extension $R0 (eg. ".opt")
  ReadRegStr $1 HKCR "$R0" ""
  StrCmp $1 "" NoBackup
    StrCmp $1 "${PRODUCT_PROGID}$R0" "NoBackup"
    WriteRegStr HKCR "$R0" "${PRODUCT_PROGID}.backup" $1
NoBackup:
  WriteRegStr HKCR "$R0" "" "${PRODUCT_PROGID}$R0"
!endif
FunctionEnd

;; Function that registers one extension for VLC
Function RegisterExtension
  ; R0 contains the extension, R1 contains the type (Audio/Video)
  ; Remove the leading dot from the filetype string
  ${StrRep} $R2 $R0 "." ""
  ; And capitalize the extension
  ${StrCase} $R2 $R2 "U"
  ; for instance: MKV Video File (VLC)
  ; redesign: brand layer, the public profile writes HKLM\Software\Classes (registry.nsh)
  !insertmacro RegClassesOwnStr "${PRODUCT_PROGID}$R0" "" "" "$R2 $R1 File (${PRODUCT_SHORT_NAME})"
  !insertmacro RegClassesOwnStr "${PRODUCT_PROGID}$R0" "shell" "" "Open"
  !insertmacro RegClassesOwnStr "${PRODUCT_PROGID}$R0" "shell\Open" "" "$(ShellAssociation_Play)"
  !insertmacro RegClassesOwnStr "${PRODUCT_PROGID}$R0" "shell\Open" "MultiSelectModel" "Player"
  !insertmacro RegClassesOwnStr "${PRODUCT_PROGID}$R0" "shell\Open\command" "" '"$INSTDIR\${PRODUCT_EXE}" --started-from-file "%1"'
  !insertmacro RegClassesOwnStr "${PRODUCT_PROGID}$R0" "DefaultIcon" "" '"$INSTDIR\${PRODUCT_EXE}",0'
!if "${PRODUCT_PROGID}" != "VLC"
  ; redesign: brand layer, the extension itself (VLC writes $0, one stray value), so the app is
  ; listed in Open with for each of its types
  !insertmacro RegClassesOwnStr "Applications\${PRODUCT_EXE}" "SupportedTypes" "$R0" ""
!else
  WriteRegStr HKCR "Applications\${PRODUCT_EXE}\SupportedTypes" $0 ""
!endif

  ${If} ${AtLeastWinVista}
    !insertmacro RegOwnStr "Software\Clients\Media\${PRODUCT_PROGID}" "Capabilities\FileAssociations" "$R0" "${PRODUCT_PROGID}$R0"
  ${EndIf}
FunctionEnd

;; Function that registers one skin extension for VLC
Function RegisterSkinExtension
  !insertmacro RegClassesOwnStr "${PRODUCT_PROGID}$R0" "" "" "${PRODUCT_SHORT_NAME} skin file ($R0)"
  !insertmacro RegClassesOwnStr "${PRODUCT_PROGID}$R0" "shell" "" "Open"
  !insertmacro RegClassesOwnStr "${PRODUCT_PROGID}$R0" "shell\Open" "" ""
  !insertmacro RegClassesOwnStr "${PRODUCT_PROGID}$R0" "shell\Open\command" "" '"$INSTDIR\${PRODUCT_EXE}" -Iskins --skins2-last "%1"'
  !insertmacro RegClassesOwnStr "${PRODUCT_PROGID}$R0" "DefaultIcon" "" '"$INSTDIR\${PRODUCT_EXE}",0'

  ${If} ${AtLeastWinVista}
    !insertmacro RegOwnStr "Software\Clients\Media\${PRODUCT_PROGID}" "Capabilities\FileAssociations" "$R0" "${PRODUCT_PROGID}$R0"
  ${EndIf}
FunctionEnd

!if "${PRODUCT_PROGID}" != "VLC"
;; redesign: brand layer, the type's default value an older Cone build took over (0.1 betas set
;; HKCR\.<ext> to Cone.<ext> and kept the previous handler in Cone.backup), in the HKLM or HKCU
;; class key it landed in: given back while that handler's ProgID still exists, else only the
;; value goes; the key always stays. Uses $1 and $2
!macro ConeUnRestoreDefault ROOT
  ReadRegStr $1 ${ROOT} "Software\Classes\$R0" ""
  ${If} $1 == "${PRODUCT_PROGID}$R0"
    ReadRegStr $1 ${ROOT} "Software\Classes\$R0" "${PRODUCT_PROGID}.backup"
    StrCpy $2 0
    ${If} $1 != ""
      ClearErrors
      EnumRegKey $2 HKCR "$1" 0
      ${If} ${Errors}
        StrCpy $2 0
      ${Else}
        StrCpy $2 1
      ${EndIf}
    ${EndIf}
    ${If} $2 == 1
      WriteRegStr ${ROOT} "Software\Classes\$R0" "" $1
    ${Else}
      DeleteRegValue ${ROOT} "Software\Classes\$R0" ""
    ${EndIf}
  ${EndIf}
  DeleteRegValue ${ROOT} "Software\Classes\$R0" "${PRODUCT_PROGID}.backup"
!macroend
!endif

;; Function that removes one extension that VLC owns.
Function un.RegisterExtension
!if "${PRODUCT_PROGID}" != "VLC"
  ; redesign: brand layer, the keys and values this installer added are in its record
  ; (un.ConeRegRemove, registry.nsh); here only the values older Cone installers left without a
  ; record, and never a key
  Push $1
  Push $2
  ; 1.0: HKCR's merged view put the Open with value into the user's own .<ext>\OpenWithProgids
  ; when that key existed
  DeleteRegValue HKCU "Software\Classes\$R0\OpenWithProgids" "${PRODUCT_PROGID}$R0"
  ; and the HKLM one of a type an older install had ticked and this one did not
  DeleteRegValue HKLM "Software\Classes\$R0\OpenWithProgids" "${PRODUCT_PROGID}$R0"
  !insertmacro ConeUnRestoreDefault HKLM
  !insertmacro ConeUnRestoreDefault HKCU
  Pop $2
  Pop $1
!else
  ;start of restore script
  ReadRegStr $1 HKCR "$R0" ""
  StrCmp $1 "${PRODUCT_PROGID}$R0" 0 NoOwn ; only do this if we own it
    ; Read the old value from Backup
    ReadRegStr $1 HKCR "$R0" "${PRODUCT_PROGID}.backup"
    StrCmp $1 "" 0 Restore ; if backup="" then delete the whole key
      DeleteRegKey HKCR "$R0"
    Goto NoOwn
Restore:
      WriteRegStr HKCR "$R0" "" $1
      DeleteRegValue HKCR "$R0" "${PRODUCT_PROGID}.backup"
NoOwn:
    DeleteRegKey HKCR "${PRODUCT_PROGID}$R0" ;Delete key with association settings
    DeleteRegKey HKLM "Software\Clients\Media\${PRODUCT_PROGID}\Capabilities\FileAssociations\${PRODUCT_PROGID}$R0" ; for vista
!endif
FunctionEnd

!macro AssociateExtensionSection TYPE EXT
  ${MementoSection} ${EXT} SEC_EXT_${TYPE}_${EXT}
    SectionIn 1 3
    Push $R0
    StrCpy $R0 ${EXT}
    Call AssociateExtension
    Pop $R0
  ${MementoSectionEnd}
!macroend

!macro AssociateSkinExtensionSection TYPE EXT
  ${MementoUnselectedSection} ${EXT} SEC_EXT_SKIN_${EXT}
    SectionIn 1 3
    Push $R0
    StrCpy $R0 ${EXT}
    Call AssociateExtension
    Pop $R0
  ${MementoSectionEnd}
!macroend

!macro AssociateExtensionUnselectedSection TYPE EXT
  ${MementoUnselectedSection} ${EXT} SEC_EXT_${TYPE}_${EXT}
    SectionIn 1 3
    Push $R0
    StrCpy $R0 ${EXT}
    Call AssociateExtension
    Pop $R0
  ${MementoSectionEnd}
!macroend

!macro RegisterExtensionMacro TYPE EXT
  Push $R0
  StrCpy $R0 ${EXT}
  Push $R1
  StrCpy $R1 ${TYPE}
  Call RegisterExtension
  Pop $R1
  Pop $R0
!macroend

!macro RegisterSkinExtensionMacro TYPE EXT
  Push $R0
  StrCpy $R0 ${EXT}
  Call RegisterSkinExtension
  Pop $R0
!macroend

!macro UnRegisterExtensionSection TYPE EXT
  Push $R0
  StrCpy $R0 ${EXT}
  Call un.RegisterExtension
  Pop $R0
!macroend

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Extension lists  Macros                    ;
; Those macros calls the previous functions  ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

!macro MacroAudioExtensions _action
  !insertmacro ${_action} Audio ".3ga"
  !insertmacro ${_action} Audio ".669"
  !insertmacro ${_action} Audio ".a52"
  !insertmacro ${_action} Audio ".aac"
  !insertmacro ${_action} Audio ".ac3"
  !insertmacro ${_action} Audio ".adt"
  !insertmacro ${_action} Audio ".adts"
  !insertmacro ${_action} Audio ".aif"
  !insertmacro ${_action} Audio ".aifc"
  !insertmacro ${_action} Audio ".aiff"
  !insertmacro ${_action} Audio ".alac"
  !insertmacro ${_action} Audio ".amr"
  !insertmacro ${_action} Audio ".aob"
  !insertmacro ${_action} Audio ".au"
  !insertmacro ${_action} Audio ".ape"
  !insertmacro ${_action} Audio ".caf"
  !insertmacro ${_action} Audio ".cda"
  !insertmacro ${_action} Audio ".dts"
  !insertmacro ${_action} Audio ".dsf"
  !insertmacro ${_action} Audio ".dff"
  !insertmacro ${_action} Audio ".flac"
  !insertmacro ${_action} Audio ".it"
  !insertmacro ${_action} Audio ".m4a"
  !insertmacro ${_action} Audio ".m4p"
  !insertmacro ${_action} Audio ".mka"
  !insertmacro ${_action} Audio ".mlp"
  !insertmacro ${_action} Audio ".mod"
  !insertmacro ${_action} Audio ".mp1"
  !insertmacro ${_action} Audio ".mp2"
  !insertmacro ${_action} Audio ".mp3"
  !insertmacro ${_action} Audio ".mpc"
  !insertmacro ${_action} Audio ".mpga"
  !insertmacro ${_action} Audio ".oga"
  !insertmacro ${_action} Audio ".oma"
  !insertmacro ${_action} Audio ".opus"
  !insertmacro ${_action} Audio ".qcp"
  !insertmacro ${_action} Audio ".ra"
  !insertmacro ${_action} Audio ".rmi"
  !insertmacro ${_action} Audio ".snd"
  !insertmacro ${_action} Audio ".s3m"
  !insertmacro ${_action} Audio ".spx"
  !insertmacro ${_action} Audio ".tak"
  !insertmacro ${_action} Audio ".tta"
  !insertmacro ${_action} Audio ".voc"
  !insertmacro ${_action} Audio ".vqf"
  !insertmacro ${_action} Audio ".w64"
  !insertmacro ${_action} Audio ".wav"
  !insertmacro ${_action} Audio ".wma"
  !insertmacro ${_action} Audio ".wv"
  !insertmacro ${_action} Audio ".xa"
  !insertmacro ${_action} Audio ".xm"
!macroend

!macro MacroVideoExtensions _action
  !insertmacro ${_action} Video ".3g2"
  !insertmacro ${_action} Video ".3gp"
  !insertmacro ${_action} Video ".3gp2"
  !insertmacro ${_action} Video ".3gpp"
  !insertmacro ${_action} Video ".amrec"
  !insertmacro ${_action} Video ".amv"
  !insertmacro ${_action} Video ".asf"
  !insertmacro ${_action} Video ".avi"
  !insertmacro ${_action} Video ".bik"
  !insertmacro ${_action} Video ".dav"
  !insertmacro ${_action} Video ".divx"
  !insertmacro ${_action} Video ".drc"
  !insertmacro ${_action} Video ".dv"
  !insertmacro ${_action} Video ".dvr-ms"
  !insertmacro ${_action} Video ".evo"
  !insertmacro ${_action} Video ".f4v"
  !insertmacro ${_action} Video ".flv"
  !insertmacro ${_action} Video ".gvi"
  !insertmacro ${_action} Video ".gxf"
  !insertmacro ${_action} Video ".k3g"
  !insertmacro ${_action} Video ".m1v"
  !insertmacro ${_action} Video ".m2t"
  !insertmacro ${_action} Video ".m2v"
  !insertmacro ${_action} Video ".m2ts"
  !insertmacro ${_action} Video ".m4v"
  !insertmacro ${_action} Video ".mkv"
  !insertmacro ${_action} Video ".mov"
  !insertmacro ${_action} Video ".mp2v"
  !insertmacro ${_action} Video ".mp4"
  !insertmacro ${_action} Video ".mp4v"
  !insertmacro ${_action} Video ".mpa"
  !insertmacro ${_action} Video ".mpe"
  !insertmacro ${_action} Video ".mpeg"
  !insertmacro ${_action} Video ".mpeg1"
  !insertmacro ${_action} Video ".mpeg2"
  !insertmacro ${_action} Video ".mpeg4"
  !insertmacro ${_action} Video ".mpg"
  !insertmacro ${_action} Video ".mpv2"
  !insertmacro ${_action} Video ".mts"
  !insertmacro ${_action} Video ".mtv"
  !insertmacro ${_action} Video ".mxf"
  !insertmacro ${_action} Video ".nsv"
  !insertmacro ${_action} Video ".nuv"
  !insertmacro ${_action} Video ".ogg"
  !insertmacro ${_action} Video ".ogm"
  !insertmacro ${_action} Video ".ogx"
  !insertmacro ${_action} Video ".ogv"
  !insertmacro ${_action} Video ".qt"
  !insertmacro ${_action} Video ".rec"
  !insertmacro ${_action} Video ".rm"
  !insertmacro ${_action} Video ".rmvb"
  !insertmacro ${_action} Video ".rpl"
  !insertmacro ${_action} Video ".skm"
  !insertmacro ${_action} Video ".thp"
  !insertmacro ${_action} Video ".tod"
  !insertmacro ${_action} Video ".tp"
  !insertmacro ${_action} Video ".ts"
  !insertmacro ${_action} Video ".tts"
  !insertmacro ${_action} Video ".vob"
  !insertmacro ${_action} Video ".vp6"
  !insertmacro ${_action} Video ".vro"
  !insertmacro ${_action} Video ".webm"
  !insertmacro ${_action} Video ".wmv"
  !insertmacro ${_action} Video ".wtv"
  !insertmacro ${_action} Video ".xesc"
!macroend

!macro MacroOtherExtensions _action
  !insertmacro ${_action} Other ".asx"
  !insertmacro ${_action} Other ".b4s"
  !insertmacro ${_action} Other ".cue"
  !insertmacro ${_action} Other ".ifo"
  !insertmacro ${_action} Other ".m3u"
  !insertmacro ${_action} Other ".m3u8"
  !insertmacro ${_action} Other ".pls"
  !insertmacro ${_action} Other ".ram"
  !insertmacro ${_action} Other ".sdp"
  !insertmacro ${_action} Other ".vlc"
  !insertmacro ${_action} Other ".wvx"
  !insertmacro ${_action} Other ".xspf"
  !insertmacro ${_action} Other ".wpl"
  !insertmacro ${_action} Other ".zpl"
!macroend

!macro MacroUnassociatedExtensions _action
  !insertmacro ${_action} Other ".iso"
  !insertmacro ${_action} Audio ".mid"
  !insertmacro ${_action} Other ".zip"
  !insertmacro ${_action} Other ".rar"
!macroend

!macro MacroSkinExtensions _action
  !insertmacro ${_action} Skin ".vlt"
  !insertmacro ${_action} Skin ".wsz"
!macroend

; One macro to rule them all
!macro MacroAllExtensions _action
  !insertmacro MacroAudioExtensions ${_action}
  !insertmacro MacroVideoExtensions ${_action}
  !insertmacro MacroOtherExtensions ${_action}
  !insertmacro MacroUnassociatedExtensions ${_action}
!macroend

; Generic function for adding the context menu for one ext.
!macro AddContextMenuExt EXT
  WriteRegStr HKCR ${EXT}\shell\PlayWith${PRODUCT_PROGID} "" "$(ContextMenuEntry_PlayWith)"
  WriteRegStr HKCR ${EXT}\shell\PlayWith${PRODUCT_PROGID} "Icon" '"$INSTDIR\${PRODUCT_EXE}",0'
  WriteRegStr HKCR ${EXT}\shell\PlayWith${PRODUCT_PROGID} "MultiSelectModel" "Player"
  WriteRegStr HKCR ${EXT}\shell\PlayWith${PRODUCT_PROGID}\command "" '"$INSTDIR\${PRODUCT_EXE}" --started-from-file --no-playlist-enqueue "%1"'

  WriteRegStr HKCR ${EXT}\shell\AddToPlaylist${PRODUCT_PROGID} "" "$(ContextMenuEntry_AddToPlaylist)"
  WriteRegStr HKCR ${EXT}\shell\AddToPlaylist${PRODUCT_PROGID} "Icon" '"$INSTDIR\${PRODUCT_EXE}",0'
  WriteRegStr HKCR ${EXT}\shell\AddToPlaylist${PRODUCT_PROGID} "MultiSelectModel" "Player"
  WriteRegStr HKCR ${EXT}\shell\AddToPlaylist${PRODUCT_PROGID}\command "" '"$INSTDIR\${PRODUCT_EXE}" --started-from-file --playlist-enqueue "%1"'
!macroend

!if "${PRODUCT_PROGID}" != "VLC"
; redesign: brand layer, one context menu verb in own class key TREE (SUBKEY: the verb's key
; inside it, "" when the verb key is TREE), written to HKLM\Software\Classes and recorded
!macro ConeContextMenuVerb TREE SUBKEY LABEL ARGS
  !insertmacro RegClassesOwnStr "${TREE}" "${SUBKEY}" "" "${LABEL}"
  !insertmacro RegClassesOwnStr "${TREE}" "${SUBKEY}" "Icon" '"$INSTDIR\${PRODUCT_EXE}",0'
  !insertmacro RegClassesOwnStr "${TREE}" "${SUBKEY}" "MultiSelectModel" "Player"
!if "${SUBKEY}" == ""
  !insertmacro RegClassesOwnStr "${TREE}" "command" "" '"$INSTDIR\${PRODUCT_EXE}" ${ARGS} "%1"'
!else
  !insertmacro RegClassesOwnStr "${TREE}" "${SUBKEY}\command" "" '"$INSTDIR\${PRODUCT_EXE}" ${ARGS} "%1"'
!endif
!macroend

; the two verbs of the ProgID of extension $R0
Function ConeAddContextMenu
  !insertmacro ConeContextMenuVerb "${PRODUCT_PROGID}$R0" "shell\PlayWith${PRODUCT_PROGID}" "$(ContextMenuEntry_PlayWith)" "--started-from-file --no-playlist-enqueue"
  !insertmacro ConeContextMenuVerb "${PRODUCT_PROGID}$R0" "shell\AddToPlaylist${PRODUCT_PROGID}" "$(ContextMenuEntry_AddToPlaylist)" "--started-from-file --playlist-enqueue"
FunctionEnd

; the folder verbs: each is an own key under the shared Directory\shell
!macro ConeAddDirectoryContextMenu
  !insertmacro ConeContextMenuVerb "Directory\shell\PlayWith${PRODUCT_PROGID}" "" "$(ContextMenuEntry_PlayWith)" "--started-from-file --no-playlist-enqueue"
  !insertmacro ConeContextMenuVerb "Directory\shell\AddToPlaylist${PRODUCT_PROGID}" "" "$(ContextMenuEntry_AddToPlaylist)" "--started-from-file --playlist-enqueue"
!macroend

!macro AddContextMenu TYPE EXT
  Push $R0
  StrCpy $R0 ${EXT}
  Call ConeAddContextMenu
  Pop $R0
!macroend
!else
!macro AddContextMenu TYPE EXT
  !insertmacro AddContextMenuExt ${PRODUCT_PROGID}${EXT}
!macroend
!endif

!macro DeleteContextMenuExt EXT
  DeleteRegKey HKCR ${EXT}\shell\PlayWith${PRODUCT_PROGID}
  DeleteRegKey HKCR ${EXT}\shell\AddToPlaylist${PRODUCT_PROGID}
!macroend

!macro DeleteContextMenu TYPE EXT
  !insertmacro DeleteContextMenuExt ${PRODUCT_PROGID}${EXT}
!macroend


