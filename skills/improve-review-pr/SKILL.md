---
name: improve-review-pr
description: Daily outer loop that reviews human reactions to automated review-pr comments, synthesizes durable knowledge about this repository, and opens a PR updating `.agents/review-lessons.md` when the feedback is worth remembering. Use when improving code-review quality from human feedback, running a scheduled review-skill retrospective, or incorporating maintainer corrections into review guidance.
---

# Improve Review PR

Run a once-per-day outer loop over the automated code-review stage.

The inner loop is already running: `review-pr` comments on pull requests throughout the day. This skill is the outer loop: read how humans reacted to those comments, extract durable knowledge, and record it in this repository's `.agents/review-lessons.md`, which `review-pr` reads on every run.

## Goal

Improve future automated reviews by learning from human validation and correction of previous `review-pr` comments.

Do not re-review product code. Do not restate one-off PR opinions. Only capture knowledge that should change how the review agent behaves on future PRs.

## Inputs

- The current checkout of the reviewed repository, including `.agents/review-lessons.md` when it exists
- The `review-pr` skill next to this one (`../review-pr/SKILL.md`), read-only: it is shared by every repository
- GitHub API access via authenticated `gh`
- Optional lookback window, default last 24 hours
- Optional `feedback_corpus.json` produced by:
  ```sh
  python3 <this skill dir>/scripts/collect_review_feedback.py \
    --repo OWNER/REPO \
    --since-hours 24 \
    --output feedback_corpus.json
  ```

If `feedback_corpus.json` is missing, run the collector yourself before analyzing.

## Workflow

### 1. Collect the day's review-agent interactions

Run or read `feedback_corpus.json`.

The corpus should include, for the lookback window:

- Pull requests that received an automated review from the review agent
- The review agent's top-level review bodies and inline comments
- Human replies to those comments
- Human reactions (for example `+1`, `eyes`, `confused`, `thumbs down`) when available
- Whether the human accepted a suggestion, dismissed it, edited around it, or explicitly disagreed
- Whether the PR author or another reviewer later fixed the same issue, ignored it, or called it wrong

Identify the review agent by login when possible (`github-actions[bot]`, a bot account, or a configured login). Prefer comments that originated from the `review-pr` publish path.

### 2. Score each feedback item

For each human interaction, classify the outcome:

- `validated` — human agreed, accepted the suggestion, or fixed the issue as recommended
- `corrected` — human said the finding was wrong, incomplete, too noisy, or the wrong severity
- `refined` — human mostly agreed but adjusted the guidance, scope, or preferred pattern
- `ambiguous` — not enough signal to learn from

Ignore pure acknowledgements with no substantive judgment.

### 3. Synthesize durable organizational knowledge

Look across the day's validated/corrected/refined items for patterns worth remembering. Good candidates:

- Repo conventions the review agent repeatedly misses
- False-positive classes that should be demoted or avoided
- Severity calibration mistakes
- Preferred alternatives to common suggestions
- Missing checks that humans keep adding manually
- Guidance about when not to comment

Reject learnings that are:

- One-off to a single PR or file
- Already covered well by `review-pr` or `.agents/review-lessons.md`
- Product-feature preferences unrelated to review quality
- Temporary project constraints unlikely to recur
- Lessons that would break the review-pr output schema, severity labels, safety rules, evidence rules, suggestion-block constraints, or annotated-diff line contract

Prefer a small number of high-confidence learnings over many weak ones.

### 4. Decide whether to update the lessons

Choose exactly one outcome:

- `no_changes`: no durable learning worth encoding
- `update_lessons`: add, tighten, or remove entries in `.agents/review-lessons.md`

The core `review-pr` skill is shared by every repository wired to the factory and is not edited here. When a learning looks portable rather than specific to this repository, still encode it as a lesson, and list it under **Portable learnings** in the report so a human can propose it upstream.

If no durable learning exists, stop after writing the synthesis report. Do not open an empty PR.

### 5. Apply lesson updates carefully

`.agents/review-lessons.md` is a short Markdown file. Create it with this header when it is missing:

```markdown
# Review lessons

Repository-specific guidance for the automated `review-pr` agent, learned from human
feedback on its comments. Each lesson is a durable rule. Keep the file short.
```

Then:

1. Read the current file completely.
2. Write each lesson as one `##` heading (the rule, in the imperative) followed by one or two sentences on why, and a link to one representative PR comment.
3. Tighten or remove an existing lesson rather than adding a contradicting one.
4. Write durable rules, not a diary of today's PRs.
5. Never add a lesson that changes the `review.json` schema, severity labels, safety rules, evidence rules, suggestion-block constraints, or annotated-diff line contract.

### 6. Open a lessons PR when there are changes

If you updated the lessons file:

1. Create a branch such as `chore/review-lessons-YYYY-MM-DD`
2. Commit only `.agents/review-lessons.md` with a short message
3. Push and open a PR against the repository default branch
4. In the PR body, include:
   - Summary of the human-feedback patterns observed
   - The lessons added, changed, or removed, and why each is durable
   - Links to representative source PRs/comments
   - Rejected candidates
   - Note that this PR only updates review guidance, not product code

Do not merge the PR. Leave it for human review.

### 7. Report the result

Return a concise report with:

```markdown
## Improve review-pr result
- **Window:** last N hours
- **PRs inspected:** count
- **Feedback items:** count validated / corrected / refined / ambiguous
- **Decision:** no_changes | update_lessons
- **Learnings encoded:** bullet list, or "none"
- **Lessons PR:** URL or "not opened"
- **Portable learnings:** lessons that would help every repository, to propose upstream on the `review-pr` skill, or "none"
- **Next step:** one concrete action for humans
```

If a lessons PR was opened, the report must include its URL.

## Guardrails

- Do not update product code, tests, or any skill file. Only `.agents/review-lessons.md` changes.
- Do not change the review-pr JSON schema, severity labels, safety rules, evidence rules, suggestion-block constraints, or annotated-diff line contract.
- Do not open a PR for weak, one-off, or already-encoded feedback.
- Do not invent human feedback that is not present in the corpus.
- Do not expose secrets, tokens, private environment variables, or internal reasoning dumps.
- Keep the lessons update small enough for a human to review quickly.
