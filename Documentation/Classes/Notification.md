# Notification

Sends a one-time desktop notification. Terminals support OSC 777, OSC 9, both or neither, and ignore the
sequences they do not know.

```4d
cs.osc.Notification.new().show("Build"; "Finished")
```

## Constructor

`cs.osc.Notification.new({protocol : Text})`

| `protocol` | Sequence written |
|---|---|
| `"777"` (default) | `OSC 777 ; notify ; title ; body ST` |
| `"9"` | `OSC 9 ; title: body ST` |

## Properties

| Property | Type | Description |
|---|---|---|
| `protocol` | Text | `"777"` or `"9"`. |
| `output` | `cs.Emitter` | What writes the sequences. |

## Functions

`.show(title : Text {; body : Text}) : Boolean` writes the notification, and returns `True` if it was written.

`.payload(title : Text {; body : Text}) : Text` returns the body of the sequence without writing it.

The title is cut to 256 bytes in UTF-8 and the body to 1024. Control characters become one space. With OSC 777, a `;` in
the title becomes `,`. With OSC 9, a text that starts with a number and `;` gets a leading space, so that terminals
do not read `4;...` as the OSC 9;4 progress sequence.
