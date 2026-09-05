# Praxis runtime dependencies

The runtime uses `serde` and `serde_json` for its manifest and event format,
and `libc` for Linux terminal, signal, lock, and process-group operations.
`Cargo.toml` and `Cargo.lock` pin the build inputs. The Nix compiler uses Axiom
schemas, validation results, and indexed sets; Krisis owns diagnostic codes,
labels, and rendering. Neither library is a runtime dependency.

## CLI and terminal libraries

| Library | Useful capabilities | Praxis decision |
| --- | --- | --- |
| [clap](https://docs.rs/clap/latest/clap/) | Dynamic command builders, typed values, possible values, help, aliases, groups, and completion integrations | Keep one small manifest-driven flag index shared by binding, runner-option separation, and completion. Adoption would need to preserve literal argv and the distinction between declared, supplied, and sensitive values. |
| [dialoguer](https://docs.rs/dialoguer/latest/dialoguer/) | Confirmation, selection, validated input, and hidden passwords | Keep the polling prompt reader so input shares the run's deadline and signal cancellation without detached reader threads. |
| [console](https://docs.rs/console/latest/console/) | Terminal styling, terminal detection, ANSI handling, and Unicode display width | Keep sparse boundary messages and three color states. The UI does not truncate or align labels by display width. |
| [indicatif](https://docs.rs/indicatif/latest/indicatif/) | Progress bars, rate-limited redraw, hidden progress, and output suspension | Keep append-only step events. Children own their live output, so a redraw loop would need output coordination that the runner deliberately does not impose. |
| [notify-rust](https://docs.rs/notify-rust/latest/notify_rust/) | Native desktop notifications through D-Bus | Keep an optional, environment-isolated helper with a delivery deadline and process-group cleanup. No desktop dependency is needed for normal execution. |

These are compatibility and ownership decisions, not measured claims that
handwritten code is faster or smaller. The benchmark harness measures Praxis
workloads; it does not compare these libraries. No additional Rust dependency
is needed for the current interaction model.

## Integration constraints

Clap's [`Arg::env`](https://github.com/clap-rs/clap/blob/master/clap_builder/src/builder/arg.rs)
reads an environment value when the argument is constructed. Sensitive source
descriptors must not use that path: help, inspection, and completion must not
resolve credentials. An adoption can still use clap for ordinary inputs while
keeping sensitive binding separate.

Dialoguer's documented [`Password::interact`](https://docs.rs/dialoguer/latest/dialoguer/struct.Password.html)
provides hidden synchronous input, but exposes no run-deadline argument. Praxis
needs cancellation, timeout, EOF handling, and terminal restoration on the same
input path, including discarding unfinished hidden input before restoring echo.

Indicatif's [`ProgressBar::suspend`](https://docs.rs/indicatif/latest/indicatif/struct.ProgressBar.html)
coordinates a redraw with other output and holds its internal lock during the
callback. Praxis avoids that coordination by writing immutable boundary events.
A child can therefore stream output or own the terminal without a progress bar
redrawing over it.

Notify-rust's [`Notification::timeout`](https://docs.rs/notify-rust/latest/notify_rust/struct.Notification.html)
sets the notification's display lifetime, not a bound on sending it. Praxis's
three-second helper deadline instead bounds delivery work, with the ordinary
process cleanup grace period on expiry. Notification failure is advisory.
