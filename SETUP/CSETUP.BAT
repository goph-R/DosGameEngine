@echo off
echo Compiling SETUP and dependencies...
echo.

cd ..\UNITS
call CUNITS.BAT
if errorlevel 1 goto error

echo Compiling VOCLOAD.PAS...
cd ..\SETUP
tpc -U..\UNITS VOCLOAD.PAS
if errorlevel 1 goto error

echo Compiling SETUP.PAS...
tpc -U..\UNITS SETUP.PAS
if errorlevel 1 goto error

echo.
echo Build successful!
goto end

:error
echo.
echo Build failed!
cd ..\SETUP

:end
