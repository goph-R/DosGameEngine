@echo off
echo Compiling XICLONE and dependencies...
echo.

rem -- Compile the engine

cd ..\UNITS
call CUNITS.BAT
if errorlevel 1 goto error

cd ..\XICLONE

rem -- Compile the main game class

echo Compiling XIGAME.PAS...
tpc -U..\UNITS XIGAME.PAS
if errorlevel 1 goto error

rem -- Compile the screen classes

echo Compiling GAMESCR.PAS...
tpc -U..\UNITS GAMESCR.PAS
if errorlevel 1 goto error

rem -- Compile the entry point

echo Compiling XICLONE.PAS...
tpc -U..\UNITS XICLONE.PAS
if errorlevel 1 goto error

echo.
echo Build successful! Run XICLONE.EXE to play the example game.
goto end

:error
echo.
echo Build failed!
cd ..\XICLONE

:end
