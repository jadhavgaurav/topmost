# Security Policy

## Supported versions

| Version | Supported |
| ------- | --------- |
| 0.2.x   | Yes |
| 0.1.x   | No. Update to 0.2.0 or later, which fixes serious stability problems. |

## What Topmost has access to

Topmost asks for Accessibility and Screen Recording. It uses them to follow one pinned window and show a picture of it. It makes no network calls, collects no data, and writes only its settings to disk. [docs/PERMISSIONS.md](docs/PERMISSIONS.md) explains each permission and what it is not used for.

## Reporting a vulnerability

Please report it privately. Do not open a public issue.

1. Use [GitHub private vulnerability reporting](https://github.com/jadhavgaurav/topmost/security/advisories/new), or email `gaurav.vjadhav01@gmail.com`.
2. Include the macOS version and architecture, the Topmost version, the steps to reproduce, and what an attacker could do with it.

The maintainer aims to acknowledge a report within a week, and to follow up when there is a fix or a decision. Please give a reasonable time to release a fix before you disclose it publicly. Reporters who ask for credit are named in the release notes.

## In scope

- Anything that lets another process abuse the permissions Topmost holds.
- Anything that makes Topmost capture more than the one window you pinned.
- Problems in `install.sh`, the release workflow or the published artifacts that could deliver a tampered build.

## Verifying a download

Each release publishes `SHA256SUMS`. `install.sh` checks it for you. To check by hand:

```bash
shasum -a 256 -c SHA256SUMS --ignore-missing
```

Releases are signed ad hoc, not with an Apple Developer ID, and are not notarized. See [docs/LIMITATIONS.md](docs/LIMITATIONS.md#10-not-notarized).
