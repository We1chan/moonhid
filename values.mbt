///|
/// Reads a 0, 1, 2 or 4 byte little-endian short item as an unsigned value.
/// Int64 preserves the entire 32-bit unsigned domain on every backend.
pub fn unsigned_value(data : Bytes) -> Result[Int64, Diagnostic] {
  let size = data.length()
  if size != 0 && size != 1 && size != 2 && size != 4 {
    return Err(
      diagnostic(0, "value_size", "Short value must contain 0, 1, 2 or 4 bytes"),
    )
  }
  let mut value : Int64 = 0
  for i = 0; i < size; i = i + 1 {
    value = value | (data[i].to_int().to_int64() << (i * 8))
  }
  Ok(value)
}

///|
/// Reads a short item as a two's-complement signed value.
pub fn signed_value(data : Bytes) -> Result[Int64, Diagnostic] {
  match unsigned_value(data) {
    Err(error) => Err(error)
    Ok(value) => {
      let bits = data.length() * 8
      if bits > 0 && (value & (1L << (bits - 1))) != 0 {
        Ok(value - (1L << bits))
      } else {
        Ok(value)
      }
    }
  }
}

///|
fn item_unsigned(item : Item) -> Int64 {
  match unsigned_value(item.data) {
    Ok(value) => value
    Err(_) => 0 // Only used with short items returned by parse_items.
  }
}

///|
fn item_signed(item : Item) -> Int64 {
  match signed_value(item.data) {
    Ok(value) => value
    Err(_) => 0
  }
}
