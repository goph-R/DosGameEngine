@echo off
echo Compiling XICLONE and dependencies...
echo.

cd ..\UNITS
call CUNITS.BAT
if errorlevel 1 goto error

cd ..\XICLONE

echo Compiling XITYPES.PAS...
tpc -U..\UNITS XITYPES.PAS
if errorlevel 1 goto error

echo Compiling XILOGIC.PAS...
tpc -U..\UNITS XILOGIC.PAS
if errorlevel 1 goto error

echo Compiling XISTYLE.PAS...
tpc -U..\UNITS XISTYLE.PAS
if errorlevel 1 goto error

echo Compiling XIRENDER.PAS...
tpc -U..\UNITS XIRENDER.PAS
if errorlevel 1 goto error

echo Compiling BASESCR.PAS...
tpc -U..\UNITS BASESCR.PAS
if errorlevel 1 goto error

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
