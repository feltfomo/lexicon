mod arguments;
mod cli;
mod model;
mod plan;
mod process;
mod run;

use model::{Manifest, Result, fail};
fn main() {
    if let Err(error) = entry() {
        eprintln!("praxis: {}", model::clean(&error.message));
        std::process::exit(error.code);
    }
}
fn entry() -> Result<()> {
    let mut args = std::env::args_os()
        .skip(1)
        .map(|arg| {
            arg.into_string()
                .map_err(|_| fail(64, "arguments must be valid UTF-8"))
        })
        .collect::<Result<Vec<_>>>()?
        .into_iter();
    if args.next().as_deref() != Some("--manifest") {
        return Err(fail(
            64,
            "usage: praxis --manifest FILE list|show|plan|run|completions",
        ));
    }
    let path = args
        .next()
        .ok_or_else(|| fail(64, "--manifest needs a file"))?;
    let bytes = std::fs::read(&path).map_err(|e| fail(66, format!("manifest {path}: {e}")))?;
    let manifest: Manifest =
        serde_json::from_slice(&bytes).map_err(|e| fail(65, format!("invalid manifest: {e}")))?;
    if manifest.version != 1 {
        return Err(fail(
            65,
            format!("unsupported manifest version {}", manifest.version),
        ));
    }
    cli::dispatch(&manifest, args.collect())
}
