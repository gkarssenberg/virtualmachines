::This file does the initial configuration of the AWS instance; things that you only want to do once, like name the computer.
::Assuming that a T3.large is being used. Provide at least 70GB of storage.
::Download and run this from the (elevated?) command line (Win+R, CMD) by using the following command without the <script> start/end:
::OR use User Data when creating the EC2 instance. Past in the following script, and replace "password fmelicenseip fmeserverserial" with the correct things:
:: <script>powershell -Command "Invoke-WebRequest https://raw.githubusercontent.com/rjcragg/AWS/master/InitialConfiguration.bat -OutFile InitialConfiguration.bat" && InitialConfiguration.bat password fmelicenseip fmeserverserial</script>

:main
	::::GENERAL SETTINGS FOR LATER IN BATCH FILE, and run procedures::::

		set EC2PASSWORD=%1
		::"Pacific Standard Time"
		set TimeZone="Pacific Standard Time"
		::https://raw.githubusercontent.com/rjcragg/AWS/master/OnstartConfiguration.bat
		set OnstartConfigurationURL=https://raw.githubusercontent.com/rjcragg/AWS/master/OnstartConfiguration.bat

		set FMEDownloadInstall=https://raw.githubusercontent.com/rjcragg/AWS/master/FMEInstalls/FMEDownloadInstall.bat
		set PORTFORWARDING=81;82;443;8080;8081
		set Oracle64InstantClient=https://s3.amazonaws.com/FMETraining/instantclient-basiclite-windows.x64-12.1.0.2.0.zip
		set NEWCOMPUTERNAME=FMETraining
		set TEMP=c:\temp
		set LOG=%TEMP%\InitialConfiguration.log

	::Make required folders and get into it
		md %TEMP%
		pushd %TEMP%

	:::::::::::::::::Here are the procedure calls:::::::::::::::::
	:: Start Logging, and call sub routines for configuring the computer
	::basicSetup sets things like license files. Always necessary
		call :basicSetup > %LOG%
	::ec2Setup sets things like computer password, timezone, etc.  Not necessary for non-ec2 training machines
		call :ec2Setup >> %LOG%
	::scheduleTasks sets up shutdown scripts, and additional startup tasks. Not neccessary for non-ec2 training machines
		call :scheduleTasks >> %LOG%
	::helpfulApps are applications that are helpful. Always necessary
		call :helpfulApps >> %LOG%
	::installFME installs FME 32 and 64 bit, and FME Server
		call :installFME >> %LOG%
	::oracle installs 32-bit and 64-bit Oracle Instant Clients
		call :oracle >> %LOG%
	::second run at Chocolatey; install all the other apps
		call :choco >> %LOG%
	::shut down the computer
		call :shutdown >> %LOG%
goto :eof

:::::::::::::::::Everything below here are sub routines:::::::::::::::::
:basicSetup
		echo "Starting Downloading, Installing, and Configuring"
	:: Log that variables are set correctly
		echo "Variables are set to:"
		set
	::We should make sure port 80 is open too, for FME Server. This might be unnecessary
		netsh firewall add portopening TCP 80 "FME Server"
	::We should make sure port 25 is open too, for FME Server. Necessary for SMTP forwarding
		netsh firewall add portopening TCP 25 "SMTP"
	::We also need to open the port for UltraVNC. The installer fails to do that
		netsh firewall add portopening TCP 5900 "VNC"
		netsh firewall add portopening TCP 5800 "VNC"
	::FME Server needs port 7078 opened for web sockets
		netsh firewall add portopening TCP 7078 "WebSockets"
	::Windows 2016 Server has stricter security settings that can block our RDP file from connecting. We can fix this with the following
		reg add "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" /v SecurityLayer /t REG_DWORD /d 0 /f
goto :eof

:ec2Setup
	::::CONFIGURE WINDOWS SETTINGS::::
	:: Set the time zone
		tzutil /s %TimeZone%
	:: The purpose of this section is to configure proxy ports for Remote Desktop
	:: It must be run with elevated permissions (right-click and run as administrator)
	:: The batch file assumes the computer name will not change.
	:: Be sure to also open the listed ports in the EC2 security group
	:: The ports to be set are in PORTFORWARDING:
	:: First, we reset the existing proxy ports.
		netsh interface portproxy reset
	:: Now we set the proxy ports and add them to the firewall
		for %%f IN (%PORTFORWARDING%) DO (
			netsh interface portproxy add v4tov4 listenport=%%f connectport=3389 connectaddress=%NEWCOMPUTERNAME%
			netsh firewall add portopening TCP %%f "Remote Desktop Port Proxy"
		)
	::Set Computer Name. This will require a reboot. Reboot is at the end of this batch file.
		wmic computersystem where name="%COMPUTERNAME%" call rename name="%NEWCOMPUTERNAME%"
	::Set Password for Administrator. I hate password complexity requiremens, but they can't be changed from the command line.
		net user Administrator %EC2PASSWORD%
	::Make sure password does not expire.
		WMIC USERACCOUNT WHERE "Name='administrator'" SET PasswordExpires=FALSE
goto :eof

:scheduleTasks
	::This section sets OnstartConfiguration.bat to run at ONSTART.
	schtasks /Create /F /RU SYSTEM /TN OnstartConfiguration /SC ONSTART /TR "cmd.exe /C aria2c.exe %OnstartConfigurationURL% --dir=/temp --allow-overwrite=true && c:\temp\OnstartConfiguration.bat"
goto :eof

:helpfulApps
	::::INSTALL SOFTWARE::::
	::Install Chocolatey  https://chocolatey.org/
		@powershell -NoProfile -ExecutionPolicy Bypass -Command "iex ((new-object net.webclient).DownloadString('https://chocolatey.org/install.ps1'))" && SET PATH=%PATH%;%ALLUSERSPROFILE%\chocolatey\bin
		::Some choco installs fail. Just get the absolute essentials now. The rest are added in the choco section
		choco install aria2 7zip -y
goto :eof

:installFME
	::Download the installer bat file and execute it. This requires the FMELICENSEIP and FMESERVERSERIAL environment variables
	aria2c %FMEDownloadInstall% --out=FMEDownloadInstall.bat --allow-overwrite=true
	CALL FMEDownloadInstall.bat
goto :eof

:oracle
	::Install the 64 bit Oracle Instant Clients
		aria2c %Oracle64InstantClient% --out=Oracle64InstantClient.zip --allow-overwrite=true
		7z x -oc:\Oracle64InstantClient -aoa Oracle64InstantClient.zip
		setx /m PATH "%PATH%;c:\Oracle64InstantClient\instantclient_12_1"
goto :eof

:choco
	::Some additional packages to consider:
		::github webdeploy carbon iisexpress
	choco install notepadplusplus google-chrome-x64 firefox adobereader ultravnc googleearth windirstat git python eclipse postman openoffice -y
goto :eof

:shutdown
	::Shutdown the computer
		echo Finished the Initial Configuration
		echo Done! %date% %time%
		shutdown /s /t 1
goto :eof
