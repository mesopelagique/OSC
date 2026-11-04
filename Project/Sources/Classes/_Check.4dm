/* Counts test results, and writes failures to stderr. Used by test_all. */

property passed : Integer
property failed : Integer

Class constructor()

	This.passed:=0
	This.failed:=0

	// Exact comparison: the = operator ignores case and treats @ as a wildcard.
Function equal($actual : Text; $expected : Text; $label : Text)

	If (Compare strings($actual; $expected; sk char codes)=0)
		This.passed+=1
	Else
		This.failed+=1
		LOG EVENT(Into system standard outputs; "FAIL "+$label+"\n  actual:   "+$actual+"\n  expected: "+$expected+"\n"; Error message)
	End if

Function isTrue($value : Boolean; $label : Text)

	This.equal(String($value); String(True); $label)

Function isFalse($value : Boolean; $label : Text)

	This.equal(String($value); String(False); $label)
