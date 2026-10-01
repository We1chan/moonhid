///|
fn user_args() -> Array[String] {
  let args = @env.args()
  if args.is_empty() {
    []
  } else {
    args[1:].to_owned()
  }
}

///|
extern "C" fn stderr_byte(byte : Int) -> Unit = "moonhid_stderr_byte"

///|
fn write_stderr_bytes(message : Bytes) -> Unit {
  for byte in message {
    stderr_byte(byte.to_int())
  }
}
