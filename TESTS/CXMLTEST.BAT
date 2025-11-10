@echo off
echo Compiling MiniXML Test...
echo.

cd ..\UNITS

echo Compiling GENTYPES.PAS...
tpc GENTYPES.PAS
if errorlevel 1 goto error

echo Compiling StrMap...
tpc StrMap.pas
if errorlevel 1 goto error

echo Compiling MiniXML...
tpc MiniXML.pas
if errorlevel 1 goto error

cd ..\TESTS
echo Compiling XMLTEST...
tpc -U..\UNITS XMLTEST.PAS
if errorlevel 1 goto error

echo.
echo Build successful!
goto end

:error
echo.
echo Build FAILED!

:end
