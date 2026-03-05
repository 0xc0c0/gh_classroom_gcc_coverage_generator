#!/usr/bin/env bash
# pex3_batch.sh
# Batch clone/update GitHub Classroom repos, drop in instructor Makefile, build pex3,
# and (optionally) gather lcov coverage for listAsLinkedList.c only.
#
# Uses global/env vars if set; prompts otherwise.
#
# Env vars you can set:
#   GH_TOKEN                 (recommended for gh api)
#   ASSIGNMENT_ID            (GitHub Classroom assignment id)
#   DEST_DIR                 (where to place repos)
#   MAKEFILE_SRC             (path to your instructor Makefile to copy in)
#   DO_COVERAGE              (1 to run lcov/genhtml, 0 to skip; default 1)
#   COVERAGE_OUT_DIR         (default: coverage-html)
#   TARGET                   (make target; default: pex3)
#   LCOV_FILE_FILTER         (default: listAsLinkedList.c)
#
# Notes:
# - This script avoids `gh classroom clone student-repos` entirely to prevent “already exists” failures.
# - It uses the Classroom REST API accepted_assignments list and then clone-or-pull per repo.

: "${DEBUG:=0}"

if [[ "${DEBUG}" == "1" ]]; then
  set -euo pipefail
  set -x
  trap 'echo "ERROR on line $LINENO: $BASH_COMMAND" >&2' ERR
fi

# -------------------------
# Helper: env-or-prompt
# -------------------------
prompt_if_unset() {
  local var_name="$1"
  local prompt="$2"
  local default="${3:-}"
  local current="${!var_name:-}"

  if [[ -n "$current" ]]; then
    return 0
  fi

  if [[ -n "$default" ]]; then
    read -rp "$prompt [$default]: " current
    current="${current:-$default}"
  else
    read -rp "$prompt: " current
  fi

  if [[ -z "$current" ]]; then
    echo "ERROR: $var_name is required."
    exit 1
  fi

  # shellcheck disable=SC2163
  export "$var_name=$current"
}

# -------------------------
# Defaults
# -------------------------
: "${DO_COVERAGE:=1}"
: "${TARGET:=pex3}"
: "${LCOV_FILE_FILTER:=listAsLinkedList.c}"
: "${CUTOFF_GIT_COMMIT_TIMESTAMP:=2026-02-22T00:00:00Z}"

COVERAGE_OUT_DIR="${COVERAGE_OUT_DIR:-coverage-html}"
COVERAGE_OUT_DIR="$(cd "$COVERAGE_OUT_DIR" 2>/dev/null || mkdir -p "$COVERAGE_OUT_DIR" && cd "$COVERAGE_OUT_DIR"; pwd)"

# -------------------------
# Require tools
# -------------------------
command -v gh >/dev/null || { echo "ERROR: gh not found"; exit 1; }
command -v jq >/dev/null || { echo "ERROR: jq not found"; exit 1; }
command -v git >/dev/null || { echo "ERROR: git not found"; exit 1; }

if [[ "$DO_COVERAGE" == "1" ]]; then
  command -v lcov >/dev/null || { echo "ERROR: lcov not found"; exit 1; }
  command -v genhtml >/dev/null || { echo "ERROR: genhtml not found"; exit 1; }
fi

# -------------------------
# Use globals if set; prompt otherwise
# -------------------------
prompt_if_unset "ASSIGNMENT_ID" "Enter GitHub Classroom Assignment ID"
prompt_if_unset "DEST_DIR" "Destination directory for repos" "repos-$ASSIGNMENT_ID"
prompt_if_unset "MAKEFILE_SRC" "Path to instructor Makefile to copy into each repo"

mkdir -p "$DEST_DIR"

echo "ASSIGNMENT_ID     = $ASSIGNMENT_ID"
echo "DEST_DIR          = $DEST_DIR"
echo "MAKEFILE_SRC      = $MAKEFILE_SRC"
echo "DO_COVERAGE       = $DO_COVERAGE"
echo "TARGET            = $TARGET"
echo "LCOV_FILE_FILTER  = $LCOV_FILE_FILTER"
echo "COVERAGE_OUT_DIR  = $COVERAGE_OUT_DIR"
echo

# -------------------------
# fetch accepted repos once, then iterate student-by-student
# -------------------------
repos_tsv=$(
  gh api --paginate \
    -H "Accept: application/vnd.github+json" \
    "/assignments/${ASSIGNMENT_ID}/accepted_assignments?per_page=100" \
  | jq -r '.[] | [.repository.full_name, (.students|map(.login)|join("+"))] | @tsv'
)

# map the GitHub username to their corresponding real name
declare -A ROSTER_NAME

while IFS=$'\t' read -r github_username roster_identifier; do
    ROSTER_NAME["$github_username"]="$roster_identifier"
done < <(
    gh api -H "X-GitHub-Api-Version: 2022-11-28" \
    "/assignments/$ASSIGNMENT_ID/grades" --paginate \
    | jq -r '.[] | [.github_username, .roster_identifier] | @tsv'
)

echo "Assignment ID: $ASSIGNMENT_ID, Roster mapping:"
echo "GitHub username -> Roster identifier"
for k in "${!ROSTER_NAME[@]}"; do
    if [[ -z "${ROSTER_NAME[$k]}" ]]; then
        ROSTER_NAME[$k]="(no roster name)"
    fi
    echo "$k -> ${ROSTER_NAME[$k]}"
done 

echo "Found $(echo "$repos_tsv" | wc -l) accepted repos for assignment $ASSIGNMENT_ID."

if [[ -z "$repos_tsv" ]]; then
  echo "ERROR: No repos returned. Check ASSIGNMENT_ID and your permissions."
  exit 1
fi

# safe column helper (never abort script)
colfmt() { column -t -s $'\t' 2>/dev/null || cat; }

fail_log="$DEST_DIR/failures.log"
: > "$fail_log"

if [[ "$DO_COVERAGE" == "1" ]]; then
  mkdir -p "$COVERAGE_OUT_DIR/info" "$COVERAGE_OUT_DIR/html"
  merge_list="$COVERAGE_OUT_DIR/info/merge_list.txt"
  : > "$merge_list"
fi

printf -- "Student(s)\tRepo\tRoster Name\tBuild\tCoverage\n" | colfmt
printf -- "----------\t----\t-----------\t-----\t--------\n" | colfmt

while IFS=$'\t' read -r full_name students; do
  repo="${full_name#*/}"
  repo_dir="$DEST_DIR/$repo"

  build_status="OK"
  cov_status="-"

# ---- clone if repo not present; otherwise reuse existing ----
if [[ -d "$repo_dir/.git" ]]; then
  # Repo already exists locally — reuse it
  :
elif [[ -d "$repo_dir" ]]; then
  # Folder exists but is not a git repo (unexpected case)
  echo "WARN: $repo_dir exists but is not a git repo. Skipping clone." >> "$fail_log"
else
  # Repo not present — clone it
  if ! git clone "https://github.com/$full_name.git" "$repo_dir" >/dev/null 2>&1; then
    echo "WARN: clone failed for $full_name" >> "$fail_log"
    printf "%s\t%s\tCLONE_FAIL\t-\n" "$students" "$full_name" | colfmt
    continue
  fi
fi

  # ---- rewind git repo to cutoff timestamp (optional) ----
  (
    #set +e
    cd "$repo_dir" || exit 1
    cutoff_commit=$(git rev-list -1 --before="$CUTOFF_GIT_COMMIT_TIMESTAMP" HEAD)
    if [[ -n "$cutoff_commit" ]]; then
      git checkout --detach "$cutoff_commit" >/dev/null 2>&1
    fi
  )

  # ---- inject Makefile ----
  if [ -f "$repo_dir/Makefile.stub" ]; then
    :
  else
    touch "$repo_dir/Makefile.stub" 2>/dev/null
    if ! cp -f "$MAKEFILE_SRC" "$repo_dir/Makefile"; then
      echo "WARN: Makefile copy failed for $full_name" >> "$fail_log"
      printf "%s\t%s\tMAKEFILE_FAIL\t-\n" "$students" "$full_name" | colfmt
      continue
    fi
  fi

  # ---- build ----
  (
    set +e
    cd "$repo_dir" || exit 1
    make clean >/dev/null 2>&1
    make "$TARGET" >/dev/null 2>&1
  )
  if [[ $? -ne 0 ]]; then
    build_status="BUILD_FAIL"
    echo "WARN: build failed for $full_name" >> "$fail_log"
    printf "%s\t%s\t%s\t-\n" "$students" "$full_name" "$build_status" | colfmt
    continue
  fi

  # ---- coverage (one info per student; no genhtml here) ----
  if [[ "$DO_COVERAGE" == "1" && ! -f "$repo_dir/DOESNOTWORK" ]]; then
    info_out="$COVERAGE_OUT_DIR/info/${repo}.info"

    (
      #set +e
      #set -o pipefail

      # High-signal debug for THIS block only:
      if [[ "${DEBUG}" == "1" ]]; then
        PS4='+(${BASH_SOURCE}:${LINENO}) ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
        set -x
        trap 'rc=$?; echo "SUBSHELL FAIL rc=$rc at ${BASH_SOURCE}:${LINENO}: ${BASH_COMMAND}" >&2; exit $rc' ERR
      fi

      cd "$repo_dir" || exit 1

      make clean >/dev/null 2>&1
      make "$TARGET" >/dev/null 2>&1

      find . -name "*.gcda" -delete >/dev/null 2>&1 || true
      ./pex3 >/dev/null 2>&1 || true

      lcov --capture --directory . \
          --output-file unfiltered.info >/dev/null 2>&1

      lcov --extract unfiltered.info "*listAsLinkedList.c" --output-file "$info_out" 2>&1 >/dev/null
    )
    rc=$?

    if [[ $rc -eq 0 && -s "$info_out" ]]; then
      cov_status="OK"
      echo "$info_out" >> "$merge_list"
    else
      cov_status="COV_FAIL"
      echo "WARN: coverage failed for $full_name (rc=$rc)" >> "$fail_log"
      # leave it out of merge list
    fi
  fi

  printf "%s\t%s\t%s\t%s\t%s\n" "$students" "$full_name" "${ROSTER_NAME[$students]:-}" "$build_status" "$cov_status" | colfmt
done <<< "$repos_tsv"

# ---- roll-up: merge + one genhtml ----
if [[ "$DO_COVERAGE" == "1" ]]; then
  merged="$COVERAGE_OUT_DIR/info/merged.info"
  rm -f "$merged"

  first=1
  while IFS= read -r f; do
    [[ -s "$f" ]] || continue

    if [[ $first -eq 1 ]]; then
      cp "$f" "$merged"
      first=0
      continue
    fi

    tmp="$COVERAGE_OUT_DIR/info/.tmp_merged.info"
    if lcov -a "$merged" -a "$f" -o "$tmp" >/dev/null 2>&1; then
      mv "$tmp" "$merged"
    else
      echo "WARN: merge failed for $f (skipping)" >> "$fail_log"
      rm -f "$tmp"
    fi
  done < "$merge_list"

  if [[ ! -s "$merged" ]]; then
    echo "No merged coverage produced. See $fail_log"
  else
    rm -rf "$COVERAGE_OUT_DIR/html"
    mkdir -p "$COVERAGE_OUT_DIR/html"
    genhtml "$merged" --output-directory "$COVERAGE_OUT_DIR/html" >/dev/null 2>&1 || \
      echo "WARN: genhtml failed (see $fail_log)"
    echo "Combined coverage HTML: $COVERAGE_OUT_DIR/html/index.html"
  fi
fi

echo
echo "Done."
echo "Failures (if any): $fail_log"
if [[ "$DO_COVERAGE" == "1" ]]; then
  echo "Coverage HTML root: $COVERAGE_OUT_DIR/"
fi
