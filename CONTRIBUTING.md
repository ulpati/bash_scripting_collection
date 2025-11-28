# Contributing

Thank you for your interest in contributing to this project!

## 🐛 Reporting Issues

Open an issue with:
- Problem description and steps to reproduce
- Environment details (OS, bash version)
- Error messages or logs

## 💡 Feature Requests

Include:
- Feature description and use case
- Implementation approach (if applicable)

## 🔧 Contributing Code

### Pull Request Process

1. Fork the repository and create a feature branch
2. Follow coding standards (see below)
3. Test thoroughly and check syntax: `bash -n script_name.sh`
4. Update documentation
5. Submit PR with clear description

### Adding New Scripts

**Required files**:
- `script_name.sh` - Executable script
- `script_name.md` - Complete documentation

**Script standards**:
- Use `#!/bin/bash` and `set -euo pipefail`
- Implement `--help` flag
- Follow `lowercase_underscore` naming
- Include error handling and inline comments
- Quote variables: `"$var"` not `$var`

**Documentation** (`script_name.md`):
- Purpose and dependencies
- Usage examples with options
- Common use cases and troubleshooting

**Update**:
- Add entry to main `README.md`
- Test edge cases before submitting

## 📝 Code Style

- Use `readonly` for constants
- Prefer `[[ ]]` over `[ ]` for conditionals
- Use meaningful variable names
- Add comments for complex logic
- Follow existing code patterns

## ⚖️ License

By contributing, you agree that your contributions will be licensed under the [CC BY-NC-SA 4.0 License](./LICENSE).