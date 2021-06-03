@echo off
set appname=tinyterm

if EXIST %appname%.exe (
	del %appname%.exe
)
tools\sjasm.exe %appname%.asm %appname%.lst
if errorlevel 1 goto ERR
echo Ok!
goto END

:ERR
del %appname%.exe
pause
echo Some errors happened...
pause
goto END

:END
