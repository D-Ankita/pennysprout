# PennySprout Recurrence Rules

Status: **NORMATIVE ALGORITHM**

All recurrence is calculated in the household IANA timezone. Server UTC timestamps are converted to one local date before occurrence evaluation. Clients never generate authoritative occurrence keys.

## 1. Shared rules

- `recurrence_anchor_date` is the first eligible local date. No occurrence exists before it.
- `activated_at` also limits availability; a task cannot be completed before it became active.
- `deactivated_at` prevents new submissions at/after that instant but does not alter old occurrences.
- Beta recurrence interval is exactly one.
- Completion time is database server time.
- An occurrence key is immutable once stored.
- Pending and approved submissions count toward `completion_limit`; rejected submissions do not.
- At most three rejected submissions are accepted per occurrence.
- A new submission is rejected if pending+approved count reached the limit or rejected count reached three.

## 2. Occurrence algorithms

### One-time

- Available from the later of activation and anchor-date local midnight.
- Key: `once`.
- It has no calendar end while task remains active.
- First approved completion atomically changes task to `INACTIVE`.

### Daily

- Eligible on each local date on/after anchor date while active.
- Key: `day:YYYY-MM-DD`.
- Window: local midnight inclusive to next local midnight exclusive.

### Selected weekdays

- Same daily window, only when ISO weekday is in `task_schedule_weekdays` (`1=Monday` through `7=Sunday`).
- Key: `day:YYYY-MM-DD`.
- At least one weekday is required; duplicates are rejected.

### Weekly

- Week begins Monday local date and ends at next Monday local midnight.
- Key: `week:YYYY-MM-DD`, using the Monday local date.
- In the first week, availability begins at the later of activation, anchor-date local midnight, and week start.
- A task activated midweek is available for the remainder of that week.

## 3. Edits

- The task row/version changes immediately after Admin approval.
- Previously stored completions keep their task version, title, reward, local date and occurrence key snapshots.
- The new recurrence governs submissions created after the update.
- If an edit makes the current date eligible, the task is available immediately.
- If an edit makes the current date ineligible, no new submission is allowed; existing pending submissions remain reviewable under their snapshot.
- Completion-limit decreases do not invalidate existing pending/approved submissions. New submissions remain blocked until the occurrence ends.

## 4. Reporting availability

- One-time contributes one available occurrence once it becomes eligible, until approved; after approval it remains one historical available occurrence.
- Daily/weekday availability counts eligible local dates intersecting the report period and active lifetime.
- Weekly availability counts distinct eligible weekly keys intersecting the report period and active lifetime.
- Completion rate numerator counts occurrence keys with at least one approved completion, not total approved submissions. This prevents a multi-completion task from exceeding 100%.
- The denominator excludes dates before activation/anchor and at/after deactivation.

## 5. Boundary tests

Implement fixed-clock tests for 23:59:59/00:00 local boundaries, Sunday/Monday transition, activation and deactivation midwindow, recurrence edits during a window, multiple limits, three rejected attempts, and UTC timestamps that fall on a different local date.
