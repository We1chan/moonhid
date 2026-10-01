///|
fn user_args() -> Array[String] {
  let args = @env.args()
  if args.length() < 2 {
    []
  } else {
    args[2:].to_owned()
  }
}

///|
extern "js" fn write_stderr_bytes(message : Bytes) -> Unit =
  #| message => { process.stderr.write(message); }
