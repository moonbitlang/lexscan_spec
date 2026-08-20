///|
pub const QUALIFIED_WORD = re"[A-Za-z]+"

///|
pub const QUALIFIED_ANCHORED_WORD = re"^[A-Za-z]+"

///|
pub const HIDDEN_NAMED_CAPTURE = re"(?<word>[a-z]+)"

///|
pub const HIDDEN_ANCHORED_NAMED_CAPTURE = re"^(?<word>[a-z]+)"

///|
pub const HIDDEN_ANONYMOUS_CAPTURE = re"(a|b)+"

///|
pub const HIDDEN_NON_GREEDY = re"^a*?"

///|
pub const HIDDEN_GREEDY_CAPTURE = re"(?<run>a+)"

///|
pub const HIDDEN_OPTIONAL_CAPTURE = re"^(?<item>a)?$"

///|
pub const HIDDEN_REPEATED_CAPTURE = re"^(?<item>a)+$"

///|
pub const QUALIFIED_CHAR = re"."

///|
pub const QUALIFIED_A = re"a"

///|
pub const QUALIFIED_B = re"b"

///|
pub const QUALIFIED_PAIR : Regex = QUALIFIED_A + QUALIFIED_B

///|
pub const QUALIFIED_EITHER : Regex = QUALIFIED_A | QUALIFIED_B
