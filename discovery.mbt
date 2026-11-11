///|
fn overlap(a : Int32, b : Int32, window : Int32) -> Bool {
  (a - b).abs() < window
}

///|
/// Select nonoverlapping high-distance windows. These are unusual shapes,
/// not calibrated failure probabilities. Equal scores retain the earlier index.
pub fn discords(profile : Profile, count : Int32) -> Array[Match] {
  let result : Array[Match] = []
  if count <= 0 {
    return result
  }
  let blocked = Array::make(profile.distances.length(), false)
  while result.length() < count {
    let mut best : Match? = None
    for i = 0; i < profile.distances.length(); i = i + 1 {
      if blocked[i] {
        continue
      }
      if (profile.distances[i], profile.indices[i]) is (Some(d), Some(j)) {
        match best {
          None => best = Some({ index: i, neighbor: j, distance: d, })
          Some(old) =>
            if d > old.distance {
              best = Some({ index: i, neighbor: j, distance: d, })
            }
        }
      }
    }
    match best {
      None => break
      Some(found) => {
        result.push(found)
        for i = 0; i < blocked.length(); i = i + 1 {
          if overlap(i, found.index, profile.window) {
            blocked[i] = true
          }
        }
      }
    }
  }
  result
}

///|
/// Nonoverlapping pairs drawn from a self-join's one-neighbour profile.
/// This is not exhaustive k-motif search. AB-joins return E_KIND.
pub fn motifs(
  profile : Profile,
  count : Int32,
) -> Result[Array[Match], ProfileError] {
  if !profile.self_join {
    return Err(problem("E_KIND", "motifs require a self-join profile"))
  }
  let result : Array[Match] = []
  if count <= 0 {
    return Ok(result)
  }
  let blocked = Array::make(profile.distances.length(), false)
  while result.length() < count {
    let mut best : Match? = None
    for i = 0; i < profile.distances.length(); i = i + 1 {
      if blocked[i] {
        continue
      }
      if (profile.distances[i], profile.indices[i]) is (Some(d), Some(j)) {
        if j < 0 ||
          j >= blocked.length() ||
          blocked[j] ||
          overlap(i, j, profile.window) {
          continue
        }
        let candidate = { index: i.min(j), neighbor: i.max(j), distance: d, }
        match best {
          None => best = Some(candidate)
          Some(old) => if d < old.distance { best = Some(candidate) }
        }
      }
    }
    match best {
      None => break
      Some(found) => {
        result.push(found)
        for i = 0; i < blocked.length(); i = i + 1 {
          if overlap(i, found.index, profile.window) ||
            overlap(i, found.neighbor, profile.window) {
            blocked[i] = true
          }
        }
      }
    }
  }
  Ok(result)
}
