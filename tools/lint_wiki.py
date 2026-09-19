#!/usr/bin/env python3
"""Wiki and agent-configuration linter.

Enforces the rules in AGENTS.md and wiki/conventions/ that would otherwise decay
across a long session. Instruction compliance attenuates as a session runs; a
check that executes is worth more than a rule that is remembered.

Usage:
    python3 tools/lint_wiki.py            # check everything
    python3 tools/lint_wiki.py --quiet    # only print failures

Exit codes:
    0  clean (warnings may still be printed)
    1  one or more errors
"""

from __future__ import annotations

import argparse
import datetime as dt
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
WIKI = ROOT / "wiki"

REQUIRED_FRONTMATTER = (
    "id",
    "title",
    "status",
    "owner",
    "last_verified",
    "applies_to",
    "summary",
)
VALID_STATUS = {"active", "draft", "superseded"}
STALE_WARN_DAYS = 180
STALE_FAIL_DAYS = 365

FENCE = re.compile(r"^\s*(```|~~~)")
WORK_ITEM_DIR = re.compile(r"^\d{4}-[a-z0-9]+(-[a-z0-9]+)*$")
REVIEW_FILE = re.compile(r"^(research|plan|impl)-review-\d{2}\.md$")
AC_ID = re.compile(r"\bAC-\d{3}\b")
VAGUE = re.compile(r"\b(correctly|properly|as expected|appropriately)\b", re.I)

errors: list[str] = []
warnings: list[str] = []


def err(msg: str) -> None:
    errors.append(msg)


def warn(msg: str) -> None:
    warnings.append(msg)


def rel(path: Path) -> str:
    try:
        return str(path.relative_to(ROOT))
    except ValueError:
        return str(path)


def read(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except OSError as exc:  # pragma: no cover - unreadable file
        err(f"{rel(path)}: cannot read ({exc})")
        return ""


def parse_frontmatter(text: str) -> dict[str, str] | None:
    """Return top-level scalar keys of a leading YAML frontmatter block.

    Deliberately not a YAML parser: only the presence and shape of the required
    scalar keys is checked, so the linter has no third-party dependency.
    """
    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        return None
    fields: dict[str, str] = {}
    for line in lines[1:]:
        if line.strip() == "---":
            return fields
        if line.startswith((" ", "\t", "-")) or not line.strip():
            continue
        if ":" in line:
            key, _, value = line.partition(":")
            fields[key.strip()] = value.strip()
    return None  # unterminated block


# --------------------------------------------------------------------------- #
# Cross-tool configuration
# --------------------------------------------------------------------------- #


def check_instruction_bridge() -> None:
    agents = ROOT / "AGENTS.md"
    claude = ROOT / "CLAUDE.md"

    if not agents.is_file():
        err("AGENTS.md: missing. It is the single source of always-on instructions.")
    if not claude.is_file():
        err("CLAUDE.md: missing. Claude Code does not read AGENTS.md directly.")
        return

    body = read(claude)
    first = next((ln for ln in body.splitlines() if ln.strip()), "")
    if first.strip() != "@AGENTS.md":
        err(
            "CLAUDE.md: first non-empty line must be exactly '@AGENTS.md'. "
            "Claude Code reads CLAUDE.md, not AGENTS.md; the import is the bridge."
        )
    if len(body.splitlines()) > 40:
        warn(
            "CLAUDE.md: over 40 lines. Cursor loads AGENTS.md and CLAUDE.md both, "
            "so content here beyond a few Claude-only notes enters context twice."
        )

    if agents.is_file():
        n = len(read(agents).splitlines())
        if n > 200:
            err(f"AGENTS.md: {n} lines. Keep it under 200; adherence drops beyond that.")
        elif n > 150:
            warn(f"AGENTS.md: {n} lines. Approaching the 200-line limit.")


def check_rule_mirrors() -> None:
    claude_rules = ROOT / ".claude" / "rules"
    cursor_rules = ROOT / ".cursor" / "rules"

    a = {p.stem for p in claude_rules.glob("*.md")} if claude_rules.is_dir() else set()
    b = {p.stem for p in cursor_rules.glob("*.mdc")} if cursor_rules.is_dir() else set()

    for name in sorted(a - b):
        err(f".cursor/rules/{name}.mdc: missing mirror of .claude/rules/{name}.md")
    for name in sorted(b - a):
        err(f".claude/rules/{name}.md: missing mirror of .cursor/rules/{name}.mdc")

    if cursor_rules.is_dir():
        for stray in cursor_rules.glob("*.md"):
            err(
                f"{rel(stray)}: Cursor ignores .md in .cursor/rules/. Rename to .mdc."
            )

    for rule in sorted(a):
        text = read(claude_rules / f"{rule}.md")
        if not text.lstrip().startswith("---"):
            warn(
                f".claude/rules/{rule}.md: no frontmatter, so it loads in every session. "
                "Add a 'paths' field to scope it, or move it into AGENTS.md."
            )

    for rule in sorted(b):
        text = read(cursor_rules / f"{rule}.mdc")
        fm = parse_frontmatter(text)
        if fm is None:
            err(f".cursor/rules/{rule}.mdc: missing or unterminated frontmatter block.")
            continue
        if "alwaysApply" not in fm:
            err(f".cursor/rules/{rule}.mdc: frontmatter must declare alwaysApply.")
        unknown = set(fm) - {"description", "globs", "alwaysApply"}
        if unknown:
            err(
                f".cursor/rules/{rule}.mdc: unsupported frontmatter key(s) "
                f"{sorted(unknown)}. Cursor accepts only description, globs, alwaysApply."
            )


def check_no_commands() -> None:
    for d in (ROOT / ".claude" / "commands", ROOT / ".cursor" / "commands"):
        if d.is_dir() and any(d.iterdir()):
            err(
                f"{rel(d)}: commands are invisible to one of the two tools. "
                "Write the workflow as a skill under .claude/skills/ instead."
            )


def check_skills_and_agents() -> None:
    skills = ROOT / ".claude" / "skills"
    if skills.is_dir():
        for d in sorted(p for p in skills.iterdir() if p.is_dir()):
            md = d / "SKILL.md"
            if not md.is_file():
                err(f"{rel(d)}: skill directory without a SKILL.md.")
                continue
            fm = parse_frontmatter(read(md))
            if fm is None:
                err(f"{rel(md)}: missing or unterminated frontmatter block.")
                continue
            if fm.get("name") != d.name:
                err(
                    f"{rel(md)}: name '{fm.get('name')}' must match the directory "
                    f"name '{d.name}'."
                )
            if not fm.get("description"):
                err(f"{rel(md)}: description is required; it decides when the skill fires.")
            budget = len(fm.get("description", "")) + len(fm.get("when_to_use", ""))
            if budget > 1536:
                err(
                    f"{rel(md)}: description plus when_to_use is {budget} characters; "
                    "it is truncated at 1536 in the skill listing."
                )
            n = len(read(md).splitlines())
            if n > 500:
                err(f"{rel(md)}: {n} lines. Keep a skill under 500; move detail into references/.")

    agents = ROOT / ".claude" / "agents"
    if agents.is_dir():
        for md in sorted(agents.glob("*.md")):
            fm = parse_frontmatter(read(md))
            if fm is None:
                err(f"{rel(md)}: missing or unterminated frontmatter block.")
                continue
            for field in ("name", "description"):
                if not fm.get(field):
                    err(f"{rel(md)}: '{field}' is required in subagent frontmatter.")
            if ":" in fm.get("name", ""):
                err(f"{rel(md)}: subagent name may not contain ':'.")


# --------------------------------------------------------------------------- #
# Wiki documents
# --------------------------------------------------------------------------- #


def wiki_documents() -> list[Path]:
    if not WIKI.is_dir():
        return []
    return [
        p
        for p in sorted(WIKI.rglob("*.md"))
        if "work" not in p.relative_to(WIKI).parts
        and "templates" not in p.relative_to(WIKI).parts
    ]


def check_frontmatter() -> None:
    seen: dict[str, Path] = {}
    today = dt.date.today()

    for doc in wiki_documents():
        fm = parse_frontmatter(read(doc))
        if fm is None:
            err(f"{rel(doc)}: missing or unterminated frontmatter block.")
            continue

        for field in REQUIRED_FRONTMATTER:
            if not fm.get(field):
                err(f"{rel(doc)}: frontmatter field '{field}' is missing or empty.")

        doc_id = fm.get("id", "")
        if doc_id:
            if doc_id in seen:
                err(f"{rel(doc)}: id '{doc_id}' already used by {rel(seen[doc_id])}.")
            seen[doc_id] = doc

        status = fm.get("status", "")
        if status and status not in VALID_STATUS:
            err(f"{rel(doc)}: status '{status}' is not one of {sorted(VALID_STATUS)}.")
        if status == "superseded" and not fm.get("superseded_by"):
            err(f"{rel(doc)}: status is superseded but superseded_by is not set.")

        raw = fm.get("last_verified", "").strip().strip("\"'")
        if raw and raw != "YYYY-MM-DD":
            try:
                age = (today - dt.date.fromisoformat(raw)).days
            except ValueError:
                err(f"{rel(doc)}: last_verified '{raw}' is not an ISO date.")
            else:
                if age < 0:
                    err(f"{rel(doc)}: last_verified '{raw}' is in the future.")
                elif status == "active" and age > STALE_FAIL_DAYS:
                    err(
                        f"{rel(doc)}: last_verified is {age} days old. Re-verify the "
                        "content or mark the document superseded."
                    )
                elif status == "active" and age > STALE_WARN_DAYS:
                    warn(f"{rel(doc)}: last_verified is {age} days old.")


def check_index_reachability() -> None:
    index = WIKI / "INDEX.md"
    if not index.is_file():
        err("wiki/INDEX.md: missing. It is the router every agent reads first.")
        return

    linked = {
        (index.parent / target.split("#", 1)[0]).resolve()
        for target in re.findall(r"\]\(([^)]+)\)", read(index))
        if not target.startswith(("http://", "https://", "#"))
    }

    for doc in wiki_documents():
        if doc.resolve() == index.resolve():
            continue
        if doc.resolve() not in linked:
            err(
                f"{rel(doc)}: not reachable from wiki/INDEX.md. Add a line saying "
                "when to read it, in the same commit that adds the document."
            )


# --------------------------------------------------------------------------- #
# Work items
# --------------------------------------------------------------------------- #


def check_work_items() -> None:
    work = WIKI / "work"
    if not work.is_dir():
        return

    numbers: dict[str, str] = {}
    for item in sorted(p for p in work.iterdir() if p.is_dir()):
        if not WORK_ITEM_DIR.match(item.name):
            err(f"{rel(item)}: work item folders are named NNNN-kebab-slug.")
            continue

        number = item.name[:4]
        if number in numbers:
            err(f"{rel(item)}: number {number} already used by {numbers[number]}.")
        numbers[number] = item.name

        state = item / "STATE.yaml"
        if not state.is_file():
            err(f"{rel(item)}: missing STATE.yaml. It is the work item's only state.")
        else:
            body = read(state)
            for field in ("phase:", "route:", "id:"):
                if field not in body:
                    err(f"{rel(state)}: missing '{field.rstrip(':')}' field.")

        route = "quick" if (item / "RECORD.md").is_file() else "full"

        plan = item / "01-plan.md"
        if plan.is_file():
            check_plan_is_prose(plan)
        elif route == "full":
            warn(f"{rel(item)}: no 01-plan.md yet.")

        criteria = item / "02-criteria.md"
        if criteria.is_file():
            check_criteria(criteria)

        check_reviews(item)


def check_plan_is_prose(plan: Path) -> None:
    """A plan containing code has stopped being a plan."""
    for lineno, line in enumerate(read(plan).splitlines(), start=1):
        if FENCE.match(line):
            err(
                f"{rel(plan)}:{lineno}: fenced code block in a plan. Plans are prose "
                "only — name the file and the change in words."
            )
            return


def check_criteria(criteria: Path) -> None:
    text = read(criteria)
    if not AC_ID.search(text):
        err(f"{rel(criteria)}: no AC-NNN identifiers found. Criteria must be numbered.")
    for lineno, line in enumerate(text.splitlines(), start=1):
        if line.lstrip().startswith("<!--"):
            continue
        if AC_ID.search(line) and VAGUE.search(line):
            err(
                f"{rel(criteria)}:{lineno}: criterion uses a vague term "
                "('correctly', 'properly', 'as expected'). Such a criterion checks nothing."
            )


def check_reviews(item: Path) -> None:
    validation = item / "validation"
    if not validation.is_dir():
        return

    rounds: dict[str, set[int]] = {}
    for report in sorted(validation.glob("*.md")):
        if not REVIEW_FILE.match(report.name):
            err(
                f"{rel(report)}: validation reports are named "
                "<research|plan|impl>-review-NN.md."
            )
            continue
        phase, _, tail = report.stem.rpartition("-review-")
        rounds.setdefault(phase, set()).add(int(tail))

        body = read(report)
        if not re.search(r"\b(PASS|CONDITIONAL|FAIL)\b", body):
            err(f"{rel(report)}: no verdict found. State PASS, CONDITIONAL or FAIL.")
        if "## Verification performed" not in body:
            err(
                f"{rel(report)}: missing '## Verification performed'. A verdict without "
                "pasted command output is an assertion, not evidence."
            )
        if "## Recurrence check" not in body:
            err(
                f"{rel(report)}: missing '## Recurrence check'. Without it an "
                "oscillating loop is indistinguishable from progress."
            )

    for phase, seen in rounds.items():
        expected = set(range(1, max(seen) + 1))
        for missing in sorted(expected - seen):
            err(
                f"{rel(validation)}: {phase}-review-{missing:02d}.md is missing. "
                "Rounds are append-only and never renumbered."
            )


# --------------------------------------------------------------------------- #


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--quiet", action="store_true", help="only print failures")
    args = parser.parse_args()

    check_instruction_bridge()
    check_rule_mirrors()
    check_no_commands()
    check_skills_and_agents()
    check_frontmatter()
    check_index_reachability()
    check_work_items()

    for w in warnings:
        print(f"warning: {w}")
    for e in errors:
        print(f"error: {e}", file=sys.stderr)

    if errors:
        print(
            f"\n{len(errors)} error(s), {len(warnings)} warning(s).",
            file=sys.stderr,
        )
        return 1

    if not args.quiet:
        print(f"lint_wiki: clean ({len(warnings)} warning(s)).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
