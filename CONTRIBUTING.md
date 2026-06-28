# Contributing to KTStack

First of all, thank you for your interest in contributing to KTStack! 🎉

KTStack is an open-source native local development environment for macOS. Whether you're fixing a typo, reporting a bug, improving documentation, or implementing a new feature, every contribution is appreciated.

---

# Before You Start

Please take a moment to:

- Search existing Issues before creating a new one.
- Search existing Pull Requests before submitting one.
- Open an Issue first for large features or architectural changes.

This helps avoid duplicated work and allows us to discuss the best approach before implementation.

---

# Ways to Contribute

There are many ways to help:

- Report bugs
- Suggest new features
- Improve documentation
- Improve UI/UX
- Fix typos
- Improve performance
- Add or improve tests
- Submit bug fixes
- Review pull requests

Not every contribution has to be code.

---

# Reporting Bugs

When opening a bug report, please include:

- KTStack version
- macOS version
- Apple Silicon or Intel
- Steps to reproduce
- Expected behavior
- Actual behavior
- Screenshots (if applicable)
- Relevant logs

The more information you provide, the easier it is to reproduce and fix the issue.

---

# Feature Requests

Feature requests are welcome.

Please explain:

- The problem you're trying to solve
- Your current workflow
- Why existing behavior isn't sufficient
- Your proposed solution (if you have one)

Real-world use cases are especially valuable.

---

# Development Setup

## Requirements

- macOS 13+
- Xcode 15+
- XcodeGen

Install XcodeGen:

```bash
brew install xcodegen
```

Generate the project:

```bash
xcodegen generate
```

Build:

```bash
xcodebuild \
  -project KDWarm.xcodeproj \
  -scheme KDWarm \
  -destination 'platform=macOS' \
  build
```

Run tests:

```bash
xcodebuild \
  -project KDWarm.xcodeproj \
  -scheme KDWarmKit-Tests \
  -destination 'platform=macOS' \
  test
```

---

# Coding Guidelines

Please try to follow the existing project style.

General expectations:

- Keep changes focused.
- Avoid unrelated refactoring.
- Prefer readable code over clever code.
- Write descriptive commit messages.
- Add tests when appropriate.
- Update documentation if behavior changes.

If you're unsure about a design decision, open an Issue first.

---

# Pull Requests

Before submitting a Pull Request:

- Ensure the project builds successfully.
- Ensure tests pass.
- Keep the PR focused on a single change.
- Update documentation if needed.

Please include:

- What changed
- Why it changed
- Screenshots (for UI changes)
- Linked Issue (if applicable)

Small, focused pull requests are easier to review.

---

# Commit Messages

Examples:

```
feat: support arbitrary project directories

fix: prevent nginx restart race condition

docs: improve installation guide

refactor: simplify runtime manager

test: add site registration tests
```

---

# Design Philosophy

KTStack aims to be:

- Native
- Lightweight
- Fast
- Predictable
- Developer-friendly

A core principle of the project is:

> KTStack should adapt to the developer's workflow—not require the developer to adapt to KTStack.

When proposing new features, please keep this philosophy in mind.

---

# Code of Conduct

Please be respectful and constructive.

We welcome contributors of all experience levels.

Friendly discussions, thoughtful feedback, and respectful disagreements help make the project better for everyone.

---

# Questions

If you're unsure where to start, feel free to open a Discussion or an Issue.

Even if you're new to Swift or open source, contributions are welcome.

Thanks for helping improve KTStack! 🚀