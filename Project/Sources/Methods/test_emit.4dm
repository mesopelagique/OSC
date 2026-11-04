//%attributes = {}
// Writes a known list of reports. tests/run.py checks the bytes that reach stdout, stderr and a pty.

var $status : cs.ProgramStatus:=cs.ProgramStatus.new("build")

$status.working("Compiling héllo"; 40)
$status.blocked("Approve?"; "permission")
$status.error("It failed")
$status.done("Built")
$status.child("eu-west").working("Pushing")
$status.child("eu-west").clear()
$status.idle()

cs.Notification.new().show("Build"; "Done")
cs.Notification.new("9").show("Build"; "Done")
