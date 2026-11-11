///|
fn accept(
  distances : Array[Double?],
  indices : Array[Int?],
  i : Int,
  j : Int,
  value : Double,
) -> Unit {
  match (distances[i], indices[i]) {
    (Some(old), Some(neighbor)) => {
      let tolerance = 1.0e-10 * (1.0 + old.abs())
      if value < old - tolerance ||
        ((value - old).abs() <= tolerance && j < neighbor) {
        distances[i] = Some(value)
        indices[i] = Some(j)
      }
    }
    _ => {
      distances[i] = Some(value)
      indices[i] = Some(j)
    }
  }
}

///|
// STOMP-style diagonal recurrence with periodic dot-product re-anchoring.
fn join(
  a : Prepared,
  b : Prepared,
  m : Int,
  exclusion : Int,
  self_join : Bool,
  target_length : Int,
) -> Profile {
  let na = a.means.length()
  let nb = b.means.length()
  let distances = Array::make(na, None)
  let indices = Array::make(na, None)
  for diagonal = 1 - na; diagonal < nb; diagonal = diagonal + 1 {
    if self_join && diagonal <= exclusion {
      continue
    }
    let mut i = if diagonal < 0 { 0 - diagonal } else { 0 }
    let mut j = if diagonal > 0 { diagonal } else { 0 }
    let mut product = dot(a.values, i, b.values, j, m)
    let mut step = 0
    while i < na && j < nb {
      if step > 0 && step % 128 == 0 {
        product = dot(a.values, i, b.values, j, m)
      }
      if a.valid[i] && b.valid[j] {
        let d = distance(a, i, b, j, m, product)
        accept(distances, indices, i, j, d)
        if self_join {
          accept(distances, indices, j, i, d)
        }
      }
      if i + 1 < na && j + 1 < nb {
        product = product -
          a.values[i] * b.values[j] +
          a.values[i + m] * b.values[j + m]
      }
      i = i + 1
      j = j + 1
      step = step + 1
    }
  }
  for i = 0; i < na; i = i + 1 {
    if indices[i] is Some(j) {
      distances[i] = Some(direct_distance(a, i, b, j, m))
    }
  }
  {
    self_join,
    window: m,
    exclusion,
    target_length,
    distances,
    indices,
    valid: a.valid.copy(),
  }
}

///|
/// Self-join with default exclusion ceil(window/4). Constant pairs have distance
/// 0; one constant has distance sqrt(window). Nonfinite windows are invalid.
pub fn matrix_profile(
  series : Array[Double],
  window : Int,
  exclusion_zone? : Int,
  max_pairs? : Int = 25000000,
) -> Result[Profile, ProfileError] {
  match checked_window(series.length(), window) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  let exclusion = exclusion_zone.unwrap_or((window + 3) / 4)
  if exclusion < 0 {
    return Err(problem("E_EXCLUSION", "exclusion zone must be nonnegative"))
  }
  let n = series.length() - window + 1
  match checked_work(n, n, max_pairs) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  match checked_work(n, window, max_pairs) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  match prepare(series, window) {
    Err(e) => Err(e)
    Ok(prepared) =>
      Ok(join(prepared, prepared, window, exclusion, true, series.length()))
  }
}

///|
/// Each source window finds its nearest target window. No exclusion is applied.
pub fn ab_join(
  source : Array[Double],
  target : Array[Double],
  window : Int,
  max_pairs? : Int = 25000000,
) -> Result[Profile, ProfileError] {
  match checked_window(source.length(), window) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  match checked_window(target.length(), window) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  match
    checked_work(
      source.length() - window + 1,
      target.length() - window + 1,
      max_pairs,
    ) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  match checked_work(source.length() - window + 1, window, max_pairs) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  match checked_work(target.length() - window + 1, window, max_pairs) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  let a = match prepare(source, window) {
    Err(e) => return Err(e)
    Ok(p) => p
  }
  let b = match prepare(target, window) {
    Err(e) => return Err(e)
    Ok(p) => p
  }
  Ok(join(a, b, window, 0, false, target.length()))
}

///|
/// Compare the complete query with every same-length target window.
pub fn distance_profile(
  query : Array[Double],
  target : Array[Double],
  max_pairs? : Int = 25000000,
) -> Result[Array[Double?], ProfileError] {
  let m = query.length()
  match checked_window(target.length(), m) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  match checked_work(m, target.length() - m + 1, max_pairs) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  let a = match prepare(query, m) {
    Err(e) => return Err(e)
    Ok(p) => p
  }
  let b = match prepare(target, m) {
    Err(e) => return Err(e)
    Ok(p) => p
  }
  if !a.valid[0] {
    return Err(problem("E_QUERY", "query must contain only finite values"))
  }
  Ok(
    Array::makei(b.means.length(), fn(j) {
      if b.valid[j] {
        Some(direct_distance(a, 0, b, j, m))
      } else {
        None
      }
    }),
  )
}
