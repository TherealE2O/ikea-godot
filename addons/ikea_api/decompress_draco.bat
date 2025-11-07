@echo off
REM Script to decompress Draco-compressed GLB files
REM Requires: npm install -g @gltf-transform/cli

if "%~1"=="" (
    echo Usage: %~nx0 ^<input.glb^> [output.glb]
    exit /b 1
)

set INPUT=%~1
if "%~2"=="" (
    set OUTPUT=%~dpn1_uncompressed.glb
) else (
    set OUTPUT=%~2
)

where gltf-transform >nul 2>&1
if %errorlevel% neq 0 (
    echo Error: gltf-transform not found. Install with:
    echo   npm install -g @gltf-transform/cli
    exit /b 1
)

echo Decompressing %INPUT% to %OUTPUT%...
gltf-transform draco "%INPUT%" "%OUTPUT%" --decode

if %errorlevel% equ 0 (
    echo Success! Decompressed model saved to: %OUTPUT%
) else (
    echo Error: Failed to decompress model
    exit /b 1
)
