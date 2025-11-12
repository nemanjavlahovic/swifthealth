##### Conventional Commits Format (v1.0.0)

ALL commits MUST follow this format: type(scope): description

**Common Types:**
- feat: New feature
- fix: Bug fix
- docs: Documentation only
- refactor: Code restructuring without behavior change
- test: Adding or updating tests
- chore: Maintenance tasks (deps, config, etc)
- ci: CI/CD pipeline changes
- perf: Performance improvements
- build: Build system changes

**Scopes (examples):**
- cli, analyzer, scoring, deps, git, lint, core

**Examples:**
- feat(cli): add ASCII header banner with SWIFTHEALTH branding
- fix(scoring): correct weight normalization calculation
- docs: update README with installation instructions
- refactor(git): simplify commit parsing logic
- chore: update .gitignore to exclude AI iteration files

**Breaking Changes:**
Use exclamation mark before colon: feat!: redesign configuration format

##### Commit Guidelines

**Atomic Commits:**
- Only commit files you directly modified
- List paths explicitly in git commands
- Keep each commit focused on one logical change

**Technical Details:**
- For tracked files: git commit -m "type(scope): description" -- path/file1 path/file2
- For new files: git add file1 file2 && git commit -m "type(scope): description" -- file1 file2
- Quote paths with special characters: "path/[brackets]/file"

**Restrictions:**
- NO Claude branding in commit messages
- NO co-author tags
- Never amend commits without explicit approval
