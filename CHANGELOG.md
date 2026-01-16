# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.1] - 2026-01-16

### Fixed

- **Critical**: Fixed incorrect threshold logic for negative metrics (toxicity, hallucination, bias, etc.) with `partial` verdicts. High scores on negative metrics now correctly result in failures.
- **Concurrency**: The `--concurrency` option now gracefully falls back to sequential execution when the `parallel` gem is not installed, with a helpful warning message.

### Added

- Tests for negative metric edge cases (partial verdicts with inverted threshold logic)

## [0.1.0] - 2026-01-15

### Added

- Initial release of RubyLLM::Tribunal
- **Deterministic assertions**: `contains`, `regex`, `json`, `equals`, `starts_with`, `ends_with`, `min_length`, `max_length`, `word_count`, `max_tokens`, `url`, `email`, `levenshtein`
- **LLM-as-Judge assertions**: `faithful`, `relevant`, `correctness`, `refusal`, `hallucination`, `bias`, `toxicity`, `harmful`, `jailbreak`, `pii`
- **Embedding-based assertions**: `similar` (requires `neighbor` gem)
- **Red Team attack generation**: encoding attacks, injection attacks, jailbreak attacks
- **Multiple reporters**: console, text, JSON, HTML, GitHub Actions, JUnit XML
- **Test framework integration**: RSpec and Minitest helpers via `EvalHelpers` module
- **Dataset-driven evaluations**: JSON and YAML dataset support
- **Rake tasks**: `tribunal:init` and `tribunal:eval`
- **Custom judges**: Register your own evaluation criteria
- **Configuration**: Customizable models, thresholds, and verbosity

### Dependencies

- Requires Ruby >= 3.2
- Requires `ruby_llm` >= 1.0
- Optional: `neighbor` gem for embedding-based similarity

[Unreleased]: https://github.com/Alqemist-labs/ruby_llm-tribunal/compare/v0.1.1...HEAD
[0.1.1]: https://github.com/Alqemist-labs/ruby_llm-tribunal/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/Alqemist-labs/ruby_llm-tribunal/releases/tag/v0.1.0
