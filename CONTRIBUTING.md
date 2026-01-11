# Contributing to MacSync

Thanks for taking the time to contribute! ❤️

## Quick Start

1. Fork the repo
2. Create a branch: `git checkout -b feature/my-feature`
3. Make your changes
4. Run tests: `bats test/macsync.bats`
5. Commit: `git commit -m 'Add my feature'`
6. Push and open a Pull Request

## Development Setup

**Prerequisites:**

- `zsh`
- `bats-core` (`brew install bats-core`)
- `rsync`

**Running Tests:**

```bash
bats test/macsync.bats
```

**Sandbox Testing:**

For safe manual testing without affecting your real files:

```bash
./test/sandbox.zsh start   # Enter sandbox
./test/sandbox.zsh reset   # Reset to fresh state
./test/sandbox.zsh clean   # Remove sandbox
```

## Reporting Bugs

1. Check existing [issues](https://github.com/Pilaton/MacSync/issues)
2. Open a new issue with:
   - MacSync version (`macsync --version`)
   - macOS version
   - Steps to reproduce
   - Expected vs actual behavior

## Suggesting Features

Open an issue describing:

- What you want to achieve
- Why it would be useful
- Possible implementation (optional)

## Code Style

- Follow [Google's Shell Style Guide](https://google.github.io/styleguide/shellguide.html)
- Use Zsh features where appropriate
- Run `shellcheck` before submitting

## Commit Messages

- Use present tense: "Add feature" not "Added feature"
- Use imperative mood: "Fix bug" not "Fixes bug"
- Keep first line under 72 characters

## Code of Conduct

Please read our [Code of Conduct](CODE_OF_CONDUCT.md) before contributing.
