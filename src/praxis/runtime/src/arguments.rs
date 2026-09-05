use crate::model::{Argument, Parameter, Result, fail};
use std::{
    borrow::Cow,
    collections::{BTreeMap, BTreeSet, btree_map::Entry},
};

pub struct Parsed<'a> {
    pub values: BTreeMap<&'a str, Cow<'a, str>>,
    pub supplied: BTreeSet<&'a str>,
    pub rest: &'a [String],
}
// parsing, runner-option separation and completion share one flag grammar
pub struct ParameterIndex<'a> {
    named: BTreeMap<&'a str, &'a Parameter>,
    shorts: BTreeMap<char, &'a Parameter>,
    pub positionals: Vec<&'a Parameter>,
}
impl<'a> ParameterIndex<'a> {
    pub fn new(parameters: &'a [Parameter]) -> Self {
        Self {
            named: parameters
                .iter()
                .filter(|p| !p.positional)
                .map(|p| (p.name.as_str(), p))
                .collect(),
            shorts: parameters
                .iter()
                .filter_map(|p| p.short.map(|s| (s, p)))
                .collect(),
            positionals: parameters.iter().filter(|p| p.positional).collect(),
        }
    }
    pub fn flag<'b>(&self, token: &'b str) -> Option<(&'a Parameter, Option<&'b str>)> {
        if let Some(long) = token.strip_prefix("--") {
            let (name, value) = long
                .split_once('=')
                .map_or((long, None), |(n, v)| (n, Some(v)));
            self.named.get(name).map(|p| (*p, value))
        } else if token.starts_with('-')
            && token.as_bytes().get(1).is_some_and(u8::is_ascii_alphabetic)
        {
            let tail = &token[2..];
            self.shorts.get(&(token.as_bytes()[1] as char)).map(|p| {
                (
                    *p,
                    (!tail.is_empty()).then(|| tail.strip_prefix('=').unwrap_or(tail)),
                )
            })
        } else {
            None
        }
    }
}
pub fn env_key(name: &str) -> String {
    format!("PRAXIS_ARG_{}", name.replace('-', "_").to_ascii_uppercase())
}
fn normalize<'a>(parameter: &Parameter, value: Cow<'a, str>) -> Result<Cow<'a, str>> {
    let invalid = || fail(64, format!("{} expects {}", parameter.name, parameter.kind));
    let value = match parameter.kind.as_str() {
        "string" => value,
        "path" if !value.is_empty() => value,
        // numeric spelling must not change choice or condition equality
        "int" => Cow::Owned(value.parse::<i64>().map_err(|_| invalid())?.to_string()),
        "bool" if matches!(value.as_ref(), "true" | "false") => value,
        _ => return Err(invalid()),
    };
    if !parameter.choices.is_empty()
        && !parameter
            .choices
            .iter()
            .any(|choice| choice == value.as_ref())
    {
        return Err(fail(
            64,
            format!(
                "{} expects one of {}{}",
                parameter.name,
                parameter
                    .choices
                    .iter()
                    .take(8)
                    .map(String::as_str)
                    .collect::<Vec<_>>()
                    .join(", "),
                if parameter.choices.len() > 8 {
                    " (see --help for all choices)"
                } else {
                    ""
                }
            ),
        ));
    }
    Ok(value)
}
pub fn parse<'a>(
    parameters: &'a [Parameter],
    args: &'a [String],
    forwarding: bool,
) -> Result<Parsed<'a>> {
    let mut values = BTreeMap::new();
    let mut supplied = BTreeSet::new();
    let parameters_by_flag = ParameterIndex::new(parameters);
    let mut rest = &[][..];
    let mut positional = 0;
    let mut index = 0;
    while index < args.len() {
        let token = &args[index];
        if token == "--" {
            rest = &args[index + 1..];
            break;
        }
        let (parameter, value) = if let Some((parameter, inline)) = parameters_by_flag.flag(token) {
            if parameter.sensitive {
                return Err(fail(
                    64,
                    format!(
                        "{} is sensitive; use its environment source or terminal input",
                        parameter.name
                    ),
                ));
            }
            let value = if let Some(value) = inline {
                value
            } else if parameter.kind == "bool" {
                "true"
            } else {
                index += 1;
                args.get(index)
                    .ok_or_else(|| fail(64, format!("{} needs a value", parameter.name)))?
                    .as_str()
            };
            (parameter, value)
        } else if token.starts_with("--")
            || (token.starts_with('-')
                && token.as_bytes().get(1).is_some_and(u8::is_ascii_alphabetic))
        {
            return Err(fail(
                64,
                "unknown flag; use -- before pass-through arguments",
            ));
        } else {
            let parameter = parameters_by_flag
                .positionals
                .get(positional)
                .ok_or_else(|| {
                    fail(
                        64,
                        "unexpected argument; use -- before pass-through arguments",
                    )
                })?;
            positional += 1;
            (*parameter, token.as_str())
        };
        let value = normalize(parameter, Cow::Borrowed(value))?;
        supplied.insert(parameter.name.as_str());
        if values.insert(parameter.name.as_str(), value).is_some() {
            return Err(fail(64, format!("{} supplied twice", parameter.name)));
        }
        index += 1;
    }
    if !rest.is_empty() && !forwarding {
        return Err(fail(64, "this command has no forwardArgs step"));
    }
    for parameter in parameters {
        if let Entry::Vacant(entry) = values.entry(parameter.name.as_str()) {
            if parameter.sensitive {
                entry.insert(Cow::Borrowed("<sensitive>"));
                continue;
            }
            let from_env = parameter.env.as_ref().map(std::env::var).transpose();
            let from_env = match from_env {
                Ok(value) => value,
                Err(std::env::VarError::NotPresent) => None,
                Err(_) => {
                    return Err(fail(
                        64,
                        format!("{} environment value must be UTF-8", parameter.name),
                    ));
                }
            };
            let provided = from_env.is_some() || parameter.default.is_some();
            let value = if let Some(value) = from_env {
                supplied.insert(parameter.name.as_str());
                Cow::Owned(value)
            } else if let Some(default) = parameter.default.as_deref() {
                Cow::Borrowed(default)
            } else if parameter.required {
                return Err(fail(
                    64,
                    format!("missing required argument {}", parameter.name),
                ));
            } else if parameter.kind == "bool" {
                Cow::Borrowed("false")
            } else {
                Cow::Borrowed("")
            };
            let value = if provided || !value.is_empty() {
                normalize(parameter, value)?
            } else {
                value
            };
            entry.insert(value);
        }
    }
    Ok(Parsed {
        values,
        rest,
        supplied,
    })
}
pub fn groups(groups: &[crate::model::ParameterGroup], supplied: &BTreeSet<&str>) -> Result<()> {
    for group in groups {
        let count = group
            .parameters
            .iter()
            .filter(|p| supplied.contains(p.as_str()))
            .count();
        let valid = match group.kind.as_str() {
            "exclusive" => count <= 1,
            "together" => count == 0 || count == group.parameters.len(),
            _ => false,
        };
        if !valid {
            return Err(fail(
                64,
                format!(
                    "{} parameter group violated: {}",
                    group.kind,
                    group.parameters.join(", ")
                ),
            ));
        }
    }
    Ok(())
}
pub fn resolve_argument(arg: &Argument, values: &BTreeMap<&str, Cow<'_, str>>) -> Result<String> {
    match arg {
        Argument::Text(value) => Ok(value.clone()),
        Argument::Parameter { param } => values
            .get(param.as_str())
            .map(|value| value.as_ref().to_owned())
            .ok_or_else(|| fail(65, format!("undeclared parameter {param}"))),
    }
}
pub fn resolve(args: &[Argument], values: &BTreeMap<&str, Cow<'_, str>>) -> Result<Vec<String>> {
    args.iter()
        .map(|arg| resolve_argument(arg, values))
        .collect()
}
#[cfg(test)]
mod tests {
    use super::*;
    fn parameter() -> Parameter {
        Parameter {
            name: "host".into(),
            description: String::new(),
            kind: "string".into(),
            positional: false,
            required: true,
            default: None,
            choices: vec![],
            env: None,
            short: None,
            sensitive: false,
        }
    }
    #[test]
    fn preserves_values() {
        let parameters = [parameter()];
        let args = [
            "--host=a b'$(false)".into(),
            "--".into(),
            "".into(),
            "-n".into(),
        ];
        let p = parse(&parameters, &args, true).unwrap();
        assert_eq!(p.values["host"], "a b'$(false)");
        assert_eq!(p.rest, ["", "-n"]);
    }
    #[test]
    fn binds_interleaved_flags_defaults_and_positionals() {
        let parameters = [
            Parameter {
                name: "target".into(),
                positional: true,
                ..parameter()
            },
            Parameter {
                name: "count".into(),
                kind: "int".into(),
                required: false,
                default: Some("4".into()),
                ..parameter()
            },
            Parameter {
                name: "color".into(),
                kind: "bool".into(),
                required: false,
                ..parameter()
            },
        ];
        let args = [
            "--count=-9223372036854775808".into(),
            "a b".into(),
            "--color=false".into(),
        ];
        let parsed = parse(&parameters, &args, false).unwrap();
        assert_eq!(parsed.values["target"], "a b");
        assert_eq!(parsed.values["count"], "-9223372036854775808");
        assert_eq!(parsed.values["color"], "false");
        let args = ["target".into()];
        let defaults = parse(&parameters, &args, false).unwrap();
        assert_eq!(defaults.values["count"], "4");
        assert_eq!(defaults.values["color"], "false");
        for value in ["9223372036854775808", "-9223372036854775809", "bad"] {
            assert!(
                parse(
                    &parameters,
                    &["target".into(), format!("--count={value}")],
                    false
                )
                .is_err()
            );
        }
        assert!(parse(&parameters, &["--target=value".into()], false).is_err());
    }
    #[test]
    fn resolves_empty_literals_and_repeated_parameters() {
        let values = BTreeMap::from([("word", Cow::Borrowed("two ' words"))]);
        let args = [
            Argument::Text(String::new()),
            Argument::Parameter {
                param: "word".into(),
            },
            Argument::Parameter {
                param: "word".into(),
            },
        ];
        assert_eq!(
            resolve(&args, &values).unwrap(),
            ["", "two ' words", "two ' words"]
        );
        assert!(
            resolve_argument(
                &Argument::Parameter {
                    param: "missing".into()
                },
                &values
            )
            .is_err()
        );
    }
    #[test]
    fn choices_compare_typed_values_and_short_forms() {
        let parameters = [Parameter {
            kind: "int".into(),
            choices: vec!["2".into()],
            short: Some('n'),
            ..parameter()
        }];
        for token in ["--host=+02", "-n02", "-n=2"] {
            let args = [token.into()];
            assert_eq!(
                parse(&parameters, &args, false).unwrap().values["host"],
                "2"
            );
        }
        assert!(parse(&parameters, &["-n3".into()], false).is_err());
        assert!(parse(&parameters, &["-n2".into(), "--host=2".into()], false).is_err());
        let parameters = [Parameter {
            short: Some('t'),
            ..parameter()
        }];
        let args = ["-t".into(), "--json".into()];
        assert_eq!(
            parse(&parameters, &args, false).unwrap().values["host"],
            "--json"
        );
    }
    #[test]
    fn rejects_missing_duplicate_and_unknown() {
        for args in [vec![], vec!["--host=x", "--host=y"], vec!["--typo=x"]] {
            assert!(
                parse(
                    &[parameter()],
                    &args.iter().map(|s| s.to_string()).collect::<Vec<_>>(),
                    false
                )
                .is_err()
            );
        }
    }
}
