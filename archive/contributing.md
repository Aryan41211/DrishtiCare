# Contributing to DrishtiCare

## Git Workflow

1. Create feature branch from `main`: `git checkout -b module-X-name`
2. Make changes, commit with descriptive messages
3. Push and create PR for review
4. Merge after approval

## Commit Convention

```
type(scope): description

Types: feat, fix, docs, refactor, test, chore
Scopes: quality, segmentation, grading, explainability, simulink, data, validation
```

Examples:
- `feat(grading): implement ordinal binary decomposition head`
- `fix(segmentation): correct vessel scale mismatch DRIVE→IDRiD`
- `docs(validation): add ablation table template`

## Code Conventions (MATLAB)

- Use `camelCase` for variables and functions
- Use `PascalCase` for class names
- Document functions with `%` comments
- Keep functions under 100 lines where possible
- Group related functions in packages (`+quality`, `+segmentation`, etc.)

## File Organization

- Source code in `src/`
- Each module in its own subfolder under `src/`
- Tests in `tests/`
- Scripts for data processing in `scripts/`
- Documentation in `docs/`

## Review Process

- All PRs require at least 1 review before merge
- Run any available tests before submitting PR
- Update documentation when adding/changing features
