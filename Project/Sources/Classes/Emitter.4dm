/* Writes OSC (Operating System Command) sequences to the terminal attached to the process.

LOG EVENT writes the bytes as UTF-8, unchanged and without a line ending, which is what an
escape sequence needs. 4D cannot tell whether stdout is a terminal, so set `enabled` to False
when the output goes to a log file.
*/

property enabled : Boolean

Class constructor()

	This.enabled:=True

	// Builds ESC ] code ; payload ST
Function sequence($code : Text; $payload : Text) : Text

	var $esc : Text:=Char(27)
	return $esc+"]"+$code+";"+$payload+$esc+"\\"

	// Writes a sequence, and returns True if it was written.
	// Information and Warning message go to stdout, Error message goes to stderr.
Function send($code : Text; $payload : Text; $importance : Integer) : Boolean

	If (Not(This.enabled))
		return False
	End if

	// A control character in the payload could end the sequence and write to the terminal.
	If (Not(Match regex("^[0-9]+\\z"; $code; 1)) || Match regex("[\\x00-\\x1F\\x7F-\\x9F]"; $payload; 1))
		return False
	End if

	LOG EVENT(Into system standard outputs; This.sequence($code; $payload); $importance)
	return True

	// Makes free text safe to send: one line, no control character, at most $maxBytes in UTF-8.
	// Control characters become a single space, and a character is never cut in half.
Function clean($text : Text; $maxBytes : Integer) : Text

	// A character takes at least one byte, so longer texts need not be scanned.
	var $window : Text:=Substring($text; 1; $maxBytes)
	var $result : Text
	var $pendingSpace : Boolean
	var $index; $code : Integer

	For ($index; 1; Length($window))
		$code:=Character code($window[[$index]])
		Case of
			: (($code<32) | (($code>=127) & ($code<=159)))
				$pendingSpace:=Length($result)>0
			: (($index=Length($window)) & ($code>=0xD800) & ($code<=0xDBFF))
				// The window ended inside a surrogate pair.
			Else
				$result+=($pendingSpace ? " " : "")+$window[[$index]]
				$pendingSpace:=False
		End case
	End for

	var $bytes : Blob
	CONVERT FROM TEXT($result; "UTF-8"; $bytes)
	If (BLOB size($bytes)<=$maxBytes)
		return $result
	End if

	// $bytes{$size} is the first byte removed: move back while it continues a character.
	var $size : Integer:=$maxBytes
	While (($size>0) && ($bytes{$size}>=0x0080) && ($bytes{$size}<0x00C0))
		$size-=1
	End while
	SET BLOB SIZE($bytes; $size)
	return Convert to text($bytes; "UTF-8")

	// Standard base64 of the text in UTF-8.
Function base64($text : Text) : Text

	var $bytes : Blob
	var $encoded : Text
	CONVERT FROM TEXT($text; "UTF-8"; $bytes)
	BASE64 ENCODE($bytes; $encoded)
	return $encoded
