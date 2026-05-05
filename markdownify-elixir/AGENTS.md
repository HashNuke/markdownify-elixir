# AGENTS.md

## Project Boundary

This directory contains the Elixir library `markdownify_ex`. The repository root
contains the retained upstream Python project and should remain untouched unless
the user explicitly asks to update the Python fork.

## Versioning Policy

Keep the Elixir package major and minor version aligned with the upstream Python
`markdownify` project. The current Python version is recorded in the root
`pyproject.toml`.

For example, if Python `markdownify` is `1.2.2`, the Elixir package should stay
on the `1.2.x` line. Use the patch version for Elixir-specific releases,
compatibility fixes, docs, or parity improvements on that upstream line.

When the upstream Python project moves to a new major or minor version:

1. Port the relevant behavior into `lib/`.
2. Update or extend the parity tests that read the root Python `tests/` tree.
3. Set `@version` in `mix.exs` to the matching major/minor version with an
   appropriate Elixir patch version.
4. Update docs and run the verification commands below.

Use `bin/bump-version [minor|patch]` for version changes. The default bump is
`patch`. Use `bin/release` after committing release changes to create the
annotated `vX.Y.Z` git tag from the `@version` value in `mix.exs`. Both scripts
support `--dry-run`.

## Verification

Run from this directory:

```sh
mix test
mix compile --warnings-as-errors
mix docs
mix hex.build --unpack --output /tmp/markdownify_ex_hex_build
```

Generated directories such as `_build/`, `deps/`, and `doc/` are ignored and
should not be committed.
