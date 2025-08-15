# AGENTS for tools

This directory contains helper scripts for building and validating the
extension.

## Guidelines

- Scripts must be executable with Ruby 3.2.
- `smoke.rb` runs RuboCop, all unit tests and optional HTML/CSS linters.
  It aborts on the first failing check and prints "All smoke checks
  passed." only when every check succeeds.
- Add new checks or tooling updates to this file.
- Keep scripts self‑contained; avoid hard‑coded absolute paths.

## Testing

Run `ruby tools/smoke.rb` before opening a pull request.

