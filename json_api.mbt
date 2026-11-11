///|
fn matches_json(matches : Array[Match]) -> Json {
  Json(
    matches.map(fn(m) {
      let item : Json = {
        "index": m.index,
        "neighbor": m.neighbor,
        "distance": m.distance,
      }
      item
    }),
  )
}

///|
fn distances_json(values : Array[Double?]) -> Json {
  Json(
    values.map(fn(value) {
      match value {
        Some(x) => Json::number(x)
        None => null
      }
    }),
  )
}

///|
/// Portable JSON form: undefined distances/indices are null, never NaN/Infinity.
pub fn profile_to_json(profile : Profile) -> Json {
  {
    "window": profile.window,
    "exclusion": profile.exclusion,
    "self_join": profile.self_join,
    "target_length": profile.target_length,
    "distances": distances_json(profile.distances),
    "indices": Json(
      profile.indices.map(fn(value) {
        match value {
          Some(i) => @json.to_json(i)
          None => null
        }
      }),
    ),
    "valid": @json.to_json(profile.valid),
  }
}

///|
fn json_series(value : Json) -> Result[Array[Double], ProfileError] {
  guard value is Array(items) else {
    return Err(problem("E_INPUT", "series must be an array of numbers or null"))
  }
  if items.length() > 100000 {
    return Err(problem("E_LIMIT", "series exceeds 100000 samples"))
  }
  let values : Array[Double] = []
  for item in items {
    match item {
      Null => values.push(@double.not_a_number)
      Number(n, ..) =>
        if finite(n) {
          values.push(n)
        } else {
          return Err(
            problem(
              "E_INPUT", "numbers must be finite; use null for missing samples",
            ),
          )
        }
      _ => return Err(problem("E_INPUT", "series contains a nonnumeric value"))
    }
  }
  Ok(values)
}

///|
fn integer(
  fields : Map[String, Json],
  key : String,
  default : Int32,
) -> Result[Int32, ProfileError] {
  match fields.get(key) {
    None => Ok(default)
    Some(Number(n, ..)) =>
      if finite(n) && n >= 0.0 && n <= 2147483647.0 && n == n.floor() {
        Ok(n.to_int())
      } else {
        Err(problem("E_INPUT", key + " must be a nonnegative integer"))
      }
    _ => Err(problem("E_INPUT", key + " must be a nonnegative integer"))
  }
}

///|
fn handle_request(request : Json) -> Result[Json, ProfileError] {
  guard request is Object(fields) else {
    return Err(problem("E_INPUT", "request must be an object"))
  }
  let operation = match fields.get("op") {
    None => "profile"
    Some(String(s)) => s
    _ => return Err(problem("E_INPUT", "op must be a string"))
  }
  let series = match fields.get("csv") {
    Some(String(csv)) => {
      guard fields.get("column") is Some(String(column)) else {
        return Err(problem("E_CSV", "CSV input requires a column name"))
      }
      match parse_csv(csv, column) {
        Err(e) => return Err(e)
        Ok(s) => s
      }
    }
    None =>
      match json_series(fields.get("series").unwrap_or(null)) {
        Err(e) => return Err(e)
        Ok(s) => s
      }
    _ => return Err(problem("E_CSV", "csv must be a string"))
  }
  let budget = match integer(fields, "max_pairs", 25000000) {
    Err(e) => return Err(e)
    Ok(n) => n
  }
  if operation == "parse" {
    return Ok({
      "ok": true,
      "series": Json(
        series.map(fn(x) { if finite(x) { Json::number(x) } else { null } }),
      ),
    })
  }
  let count = match integer(fields, "count", 3) {
    Err(e) => return Err(e)
    Ok(n) => n
  }
  if count > 100 {
    return Err(problem("E_LIMIT", "count must not exceed 100"))
  }
  if operation == "query" {
    let query = match json_series(fields.get("query").unwrap_or(null)) {
      Err(e) => return Err(e)
      Ok(q) => q
    }
    let distances = match distance_profile(query, series, max_pairs=budget) {
      Err(e) => return Err(e)
      Ok(d) => d
    }
    if fields.contains("ignore_start") {
      let start = match integer(fields, "ignore_start", 0) {
        Err(e) => return Err(e)
        Ok(i) => i
      }
      if start >= distances.length() {
        return Err(
          problem("E_INPUT", "ignore_start is outside the target windows"),
        )
      }
      let exclusion = (query.length() + 3) / 4
      for i = 0; i < distances.length(); i = i + 1 {
        if (i - start).abs() <= exclusion {
          distances[i] = None
        }
      }
    }
    let matches : Array[Json] = []
    let blocked = Array::make(distances.length(), false)
    while matches.length() < count {
      let mut best = -1
      let mut score = @double.infinity
      for i, d in distances {
        if !blocked[i] && d is Some(value) && value < score {
          best = i
          score = value
        }
      }
      if best < 0 {
        break
      }
      matches.push({ "index": best, "distance": score })
      for i = 0; i < blocked.length(); i = i + 1 {
        if overlap(i, best, query.length()) {
          blocked[i] = true
        }
      }
    }
    return Ok({
      "ok": true,
      "kind": "query",
      "window": query.length(),
      "distances": distances_json(distances),
      "matches": Json(matches),
    })
  }
  let window = match integer(fields, "window", 32) {
    Err(e) => return Err(e)
    Ok(n) => n
  }
  let result = if operation == "profile" {
    let exclusion = match integer(fields, "exclusion", (window + 3) / 4) {
      Err(e) => return Err(e)
      Ok(n) => n
    }
    matrix_profile(series, window, exclusion_zone=exclusion, max_pairs=budget)
  } else if operation == "abjoin" {
    let target = match json_series(fields.get("target").unwrap_or(null)) {
      Err(e) => return Err(e)
      Ok(s) => s
    }
    ab_join(series, target, window, max_pairs=budget)
  } else {
    return Err(problem("E_INPUT", "op must be profile, abjoin or query"))
  }
  let profile = match result {
    Err(e) => return Err(e)
    Ok(p) => p
  }
  let motif_list = if profile.self_join {
    motifs(profile, count).unwrap()
  } else {
    []
  }
  let mut invalid = 0
  let mut unmatched = 0
  for i, valid in profile.valid {
    if !valid {
      invalid = invalid + 1
    } else if profile.indices[i] is None {
      unmatched = unmatched + 1
    }
  }
  Ok({
    "ok": true,
    "kind": operation,
    "samples": series.length(),
    "profile": profile_to_json(profile),
    "motifs": matches_json(motif_list),
    "discords": matches_json(discords(profile, count)),
    "invalid_windows": invalid,
    "unmatched_windows": unmatched,
  })
}

///|
/// JSON host boundary shared by the CLI and browser. Errors are JSON envelopes;
/// untrusted input never reaches a host eval or an external service.
pub fn analyze_json(text : String) -> String {
  let result = if text.length() > 8000000 {
    Err(problem("E_LIMIT", "request exceeds 8 million UTF-16 code units"))
  } else {
    let request = @json.parse(text) catch {
      _ =>
        return "{\"ok\":false,\"error\":{\"code\":\"E_JSON\",\"message\":\"invalid JSON request\"}}"
    }
    handle_request(request)
  }
  match result {
    Ok(value) => value.stringify()
    Err(e) => {
      let reply : Json = {
        "ok": false,
        "error": { "code": e.code, "message": e.message },
      }
      reply.stringify()
    }
  }
}
