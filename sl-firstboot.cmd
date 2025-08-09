@ECHO OFF
SETLOCAL ENABLEDELAYEDEXPANSION

IF "%~1" == "" (
  ECHO Usage:
  ECHO   [1;37m%~n0.cmd ^<USB drive letter^> ^<path\to\payload\script^>[0m
  ECHO.
  ECHO This script allows you to run the provided payload script during the first
  ECHO boot of a Raspberry Pi OS image.
  ECHO.
  ECHO It copies an initialization script ^(sl-firstboot-init^) onto the FAT32 boot
  ECHO partition of the USB drive. It then copies your payload script as well ^(as
  ECHO sl-firstboot-payload^). It modifies the `init=` value in the cmdline.txt file
  ECHO of that partition to run sl-firstboot-init when the Raspberry Pi boots up for
  ECHO the first time.
  ECHO.
  ECHO When the Raspberry Pi boots up it will:
  ECHO   1. mount the boot partitions as read-write,
  ECHO   2. run sl-firstboot-init,
  ECHO   3. unmount the boot partition,
  ECHO   4. reboot the system.
  ECHO When sl-firstboot-init is run, it will:
  ECHO   1. run sl-firstboot-payload ^(i.e. your script^),
  ECHO   2. if the script fails, start /bin/bash and exit, otherwise
  ECHO   3. revert the changes made to cmdline.txt on the boot partition,
  ECHO   4. delete the initialization script from the boot partition,
  ECHO   5. delete the payload script from the boot partition,
  ECHO.
  ECHO If your payload script runs successfully, all changes made to the image by
  ECHO sl-firstboot will be reverted. Any changes made to the image by your payload
  ECHO script will remain. The system will reboot and continue to boot normally.
  EXIT /B 0
)
WHERE dos2unix >NUL 2>&1
IF ERRORLEVEL 1 (
  SET sCopyCommand=COPY /V /Y /L
  ECHO [1;33m![0m The dos2unix command is not available; make sure your script uses unix-
  ECHO   style line-breaks as they will not be automatically be converted!
) ELSE (
  SET sCopyCommand=dos2unix -e -n
  ECHO [1;32m+[0m dos2unix will be used to automatically adjust line-breaks.
)

REM as far as I can tell, the way boot works on Debian means that initramfs
REM ends up running whatever command is put in the cmdline.txt as the `init=`
REM value. On a fresh install, this is set to:
REM init=/usr/lib/raspberrypi-sys-mods/firstboot 
REM
REM We replace the `init=` value with a command that mounts the boot partition
REM and executes the sl-firstboot-init script. It adds ` -- ` and the original
REM `init=` value after this command. The sl-firstboot-init script removes everything
REM after `init=` up to and including ` -- ` to revert it to the original value.
REm it then reboots so the original `init=` command is run.

REM If there is no `init=` value, it adds the same command but does not add
REM ` -- ` behind it. In that case the sl-firstboot-init script will remove the
REM entire `init=` setting.

REM ***NOTES***
REM The `init=` value CANNOT contain a dot ('.') or an equals sign ('=') as this
REM will prevent the command from being executed as expected.
SET sWantedInit=/bin/bash -c "cd /boot;[ -d firmware ]&&cd firmware;mount $(pwd); $(pwd)/sl-firstboot-init; umount $(pwd); reboot -f"

IF NOT EXIST "%~2" (
  ECHO [1;31mX[0m Cannot find "%~2".
  EXIT /B 1
)
IF EXIST "%~d1\cmdline.txt" GOTO :lStart_CmdLineUpdate
IF NOT EXIST "%~d1" (
  ECHO [1;31mX[0m The %~d1 drive does not exist.
) ELSE (
  ECHO [1;31mX[0m The file %~d1\cmdline.txt does not exist.
)
ECHO   This script can only modify a Raspberry Pi OS boot partition and %~d1
ECHO   does not appear to contain one.
EXIT /B 1

:lStart_CmdLineUpdate
FINDSTR /C:" init=!sWantedInit:"=\"!" "%~d1\cmdline.txt" >NUL
IF NOT ERRORLEVEL 1 (
  ECHO [1;32m+[0m %~d1\cmdline.txt already has the correct "init=" value.
  GOTO :lEnd_CmdLineUpdate
)

FOR /F "tokens=*" %%I IN (%~d1\cmdline.txt) DO (
  REM The contents of the file are space separated value. We want to look 
  REM through them to find the `init=` value and insert some code. To do this
  REM we convert the line that has the contents into a list of arguments passed
  REM to a function, so the function can go through its arguments to find the
  REM `init=` value and replace it, then write the new contents to disk.
  SET sLine=%%I
  REM Double all quotes to escape them:
  SET sLine=!sLine:"=""!
  REM Wrap all space-separated values in quotes by adding a quote to the front
  REM and back of the line, and around each space:
  SET sLine="!sLine: =" "!"
  REM Now we can pass the line as arguments to the function:
  ECHO + Configuring cmdline.txt to run sl-firstboot...
  CALL :fCreateNewCmdLine !sLine!
  ECHO !sNewCmdLine! > "%~d1\cmdline.txt"
  GOTO :lEnd_CmdLineUpdate
)
ECHO [1;31mX[0m The file %~d1\cmdline.txt appears to be empty.
EXIT /B 1

:fCreateNewCmdLine
  SET sNewCmdLine=
  SEt bInitAdded=false
:lLoop_CreateNewCmdLine
  SET sComponent=%~1
  IF "!sComponent!" == "" (
    if "!bInitAdded!" == "false" (
      SET sNewCmdLine=!sNewCmdLine! init=!sWantedInit!
      ECHO   [32m+ init=!sWantedInit![0m
      SET bInitAdded=true
    )
    EXIT /B 0
  ) ELSE IF "!sComponent:~0,5!" == "init=" (
    REM We insert ourselves into the init= value, if we encounter another
    REM word that start with init=, we do not touch it:
    IF "!bInitAdded!" == "true" (
      ECHO     !sComponent!
      SET sNewCmdLine=!sNewCmdLine! !sComponent!
    ) ELSE (
      SET sNewCmdLine=!sNewCmdLine! init=!sWantedInit! -- !sComponent:~5!
      ECHO   [31m- !sComponent![0m
      ECHO   [32m+ init=!sWantedInit! -- !sComponent:~5![0m
      SET bInitAdded=true
    )
  ) ELSE IF "!sComponent!" == "quiet" (
    REM We'll remove `quiet` from the cmdline.txt file so we can see more status.
    ECHO   [31m- !sComponent![0m
  ) ELSE (
    ECHO     !sComponent!
    SET sNewCmdLine=!sNewCmdLine! !sComponent!
  )
  SHIFT /1
  GOTO :lLoop_CreateNewCmdLine

:lEnd_CmdLineUpdate

CALL :fCopy "%~dp0sl-firstboot-init" "%~d1\sl-firstboot-init"
IF ERRORLEVEL 1 EXIT /B 1

CALL :fCopy "%~f2" "%~d1\sl-firstboot-payload"
IF ERRORLEVEL 1 EXIT /B 1

EXIT /B 0

:fCopy
!sCopyCommand! "%~1" "%~2" >NUL 2>&1
IF ERRORLEVEL 1 (
  ECHO [1;31mX[0m Failed to copy "%~1" to "%~2".
  EXIT /B 1
)
ECHO [1;32m+[0m Copied "%~1" to "%~2".
EXIT /B 0
