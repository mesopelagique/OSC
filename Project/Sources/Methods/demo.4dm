//%attributes = {}
// A fake build: run it from a terminal that supports OSC 7501, and watch its tab or status.
// tool4d --project=Project/OSC.4DProject --startup-method=demo --skip-onstartup --dataless

var $name : Text:="OSC demo"
var $status : cs.ProgramStatus:=cs.ProgramStatus.new("osc-demo")
var $percent : Integer

$status.title:=$name  // label of the record, sent with every report
$status.output.send("2"; $name)  // window title

For ($percent; 0; 100; 20)
	$status.working("Compiling"; $percent)
	DELAY PROCESS(Current process; 60)
End for

$status.blocked("Waiting for an imaginary approval"; "permission")
DELAY PROCESS(Current process; 180)

$status.done("Build finished")
cs.Notification.new().show($name; "Build finished")
