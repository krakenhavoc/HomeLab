# Contributing to HomeLab

Thank you for your interest in contributing to this HomeLab project! This guide will help you understand how to contribute effectively.

## 🎯 Purpose

This repository serves as a portfolio and documentation of my homelab infrastructure. While it's primarily a personal project, suggestions and improvements are welcome.

## 📋 Types of Contributions

### Welcome Contributions

- **Bug Reports**: Found an error in documentation or code? Let me know!
- **Documentation Improvements**: Typos, clarifications, or additional explanations
- **Code Enhancements**: Better practices, security improvements, or optimizations
- **Suggestions**: Ideas for better organization or additional features

### Not Accepting

- Major architectural changes (this reflects my personal setup)
- Alternative technology stacks (unless for comparison purposes)
- Personal preference changes without clear benefit

## 🚀 How to Contribute

### Reporting Issues

1. Check if the issue already exists
2. Use the issue template if available
3. Provide clear description and context
4. Include relevant system information if applicable

### Suggesting Enhancements

1. Open an issue first to discuss the enhancement
2. Explain the benefit and use case
3. Consider if it applies broadly or just to your setup

### Pull Requests

1. **Clone the Repository**
   ```bash
   git clone https://github.com/krakenhavoc/HomeLab.git
   cd HomeLab
   git checkout -b feature/your-feature-name
   ```

2. **Configure Pre-Commit**
    ```bash
    python -m venv <venv-name>
    source ./<venv-name>/bin/activate
    pip install pre-commit
    pre-commit install
    ```

3. **Make Your Changes**
   - Follow existing code style
   - Update documentation as needed
   - Test your changes thoroughly

4. **Commit Guidelines**
   ```bash
   git commit -m "type: brief description"
   ```

   Commit types:
   - `feat`: New feature
   - `fix`: Bug fix
   - `docs`: Documentation changes
   - `style`: Formatting changes
   - `refactor`: Code refactoring
   - `test`: Adding tests
   - `chore`: Maintenance tasks

5. **Submit Pull Request**
   - Provide clear description of changes
   - Reference any related issues
   - Ensure all checks pass
   - Complete the PR template checklist
   - Request review from maintainers

### PR Guidelines

- **Title**: Use conventional commit format (e.g., `feat: add new feature`)
- **Description**: Explain what and why, not just how
- **Size**: Keep PRs small and focused (prefer multiple small PRs)
- **Tests**: Include tests if applicable
- **Documentation**: Update relevant docs
- **Breaking Changes**: Clearly mark and explain any breaking changes

### Branching Strategy

- `main` - Production-ready code
- `feature/*` - New features
- `fix/*` - Bug fixes
- `docs/*` - Documentation updates
- `chore/*` - Maintenance tasks

### Reviewer Checklist

When reviewing PRs, check for:

- [ ] Code follows project style guidelines
- [ ] Documentation is updated
- [ ] Commit messages follow convention
- [ ] No sensitive data (secrets, passwords)
- [ ] Tests pass (if applicable)
- [ ] Changes are backwards compatible (or breaking changes documented)
- [ ] No unnecessary files committed
- [ ] PR description is clear and complete

## 📝 Documentation Standards

### Markdown Files

- Use clear, concise language
- Include code examples where helpful
- Keep formatting consistent
- Update table of contents if applicable

### Code Comments

- Comment complex logic
- Include usage examples
- Document parameters and return values
- Explain non-obvious decisions

### README Files

Each directory should have a README explaining:
- Purpose of the directory
- Contents overview
- Usage instructions
- Related documentation

## 🔒 Security

### Reporting Security Issues

If you discover a security vulnerability:
1. **DO NOT** open a public issue
2. Email details privately (see repository contact)
3. Include steps to reproduce
4. Allow reasonable time for response

### Security Best Practices

- Never commit credentials or secrets
- Use environment variables for sensitive data
- Follow principle of least privilege
- Keep dependencies updated

## 💻 Code Style

### Shell Scripts

```bash
#!/usr/bin/env bash

# Use strict mode
set -euo pipefail

# Constants in UPPERCASE
readonly CONST_VAR="value"

# Functions in lowercase with underscores
function_name() {
    local var="value"
    # Implementation
}

# Clear error handling
error_exit() {
    echo "Error: $1" >&2
    exit 1
}
```

### Python Scripts

```python
#!/usr/bin/env python3
"""Module docstring describing purpose."""

import os
import sys

# Constants
CONSTANT_NAME = "value"

def function_name(param: str) -> bool:
    """Function docstring.

    Args:
        param: Parameter description

    Returns:
        Return value description
    """
    pass

if __name__ == '__main__':
    main()
```

### Terraform

```hcl
# Use descriptive resource names
resource "proxmox_vm_qemu" "web_server" {
  # Group related settings
  name        = "web-server-01"
  target_node = var.proxmox_node

  # Comment complex configurations
  # This enables cloud-init for automated setup
  os_type = "cloud-init"
}

# Always use variables for configurable values
variable "vm_count" {
  description = "Number of VMs to create"
  type        = number
  default     = 3
}
```

### Ansible

```yaml
---
# Use descriptive task names
- name: Install and configure Nginx
  hosts: web_servers
  become: yes

  tasks:
    # Group related tasks
    - name: Install Nginx
      apt:
        name: nginx
        state: present

    # Use handlers for service restarts
    - name: Copy Nginx config
      template:
        src: nginx.conf.j2
        dest: /etc/nginx/nginx.conf
      notify: Reload Nginx

  handlers:
    - name: Reload Nginx
      service:
        name: nginx
        state: reloaded
```

## 🧪 Testing

### Before Submitting

- [ ] Code runs without errors
- [ ] Documentation is updated
- [ ] Scripts are executable (chmod +x)
- [ ] No sensitive data in commits
- [ ] Follows project style guide

### Script Testing

```bash
# Test script syntax
bash -n script.sh

# Lint shell scripts
shellcheck script.sh

# Test with dry-run if available
./script.sh --dry-run
```

## 📦 Dependencies

### Adding New Dependencies

When adding new tools or dependencies:
1. Explain why it's needed
2. Document installation steps
3. Update prerequisites in README
4. Consider alternatives available

## 🤝 Code of Conduct

### Our Standards

- Be respectful and constructive
- Focus on what's best for the project
- Accept feedback gracefully
- Show empathy towards others

### Unacceptable Behavior

- Harassment or discriminatory language
- Trolling or insulting comments
- Personal or political attacks
- Publishing others' private information

## 📞 Getting Help

- Open an issue for questions
- Check existing documentation first
- Be specific about your environment
- Include relevant logs or error messages

## 🏆 Recognition

Contributors will be acknowledged in:
- README.md contributors section
- Release notes for significant contributions
- Commit history

## 📄 License

By contributing, you agree that your contributions will be licensed under the MIT License.

## 🔄 Review Process

1. Maintainer will review within 1-2 weeks
2. Feedback will be provided if changes needed
3. Once approved, PR will be merged
4. Thanks for contributing! 🎉

## 📚 Additional Resources

- [GitHub Flow Guide](https://guides.github.com/introduction/flow/)
- [Writing Good Commit Messages](https://chris.beams.io/posts/git-commit/)
- [Markdown Guide](https://www.markdownguide.org/)

---

Thank you for helping improve this HomeLab project! Your contributions are appreciated.
