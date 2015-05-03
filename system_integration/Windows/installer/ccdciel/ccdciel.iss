; Script generated by the Inno Setup Script Wizard.
; SEE THE DOCUMENTATION FOR DETAILS ON CREATING INNO SETUP SCRIPT FILES!
 
[Setup]
AppName=CCDciel
AppVerName=CCDciel V3
AppPublisherURL=http://sourceforge.net/projects/ccdciel
AppSupportURL=http://sourceforge.net/projects/ccdciel
AppUpdatesURL=http://sourceforge.net/projects/ccdciel
DefaultDirName={pf}\CCDciel}
UsePreviousAppDir=false
DefaultGroupName=CCDciel
AllowNoIcons=true
InfoBeforeFile=Presetup\readme.txt
OutputDir=.\
OutputBaseFilename=ccdciel-windows
Compression=lzma
SolidCompression=true
Uninstallable=true
UninstallLogMode=append
DirExistsWarning=no
ShowLanguageDialog=yes
AppID={{6570df38-f18f-11e4-9532-fb2d36b55e00}

[Tasks]
Name: desktopicon; Description: {cm:CreateDesktopIcon}; GroupDescription: {cm:AdditionalIcons}

[Files]
Source: Data\*; DestDir: {app}; Flags: ignoreversion recursesubdirs createallsubdirs restartreplace
; NOTE: Don't use "Flags: ignoreversion" on any shared system files

[Icons]
Name: {group}\CCDciel; Filename: {app}\ccdciel.exe; WorkingDir: {app}
Name: {userdesktop}\CCDciel; Filename: {app}\ccdciel.exe; WorkingDir: {app}; Tasks: desktopicon
 
