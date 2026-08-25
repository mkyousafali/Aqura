; Aqura PC Lock Guard — NSIS custom installer script

!macro customInstall
  ; Create data directory
  CreateDirectory "$INSTDIR\data"

  ; Register the auto-start entry (machine-wide)
  WriteRegStr HKLM "SOFTWARE\Microsoft\Windows\CurrentVersion\Run" "AquraPCLockGuard" '"$INSTDIR\Aqura PC Lock Guard.exe"'
!macroend

!macro customUnInstall
  ; Remove auto-start
  DeleteRegValue HKLM "SOFTWARE\Microsoft\Windows\CurrentVersion\Run" "AquraPCLockGuard"

  ; Remove policy registry entries created by Lock Guard
  DeleteRegValue HKLM "SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" "NoClose"
  DeleteRegValue HKLM "SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" "StartMenuLogOff"
  DeleteRegValue HKLM "SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" "NoControlPanel"
  DeleteRegValue HKLM "SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" "NoSetDate"
  DeleteRegValue HKLM "SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" "NoAddPrinter"
  DeleteRegValue HKLM "SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" "NoDeletePrinter"
  DeleteRegValue HKLM "SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" "HideFastUserSwitching"
  DeleteRegValue HKLM "SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" "DisableTaskMgr"
  DeleteRegValue HKLM "SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" "DisableRegistryTools"
  DeleteRegValue HKLM "SOFTWARE\Policies\Microsoft\Windows\System" "DisableCMD"
  DeleteRegValue HKLM "SOFTWARE\Policies\Microsoft\Windows NT\Printers" "DisableWebPnPDownload"
!macroend
