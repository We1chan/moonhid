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

///|
fn power_of_ten(exponent : Int) -> Double {
  let mut result = 1.0
  for i = 0; i < exponent.abs(); i = i + 1 {
    result = result * 10.0
  }
  result
}

///|
/// Applies 10^exponent. Negative exponents divide by an exact power of ten.
fn scale_by_exponent(value : Double, exponent : Int) -> Double {
  if exponent >= 0 {
    value * power_of_ten(exponent)
  } else {
    value / power_of_ten(exponent)
  }
}

///|
/// Converts a logical value to a physical quantity per HID 1.11 §6.2.2.7:
/// a linear map from the Logical range onto effective_physical_range, then
/// multiplied by 10^Unit Exponent (0 when undeclared). The result is a Double
/// in the Unit's base system units; decode_unit names the dimensions.
pub fn physical_value(
  field : Field,
  logical : Int64,
) -> Result[Double, Diagnostic] {
  if field.logical_max <= field.logical_min {
    return Err(
      diagnostic(
        field.descriptor_offset,
        "physical_range",
        "Scaling needs Logical Maximum above Logical Minimum",
      ),
    )
  }
  if logical < field.logical_min || logical > field.logical_max {
    return Err(
      if (field.flags & 64) != 0 {
        diagnostic(
          field.descriptor_offset,
          "null_value",
          "Value is the field's Null State",
        )
      } else {
        diagnostic(
          field.descriptor_offset,
          "logical_range",
          "Value is outside the field's logical range",
        )
      },
    )
  }
  let (physical_min, physical_max) = effective_physical_range(field)
  let scaled = physical_min.to_double() +
    (logical - field.logical_min).to_double() *
    (physical_max - physical_min).to_double() /
    (field.logical_max - field.logical_min).to_double()
  Ok(scale_by_exponent(scaled, field.unit_exponent.unwrap_or(0)))
}

///|
/// Inverse of physical_value, rounding half away from zero on every backend.
/// Results outside the Logical range are rejected rather than clamped.
pub fn logical_from_physical(
  field : Field,
  physical : Double,
) -> Result[Int64, Diagnostic] {
  let (physical_min, physical_max) = effective_physical_range(field)
  if field.logical_max <= field.logical_min || physical_max == physical_min {
    return Err(
      diagnostic(
        field.descriptor_offset,
        "physical_range",
        "Scaling needs distinct Logical and Physical endpoints",
      ),
    )
  }
  if physical.is_nan() || physical.is_inf() {
    return Err(
      diagnostic(
        field.descriptor_offset,
        "value_range",
        "Physical value must be finite",
      ),
    )
  }
  let base = scale_by_exponent(physical, -field.unit_exponent.unwrap_or(0))
  let logical = field.logical_min.to_double() +
    (base - physical_min.to_double()) *
    (field.logical_max - field.logical_min).to_double() /
    (physical_max - physical_min).to_double()
  // Core Double::round sends halves toward +infinity (-2.5 becomes -2), which
  // would make negative quantities asymmetric. x - floor(x) is exact here.
  let whole = logical.abs().floor()
  let magnitude = if logical.abs() - whole >= 0.5 { whole + 1.0 } else { whole }
  let rounded = if logical < 0.0 { -magnitude } else { magnitude }
  if rounded < field.logical_min.to_double() ||
    rounded > field.logical_max.to_double() {
    return Err(
      diagnostic(
        field.descriptor_offset,
        "logical_range",
        "Physical value maps outside the field's logical range",
      ),
    )
  }
  Ok(rounded.to_int64())
}
