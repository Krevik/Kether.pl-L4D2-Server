@echo off

for %%i in (*.sp) do (
    echo Compiling: %%i
    compile.exe "%%i"
)

echo Done.
pause