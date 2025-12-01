@echo off

setlocal enabledelayedexpansion

title Rime package installer

set root_dir=%~dp0
set PATH=%root_dir%;%PATH%

set config_file=%~dp0\rime-install-config.bat
if exist "%config_file%" call "%config_file%"

if not defined rime_dir set rime_dir=%APPDATA%\Rime
if not defined download_cache_dir set download_cache_dir=%TEMP%
if not exist "%download_cache_dir%" mkdir "%download_cache_dir%"

echo.
echo Rime package installer
echo.
echo Working directory: %CD%
echo Package installer directory: %root_dir%
echo Download cache directory: %download_cache_dir%
echo Rime user directory: %rime_dir%
echo.

if defined ProgramFiles(x86) (set arch=64) else (set arch=32)

call :find_7z
call :find_git_bash
call :find_downloader

if not defined use_plum if "%has_git_bash%" == "1" set use_plum=1

:process_arguments
if "%1" == "" set batch_interactive=1

if "%1" == "--select" if "%use_plum" == "1" (
  call :install_with_plum %*
  exit /b !errorlevel!
)

set /a installed_packages=0

:next
if "%batch_interactive%" == "1" (
  set package=
  echo. && (set /p package=Enter package name, URL, user/repo or downloaded ZIP to install: )
) else (
  set package=%1
  shift
)
if "%package%" == "" goto finish

call :install_package
if errorlevel 1 exit /b %errorlevel%
goto next

:install_package
if "%package%" == "7z" (
  call :install_7z
  exit /b %errorlevel%
) else if "%package%" == "git" (
  call :install_git
  exit /b %errorlevel%
) else if "%package%" == "plum" (
  call :install_with_plum plum
  exit /b %errorlevel%
) else if "%package:.zip=%.zip" == "%package%" (
  if "https://github.com/%package:https://github.com/=%" == "%package%" (
     set user_repo_path=%package:https://github.com/=%
     set archive_name=%package:*/archive/=%
     for /f "tokens=1 usebackq delims=." %%g in ('!archive_name!') do set branch=%%g
     call set package_repo=%%user_repo_path:/archive/!archive_name!=%%
     call :download_package
  ) else (
    set package_file=%package%
    call :install_zip_package
  )
  goto :after_install_package
)

:prefer_plum_installer
if "%use_plum%" == "1" (
  call :install_with_plum %package%
  goto after_install_package
)
:fallback_to_builtin_installer
set branch=
if "https://github.com/%package:https://github.com/=%" == "%package%" (
  set user_repo_path=%package:https://github.com/=%
  if not "%package:/tree/=%" == "%package%" (
    set branch=%package:*/tree/=%
  )
  if defined branch (
    call set package_repo=%%user_repo_path:/tree/!branch!=%%
  ) else (
    set package_repo=!user_repo_path!
  )
  call :download_package
) else if "%package:-packages.bat=%-packages.bat" == "%package%" (
  call "%package%"
  call :install_package_group
) else if ":%package::=%" == "%package%" (
  call "%package::=%-packages.bat"
  call :install_package_group
) else if not "%package:/=%" == "%package%" (
  for /f "tokens=1,2 usebackq delims=@" %%g in ('%package%') do (
    set package_repo=%%g
    set branch=%%h
  )
  call :download_package
) else (
  for /f "tokens=1,2 usebackq delims=@" %%g in ('%package%') do (
    set user_repo_path=%%g
    set branch=%%h
  )
  set package_repo=rime/rime-!user_repo_path:rime-=!
  call :download_package
)
:after_install_package
if not errorlevel 1 set /a installed_packages+=1
exit /b %errorlevel%

:download_package
if not defined downloader (
  set error_message=Downloader not found.
  goto error
)
call :install_7z /needed
if errorlevel 1 exit /b %errorlevel%
if not defined branch (
  for /f "tokens=2 usebackq delims=:, " %%g in (`
    %downloader% https://api.github.com/repos/%package_repo% ^| findstr default_branch
  `) do set branch=%%~g
)
set package_url=https://github.com/%package_repo%/archive/%branch%.zip
echo.
echo Downloading %package_url% ...
echo.
set package_file=%download_cache_dir%\%package_repo:*/=%-%branch%.zip
if "%no_update%" == "1" if exist "%package_file%" goto skip_download_package
%downloader% "%package_url%" %save_to% "%package_file%"
if errorlevel 1 (
  set error_message=Error downloading %package_url%
  goto error
)
:skip_download_package
call :install_zip_package
exit /b %errorlevel%

:install_zip_package
call :install_7z /needed
if errorlevel 1 exit /b %errorlevel%
echo.
echo Unpacking %package_file% ...
echo.
for %%f in (%package_file%) do set package_dir=%%~nf
set unpack_package_dir=%TEMP%\%package_dir%
rem clean up obsolete files in target directory
if exist "%unpack_package_dir%" rmdir /s /q "%unpack_package_dir%"
rem unzip package
7z x "%package_file%" -o"%TEMP%" -y
if errorlevel 1 (
  set error_message=Error unpacking package %package_file%
  goto error
)
if not exist "%rime_dir%" (
  mkdir "%rime_dir%"
  if errorlevel 1 (
    set error_message=Error creating rime user directory: %rime_dir%
    goto error
  )
)
rem install files from the unzipped package
pushd "%unpack_package_dir%"
for %%f in (
    *.yaml
    *.txt
    opencc\*.json
    opencc\*.ocd
    opencc\*.txt
) do (
  echo.
  echo Installing %%f ...
  echo.
  set target_file=%rime_dir%\%%f
  for %%t in (!target_file!) do set target_dir=%%~dpt
  if not exist "!target_dir!" mkdir "!target_dir!"
  copy /y "%%f" "!target_file!"
  if errorlevel 1 (
    popd
    set error_message=Error installing files from package %package%
    goto error
  )
)
popd
exit /b

:install_package_group
if not defined package_list (
  set error_message=package_list is undefined in %package%
  goto error
)
for %%p in (%package_list%) do (
  set package=%%p
  call :install_package
  if errorlevel 1 exit /b !errorlevel!
)
exit /b

:install_with_plum
call :install_git /needed
if errorlevel 1 exit /b %errorlevel%

set WSLENV=plum_dir:rime_dir

if defined plum_dir if exist "%plum_dir%"/rime-install (
   bash "%plum_dir%"/rime-install %*
   exit /b !errorlevel!
)
if exist plum/rime-install (
  bash plum/rime-install %*
) else if exist rime-install (
  bash rime-install %*
) else (
  echo Downloading rime-install ...
  set script_url=https://raw.githubusercontent.com/rime/plum/master/rime-install
  curl -fsSL "!script_url!" -o "%download_cache_dir%"/rime-install
  if errorlevel 1 (
    set error_message=Error downloading rime-install
    goto error
  )
  bash "%download_cache_dir%"/rime-install %*
)
exit /b %errorlevel%

:install_7z
where /q 7z
if not errorlevel 1 (
   if "%1" == "/needed" exit /b
   echo.
   echo Found 7z
   echo.
   exit /b
)

rem check for updates at https://www.7-zip.org/download.html
if not defined _7z_version set _7z_version=18.01

if "%arch%" == "64" (set _7z_arch=-x%arch%) else (set _7z_arch=)
set _7z_installer=7z%_7z_version:.=%%_7z_arch%.exe

rem find local 7z installer
where /q %_7z_installer%
if not errorlevel 1 (
   echo.
   echo Found installer: %_7z_installer%
   echo.
   set _7z_installer_path=%_7z_installer%
   goto run_7z_installer
)

set _7z_installer_path=%download_cache_dir%\%_7z_installer%
if "%no_update%" == "1" if exist "%_7z_installer_path%" goto run_7z_installer

:download_7z_installer
set _7z_download_url=https://www.7-zip.org/a/%_7z_installer%
if not defined downloader (
   echo.
   echo TODO: please download and install 7z: %_7z_download_url%
   echo.
   set error_message=Downloader not found.
   goto error
)
echo.
echo Downloading installer: %_7z_installer%
echo.
%downloader% "%_7z_download_url%" %save_to% "%_7z_installer_path%"
if errorlevel 1 (
  set error_message=Error downloading %_7z_installer%
  goto error
)
rem TODO: verify installer
echo.
echo Download complete: %_7z_installer%
echo.

:run_7z_installer
echo.
echo Installing 7z ...
echo.
"%_7z_installer_path%" /S

exit /b

:install_git
where /q git
if not errorlevel 1 (
   if "%1" == "/needed" exit /b
   echo.
   echo Found git
   echo.
   exit /b
)

rem check for updates at https://github.com/git-for-windows/git/releases/latest
if not defined git_version set git_version=2.17.0
if not defined git_release set git_release=.1

set git_installer=Git-%git_version%%git_release:.1=%-%arch%-bit.exe
rem find local Git installer
where /q %git_installer%
if not errorlevel 1 (
   echo.
   echo Found installer: %git_installer%
   echo.
   set git_installer_path=%git_installer%
   goto run_git_installer
)

set git_installer_path=%download_cache_dir%\%git_installer%
if "%no_update%" == "1" if exist "%git_installer_path%" goto run_git_installer

:download_git_installer
set git_download_url_prefix=https://github.com/git-for-windows/git/releases/download/
set git_download_url=%git_download_url_prefix%v%git_version%.windows%git_release%/%git_installer%

if not defined downloader (
   echo.
   echo TODO: please download and install git: %git_download_url%
   echo.
   set error_message=Downloader not found.
   goto error
)
echo.
echo Downloading installer: %git_installer%
echo.
%downloader% "%git_download_url%" %save_to% "%git_installer_path%"
if errorlevel 1 (
   set error_message=Error downloading %git_installer%
   goto error
)
rem TODO: verify installer
echo.
echo Download complete: %git_installer%
echo.

:run_git_installer
echo.
echo Installing git ...
echo.
"%git_installer_path%" /SILENT

exit /b

:find_7z
set search_path=^
%ProgramFiles%\7-Zip;

if defined ProgramW6432 set search_path=%search_path%^
%ProgramW6432%\7-Zip;

if defined ProgramFiles(x86) set search_path=%search_path%^
%ProgramFiles(x86)%\7-Zip;

set PATH=%search_path%%PATH%

where /q 7z
if %errorlevel% equ 0 set has_7z=1
exit /b

:find_git_bash
set search_path=^
%ProgramFiles%\Git\cmd;^
%ProgramFiles%\Git\mingw%arch%\bin;^
%ProgramFiles%\Git\usr\bin;

rem find 64-bit Git in 32-bit cmd.exe
if defined ProgramW6432 set search_path=%search_path%^
%ProgramW6432%\Git\cmd;^
%ProgramW6432%\Git\mingw%arch%\bin;^
%ProgramW6432%\Git\usr\bin;

rem find user installed 32-bit Git on 64-bit OS
if defined ProgramFiles(x86) set search_path=%search_path%^
%ProgramFiles(x86)%\Git\cmd;^
%ProgramFiles(x86)%\Git\mingw32\bin;^
%ProgramFiles(x86)%\Git\usr\bin;

set PATH=%search_path%%PATH%

where /q git
if %errorlevel% equ 0 set has_git=1

where /q bash
if %errorlevel% equ 0 set has_bash=1

if "%has_git%" == "1" if "%has_bash%" == "1" set has_git_bash=1
exit /b

:find_downloader
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
:downloader_found
exit /b

:error
echo.
echo Installation failed: %error_message%
echo.
exit /b 1

:finish
echo.
if %installed_packages% equ 0 (
  echo No package installed.
) else (
  echo Installed %installed_packages% packages.
)
echo.

:exit
