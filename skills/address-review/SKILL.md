---
name: address-review
description: Address review feedback and merge conflicts on an open GitHub pull request by merging the base branch when it conflicts, reading unresolved review comments and any extra fix request, changing code on the PR branch, validating the change, pushing a follow-up commit, and replying to each comment.
---

# Address Review

Fix the review feedback on the pull request passed in the prompt, on that pull request's own branch.

Expect the prompt to give the repository, the PR number and the branch, which is already checked out. It may also point to a `fix_request.md` file with extra instructions from a human.

The prompt also gives a mode. In `conflict` mode, only resolve merge conflicts with the base branch (step 0) and stop there. In `review` mode, run step 0 when needed, then the rest of the workflow.

## Workflow

### 0. Resolve merge conflicts with the base branch

Check `gh pr view <number> --json mergeable,baseRefName`. If `mergeable` is `CONFLICTING`:

- Run `git fetch origin <base>` then `git merge origin/<base>`. Never rebase and never force-push.
- For each conflicted file, find what changed it on the base branch (`git log --oneline HEAD..origin/<base> -- <file>`, then `gh pr list --state merged --search <sha>` for the PR behind it). Read that PR so you understand its intent.
- Resolve so that both sides keep working: the base branch's change and this PR's change. Do not drop either side's behavior to make the conflict go away.
- Validate with the repository's own checks (see `../repo-toolchain/SKILL.md`). Commit the merge with a message such as `Merge main and resolve conflicts`, then `git push`.
- Post one PR comment that lists the conflicted files, which PR on the base branch caused each conflict, and how you combined them.

If the two sides want incompatible behavior and you cannot keep both, run `git merge --abort`, push nothing, and post a PR comment that explains the conflict and asks a human to decide.

### 1. Gather the feedback

- Fetch the PR, its description and its latest reviews with `gh pr view <number> --json title,body,reviews,headRefName`.
- Fetch inline review comments with `gh api repos/<owner>/<repo>/pulls/<number>/comments`. Keep top-level comments (no `in_reply_to_id`) that nobody has answered yet.
- Read `fix_request.md` if it exists. A human wrote it; it takes priority over automated review comments when they conflict.
- If the PR links an issue with checked-in specs (`specs/<issue-slug>/PRODUCT.md` and `TECH.md`), read them. Specs win over review comments when they disagree; say so in your reply.

### 2. Decide, comment by comment

For each piece of feedback, decide whether to fix it or push back:

- **Fix** when it points to a real bug, a spec mismatch, or a clear improvement inside the PR's scope.
- **Push back** when it is wrong, out of scope, or contradicts the specs. Explain why in one or two sentences.

Do not widen the PR's scope. Do not rewrite unrelated code.

### 3. Change the code

- Make the smallest changes that address the feedback you accepted.
- Add or update tests when the feedback is about behavior.
- Validate with the repository's own checks: read `../repo-toolchain/SKILL.md` (next to this skill) to find and run them. Fix what you broke. Do not claim a check passed unless you ran it.

### 4. Push and reply

- Commit on the checked-out PR branch with a short message such as `Address review feedback`, then `git push`. Never force-push and never open a new PR.
- Reply to each inline comment you handled with `gh api repos/<owner>/<repo>/pulls/<number>/comments/<comment_id>/replies -f body=...`: one or two sentences saying what changed, or why you did not change it.
- Post one PR comment with `gh pr comment` that lists what was fixed, what was pushed back, and the validation results.

## Guardrails

- Only touch the PR branch named in the prompt.
- If the feedback cannot be addressed without a product decision, do not guess: post a PR comment with the specific question and stop without pushing.
- If validation fails and you cannot fix it, push nothing and explain the failure in a PR comment.
