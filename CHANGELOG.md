# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-03-19

### Added

- Initial release extracted from [Rodar](https://github.com/rodar-project/rodar)
- `RodarFeel.eval/2` — parse and evaluate FEEL expressions
- `RodarFeel.Parser` — NimbleParsec-based FEEL parser producing AST
- `RodarFeel.Evaluator` — tree-walking evaluator with null propagation and three-valued boolean logic
- `RodarFeel.Functions` — built-in FEEL functions (numeric, string, boolean, null)
