#!/usr/bin/env python3
"""Normalise parenthesised commit scopes to square brackets.

Rewrites ``type(scope): subject`` to ``type[scope]: subject`` in the history of
one or more branches, which is what the shared commitlint preset
(``papanito/git-hooks``) and ``standards/technical_standards.md`` §3 require.

Why not ``git filter-branch``/``git filter-repo``: both rebuild every commit
they visit, so they strip GPG signatures from commits that never needed a
change — on a signing-enabled repo that rewrites the whole history and destroys
the branch's shared ancestry with the default branch. This script rebuilds a
commit only when its message or one of its parents actually changes, and reuses
every other commit byte-for-byte.

Published history is never touched unless ``--all-history`` is passed: commits
reachable from any remote-tracking ref keep their original message, so the
branch stays pushable without a force-push over published commits.

Commit-SHA references inside the body of a rewritten commit (e.g. ``This
reverts commit <sha>.``) are updated to the rewritten SHA. Tags are left alone.

Usage:
    rewrite_scopes.py                    # current branch, unpushed commits only
    rewrite_scopes.py --dry-run feat/x   # show what would change
    rewrite_scopes.py --all-history      # also rewrite published commits
"""

import argparse
import re
import subprocess
import sys

SCOPE_PATTERN = re.compile(r"^([a-z]+)\(([^)]+)\):")
HEX_SHA = re.compile(r"\b[0-9a-f]{40}\b")


def git(*args, stdin=None, binary=False):
    """Run a git command and return its stdout."""
    result = subprocess.run(["git", *args], input=stdin, capture_output=True)
    if result.returncode != 0:
        sys.exit(f"git {' '.join(args)}: {result.stderr.decode().strip()}")
    return result.stdout if binary else result.stdout.decode()


def read_commit(sha):
    """Split a commit object into fields, parents and raw message."""
    raw = git("cat-file", "commit", sha, binary=True)
    head, _, message = raw.partition(b"\n\n")
    fields, parents = {}, []
    for line in head.decode().splitlines():
        key, _, value = line.partition(" ")
        if key == "parent":
            parents.append(value)
        elif key in ("tree", "author", "committer"):
            fields[key] = value
        # every other header (gpgsig, mergetag, ...) is dropped on rewrite
    return fields, parents, message


def write_commit(fields, parents, message):
    """Write a commit object and return its SHA."""
    out = bytearray()
    out += f"tree {fields['tree']}\n".encode()
    for parent in parents:
        out += f"parent {parent}\n".encode()
    out += f"author {fields['author']}\n".encode()
    out += f"committer {fields['committer']}\n".encode()
    out += b"\n" + message
    return git("hash-object", "-t", "commit", "-w", "--stdin", stdin=bytes(out)).strip()


def rewrite_message(message, rewritten):
    """Bracket the scope on the subject line and retarget SHA references."""
    subject, separator, body = message.partition(b"\n")
    subject = SCOPE_PATTERN.sub(
        lambda m: f"{m.group(1)}[{m.group(2)}]:", subject.decode()
    )
    if body and rewritten:
        text = body.decode()
        for old, new in rewritten.items():
            text = HEX_SHA.sub(lambda m: new if m.group(0) == old else m.group(0), text)
        body = text.encode()
    return subject.encode() + separator + body


def rewrite_branch(branch, published, dry_run, backup):
    """Rewrite the branch and return the list of changed commits."""
    tip = git("rev-parse", f"refs/heads/{branch}").strip()
    if backup:
        git("update-ref", f"refs/backup/pre-scope-normalize/{branch}", tip)

    new_shas, rewritten, changed = {}, {}, []
    for sha in git("rev-list", "--reverse", "--topo-order", tip).split():
        if sha in published:
            new_shas[sha] = sha
            continue
        fields, parents, message = read_commit(sha)
        new_parents = [new_shas.get(parent, parent) for parent in parents]
        new_message = rewrite_message(message, rewritten)
        if new_parents == parents and new_message == message:
            new_shas[sha] = sha
            continue
        new_sha = write_commit(fields, new_parents, new_message)
        new_shas[sha] = new_sha
        rewritten[sha] = new_sha
        changed.append((sha, new_sha, new_message.split(b"\n", 1)[0].decode()))

    if changed and not dry_run:
        git("update-ref", f"refs/heads/{branch}", new_shas[tip])

    for old, new, subject in changed:
        print(f"  {old[:8]} -> {new[:8]}  {subject}")
    return changed


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("branches", nargs="*", help="branches (default: current)")
    parser.add_argument(
        "--all-history",
        action="store_true",
        help="also rewrite commits already reachable from a remote",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="print the changes without moving any ref",
    )
    parser.add_argument(
        "--no-backup",
        action="store_true",
        help="skip refs/backup/pre-scope-normalize/<branch>",
    )
    args = parser.parse_args()

    branches = args.branches or [git("rev-parse", "--abbrev-ref", "HEAD").strip()]
    if "HEAD" in branches:
        sys.exit("Detached HEAD: name the branch to rewrite explicitly")

    published = set() if args.all_history else set(git("rev-list", "--remotes").split())

    for branch in branches:
        git("rev-parse", "--verify", f"refs/heads/{branch}")
        print(f"### {branch}")
        changed = rewrite_branch(branch, published, args.dry_run, not args.no_backup)
        print(f"  {len(changed)} commit(s) rewritten")
        if changed and not args.all_history:
            print("  backup: refs/backup/pre-scope-normalize/" + branch)
        if args.dry_run and changed:
            print("  dry run: no ref moved")


if __name__ == "__main__":
    main()
