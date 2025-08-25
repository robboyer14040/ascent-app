global theSender, theBody, theAttachment, theSubject



on send_activity(filePath, subject)
	tell application "Finder"
		set theAttachment to filePath
		set theSubject to subject
		(*set theSubject to name of oneFile*)
		--preceding code disabled for filevault compatibility.
	end tell
	makeMessage()
end send_activity

on getAccounts()
	tell application "Mail"
		set listOfSenders to {}
		set everyAccount to every account
		repeat with eachAccount in everyAccount
			set everyEmailAddress to email addresses of eachAccount
			if (everyEmailAddress is not equal to missing value) then
				repeat with eachEmailAddress in everyEmailAddress
					set listOfSenders to listOfSenders & {(full name of eachAccount & " <" & eachEmailAddress & ">") as string}
				end repeat
			end if
		end repeat
	end tell
	-- Prompt the user to select which account to send this message from.
	set theResult to choose from list listOfSenders with prompt Â
		"Which account would you like to send this message from?" without multiple selections allowed
	if theResult is not equal to false then
		set theSender to item 1 of theResult
	end if
end getAccounts

on makeMessage()
	--previous line added for Filevault compatibility.
	set theBody to "Activity Attached:"
	tell application "Mail"
		set newMessage to make new outgoing message with properties {subject:theSubject, content:theBody & return & return}
		tell newMessage
			set visible to true
			(* set sender to theSender *)
			tell content
				make new attachment with properties {file name:theAttachment} at after the last paragraph
			end tell
		end tell
		activate
	end tell
end makeMessage