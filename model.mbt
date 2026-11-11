///|
/// Recoverable input/range error; failed operations return no partial result.
#derive(Eq, Debug)
pub struct ProfileError {
  code : String
  message : String
}

///|
pub extend ProfileError with Eq::{equal, not_equal}

///|
pub extend ProfileError with @debug.Debug::{to_repr}

///|
fn problem(code : String, message : String) -> ProfileError {
  { code, message, }
}

///|
/// Nearest-neighbour distances and zero-based target offsets. None means no
/// valid neighbour. valid separately distinguishes an invalid source window.
#derive(Debug)
pub struct Profile {
  self_join : Bool
  window : Int
  exclusion : Int
  target_length : Int
  distances : Array[Double?]
  indices : Array[Int?]
  valid : Array[Bool]
}

///|
pub extend Profile with @debug.Debug::{to_repr}

///|
/// Evidence for a pair of windows.
#derive(Eq, Debug)
pub struct Match {
  index : Int
  neighbor : Int
  distance : Double
}

///|
pub extend Match with Eq::{equal, not_equal}

///|
pub extend Match with @debug.Debug::{to_repr}

///|
priv struct Prepared {
  values : Array[Double]
  means : Array[Double]
  sigmas : Array[Double]
  valid : Array[Bool]
  constant : Array[Bool]
}

///|
fn finite(x : Double) -> Bool {
  x == x && x != @double.infinity && x != @double.neg_infinity
}

///|
fn checked_window(n : Int, m : Int) -> Result[Unit, ProfileError] {
  if m < 3 || m > n {
    Err(problem("E_WINDOW", "window must be between 3 and the series length"))
  } else {
    Ok(())
  }
}

///|
fn checked_work(a : Int, b : Int, limit : Int) -> Result[Unit, ProfileError] {
  if limit < 1 || a.to_int64() * b.to_int64() > limit.to_int64() {
    Err(
      problem(
        "E_LIMIT", "pair budget exceeded; shorten the series or increase the explicit budget",
      ),
    )
  } else {
    Ok(())
  }
}
