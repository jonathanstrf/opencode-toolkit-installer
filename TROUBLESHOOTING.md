# TROUBLESHOOTING

1) "ERROR: rsync is required"
   - Install rsync (macOS: preinstalled; on some minimal systems install via package manager).

2) Repo not found
   - Ensure ai-toolkit is cloned to the path you passed with --spartan-repo, or allow auto-clone.

3) Commands not discovered by OpenCode
   - Verify files landed in ~/.config/opencode/commands/
   - Restart OpenCode or your terminal session.

4) CLAUDE.md not enhanced
   - Ensure enhance-claude-portable.sh is present and executable in the package.
