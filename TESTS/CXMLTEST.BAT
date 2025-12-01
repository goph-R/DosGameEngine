@echo off
echo Compiling MiniXML Test...
echo.

cd ..\UNITS
call CUNITS.BAT
if errorlevel 1 goto error

echo Compiling XMLTEST.PAS...
cd ..\TESTS
tpc -U..\UNITS XMLTEST.PAS
if errorlevel 1 goto error

echo.
echo Build successful!
goto end

:error
echo.
echo Build failed!
cd ..\TESTS

:end
