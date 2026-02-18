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
		-- Chrome is already running, just bring it to front
		tell application "Google Chrome" to activate
	else
		do shell script "open -a '/Applications/Google Chrome.app' --args " & mv2Flags & loadFlag
	end if
end run
