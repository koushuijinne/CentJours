@echo off
setlocal EnableDelayedExpansion

set "SCRIPT_DIR=%~dp0"
for %%I in ("%SCRIPT_DIR%..") do set "PROJECT_DIR=%%~fI"

set "GODOT_EXE=%~1"
if "%GODOT_EXE%"=="" set "GODOT_EXE=%GODOT_BINARY%"

if "%GODOT_EXE%"=="" (
    echo Usage: tools\run_gdunit_windows.cmd ^<godot_binary^> [res://tests/path ...]
    echo Or set GODOT_BINARY in the environment.
    exit /b 1
)

shift

set /a TEST_ROOT_COUNT=0
:collect_test_roots
if "%~1"=="" goto finish_collect
set /a TEST_ROOT_COUNT+=1
set "TEST_ROOT_!TEST_ROOT_COUNT!=%~1"
shift
goto collect_test_roots

:finish_collect
if %TEST_ROOT_COUNT% EQU 0 (
    set /a TEST_ROOT_COUNT=1
    set "TEST_ROOT_1=res://tests/godot"
)

echo [run_gdunit_windows] Refreshing Godot script-class cache...
call "%GODOT_EXE%" --headless --editor --path "%PROJECT_DIR%" --quit
if errorlevel 1 exit /b %errorlevel%

set "EXIT_CODE=0"
for /L %%I in (1,1,%TEST_ROOT_COUNT%) do (
    set "TEST_ROOT=!TEST_ROOT_%%I!"
    echo [run_gdunit_windows] Running GdUnit4 suite at !TEST_ROOT!...
    pushd "%PROJECT_DIR%"
    call "addons\gdUnit4\runtest.cmd" --godot_binary "%GODOT_EXE%" -a "!TEST_ROOT!" -c
    set "EXIT_CODE=!ERRORLEVEL!"
    popd
    if not "!EXIT_CODE!"=="0" exit /b !EXIT_CODE!
)

exit /b %EXIT_CODE%
