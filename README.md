# OSC

A 4D component to talk to the terminal with OSC escape sequences, written through
`LOG EVENT(Into system standard outputs; ...)`.

Its main class reports what your program is doing with the **Program Status Protocol, OSC 7501**:

- **Specification (revision 0.4): <https://www.superlogical.com/rex/docs/build/program-status>**
- Why it exists, by its author: <https://mitchellh.com/writing/program-status-osc7501>

A program says it is `working`, `blocked`, `done`, and so on, and the terminal shows that in its own
way, such as a spinner on the tab or a badge on the session. Terminals that do not know a sequence ignore it.

| Class | Sequence | Use it to |
|---|---|---|
| [`cs.osc.ProgramStatus`](Documentation/Classes/ProgramStatus.md) | OSC 7501 | Report the current state of the program |
| [`cs.osc.Notification`](Documentation/Classes/Notification.md) | OSC 777, OSC 9 | Send a one-time desktop notification |
| [`cs.osc.Emitter`](Documentation/Classes/Emitter.md) | any | Write any other OSC sequence |

## Report a status

```4d
var $status : cs.osc.ProgramStatus:=cs.osc.ProgramStatus.new("build")

$status.working("Compiling")           // no percentage: indeterminate
$status.working("Compiling"; 40)       // 40%
$status.blocked("Deploy to production?"; "permission")   // or "question", "auth"
$status.idle()                         // the user cancelled
$status.done("Built in 12 s")
$status.error("Compilation failed")
```

`$status.working("Compiling"; 40)` writes this, in which `msg` is base64:

```
ESC ] 7501 ; state=working:app=build:progress=40:msg=Q29tcGlsaW5n ESC \
```

Report `done` or `error` just before your program exits. Terminals drop `working` and `blocked` records
when the process exits, and keep `done` and `error` until the user has seen them.

### Several records

```4d
var $deploy : cs.osc.ProgramStatus:=cs.osc.ProgramStatus.new("deploy")
var $region : cs.osc.ProgramStatus:=$deploy.child("eu-west")
$region.title:="EU West"

$deploy.working("Deploying v2.4.1")
$region.working("Pushing image"; 40)
$region.clear()                        // removes this record and those beneath it
$deploy.done("Deployed")
```

`clear()` on an object without an id removes **every** record of the terminal, as the protocol specifies.

## Send a notification

```4d
cs.osc.Notification.new().show("Build"; "Finished")      // OSC 777: title and body
cs.osc.Notification.new("9").show("Build"; "Finished")   // OSC 9: one text, "Build: Finished"
```

Terminals support one, both or neither. Use a notification for an event, and `ProgramStatus` for a state:
the terminal keeps a state up to date, and forgets a notification once it is shown.

## Send another sequence

```4d
var $emitter : cs.osc.Emitter:=cs.osc.Emitter.new()
$emitter.send("2"; $emitter.clean("My window title"; 256))   // OSC 2: window title
```

## What the classes guarantee

- **Valid reports.** `msg` and `title` become one line without control characters, and are cut to the limits of the
  specification without splitting a character. Above these limits, a terminal discards the whole report.
- **`app` and `title` in every report**, because each report replaces its record completely.
- **Nothing that could break out of a sequence.** Escape characters in your text cannot reach the terminal.
- **No errors raised.** Functions return `True` if they wrote something. A report the protocol would ignore, such as
  one with an unknown state or an invalid id, is not written and returns `False`.

## Limits

- **4D cannot tell whether stdout is a terminal.** If your output goes to a log file, the sequences go there too.
  In that case, set `$status.output.enabled:=False`.
- **`error` goes to stderr**, because it uses `Error message`, and `blocked` uses `Warning message`, which goes to stdout.
  With `2>file`, the terminal does not receive `error` reports.
- **No feature detection.** 4D cannot read the terminal's reply to `OSC 7501 ; ?`. The specification allows
  this: a program that cannot read replies may send reports without asking.
- **tmux and screen** may not forward OSC 7501 to the outer terminal.

## Install

In `Project/Sources/dependencies.json`:

```json
{
	"dependencies": {
		"OSC": {
			"github": "mesopelagique/OSC"
		}
	}
}
```

This needs a published release of this repository.

## Try it and test it

```bash
# A fake build, to watch in a terminal that supports OSC 7501
tool4d --project=Project/OSC.4DProject --startup-method=demo --skip-onstartup --dataless

# The tests: finds tool4d through 4D-Analyzer, or pass its path, or set TOOL4D
python3 tests/run.py
```

`tests/run.py` runs the unit tests of `test_all`, then decodes what really leaves the process: stdout and stderr
apart, then both on a pty.

## License

[MIT](LICENSE)
