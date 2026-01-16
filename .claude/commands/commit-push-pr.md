---
name: commit-push-pr
description: Stage, commit, push changes and optionally create a PR
---

# Commit, Push, and PR Workflow

Execute the following steps to commit and push changes:

## 1. Check Current Status

```bash
git status
git diff --stat
```

## 2. Run Quality Gates

Before committing, ensure code quality:

```bash
bundle exec rubocop -A
rails test
bundle exec brakeman -q --no-pager
```

If any quality gate fails, fix the issues before proceeding.

## 3. Stage Changes

Review and stage changes:

```bash
git add -A
git status
```

## 4. Create Commit

Generate a commit message following conventional commits:

Format: `<type>(<scope>): <description>`

Types:
- `feat`: New feature
- `fix`: Bug fix
- `refactor`: Code refactoring
- `test`: Adding tests
- `docs`: Documentation
- `chore`: Maintenance

Example:
```bash
git commit -m "feat(cards): add ability to close cards

- Add Closure model for state tracking
- Add Cards::ClosuresController
- Add Closeable concern
- Include tests for closing behavior"
```

## 5. Push Changes

```bash
git push origin $(git branch --show-current)
```

## 6. Create PR (Optional)

If GitHub CLI is available:

```bash
gh pr create --title "feat(cards): add ability to close cards" --body "
## Summary
Added the ability to close cards using a state record pattern.

## Changes
- Closure model tracks when/who closed a card
- Closeable concern for reusable closing behavior
- REST endpoint at POST /cards/:id/closure

## Testing
- Added unit tests for Closeable concern
- Added controller tests for closure actions
"
```

## Notes

- Always run quality gates before committing
- Write descriptive commit messages
- Keep commits focused on single concerns
- Reference issue numbers if applicable
