on run
	set extensionPath to (POSIX path of (path to home folder)) & ".ubo/ublock0.chromium"
	set mv2Flags to "--disable-features=ExtensionManifestV2Unsupported,ExtensionManifestV2Disabled"
	set loadFlag to ""

	-- Check if extension directory exists
	try
		do shell script "test -d " & quoted form of extensionPath
		set loadFlag to " --load-extension=" & quoted form of extensionPath
	end try

	-- Check if Chrome is already running
	set chromeRunning to false
	try
		tell application "System Events"
			set chromeRunning to (exists (processes where name is "Google Chrome"))
		end tell
	end try

	if chromeRunning then
		-- Check if Chrome was already launched with MV2 flags
		set hasFlags to false
		try
			set hasFlags to (do shell script "ps aux | grep -v grep | grep 'Google Chrome' | grep -c 'ExtensionManifestV2Unsupported' || true") is not "0"
		end try

		if hasFlags then
			-- Chrome is already running with the right flags, just bring it to front
			tell application "Google Chrome" to activate
		else
			-- Chrome is running without flags, need to restart
			display dialog "Chrome is running without uBlock Origin." & return & return & "Quit Chrome and relaunch with uBlock Origin?" buttons {"Cancel", "Quit & Relaunch"} default button "Quit & Relaunch" with icon caution
			if button returned of result is "Quit & Relaunch" then
				tell application "Google Chrome" to quit
				delay 2
				repeat
					try
						tell application "System Events"
							set stillRunning to (exists (processes where name is "Google Chrome"))
						end tell
					on error
						set stillRunning to false
					end try
					if not stillRunning then exit repeat
					delay 0.5
				end repeat
				do shell script "open -a '/Applications/Google Chrome.app' --args " & mv2Flags & loadFlag
			end if
		end if
	else
		do shell script "open -a '/Applications/Google Chrome.app' --args " & mv2Flags & loadFlag
	end if
end run
