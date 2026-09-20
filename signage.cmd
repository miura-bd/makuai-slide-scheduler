@echo off
rem makuai-slide-scheduler を Windows でサイネージモード起動する。
rem このファイルをダブルクリックするか、コマンドプロンプトから実行します。
rem
rem   signage.cmd              キオスク表示で起動する（本番）
rem   signage.cmd --windowed   ウィンドウで起動する（設定や本番前の確認用）
rem   signage.cmd --help
rem
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul 2>&1
title makuai-slide-scheduler

set "HERE=%~dp0"
set "PAGE=%HERE%index.html"
set "WINMODE=--kiosk"
set "EXTRA="
rem 変数名に括弧が入るため、if (...) の外で退避しておく
set "PF86=%ProgramFiles(x86)%"

:parse
if "%~1"=="" goto parsed
if /I "%~1"=="-h"         goto usage
if /I "%~1"=="--help"     goto usage
if /I "%~1"=="/?"         goto usage
if /I "%~1"=="--windowed" (
  set "WINMODE=--window-size=1280,720"
  shift
  goto parse
)
if /I "%~1"=="--" (
  shift
  goto collect
)
echo signage.cmd: 不明な引数: %~1
echo.
goto usage

:collect
if "%~1"=="" goto parsed
set "EXTRA=!EXTRA! %1"
shift
goto collect

:parsed
if not exist "%PAGE%" (
  echo signage.cmd: index.html が見つかりません: %PAGE%
  echo   この signage.cmd は index.html と同じフォルダに置いてください。
  goto fail
)

rem ---------- ブラウザを探す ----------
set "BROWSER="
set "PROC="
if defined MAKUAI_BROWSER (
  set "BROWSER=%MAKUAI_BROWSER%"
  for %%I in ("%MAKUAI_BROWSER%") do set "PROC=%%~nxI"
)
call :find "%ProgramFiles%\Google\Chrome\Application\chrome.exe"  chrome.exe
call :find "%PF86%\Google\Chrome\Application\chrome.exe"          chrome.exe
call :find "%LocalAppData%\Google\Chrome\Application\chrome.exe"  chrome.exe
call :find "%ProgramFiles%\Microsoft\Edge\Application\msedge.exe" msedge.exe
call :find "%PF86%\Microsoft\Edge\Application\msedge.exe"         msedge.exe

if not defined BROWSER (
  echo signage.cmd: Chrome / Edge が見つかりません。
  echo   Google Chrome を入れるか、環境変数 MAKUAI_BROWSER で
  echo   実行ファイルの場所を指定してください。
  goto fail
)

rem ---------- すでに開いているブラウザがあると、キオスクにならない ----------
rem 同じプロファイルで起動中だと、新しいウィンドウを既存のプロセスに任せてしまい、
rem --kiosk が効かずに普通のタブが開くだけになる。
tasklist /FI "IMAGENAME eq %PROC%" 2>nul | find /I "%PROC%" >nul
if not errorlevel 1 (
  echo signage.cmd: ブラウザ ^(%PROC%^) がすでに起動しています。
  echo   開いているウィンドウをすべて閉じてから、もう一度実行してください。
  echo   そのまま起動すると、キオスク表示にならず普通のタブが開くだけになります。
  goto fail
)

rem ---------- 起動 ----------
set "URL=%PAGE:\=/%"
set "URL=file:///%URL%"

set "FLAGS=--no-first-run --no-default-browser-check --noerrdialogs"
set "FLAGS=%FLAGS% --disable-infobars --disable-session-crashed-bubble"
set "FLAGS=%FLAGS% --disable-features=Translate,TranslateUI"
set "FLAGS=%FLAGS% --disable-component-update --check-for-update-interval=31536000"
set "FLAGS=%FLAGS% --autoplay-policy=no-user-gesture-required"
set "FLAGS=%FLAGS% --overscroll-history-navigation=0"
if defined MAKUAI_PROFILE set "FLAGS=%FLAGS% --user-data-dir=%MAKUAI_PROFILE%"

echo signage.cmd: %PROC% で起動します
echo   ページ : %PAGE%
if "%WINMODE%"=="--kiosk" echo   終了   : 表示中に Alt+F4

start "" "%BROWSER%" %FLAGS% %WINMODE%%EXTRA% "%URL%"
exit /b 0

:find
if defined BROWSER goto :eof
if exist %1 (
  set "BROWSER=%~1"
  set "PROC=%~2"
)
goto :eof

:usage
echo makuai-slide-scheduler をサイネージモードで起動します。
echo.
echo   signage.cmd              キオスク表示で起動する（本番）
echo   signage.cmd --windowed   ウィンドウで起動する（設定や本番前の確認用）
echo   signage.cmd -- ^<引数...^>  以降をブラウザにそのまま渡す
echo.
echo 環境変数:
echo   MAKUAI_BROWSER   使うブラウザの実行ファイルを明示する
echo   MAKUAI_PROFILE   プロファイルを専用のものに分けたいときに指定する
echo.
echo 登壇スケジュールの登録は index.html を開いて行ってください。
echo 既定のブラウザが Chrome / Edge でない場合は、--windowed で開いて
echo 登録してください。設定はブラウザごとに別で保存されます。
echo.
pause
exit /b 0

:fail
echo.
pause
exit /b 1
