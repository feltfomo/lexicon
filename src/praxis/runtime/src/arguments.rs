use crate::model::{Argument, Parameter, Result, fail};
use std::collections::{BTreeMap, btree_map::Entry};

pub struct Parsed<'a> {
    pub values: BTreeMap<&'a str, &'a str>,
    pub rest: &'a [String],
}
pub fn env_key(name: &str) -> String {
    format!("PRAXIS_ARG_{}", name.replace('-', "_").to_ascii_uppercase())
}
fn check(parameter: &Parameter, value: &str) -> Result<()> {
    let valid = match parameter.kind.as_str() {
        "string" => true,
        "path" => !value.is_empty(),
        "int" => value.parse::<i64>().is_ok(),
        "bool" => matches!(value, "true" | "false"),
        _ => false,
    };
    if valid {
        Ok(())
    } else {
        Err(fail(
            64,
            format!("{} expects {}", parameter.name, parameter.kind),
        ))
    }
}
pub fn parse<'a>(
    parameters: &'a [Parameter],
    args: &'a [String],
    forwarding: bool,
) -> Result<Parsed<'a>> {
    let mut values = BTreeMap::new();
    let mut rest = &[][..];
    let positionals: Vec<_> = parameters.iter().filter(|p| p.positional).collect();
    let named: BTreeMap<_, _> = parameters
        .iter()
        .filter(|p| !p.positional)
        .map(|p| (p.name.as_str(), p))
        .collect();
    let mut positional = 0;
    let mut index = 0;
    while index < args.len() {
        let token = &args[index];
        if token == "--" {
            rest = &args[index + 1..];
            break;
        }
        let (parameter, value) = if let Some(flag) = token.strip_prefix("--") {
            let (name, inline) = flag
                .split_once('=')
                .map_or((flag, None), |(k, v)| (k, Some(v)));
            let parameter = named.get(name).copied().ok_or_else(|| {
                fail(
                    64,
                    format!("unknown flag --{name}; use -- before pass-through arguments"),
                )
            })?;
            let value = if let Some(value) = inline {
                value
            } else if parameter.kind == "bool" {
                "true"
            } else {
                index += 1;
                args.get(index)
                    .ok_or_else(|| fail(64, format!("--{name} needs a value")))?
                    .as_str()
            };
            (parameter, value)
        } else {
            let parameter = positionals.get(positional).ok_or_else(|| {
                fail(
                    64,
                    "unexpected argument; use -- before pass-through arguments",
                )
            })?;
            positional += 1;
            (*parameter, token.as_str())
        };
        check(parameter, value)?;
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
            let value = if let Some(default) = parameter.default.as_deref() {
                default
            } else if parameter.required {
                return Err(fail(
                    64,
                    format!("missing required argument {}", parameter.name),
                ));
            } else if parameter.kind == "bool" {
                "false"
            } else {
                ""
            };
            if !value.is_empty() {
                check(parameter, value)?;
            }
            entry.insert(value);
        }
    }
    Ok(Parsed { values, rest })
}
pub fn resolve_argument(arg: &Argument, values: &BTreeMap<&str, &str>) -> Result<String> {
    match arg {
        Argument::Text(value) => Ok(value.clone()),
        Argument::Parameter { param } => values
            .get(param.as_str())
            .map(|value| (*value).to_owned())
            .ok_or_else(|| fail(65, format!("undeclared parameter {param}"))),
    }
}
pub fn resolve(args: &[Argument], values: &BTreeMap<&str, &str>) -> Result<Vec<String>> {
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
        let values = BTreeMap::from([("word", "two ' words")]);
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
