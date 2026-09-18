# linux-dev-bootstrap

`linux-dev-bootstrap` is a small, standalone POSIX shell utility for bootstrapping a minimal Linux development environment across Debian, Ubuntu, and Alpine.

## Purpose

The script provides a simple, repeatable way to verify and install basic development prerequisites on minimal Linux systems, using only the native package manager and POSIX shell capabilities.

## Supported Distributions

- **Debian 12**
- **Ubuntu 22.04**
- **Ubuntu 24.04**
- **Alpine 3.20**

## Required Packages

The bootstrap process ensures the following packages and tools are present:

- `git`
- `curl`
- `jq`
- `python3`
- `ca-certificates`

## Installation and Setup

Clone the repository:

```sh
git clone https://github.com/Mresyzz/linux-dev-bootstrap.git
cd linux-dev-bootstrap
chmod +x install.sh
```

## Usage

### 1. Normal Installation

Installs any missing required packages using the system package manager (`apt-get` or `apk`). Only missing packages are installed; already installed tools are skipped.

```sh
sudo ./install.sh
```

### 2. Environment Verification (`--check`)

Inspects required tools without modifying the system state. Prints status for each prerequisite and exits with code `0` if all are available, or non-zero if any required tool is missing.

```sh
./install.sh --check
```

*Note: Does not require root privileges.*

### 3. Dry Run (`--dry-run`)

Detects the system package manager and inspects missing packages, printing the exact package management commands that would be executed without running them.

```sh
./install.sh --dry-run
```

*Note: Does not require root privileges.*

### 4. Help (`--help` / `-h`)

Displays usage syntax and available flags:

```sh
./install.sh --help
```

## CI Safety Behavior

To prevent unattended CI environments from unintentionally altering their host or container package state, `install.sh` incorporates a CI safety mechanism:

- If `CI=true` is present in the environment and no explicit command-line argument is supplied, `install.sh` automatically defaults to `--dry-run` mode.
- A notification (`CI environment detected; running in dry-run mode.`) is printed to stdout.
- Explicit flags such as `--check` or `--dry-run` always take precedence when provided.

## Privilege Requirements

- **`--check` and `--dry-run`**: Run entirely unprivileged and never require `root` or `sudo`.
- **Install Mode**: Requires administrative privileges (`root` / `uid 0`) to invoke package managers. If run as an unprivileged user when packages need to be installed, the script terminates immediately with a diagnostic message directing the user to rerun with `sudo` or as root. The script never silently invokes `sudo` or attempts privilege escalation.

## Current Limitations

- Package manager support is limited to `apt-get` (Debian/Ubuntu) and `apk` (Alpine). Other distributions (e.g., Fedora, Arch Linux) are currently unsupported.
- The installed package set is fixed to basic development dependencies (`git`, `curl`, `jq`, `python3`, `ca-certificates`). It is not intended as a general-purpose package manager wrapper or system configuration framework.

## CI Portability Testing

Automated testing in GitHub Actions consists of two independent checks:

1. **ShellCheck**: Static POSIX shell analysis using `shellcheck install.sh` on `ubuntu-latest`.
2. **Runtime Portability**: Multi-distribution compatibility verification using [OpsScript Gate](https://github.com/Mresyzz/opsscript-gate) (`Mresyzz/opsscript-gate@v0.2.0`). Because OpsScript Gate sets `CI=true`, the script exercises its safe dry-run path across targeted container environments (Debian, Ubuntu, Alpine) without modifying the container images.

## License

This project is licensed under the [MIT License](LICENSE).
