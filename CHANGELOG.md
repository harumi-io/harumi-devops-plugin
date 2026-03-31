# Changelog

## Unreleased

- `setup-devops-config` skill: detects stack from codebase and generates `.devops.yaml`
- Registered `setup-devops-config` in the `using-devops` bootstrap skill trigger rules
- Eval infrastructure: `eval-viewer/` and `scripts/aggregate_benchmark.py` (ported from skill-creator)
- Evals for all three skills: `infrastructure`, `setup-devops-config`, `using-devops`
- Sample mock-repo fixtures for `setup-devops-config` evals (AWS+GitHub Actions, GCP+GitLab CI)

## 0.1.0

- Initial release
- Plugin scaffold with Claude Code and Cursor manifests
- Session-start hook with `.devops.yaml` config loading
- `using-devops` bootstrap skill
- `infrastructure` skill (generalized from Harumi.io devops skill)
- Default `.devops.yaml` config
