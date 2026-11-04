/* Sends a one-time desktop notification, with OSC 777 (title and body) or OSC 9 (text only).

Terminals support one, both or neither, and ignore the sequences they do not know.
To report what the program is doing, use ProgramStatus: a terminal keeps that state up to date,
while a notification is forgotten once it is shown.
*/

property protocol : Text
property output : cs.Emitter

Class constructor($protocol : Text)

	This.protocol:=(Length($protocol)>0) ? $protocol : "777"
	This.output:=cs.Emitter.new()

	// Returns True if the notification was written.
Function show($title : Text; $body : Text) : Boolean

	var $payload : Text:=This.payload($title; $body)
	If (Length($payload)=0)
		return False
	End if
	return This.output.send(This.protocol; $payload)

	// The body of the sequence, or an empty text if there is nothing to send.
Function payload($title : Text; $body : Text) : Text

	// OSC 777 separates its fields with ";", so the title cannot contain one.
	var $cleanTitle : Text:=This.output.clean(Replace string($title; ";"; ","; *); 256)
	var $cleanBody : Text:=This.output.clean($body; 1024)

	If ((Length($cleanTitle)=0) && (Length($cleanBody)=0))
		return ""
	End if

	var $text : Text
	Case of
		: (This.protocol="777")
			return "notify;"+$cleanTitle+";"+$cleanBody

		: (This.protocol="9")
			$text:=$cleanTitle+(((Length($cleanTitle)>0) && (Length($cleanBody)>0)) ? ": " : "")+$cleanBody
			// OSC 9;4;... is the progress sequence: a leading space keeps this text a notification.
			return (Match regex("^[0-9]+;"; $text; 1) ? " " : "")+$text

		Else
			return ""
	End case
