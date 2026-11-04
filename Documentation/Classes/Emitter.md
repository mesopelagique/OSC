# Emitter

Writes OSC sequences to the terminal attached to the process, with
`LOG EVENT(Into system standard outputs; ...)`. `ProgramStatus` and `Notification` are built on it.

```4d
var $emitter : cs.osc.Emitter:=cs.osc.Emitter.new()
$emitter.send("2"; $emitter.clean("My window title"; 256))
```

## Properties

| Property | Type | Description |
|---|---|---|
| `enabled` | Boolean | `True` by default. 4D cannot tell whether stdout is a terminal: set it to `False` when the output goes to a log file. |

## Functions

`.send(code : Text; payload : Text {; importance : Integer}) : Boolean` writes `ESC ] code ; payload ESC \`, and returns `True`
if it was written. `Information message` (default) and `Warning message` go to stdout, and `Error message` goes to stderr. It
writes nothing if `code` is not a number, or if `payload` contains a control character.

`.sequence(code : Text; payload : Text) : Text` returns the sequence without writing it or checking it.

`.clean(text : Text; maxBytes : Integer) : Text` returns the text on one line, without control characters, and at most
`maxBytes` long in UTF-8. Control characters become one space, and a character is never cut in half.

`.base64(text : Text) : Text` returns the standard base64 of the text in UTF-8.
