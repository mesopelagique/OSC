# ProgramStatus

Reports what the program is doing to the terminal, with the
[Program Status Protocol (OSC 7501)](https://www.superlogical.com/rex/docs/build/program-status).

```4d
var $status : cs.osc.ProgramStatus:=cs.osc.ProgramStatus.new("build")
$status.working("Compiling"; 40)
$status.done("Built")
```

## Constructor

`cs.osc.ProgramStatus.new({app : Text {; id : Text}})`

| Parameter | Description |
|---|---|
| `app` | Stable identifier of the program, such as `build`: 1 to 32 of `A-Z a-z 0-9 _ . + -`. Otherwise it is not sent. |
| `id` | Record to report on, such as `deploy/us-east`. Empty for the root record. |

## Properties

| Property | Type | Description |
|---|---|---|
| `app` | Text | Sent in every report. |
| `id` | Text | Sent in every report. |
| `title` | Text | Short label, sent in every report. Cut to 192 bytes in UTF-8. |
| `output` | `cs.Emitter` | What writes the reports. Set `output.enabled` to `False` to write nothing. |

## Functions

All of them return `True` if the report was written. `msg` is optional, and is cut to 2048 bytes in UTF-8.

| Function | State | Lifetime in the terminal |
|---|---|---|
| `.idle({msg})` | At rest, waiting for an instruction. Report it when the user cancels. | Until replaced |
| `.working({msg {; progress}})` | Running. `progress`: 0 to 100, indeterminate without it. | Until the process exits or the next shell prompt |
| `.blocked({msg {; kind {; progress}}})` | Waiting for the user. `kind`: `permission`, `question` or `auth`. | Same as `working` |
| `.done({msg})` | Finished, the result is ready. | Stays after the process exits |
| `.error({msg})` | Failed and stopped. | Stays after the process exits |
| `.clear()` | Removes the record and those beneath it. **Without an id, removes every record of the terminal.** | |

`.child(segment : Text) : cs.ProgramStatus` returns a status for one part of the work. Its id is the id of its parent
followed by `/segment`, and it shares the `app` and the `output` of its parent.

`.report(record : Object) : Boolean` writes a report from an object with `state`, and optionally `msg`, `kind`, `progress`,
`id`, `app` and `title`. The last three default to the properties.

`.payload(record : Object) : Text` returns the body of that report without writing it, or an empty text if
the protocol would ignore it.

## Rules applied to a report

| Input | Result |
|---|---|
| Unknown `state` | Nothing is written |
| Invalid `id` (characters, 32 bytes per segment, 8 levels, 128 bytes) | Nothing is written: it must not overwrite the root record |
| Invalid `app` | `app` is not sent |
| `kind` not known, or state other than `blocked` | `kind` is not sent |
| `progress` not a number, or state other than `working` and `blocked` | `progress` is not sent |
| `progress` out of range or decimal | Limited to 0 to 100, and rounded |
| Line endings and control characters in `msg` or `title` | Replaced by one space |

`error` is written with `Error message`, so to stderr. `blocked` is written with `Warning message`, and the others with
`Information message`, so to stdout.
