///|
/// Offsets are UTF-16 indices for hex text and byte offsets for binary input.
pub(all) struct Diagnostic {
  offset : Int
  code : String
  message : String
} derive(Debug, Eq)

///|
pub extend Diagnostic with @debug.Debug::{to_repr}

///|
pub extend Diagnostic with Eq::{equal, not_equal}

///|
fn diagnostic(offset : Int, code : String, message : String) -> Diagnostic {
  { offset, code, message, }
}

///|
/// Accepts hexadecimal byte pairs, optionally separated by ASCII whitespace.
/// Whitespace inside a byte pair, 0x prefixes and punctuation are rejected.
pub fn parse_hex(text : String) -> Result[Bytes, Diagnostic] {
  let bytes : Array[Byte] = []
  let mut high = -1
  let mut high_offset = 0
  for i = 0; i < text.length(); i = i + 1 {
    let c = text[i].to_int()
    if c == 32 || c == 9 || c == 10 || c == 13 {
      if high >= 0 {
        return Err(diagnostic(i, "split_byte", "Whitespace splits a byte pair"))
      }
      continue
    }
    let digit = if c >= 48 && c <= 57 {
      c - 48
    } else if c >= 65 && c <= 70 {
      c - 55
    } else if c >= 97 && c <= 102 {
      c - 87
    } else {
      return Err(diagnostic(i, "invalid_hex", "Expected a hexadecimal digit"))
    }
    if high < 0 {
      high = digit
      high_offset = i
    } else {
      bytes.push((high * 16 + digit).to_byte())
      high = -1
    }
  }
  if high >= 0 {
    Err(diagnostic(high_offset, "odd_hex", "Byte pair has only one digit"))
  } else {
    Ok(Bytes::from_array(bytes[:]))
  }
}
