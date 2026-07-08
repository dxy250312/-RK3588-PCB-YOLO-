# Contributing

Thank you for your interest in this project. Contributions are welcome for documentation, reproducible scripts, deployment notes, UI improvements, and bug fixes.

## Reporting Issues

Before opening an issue:

1. Search existing issues to avoid duplicates.
2. Describe your hardware and software environment.
3. Provide clear steps to reproduce the problem.
4. Attach only public, non-sensitive logs or screenshots.
5. Do not attach private datasets, model binaries, or business images.

Useful issue information:

- Operating system and board model.
- Python version.
- RKNN Toolkit version.
- Command used.
- Expected behavior.
- Actual behavior.

## Pull Requests

Before submitting a pull request:

1. Keep changes focused.
2. Do not include datasets, images, model binaries, logs, or generated outputs.
3. Update documentation when commands or paths change.
4. Run syntax checks for modified Python files.
5. Make sure the repository can still be cloned and used without private files.

## Code Style

Python:

- Follow PEP 8.
- Prefer type hints for public functions.
- Use `argparse` for command-line tools.
- Use clear exceptions for failure cases.
- Keep algorithm changes separate from formatting changes.

C/C++:

- Use clear file names and function names.
- Keep UI code and processing code separated where possible.
- Prefer CMake targets over hard-coded build commands.

Vala/GTK:

- Keep UI widgets, services, and configuration in separate files.
- Put hardware paths and runtime constants in configuration files.
- Avoid absolute machine-specific paths in source code.

## Documentation Style

- Keep README commands copyable.
- Use placeholder paths such as `<project_root>` and `<dataset_root>`.
- Document assumptions for board wiring and runtime files.

## Release Checklist

Before release, verify:

- No dataset files are included.
- No model binaries are included.
- No local machine paths are included.
- No board addresses are included.
- No private business material is included.
- The archive size is below the required limit.
