# File: .github/PULL_REQUEST_TEMPLATE.md

## 📋 Pull Request Summary

Brief description of what this PR accomplishes.

## 🔗 Related Issue

Closes #[issue_number]

## 📂 Type of Change

- [ ] 🐛 Bug fix (non-breaking change which fixes an issue)
- [ ] ✨ New feature (non-breaking change which adds functionality)
- [ ] 💥 Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] 📚 Documentation update
- [ ] 🧪 New lab/exercise
- [ ] 🔧 Refactoring (no functional changes)
- [ ] 🎨 Style/formatting changes
- [ ] 🚀 Performance improvement
- [ ] 🔒 Security improvement
- [ ] 🧹 Cleanup/maintenance

## 🎯 What Changed

### Added

- New feature or functionality
- New files or directories

### Modified

- Changes to existing functionality
- Updated files

### Removed

- Deprecated features
- Deleted files

### Fixed

- Bug fixes
- Corrections

## 🧪 Testing Performed

- [ ] Manual testing completed
- [ ] All existing examples still work
- [ ] New examples tested
- [ ] Docker builds successful
- [ ] Docker Compose services start correctly
- [ ] Documentation renders correctly
- [ ] Links are functional

### Test Environment

- **OS**: [Windows 11 / macOS Monterey / Ubuntu 20.04]
- **Docker Version**: [e.g. 24.0.6]
- **Docker Compose Version**: [e.g. 2.21.0]

### Test Commands Run

```bash
# List the key commands you used to test
docker build -t test-image .
docker-compose up -d
# etc.
```

## 📋 Checklist

### Code Quality

- [ ] Code follows project style guidelines
- [ ] Self-review of code completed
- [ ] Code is well-commented, particularly in hard-to-understand areas
- [ ] No unnecessary files included
- [ ] No sensitive information (passwords, keys, etc.) included

### Documentation

- [ ] README files updated (if applicable)
- [ ] Inline comments added for complex logic
- [ ] Documentation is clear and helpful
- [ ] Examples are working and tested

### Docker Best Practices

- [ ] Dockerfile follows best practices (if applicable)
- [ ] Images are optimized for size
- [ ] Security practices followed
- [ ] No hardcoded secrets
- [ ] Appropriate user permissions set
- [ ] Health checks included (if applicable)

### Repository Standards

- [ ] Branch is up-to-date with main/develop
- [ ] Commit messages are descriptive
- [ ] Changes are focused and atomic
- [ ] No merge conflicts

## 🔄 Breaking Changes

If this includes breaking changes, please describe:

- What breaks
- Why the change was necessary
- How users should adapt their code
- Migration guide (if complex)

## 📸 Screenshots/Demos

If applicable, add screenshots or demo output:

### Before

```
# Show previous behavior/output
```

### After

```
# Show new behavior/output
```

## 📚 Learning Value

How does this contribution help users learn Docker?

- [ ] Introduces new concept
- [ ] Provides clearer examples
- [ ] Demonstrates best practices
- [ ] Solves common problems
- [ ] Improves user experience

## 🎯 Reviewer Focus Areas

What should reviewers pay special attention to?

- [ ] Security implications
- [ ] Performance impact
- [ ] Documentation clarity
- [ ] Code correctness
- [ ] User experience
- [ ] Breaking changes

## 📝 Additional Notes

Any additional context, concerns, or considerations:

### Future Work

- [ ] Follow-up tasks needed
- [ ] Related issues to create
- [ ] Additional improvements planned

### Questions for Reviewers

- Any specific questions or areas where you'd like feedback

---

## 📋 For Maintainers

### Review Checklist

- [ ] Code quality meets standards
- [ ] Tests pass (if applicable)
- [ ] Documentation is accurate
- [ ] No security concerns
- [ ] Follows project conventions
- [ ] Ready to merge

### Merge Strategy

- [ ] Squash and merge
- [ ] Create merge commit
- [ ] Rebase and merge

---

**🙏 Thank you for contributing to DockVerseHub! Your improvements help the entire Docker learning community.**
