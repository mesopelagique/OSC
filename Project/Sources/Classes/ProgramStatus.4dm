/* Reports what the program is doing to the terminal, with the Program Status Protocol (OSC 7501).

Specification: https://www.superlogical.com/rex/docs/build/program-status (revision 0.4)

Each report replaces its record, so `app` and `title` are sent again in every report.
Functions return True if the report was written, and never throw: reporting a status must not
break the program. Reports the protocol would ignore (unknown state, invalid id) are not written.
*/

property app : Text
property id : Text
property title : Text
property output : cs.Emitter

Class constructor($app : Text; $id : Text)

	This.app:=$app
	This.id:=$id
	This.title:=""
	This.output:=cs.Emitter.new()

	// At rest, waiting for the next instruction. Also the state to report when the user cancels.
Function idle($msg : Text) : Boolean

	return This.report({state: "idle"; msg: $msg})

	// Running. Without $progress (0 to 100) the terminal shows it as indeterminate.
Function working($msg : Text; $progress : Integer) : Boolean

	var $record : Object:={state: "working"; msg: $msg}
	If (Count parameters>=2)
		$record.progress:=$progress
	End if
	return This.report($record)

	// Cannot continue until the user acts. $kind: "permission", "question" or "auth".
Function blocked($msg : Text; $kind : Text; $progress : Integer) : Boolean

	var $record : Object:={state: "blocked"; msg: $msg; kind: $kind}
	If (Count parameters>=3)
		$record.progress:=$progress
	End if
	return This.report($record)

	// Finished, and the result is ready. Stays after the process exits.
Function done($msg : Text) : Boolean

	return This.report({state: "done"; msg: $msg})

	// Failed and stopped. Stays after the process exits.
Function error($msg : Text) : Boolean

	return This.report({state: "error"; msg: $msg})

	// Removes this record and those beneath it. WITHOUT AN ID, THIS REMOVES EVERY RECORD OF THE TERMINAL.
Function clear() : Boolean

	return This.report({state: "clear"})

	// A status for one part of the work, such as a region of a deployment.
Function child($segment : Text) : cs.ProgramStatus

	var $child : cs.ProgramStatus:=cs.ProgramStatus.new(This.app; (Length(This.id)>0) ? (This.id+"/"+$segment) : $segment)
	$child.output:=This.output
	return $child

	// Writes a report. $record: state, and optionally msg, kind, progress, id, app, title.
	// id, app and title default to the properties of this object.
Function report($record : Object) : Boolean

	var $payload : Text:=This.payload($record)
	If (Length($payload)=0)
		return False
	End if

	var $importance : Integer
	Case of
		: ($record.state="error")
			$importance:=Error message
		: ($record.state="blocked")
			$importance:=Warning message
		Else
			$importance:=Information message
	End case
	return This.output.send("7501"; $payload; $importance)

	// The body of the report, or an empty text if the protocol would ignore it.
Function payload($record : Object) : Text

	var $state : Text:=String($record.state)
	If (Not(Match regex("^(idle|working|done|blocked|error|clear)\\z"; $state; 1)))
		return ""
	End if

	var $pairs : Collection:=["state="+$state]

	var $id : Text:=($record.id#Null) ? String($record.id) : This.id
	If (Length($id)>0)
		If ((Length($id)>128) || Not(Match regex("^[A-Za-z0-9_.+-]{1,32}(/[A-Za-z0-9_.+-]{1,32}){0,7}\\z"; $id; 1)))
			return ""
		End if
		$pairs.push("id="+$id)
	End if

	If ($state="clear")
		return $pairs.join(":")
	End if

	var $kind : Text:=String($record.kind)
	If (($state="blocked") && Match regex("^(permission|question|auth)\\z"; $kind; 1))
		$pairs.push("kind="+$kind)
	End if

	var $app : Text:=($record.app#Null) ? String($record.app) : This.app
	If (Match regex("^[A-Za-z0-9_.+-]{1,32}\\z"; $app; 1))
		$pairs.push("app="+$app)
	End if

	var $title : Text:=This.output.clean(($record.title#Null) ? String($record.title) : This.title; 192)
	If (Length($title)>0)
		$pairs.push("title="+This.output.base64($title))
	End if

	If ((($state="working") | ($state="blocked")) && (Value type($record.progress)=Is real))
		var $percent : Real:=Round($record.progress; 0)
		$percent:=($percent<0) ? 0 : (($percent>100) ? 100 : $percent)
		$pairs.push("progress="+String($percent))
	End if

	var $msg : Text:=This.output.clean(String($record.msg); 2048)
	If (Length($msg)>0)
		$pairs.push("msg="+This.output.base64($msg))
	End if

	return $pairs.join(":")
