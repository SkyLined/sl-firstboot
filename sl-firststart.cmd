@ECHO OFF
SETLOCAL ENABLEDELAYEDEXPANSION

IF "%~1" == "" (
  ECHO Usage:
  ECHO   %~n0.cmd ^<USB drive letter^> ^<path\to\payload\script^>
  ECHO.
  ECHO This script allows you to run the provided payload script after the first
  ECHO boot of a Raspberry Pi OS image.
  ECHO.
  ECHO It uses sl-firstboot to copy an initialization script ^(sl-firststart-init^)
  ECHO onto the boot partition of the USB drive. It then copies the provided
  ECHO payload script as well ^(as sl-firststart-payload^).
  ECHO.
  ECHO When the Raspberry Pi is first booted, sl-firstboot runs sl-firststart-init.
  ECHO When sl-firststart-init runs, it will:
  ECHO   1. move sl-firststart-payload from the boot partition to /usr/lib/
  ECHO   2. create a sl-firststart service,
  ECHO   3. enable the sl-firststart service,
  ECHO   4. disable the userconfig.service,
  ECHO   5. reboot the system.
  ECHO.
  ECHO After this first boot, all changes made to the boot partition by sl-firstboot
  ECHO will have been reverted. The root partition will have your payload script
  ECHO and the service added. The system will reboot and continue with booting
  ECHO normally. When the system has been booted and network connectivity is
  ECHO established, the sl-firststart service starts.
  ECHO The sl-firststart service will:
  ECHO   1. run /usr/lib/sl-firststart-payload,
  ECHO   2. if this fails, run /bin/bash and exit, otherwise
  ECHO   2. delete /usr/lib/sl-firststart-payload,
  ECHO   3. disable the sl-firststart service*.
  ECHO   4. delete the sl-firststart service.
  ECHO.
  ECHO If your payload script fails, the remaining steps are not executed.
  ECHO This means the payload script will continue to be run every time the
  ECHO system boots. Once the payload script succeeds, the service and script
  ECHO are removed and will no longer be executed on start up.
  ECHO.
  ECHO *Note: the userconfig.service is disabled as this this the normal first start
  ECHO script for Raspbian OS ^(which asks you to provide a username and password^).
  ECHO The payload script run through sl-firststart is expected to replace this script.
  EXIT /B 0
)
WHERE dos2unix >NUL 2>&1
IF ERRORLEVEL 1 (
  SET sCopyCommand=COPY /V /Y /L
  REM No warning here; sl-firstboot will do that.
) ELSE (
  SET sCopyCommand=dos2unix -e -n
)

IF NOT EXIST "%~2" (
  ECHO [1;31m- Cannot find "%~2".[0m
  EXIT /B 1
)

CALL "%~dp0sl-firstboot.cmd" "%~d1" "%~dp0sl-firststart-init"
IF ERRORLEVEL 1 EXIT /B 1

CALL :fCopy "%~2" "%~d1\sl-firststart-payload"
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
