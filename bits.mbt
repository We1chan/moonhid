///|
/// Extracts 1..32 bits, least significant bit first, including unaligned fields.
/// signed=true interprets the result as two's complement.
pub fn extract_bits(
  bytes : Bytes,
  bit_offset : Int,
  bit_size : Int,
  signed? : Bool = false,
) -> Result[Int64, Diagnostic] {
  if bit_offset < 0 || bit_size < 1 || bit_size > 32 {
    return Err(
      diagnostic(0, "bit_range", "Offset must be nonnegative and width 1..32"),
    )
  }
  let start_byte = bit_offset / 8
  let start_bit = bit_offset % 8
  let end_byte = start_byte + (start_bit + bit_size + 7) / 8
  if end_byte > bytes.length() {
    return Err(
      diagnostic(
        start_byte, "short_report", "Report does not contain the requested bits",
      ),
    )
  }
  let mut value : Int64 = 0
  for i = 0; i < bit_size; i = i + 1 {
    let position = start_bit + i
    let bit = (bytes[start_byte + position / 8].to_int() >> (position % 8)) & 1
    value = value | (bit.to_int64() << i)
  }
  if signed && (value & (1L << (bit_size - 1))) != 0 {
    Ok(value - (1L << bit_size))
  } else {
    Ok(value)
  }
}
