@echo off
echo Compiling TMX Memory Test...
echo.

cd ..\UNITS
echo Compiling StrMap...
tpc StrMap.pas
if errorlevel 1 goto error

echo Compiling MiniXML...
tpc MiniXML.pas
if errorlevel 1 goto error

cd ..\TESTS
echo Compiling TMXMEMTEST...
tpc -U..\UNITS TMXMEMTEST.PAS
if errorlevel 1 goto error

echo.
echo Build successful!
goto end

:error
echo.
echo Build FAILED!

:end
