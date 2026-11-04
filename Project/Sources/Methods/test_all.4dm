//%attributes = {}
// Unit tests. tests/run.py runs this method and reads the summary it writes last.

var $check : cs._Check:=cs._Check.new()
var $status : cs.ProgramStatus
var $emitter : cs.Emitter:=cs.Emitter.new()
var $esc : Text:=Char(27)

// MARK: Examples of the specification

$status:=cs.ProgramStatus.new("terraform")
$check.equal($status.payload({state: "blocked"; kind: "permission"; msg: "Apply 3 to add, 1 to change, 0 to destroy?"}); \
"state=blocked:kind=permission:app=terraform:msg=QXBwbHkgMyB0byBhZGQsIDEgdG8gY2hhbmdlLCAwIHRvIGRlc3Ryb3k/"; "spec: blocked")

$status:=cs.ProgramStatus.new("brew")
$check.equal($status.payload({state: "working"; msg: "Installing updates"}); "state=working:app=brew:msg=SW5zdGFsbGluZyB1cGRhdGVz"; "spec: working")
$check.equal($status.payload({state: "done"; msg: "Upgraded 12 packages"}); "state=done:app=brew:msg=VXBncmFkZWQgMTIgcGFja2FnZXM="; "spec: done")

$status:=cs.ProgramStatus.new(""; "us-east")
$status.title:="US East"
$check.equal($status.payload({state: "working"; progress: 40; msg: "Pushing image"}); "state=working:id=us-east:title=VVMgRWFzdA==:progress=40:msg=UHVzaGluZyBpbWFnZQ=="; "spec: child")
$check.equal($status.payload({state: "clear"}); "state=clear:id=us-east"; "spec: clear child")

$check.equal($emitter.sequence("7501"; "state=idle"); $esc+"]7501;state=idle"+$esc+"\\"; "sequence framing")

// MARK: States and ids that the protocol would ignore

$status:=cs.ProgramStatus.new("app")
$check.equal($status.payload({state: "paused"}); ""; "unknown state")
$check.equal($status.payload({state: "WORKING"}); ""; "state is case sensitive")
$check.equal($status.payload({}); ""; "no state")
$check.isFalse($status.report({state: "paused"}); "report refuses an unknown state")

var $invalidIds : Collection:=["a b"; "a\n"; "a/"; "/a"; "a//b"; "é"; "a:b"; "a;b"; "1/2/3/4/5/6/7/8/9"; "x"*33; (("x"*32)+"/")*4+("x"*2)]
var $invalidId : Text
For each ($invalidId; $invalidIds)
	$check.equal($status.payload({state: "idle"; id: $invalidId}); ""; "invalid id: "+$invalidId)
End for each
$check.equal($status.payload({state: "clear"; id: "a b"}); ""; "clear never falls back to the root record")

$check.equal($status.payload({state: "idle"; id: "1/2/3/4/5/6/7/8"}); "state=idle:id=1/2/3/4/5/6/7/8:app=app"; "8 levels are allowed")
$check.equal($status.payload({state: "idle"; id: "x"*32}); "state=idle:id="+("x"*32)+":app=app"; "32 bytes per segment are allowed")

// MARK: Keys

$check.equal($status.payload({state: "blocked"; kind: "auth"}); "state=blocked:kind=auth:app=app"; "kind with blocked")
$check.equal($status.payload({state: "working"; kind: "auth"}); "state=working:app=app"; "kind only with blocked")
$check.equal($status.payload({state: "blocked"; kind: "other"}); "state=blocked:app=app"; "unknown kind is absent")

$check.equal($status.payload({state: "working"; progress: 0}); "state=working:app=app:progress=0"; "progress 0 is sent")
$check.equal($status.payload({state: "blocked"; progress: 50}); "state=blocked:app=app:progress=50"; "progress with blocked")
$check.equal($status.payload({state: "done"; progress: 50}); "state=done:app=app"; "no progress with done")
$check.equal($status.payload({state: "working"; progress: 150}); "state=working:app=app:progress=100"; "progress above 100")
$check.equal($status.payload({state: "working"; progress: -5}); "state=working:app=app:progress=0"; "progress below 0")
$check.equal($status.payload({state: "working"; progress: 33.6}); "state=working:app=app:progress=34"; "progress is rounded")
$check.equal($status.payload({state: "working"; progress: "40"}); "state=working:app=app"; "progress as text is absent")

$check.equal(cs.ProgramStatus.new("not valid").payload({state: "idle"}); "state=idle"; "invalid app is absent")
$check.equal(cs.ProgramStatus.new("x"*33).payload({state: "idle"}); "state=idle"; "app above 32 bytes is absent")
$check.equal($status.payload({state: "idle"; app: "other"; title: "T"; msg: "M"}); "state=idle:app=other:title=VA==:msg=TQ=="; "record overrides the properties")
$check.equal($status.payload({state: "idle"; msg: "@"}); "state=idle:app=app:msg=QA=="; "@ is not a wildcard")

// MARK: Free text

$check.equal($emitter.clean("one\r\ntwo\tthree"; 100); "one two three"; "control characters become one space")
$check.equal($emitter.clean("\nabc\n"; 100); "abc"; "no space at the ends")
$check.equal($emitter.clean("a"+$esc+"]0;x"+Char(7)+"b"; 100); "a ]0;x b"; "escape sequences are disarmed")
$check.equal($emitter.clean("a"+Char(0x009B)+"b"+Char(127)+"c"; 100); "a b c"; "C1 controls and DEL")
$check.equal($emitter.clean("héllo"; 3); "hé"; "cut before a character that does not fit")
$check.equal($emitter.clean("hé"; 2); "h"; "never cut a 2 byte character")
$check.equal($emitter.clean("a€"; 3); "a"; "never cut a 3 byte character")
var $emoji : Text:=Char(0xD83D)+Char(0xDE00)
$check.equal($emitter.clean("a"+$emoji; 5); "a"+$emoji; "4 byte character that fits")
$check.equal($emitter.clean("a"+$emoji; 4); "a"; "never cut a 4 byte character")
$check.equal($emitter.clean($emoji+$emoji; 1); ""; "never keep half of a surrogate pair")
$check.equal($emitter.base64("héllo wörld"); "aMOpbGxvIHfDtnJsZA=="; "base64 of UTF-8")

// Limits: a report above them is discarded whole by the terminal.
// 4D evaluates operators from left to right, without precedence: keep the parentheses.
var $longText : Text:="é"*3000
var $longId : Text:=((("y"*15)+"/")*7)+("y"*15)
var $longStatus : cs.ProgramStatus:=cs.ProgramStatus.new("x"*32; $longId)
$longStatus.title:=$longText
var $longPayload : Text:=$longStatus.payload({state: "blocked"; kind: "permission"; progress: 100; msg: $longText})
var $parts : Collection:=Split string($longPayload; ":")
$check.equal(String($parts.length); "7"; "every key of the longest report")
$check.equal(String(Length(String($parts.find(Formula($1.value="title=@"))))); String(Length("title=")+256); "title fills its 256 encoded bytes")
$check.equal(String(Length(String($parts.find(Formula($1.value="msg=@"))))); String(Length("msg=")+2732); "msg fills its 2732 encoded bytes")
var $longSequence : Text:=$emitter.sequence("7501"; $longPayload)
$check.isTrue(Length($longSequence)>3000; "the longest report is really long")
$check.isTrue(Length($longSequence)<=4096; "whole sequence below 4096 bytes")
$check.isTrue(Position("\n"; $longPayload)=0; "base64 stays on one line")

// MARK: Children

var $root : cs.ProgramStatus:=cs.ProgramStatus.new("deploy")
var $region : cs.ProgramStatus:=$root.child("eu-west")
var $task : cs.ProgramStatus:=$region.child("push")
$check.equal($region.payload({state: "idle"}); "state=idle:id=eu-west:app=deploy"; "child of the root")
$check.equal($task.payload({state: "idle"}); "state=idle:id=eu-west/push:app=deploy"; "child of a child")
$root.output.enabled:=False
$check.isFalse($task.done(); "children share the output of their parent")

// MARK: Convenience functions, with the output disabled so that nothing is written

$check.isFalse($root.idle(); "idle disabled")
$check.isFalse($root.working("x"; 10); "working disabled")
$check.isFalse($root.blocked("x"; "auth"; 10); "blocked disabled")
$check.isFalse($root.error("x"); "error disabled")
$check.isFalse($root.clear(); "clear disabled")

// MARK: Emitter

var $disabled : cs.Emitter:=cs.Emitter.new()
$disabled.enabled:=False
$check.isFalse($disabled.send("7501"; "state=idle"); "disabled emitter writes nothing")
$check.isFalse($emitter.send("7501"; "state=idle"+$esc+"]0;evil"); "send refuses ESC in the payload")
$check.isFalse($emitter.send("7501"; "state=idle"+Char(7)); "send refuses BEL in the payload")
$check.isFalse($emitter.send("7501"; "a"+Char(0x009C)); "send refuses C1 ST in the payload")
$check.isFalse($emitter.send("75;01"; "state=idle"); "send refuses a code that is not a number")

// MARK: Notification

var $notification : cs.Notification:=cs.Notification.new()
$check.equal($notification.payload("Build"; "It works; really"); "notify;Build;It works; really"; "777 keeps ; in the body")
$check.equal($notification.payload("a;b"; "c"); "notify;a,b;c"; "777 removes ; from the title")
$check.equal($notification.payload("Line\none"; "a"+$esc+"b"); "notify;Line one;a b"; "777 removes control characters")
$check.equal($notification.payload(""; ""); ""; "nothing to send")
$check.isFalse($notification.show(""; ""); "show refuses an empty notification")

$notification:=cs.Notification.new("9")
$check.equal($notification.payload("Build"; "done"); "Build: done"; "9 with title and body")
$check.equal($notification.payload(""; "done"); "done"; "9 with body only")
$check.equal($notification.payload("Build"; ""); "Build"; "9 with title only")
$check.equal($notification.payload(""; "4;1;50"); " 4;1;50"; "9 never turns into a progress sequence")

$check.equal(cs.Notification.new("99").payload("a"; "b"); ""; "unknown protocol")
$check.isFalse(cs.Notification.new("99").show("a"; "b"); "show refuses an unknown protocol")

// MARK: Summary

LOG EVENT(Into system standard outputs; "osc-tests: "+String($check.passed)+" passed, "+String($check.failed)+" failed\n"; Information message)
