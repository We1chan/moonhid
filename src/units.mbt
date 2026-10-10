///|
fn signed_nibble(value : Int) -> Int {
  let nibble = value & 15
  if nibble >= 8 {
    nibble - 16
  } else {
    nibble
  }
}

///|
/// Unit dimensions are signed nibble exponents, not converted physical values.
pub(all) struct UnitDimensions {
  raw : Int64
  system : Int
  length : Int
  mass : Int
  time : Int
  temperature : Int
  current : Int
  luminous_intensity : Int
  reserved : Int
} derive(Debug, Eq)

///|
pub extend UnitDimensions with @debug.Debug::{to_repr}

///|
pub extend UnitDimensions with Eq::{equal, not_equal}

///|
pub fn decode_unit(raw : Int64) -> Result[UnitDimensions, Diagnostic] {
  if raw < 0 || raw > 4294967295L {
    return Err(
      diagnostic(0, "unit_range", "Unit must fit an unsigned 32-bit item"),
    )
  }
  Ok({
    raw,
    system: (raw & 15L).to_int(),
    length: signed_nibble((raw >> 4).to_int()),
    mass: signed_nibble((raw >> 8).to_int()),
    time: signed_nibble((raw >> 12).to_int()),
    temperature: signed_nibble((raw >> 16).to_int()),
    current: signed_nibble((raw >> 20).to_int()),
    luminous_intensity: signed_nibble((raw >> 24).to_int()),
    reserved: ((raw >> 28) & 15L).to_int(),
  })
}

///|
/// HID defaults to the logical range when either physical endpoint is absent,
/// or both declared physical endpoints are zero. Declared metadata stays intact.
pub fn effective_physical_range(field : Field) -> (Int64, Int64) {
  match (field.physical_min, field.physical_max) {
    (Some(minimum), Some(maximum)) if minimum != 0 || maximum != 0 =>
      (minimum, maximum)
    _ => (field.logical_min, field.logical_max)
  }
}
