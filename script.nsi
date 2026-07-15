!include LogicLib.nsh
!define APP_NAME "Dpm"
Outfile "${OUT}"
RequestExecutionLevel admin ; Required for adding to PATH

Var TEMP_INSTALL_DIR

Section "Install"
    GetTempFileName $TEMP_INSTALL_DIR
    Delete $TEMP_INSTALL_DIR
    CreateDirectory $TEMP_INSTALL_DIR

    SetOutPath $TEMP_INSTALL_DIR
    File /r "${SOURCE_DIR}\*"

    nsExec::ExecToLog '"$TEMP_INSTALL_DIR\bin\dpm.exe" bootstrap "$TEMP_INSTALL_DIR"'

    ; Use powershell to add %APPDATA%\dpm\bin to the user's PATH if it isn't already in the PATH.
    ; Accounts for when the user's PATH doesn't exist.
    nsExec::ExecToLog `powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "if ([Environment]::GetEnvironmentVariable('path','User') -eq $$null -Or !([Environment]::GetEnvironmentVariable('path','User').split(\";\") -Contains \"$$env:APPDATA\dpm\bin\")) { echo \"Updating PATH\"; [Environment]::SetEnvironmentVariable('path',\"$$env:APPDATA\dpm\bin;$$([Environment]::GetEnvironmentVariable('path','User'))\",'User'); }"`
SectionEnd

Section -PostInstallCleanup
    RMDir /r $TEMP_INSTALL_DIR
SectionEnd
