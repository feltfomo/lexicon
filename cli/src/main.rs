use std::process::ExitCode;

fn main() -> ExitCode {
    let arguments: Vec<String> = std::env::args().skip(1).collect();

    let request = match lexicon::parse(&arguments) {
        Ok(request) => request,
        Err(refusal) => {
            eprintln!("{refusal}");

            return ExitCode::FAILURE;
        }
    };

    match lexicon::execute(&request) {
        Ok(None) => ExitCode::SUCCESS,
        Ok(Some(report)) => {
            eprintln!("{report}");

            ExitCode::FAILURE
        }
        Err(refusal) => {
            eprintln!("{refusal}");

            ExitCode::FAILURE
        }
    }
}
