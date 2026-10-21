# sed and grep: find and change text across a codebase

Notes from refactoring the landing zone (Part 2, step 2.3), where every reference to
`google_project.p[...]` had to become `module.project[...]` across six files.

- **grep** finds lines that match a pattern. It never changes anything.
- **sed** (stream editor) changes text. With `-i` it edits files in place.

The safe habit: **grep first, preview the sed, apply, grep again, review with `git diff`.**

## 1. grep: find things

```bash
grep -n "google_project.p" *.tf          # -n: show line numbers
grep -rn "roles/owner" .                 # -r: search folders recursively
grep -rln "yourdomain.com" .             # -l: only list file names
grep -c "resource " *.tf                 # -c: count matches per file
grep -in "todo" *.tf                     # -i: ignore upper/lower case
grep -v "^#" main.tf                     # -v: lines that do NOT match (here: skip comments)
grep -n -A2 -B1 "deletion_policy" *.tf   # show 2 lines after and 1 before each match
grep -rn --include="*.tf" "google_" .    # only search .tf files
```

Several patterns at once: `\|` means "or".

```bash
grep -n "google_project.p\|google_project_service.apis" *.tf
```

No output from grep means no match. That's how the step 2.3 check works.

## 2. sed: change things

The basic form is `s/find/replace/flags`:

```bash
sed 's/old/new/' file.tf       # first match on each line, printed to screen only
sed 's/old/new/g' file.tf      # g: every match on each line
sed -i 's/old/new/g' *.tf      # -i: write the change into the files (Linux)
sed -i '' 's/old/new/g' *.tf   # the same on macOS
```

**Mac vs Linux:** macOS sed needs an argument after `-i` (the backup file suffix, here empty `''`).
Without it, macOS sed fails with something like `invalid command code` and changes nothing.
To make a backup on either system: `sed -i.bak 's/old/new/g' *.tf`, then delete the `.bak` files.

### Preview before you change

Run without `-i` and filter to the changed lines, or compare with `diff`:

```bash
sed 's/google_project\.p\[/module.project[/g' network.tf | grep -n "module.project"
sed 's/google_project\.p\[/module.project[/g' network.tf | diff network.tf -
```

## 3. Patterns (regular expressions): the characters that bite

Some characters have special meanings. To match them literally, put `\` in front.

| Character | Means | Match it literally with |
|---|---|---|
| `.` | any single character | `\.` |
| `[` `]` | "one of these characters", e.g. `[a-z]` | `\[` `\]` |
| `*` | the previous thing, zero or more times | `\*` |
| `^` / `$` | start / end of line | `\^` / `\$` |
| `/` | sed's separator | `\/`, or use another separator: `s#a/b#c/d#g` |

That's why the command was `google_project\.p\[`. Without the backslashes, `.` would match any
character and `[` would start a character list.

### Lesson from step 2.3: don't make the pattern stricter than it needs to be

The first version only matched quoted keys:

```bash
sed -i 's/google_project\.p\[\("[a-z-]*"\)\]/module.project[\1]/g' *.tf
```

`\("[a-z-]*"\)` means "a quoted name made of lowercase letters and hyphens", and `\1` puts it back.
It worked for `google_project.p["prod-app"]` but skipped `google_project.p[each.key]` in `network.tf`
(no quotes). The simpler version only changes the part that actually differs, so it matches any key:

```bash
sed -i 's/google_project\.p\[/module.project[/g' *.tf
```

Rule of thumb: replace the smallest piece of text that changes, and always grep afterwards.

### Capture groups: reuse part of the match

`\(...\)` captures text and `\1`, `\2` put it back. With `-E` (extended regex) you write `(...)`
without backslashes:

```bash
# region = "us-central1"  ->  region = "europe-west2", keeping whatever spacing was there
sed -E 's/(region *= *)"us-central1"/\1"europe-west2"/' *.tf
```

## 4. Recipes for this repo

```bash
# Replace a placeholder in every file under the current folder
grep -rl "YOUR_GH_OWNER" . | xargs sed -i "s/YOUR_GH_OWNER/$GH_OWNER/g"      # macOS: sed -i ''

# Which files grant a basic role? (OPA blocks these, but check before you push)
grep -rn 'roles/\(owner\|editor\|viewer\)"' --include="*.tf" .

# Every resource type in the project, counted
grep -ho '^resource "[a-z_]*"' *.tf | sort | uniq -c | sort -rn

# Terraform state: what is actually deployed, filtered
terraform state list | grep google_project
terraform state list | grep -c iam_member

# Delete lines matching a pattern (here: checkov skip comments) - preview first!
sed '/checkov:skip/d' main.tf
```

Double quotes (`"...$GH_OWNER..."`) let the shell fill in variables. Single quotes (`'...'`) pass the
text exactly as written, which is what you want for patterns with `$`, `\` or `!`.

## 5. A safe workflow for big replacements

```bash
git status                                   # start from a clean tree, so the change is easy to undo
grep -rn "old_name" --include="*.tf" .       # 1. what will change?
sed -i 's/old_name/new_name/g' *.tf          # 2. change it
grep -rn "old_name" --include="*.tf" .       # 3. anything left? (no output = done)
git diff                                     # 4. read every changed line
terraform fmt && terraform validate          # 5. still valid Terraform?
git checkout -- .                            # undo everything if it went wrong
```

Watch out for files that *should* keep the old text. In step 2.4, `moved.tf` deliberately names the
old addresses in its `from =` lines; running the replacement after creating it would break it.
Either run sed before creating such files, or target specific files instead of `*.tf`.

## 6. Going further

- **ripgrep (`rg`)**: a faster grep that skips `.git` and `.terraform` folders by default:
  `rg -n "google_project\.p\["`. Install with `brew install ripgrep`.
- **Your editor**: VS Code's search panel (Cmd/Ctrl+Shift+F) does project-wide find and replace with
  regex, and shows a preview of every change before you apply it.
- **Terraform's own refactoring tools**: `moved` blocks (Part 2) and `terraform state mv` change
  where resources live in state; sed only changes the code. You usually need both.
