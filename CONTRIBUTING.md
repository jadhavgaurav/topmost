# Contributing to Topmost

Thank you for your interest in contributing to **Topmost**!

## Code of Conduct

Please maintain a welcoming, respectful, and constructive environment for all contributors and users.

## Development Workflow

### Prerequisites
- macOS 14.0 or later
- Xcode Command Line Tools (`xcode-select --install`)
- Swift 5.9 or later

### Building the Project
```bash
# Build debug binary
swift build

# Build universal release binary
./scripts/build.sh
```

### Running Tests
```bash
./scripts/test.sh
```

### Packaging
```bash
./scripts/package.sh
```

## Pull Request Guidelines

1. Fork the repository and create your feature branch: `git checkout -b feature/amazing-feature`.
2. Follow Swift conventions, maintain clean modular architecture, and avoid introducing unnecessary third-party dependencies.
3. Add unit test coverage in `Tests/TopmostTests/main.swift` for any logic additions.
4. Ensure `./scripts/test.sh` passes with 0 failures before opening a pull request.
5. Provide a clear description of the change and any relevant context in your PR.
