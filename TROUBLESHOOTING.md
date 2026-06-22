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

5) Running .sh files on Windows
   - .sh files require a bash interpreter. Options:
     a) Use the native PowerShell installer instead (recommended):
        .\scripts\setup-opencode-toolkits.ps1
     b) Git Bash — open Git Bash and run:
        bash ~/Code/opencode-toolkit-installer/scripts/setup-opencode-toolkits.sh
     c) WSL — open a WSL terminal and run:
        bash ~/Code/opencode-toolkit-installer/scripts/setup-opencode-toolkits.sh

6) enhance-claude-portable.sh fails on Windows
   - Run the native PowerShell version instead:
     .\scripts\enhance-claude-portable.ps1
