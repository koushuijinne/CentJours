@echo off
REM Cent Jours — Windows release build script
REM Prerequisites:
REM   1. Rust toolchain (stable)
REM   2. Godot 4.6.1 with export templates installed
REM   3. Godot console binary path set below

setlocal

REM ── Configuration ──────────────────────────────────────────
set GODOT_BIN=E:\software\godot\Godot_v4.6.1-stable_win64_console.exe
set PROJECT_DIR=%~dp0..
set BUILD_DIR=%PROJECT_DIR%\build
set RUST_DIR=%PROJECT_DIR%\cent-jours-core

REM ── Step 1: Build Rust GDExtension (release) ──────────────
echo [1/4] Building Rust GDExtension (release)...
pushd "%RUST_DIR%"
cargo build --release --features godot-extension
if %ERRORLEVEL% neq 0 (
    echo ERROR: Rust build failed.
    exit /b 1
)
popd
echo       Done.

REM ── Step 2: Run Rust tests ────────────────────────────────
echo [2/4] Running Rust tests...
pushd "%RUST_DIR%"
cargo test
if %ERRORLEVEL% neq 0 (
    echo WARNING: Some Rust tests failed. Continuing anyway.
)
popd
echo       Done.

REM ── Step 3: Create build directory ────────────────────────
echo [3/4] Preparing build directory...
if not exist "%BUILD_DIR%" mkdir "%BUILD_DIR%"

REM ── Step 4: Export with Godot ─────────────────────────────
echo [4/4] Exporting Godot project...
"%GODOT_BIN%" --headless --path "%PROJECT_DIR%" --export-release "Windows Desktop" "%BUILD_DIR%\CentJours.exe"
if %ERRORLEVEL% neq 0 (
    echo ERROR: Godot export failed.
    echo   Make sure export templates are installed:
    echo   Editor ^> Manage Export Templates ^> Download
    exit /b 1
)

echo.
echo ================================================
echo   Build complete: %BUILD_DIR%\CentJours.exe
echo ================================================
