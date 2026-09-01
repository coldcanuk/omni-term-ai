# 🤖 AGENT PRIME DIRECTIVE

**All AI Agents contributing to this repository MUST strictly adhere to the following Git Worktree methodology.**

### 🛑 Rule 1: No Direct Commits to Main
Writing, modifying, or committing directly to the `main` branch is **strictly prohibited**. The `main` branch must remain pristine and only be updated via Pull Requests.

### 🌳 Rule 2: Always Use Worktrees
All new features, bug fixes, or documentation updates must be isolated in a new Git worktree.
```bash
git worktree add -b gb/<feature-name> .worktrees/gb-<feature-name>-wt
cd .worktrees/gb-<feature-name>-wt
```

### 📤 Rule 3: Commit and Push
All work must be committed and pushed to the remote branch of the worktree.
```bash
git add .
git commit -m "feat: <description>"
git push -u origin gb/<feature-name>
```

### 🔀 Rule 4: Pull Request & Merge
When the job is complete, do not merge locally. You must open a Pull Request against `main`, and merge the PR.
```bash
gh pr create --title "<Title>" --body "<Description>"
gh pr merge --merge --delete-branch
```

### 🧹 Rule 5: Cleanup
After a successful merge, the local worktree must be safely deleted.
```bash
cd /opt/repo/omni-term-ai
git checkout main
git pull origin main
git worktree remove .worktrees/gb-<feature-name>-wt
```
