@echo off




rem Script zum Synchronisieren von Daten per Microsoft SyncToy;
rem Zur Verwendung mit dem Windows Taskplaner;
rem
rem Script startet alle mit MS SyncToy erstellten Sync Jobs.
rem Bitte als Administrator ausfuehren!
rem
rem Verbindung zu Laufwerk W: wird vorausgesetzt!
rem
rem Speedpoint nG GmbH (FW); Stand: April 2013




rem ###########################################################################
rem Bitte anpassen ############################################################
rem ###########################################################################

rem Pfad und Name zur Logdatei (wird an DV Backup Logdatei angehaengt):
rem ACHTUNG: Dateinamen mit dem Backup Script des DV Servers abgleichen!
set logfile=W:\DMPPABackupLog.txt

rem Ist DMP-Assist 5 vorhanden (0 oder 1)?
set dmp5=1

rem Pfad zu DMP-Assist 5, falls vorhanden:
set dmp5pfad=C:\CGM\DMP-Assist

rem Ist PraxisArchiv vorhanden (0 oder 1)?
set pa=1

rem Pfad zu PraxisArchiv:
set papfad=C:\CGM\PraxisArchiv

rem Pfad zu MS SyncToy:
set stpfad="C:\Program Files\SyncToy 2.1"

rem IP Adresse des DATA VITAL Servers (Zielpfade fuer SyncToy):
set dvserver=192.168.0.1

rem Soll dieser Windows PC nach der Sicherung herunterfahren (0 oder 1)?
set shutdown=0

rem Haltepunkte zwecks Debugging aktivieren (0 oder 1)?
set debug=0

rem ###########################################################################
rem Ende der Anpassungen ######################################################
rem ###########################################################################








echo. >> %logfile%
echo ### Backup Start: %date:~0% - %time:~0,8% Uhr >> %logfile%

REM Pruefung ob DMP-Sicherung und PA-Sicherung ausgeschaltet (falsche Einstellung)
if "%dmp5%" == "1" goto PRF
if "%pa%" == "1" goto PRF
echo DMP und Praxisarchiv nicht eingestellt. Abbruch >> %logfile% && GOTO FERTIG

:PRF
rem Pruefungen ob Linuxserver erreichbar u. Synctoy installiert bzw. Pfad ok:
echo Pruefungen auf Linuxserver u. SyncToy laufen...
echo.
ping -n 5 %dvserver% >nul || echo ABBRUCH: DATA VITAL Server unter %dvserver% nicht erreichbar. >> %logfile% && GOTO FERTIG 
IF NOT EXIST %stpfad%\SyncToyCMD.exe echo ABBRUCH: MS SyncToy nicht gefunden. >> %logfile% && GOTO FERTIG

IF "%dmp5%" == "0" GOTO PACHECK
IF NOT EXIST %dmp5pfad%\addon echo ABBRUCH: Keine DMP Daten in %dmp5pfad% gefunden. >> %logfile% && GOTO FERTIG
echo DMP Dienste anhalten...
net stop DMPBackupDaemon >> %logfile% 2>&1
taskkill /f /im "DerbyService.exe" >> %logfile% 2>&1
echo Backup vorbereiten...
IF "%debug%" == "1" pause

:PACHECK
IF "%pa%" == "0" GOTO BACKUP
IF NOT EXIST %papfad%\Data echo ABBRUCH: Data Verzeichnis nicht in %papfad% gefunden. >> %logfile% && GOTO FERTIG
echo Brennmodul anhalten...
tasklist | find /i "CDRecNG.exe" && taskkill /f /im CDRecNG.exe >> %logfile% 2>&1
echo.
echo "PA Serverdienste anhalten..."
echo.
start /B /D "%papfad%\Backup" SrvLock.exe || echo Fehler: SrvLock.exe >> %logfile%
IF "%debug%" == "1" pause

:BACKUP
echo Netzlaufwerk auf %dvserver% wird verbunden. >> %logfile%
net use W: /delete /yes >nul
net use W: \\%dvserver%\Word /persistent:yes >> %logfile% 2>&1
ping -n 3 127.0.0.1 >nul
dir W: >nul
echo cls
IF "%debug%" == "1" pause
@cls
echo.
echo SyncToy Start: %time:~0,8% Uhr >> %logfile%
start /B /D %stpfad% /wait SyncToyCmd -R || set syncfail=1
IF "%syncfail%" == "1" echo !!! FEHLER bei SyncToy Ausfuehrung !!! >> %logfile%
echo Fuer Details zu SyncToy bitte dessen Log beachten! >> %logfile%
@cls
echo.
echo SyncToy Ende : %time:~0,8% Uhr >> %logfile%
echo. >> %logfile%
IF "%shutdown%" == "1" GOTO DOWN
IF "%debug%" == "1" pause
GOTO WEITER1


:DOWN
echo.
echo PA Serverdienste starten...
start /B /D "%papfad%\Backup" SrvUnlock.exe || echo Fehler: SrvUnlock.exe >> %logfile%
tasklist | find /i "CDRecNG.exe" >nul && echo LZ-Archivierung erfolgreich gestartet. >> %logfile% 
echo.
echo Herunterfahren...
IF "%debug%" == "1" pause
shutdown /s /f /t 10 /c "Have a nice day!"
exit


:WEITER1
IF "%pa%" == "0" GOTO :DMPSTART
echo.
echo PA Serverdienste starten...
start /B /D "%papfad%\Backup" SrvUnlock.exe || echo Fehler: SrvUnlock.exe >> %logfile%
rem ***** echo Langzeitarchivierung starten...
rem ***** ping -n 3 127.0.0.1 >nul
rem ***** start /MIN /D "%papfad%\Common\CDRec" CDRecNG.exe || echo Fehler beim Start der LZ-Archivierung! >> %logfile%
tasklist | find /i "CDRecNG.exe" >nul && echo LZ-Archivierung erfolgreich gestartet. >> %logfile% 
IF "%debug%" == "1" pause


:DMPSTART
IF "%dmp5%" == "0" GOTO FERTIG
echo.
echo DMP Dienste starten...
ping -n 5 127.0.0.1 >nul
rem net start DmpBackupDaemon || set fail1=1
start /B /D "%dmp5pfad%\Tools" DerbyService.exe || set fail2=1 
ping -n 10 127.0.0.1 >nul
IF "%fail1%" == "1" GOTO DMPFAIL
IF "%fail2%" == "1" GOTO DMPFAIL
echo DMP Dienste erfolgreich gestartet. >> %logfile%
GOTO FERTIG


:DMPFAIL
echo Fehler beim Start der DMP Dienste! >> %logfile%
GOTO FERTIG


:FERTIG
IF "%debug%" == "1" pause
cls
echo.
echo Vorgang abeschlossen, Details siehe %logfile%.
echo.
echo ### Backup Ende: %date:~0% - %time:~0,8% Uhr >> %logfile%
echo ------------------------------------------------------------- >> %logfile%
ping -n 5 127.0.0.1 >nul
IF "%debug%" == "1" pause


exit
