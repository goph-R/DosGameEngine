@echo off
REM Compile TMXOPT.EXE
echo Compiling TMXOPT.PAS...

REM Compile with paths to UNITS folder
tpc -B -U..\..\UNITS TMXOPT.PAS

if errorlevel 1 goto error

echo.
echo Compilation successful!
echo.
goto end

:error
echo.
echo Compilation failed!
echo.

:end
