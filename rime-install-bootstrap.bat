@echo off

setlocal

set root_dir=%~dp0
set PATH=%root_dir%;%PATH%

set script_path=%root_dir%rime-install.bat
set config_path=%root_dir%rime-install-config.bat

rem download rime-install.bat if missing
if exist "%script_path%" goto end_download

where /q curl
if %errorlevel% equ 0 (
   set downloader=curl -fsSL
   set save_to=-o
   goto downloader_found
)

where /q powershell
if %errorlevel% equ 0 (
   set downloader=powershell Invoke-WebRequest
   set save_to=-OutFile
   goto downloader_found
)

echo Error: downloader not found.
exit /b 1
:downloader_found

set script_url=https://raw.githubusercontent.com/rime/plum/master/rime-install.bat
set config_url=https://github.com/rime/plum/raw/master/rime-install-config.bat

echo Downloading rime-install.bat ...
%downloader% "%script_url%" %save_to% "%script_path%"
if errorlevel 1 (
   echo Error downloading rime-install.bat
   exit /b 1
)

if exist "%config_path%" goto end_download

echo Downloading rime-install-config.bat template ...
%downloader% "%config_url%" %save_to% "%config_path%"
if errorlevel 1 (
   echo Error downloading rime-install-config.bat
   exit /b 1
)

:end_download

set link_name=Rime package installer

rem create shortcut
powershell "$s=(New-Object -COM WScript.Shell).CreateShortcut('%root_dir%%link_name%.lnk');$s.TargetPath='\"%ComSpec%\"';$s.Arguments='/k \"%script_path%\"';$s.WorkingDirectory='%root_dir%';$s.Save()"
