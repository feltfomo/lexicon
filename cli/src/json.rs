// nix output is decoded here because the crate has no dependencies.

use std::collections::BTreeMap;

#[derive(Debug, Clone, PartialEq)]
pub enum Value {
    Null,
    Bool(bool),
    Number(f64),
    Text(String),
    List(Vec<Value>),
    Fields(BTreeMap<String, Value>),
}

impl Value {
    pub fn text(&self) -> Option<&str> {
        match self {
            Value::Text(held) => Some(held),
            _ => None,
        }
    }

    pub fn field(&self, name: &str) -> Option<&Value> {
        match self {
            Value::Fields(held) => held.get(name),
            _ => None,
        }
    }

    pub fn names(&self) -> Option<Vec<String>> {
        match self {
            Value::Fields(held) => Some(held.keys().cloned().collect()),
            Value::List(held) => held
                .iter()
                .map(|one| one.text().map(str::to_string))
                .collect(),
            _ => None,
        }
    }
}

pub fn read(source: &str) -> Result<Value, String> {
    let held: Vec<char> = source.chars().collect();
    let mut at = 0;

    let value = value(&held, &mut at)?;

    skip(&held, &mut at);

    if at < held.len() {
        return Err(format!("there is text after the value read, at {at}"));
    }

    Ok(value)
}

fn skip(source: &[char], at: &mut usize) {
    while *at < source.len() && source[*at].is_whitespace() {
        *at += 1;
    }
}

fn taken(source: &[char], at: &mut usize, word: &str) -> bool {
    let held: Vec<char> = word.chars().collect();

    if source.len() >= *at + held.len() && source[*at..*at + held.len()] == held[..] {
        *at += held.len();

        return true;
    }

    false
}

fn value(source: &[char], at: &mut usize) -> Result<Value, String> {
    skip(source, at);

    match source.get(*at) {
        None => Err("the value ended before it was read".to_string()),
        Some('n') if taken(source, at, "null") => Ok(Value::Null),
        Some('t') if taken(source, at, "true") => Ok(Value::Bool(true)),
        Some('f') if taken(source, at, "false") => Ok(Value::Bool(false)),
        Some('"') => text(source, at).map(Value::Text),
        Some('[') => list(source, at),
        Some('{') => fields(source, at),
        Some(_) => number(source, at),
    }
}

fn text(source: &[char], at: &mut usize) -> Result<String, String> {
    *at += 1;

    let mut held = String::new();

    while let Some(&seen) = source.get(*at) {
        *at += 1;

        match seen {
            '"' => return Ok(held),
            '\\' => {
                let escaped = source
                    .get(*at)
                    .ok_or_else(|| "a string ended inside an escape".to_string())?;

                *at += 1;

                match escaped {
                    'n' => held.push('\n'),
                    't' => held.push('\t'),
                    'r' => held.push('\r'),
                    'b' => held.push('\u{8}'),
                    'f' => held.push('\u{c}'),
                    'u' => {
                        let digits: String = source
                            .get(*at..*at + 4)
                            .ok_or_else(|| "a string ended inside an escape".to_string())?
                            .iter()
                            .collect();

                        *at += 4;

                        let point = u32::from_str_radix(&digits, 16)
                            .map_err(|failure| format!("{digits} is no code point, {failure}"))?;

                        held.push(char::from_u32(point).unwrap_or('\u{fffd}'));
                    }
                    other => held.push(*other),
                }
            }
            other => held.push(other),
        }
    }

    Err("a string was never closed".to_string())
}

fn list(source: &[char], at: &mut usize) -> Result<Value, String> {
    *at += 1;

    let mut held = Vec::new();

    loop {
        skip(source, at);

        match source.get(*at) {
            None => return Err("a list was never closed".to_string()),
            Some(']') => {
                *at += 1;

                return Ok(Value::List(held));
            }
            Some(',') if !held.is_empty() => {
                *at += 1;

                held.push(value(source, at)?);
            }
            Some(_) if held.is_empty() => held.push(value(source, at)?),
            Some(seen) => return Err(format!("{seen} is where a comma or a close belongs")),
        }
    }
}

fn fields(source: &[char], at: &mut usize) -> Result<Value, String> {
    *at += 1;

    let mut held = BTreeMap::new();

    loop {
        skip(source, at);

        match source.get(*at) {
            None => return Err("an attribute set was never closed".to_string()),
            Some('}') => {
                *at += 1;

                return Ok(Value::Fields(held));
            }
            Some(',') if !held.is_empty() => {
                *at += 1;

                let (name, one) = field(source, at)?;

                held.insert(name, one);
            }
            Some('"') if held.is_empty() => {
                let (name, one) = field(source, at)?;

                held.insert(name, one);
            }
            Some(seen) => return Err(format!("{seen} is no attribute name")),
        }
    }
}

fn field(source: &[char], at: &mut usize) -> Result<(String, Value), String> {
    skip(source, at);

    match source.get(*at) {
        Some('"') => {}
        Some(seen) => return Err(format!("{seen} is no attribute name")),
        None => return Err("an attribute set was never closed".to_string()),
    }

    let name = text(source, at)?;

    skip(source, at);

    if source.get(*at) != Some(&':') {
        return Err(format!("the name {name} is followed by no value"));
    }

    *at += 1;

    Ok((name, value(source, at)?))
}

fn number(source: &[char], at: &mut usize) -> Result<Value, String> {
    let from = *at;

    while let Some(&seen) = source.get(*at) {
        if seen.is_ascii_digit() || matches!(seen, '-' | '+' | '.' | 'e' | 'E') {
            *at += 1;
        } else {
            break;
        }
    }

    let held: String = source[from..*at].iter().collect();

    held.parse::<f64>()
        .map(Value::Number)
        .map_err(|failure| format!("{held} is no number, {failure}"))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn the_names_of_an_attribute_set_are_read_in_order() {
        let held = read(r#"{"greet": {}, "check": {}}"#).expect("the value was refused");

        assert_eq!(
            held.names(),
            Some(vec!["check".to_string(), "greet".to_string()])
        );
    }

    #[test]
    fn a_list_of_strings_reads_as_names_too() {
        let held = read(r#"["one", "two"]"#).expect("the value was refused");

        assert_eq!(
            held.names(),
            Some(vec!["one".to_string(), "two".to_string()])
        );
    }

    #[test]
    fn an_app_is_read_field_by_field() {
        let held = read(r#"{"type": "app", "program": "/nix/store/held/bin/greet"}"#)
            .expect("the value was refused");

        assert_eq!(held.field("type").and_then(Value::text), Some("app"));
        assert_eq!(
            held.field("program").and_then(Value::text),
            Some("/nix/store/held/bin/greet")
        );
    }

    #[test]
    fn an_escape_is_read_rather_than_carried() {
        let held = read(r#""one\ntwo\u0021""#).expect("the value was refused");

        assert_eq!(held.text(), Some("one\ntwo!"));
    }

    #[test]
    fn text_after_the_value_is_refused() {
        assert!(read("{} {}").is_err());
    }

    #[test]
    fn nothing_at_all_is_refused() {
        assert!(read("").is_err());
        assert!(read("   ").is_err());
    }

    // nix writes its json down a pipe, so a run that died mid-write hands
    // over a prefix of a valid value rather than something unparseable
    #[test]
    fn an_attribute_set_cut_off_mid_write_is_refused() {
        assert!(read("{").is_err());
        assert!(read("{\"program\"").is_err());
        assert!(read("{\"program\": \"/nix/store/held").is_err());
        assert!(read("{\"program\": \"/nix/store/held\"").is_err());
    }

    #[test]
    fn a_list_cut_off_mid_write_is_refused() {
        assert!(read("[").is_err());
        assert!(read("[\"one\", \"two").is_err());
        assert!(read("[\"one\", \"two\"").is_err());
    }

    #[test]
    fn a_word_that_only_begins_like_a_literal_is_refused() {
        assert!(read("nul").is_err());
        assert!(read("tru").is_err());
        assert!(read("fals").is_err());
    }

    #[test]
    fn a_string_cut_off_inside_an_escape_is_refused() {
        assert!(read("\"one\\").is_err());
        assert!(read("\"one\\u00").is_err());
        assert!(read("\"one\\uzzzz\"").is_err());
    }

    #[test]
    fn an_attribute_name_that_is_no_string_is_refused() {
        assert!(read("{program: 1}").is_err());
    }

    #[test]
    fn a_name_followed_by_no_value_is_refused() {
        assert!(read("{\"program\" 1}").is_err());
    }

    #[test]
    fn nothing_where_a_value_belongs_is_refused() {
        assert!(read("{\"program\": }").is_err());
        assert!(read("[1, , 2]").is_err());
    }

    #[test]
    fn a_number_with_text_stuck_to_it_is_refused() {
        assert!(read("123held").is_err());
        assert!(read("1.2.3").is_err());
    }

    // a refused read has to stay a refusal rather than becoming an empty
    // attribute set, because a caller reads names off what comes back
    #[test]
    fn a_refusal_carries_no_value_a_caller_could_walk() {
        for held in ["", "{", "{\"apps\": {", "nul"] {
            assert!(read(held).is_err(), "{held} was read rather than refused");
        }
    }
}
