@echo off
setlocal enabledelayedexpansion

set "files="

for %%i in (*.sp) do (
    set "files=!files! %%i"
)

echo Compiling: %files%
compile.exe %files%

echo Done.
