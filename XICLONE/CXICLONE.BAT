@echo off
echo Compiling XICLONE and dependencies...
echo.

cd ..\UNITS
call CUNITS.BAT
if errorlevel 1 goto error

cd ..\XICLONE

echo Compiling XIGAME.PAS...
tpc -U..\UNITS XIGAME.PAS
if errorlevel 1 goto error

rem echo Compiling HISCORE.PAS...
rem tpc -U..\UNITS HISCORE.PAS
rem if errorlevel 1 goto error

echo Compiling GAMESCR.PAS...
tpc -U..\UNITS GAMESCR.PAS
if errorlevel 1 goto error

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
