@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
for %%I in ("%SCRIPT_DIR%..") do set "PROJECT_DIR=%%~fI"

set "GODOT_EXE=%~1"
if "%GODOT_EXE%"=="" set "GODOT_EXE=%GODOT_BINARY%"

set "TEST_ROOT=%~2"
if "%TEST_ROOT%"=="" set "TEST_ROOT=res://tests/godot"

if "%GODOT_EXE%"=="" (
    echo Usage: tools\run_gdunit_windows.cmd ^<godot_binary^> [res://tests/path]
    echo Or set GODOT_BINARY in the environment.
    exit /b 1
)

echo [run_gdunit_windows] Refreshing Godot script-class cache...
call "%GODOT_EXE%" --headless --editor --path "%PROJECT_DIR%" --quit
if errorlevel 1 exit /b %errorlevel%

echo [run_gdunit_windows] Running GdUnit4 suite at %TEST_ROOT%...
pushd "%PROJECT_DIR%"
call "addons\gdUnit4\runtest.cmd" --godot_binary "%GODOT_EXE%" -a "%TEST_ROOT%" -c
set "EXIT_CODE=%ERRORLEVEL%"
popd

exit /b %EXIT_CODE%
