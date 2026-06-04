#!/bin/bash

set -e

source $(dirname $0)/helpers.sh

it_returns_all_branches() {
  # init_repo already creates master and bogus; add a third branch
  local repo=$(init_repo)
  make_commit_to_branch $repo develop >/dev/null

  check_uri_with_branches $repo | jq -e '
    .[0].branches == "bogus,develop,master"
  '
}

it_sorts_branches() {
  local repo=$(init_repo)
  make_commit_to_branch $repo feat/qwer >/dev/null
  make_commit_to_branch $repo feat/hjkl >/dev/null
  make_commit_to_branch $repo feat/wasd >/dev/null
  make_commit_to_branch $repo feat/abcd >/dev/null

  # bogus and master are created by init_repo and sort around the feat/* branches
  check_uri_with_branches $repo | jq -e '
    .[0].branches == "bogus,feat/abcd,feat/hjkl,feat/qwer,feat/wasd,master"
  '
}

it_errors_if_branch_filters_and_branch_regex_are_set() {
  local repo=$(init_repo)
  local failed_output=$TMPDIR/filters-and-regex-output

  if check_uri_with_branch_filters_and_regex $repo "feat/.*" "feat/*" 2>"$failed_output"; then
    echo "checking should have failed"
    return 1
  fi

  grep "only one of branch_filters or branch_regex can be specified" "$failed_output"
}

it_uses_all_branch_filters() {
  local repo=$(init_repo)
  make_commit_to_branch $repo issue/hjkl >/dev/null
  make_commit_to_branch $repo feat/oiuy >/dev/null
  make_commit_to_branch $repo bug/876 >/dev/null
  make_commit_to_branch $repo refactor/ui >/dev/null

  check_uri_with_branch_filters $repo "bug/*" "issue/*" | jq -e '
    .[0].branches == "bug/876,issue/hjkl"
  '
}

it_uses_branch_regex() {
  local repo=$(init_repo)
  make_commit_to_branch $repo issue/hjkl >/dev/null
  make_commit_to_branch $repo feat/oiuy >/dev/null
  make_commit_to_branch $repo bug/876 >/dev/null
  make_commit_to_branch $repo refactor/ui >/dev/null

  check_uri_with_branch_regex $repo '(refactor\/|feat\/).*' | jq -e '
    .[0].branches == "feat/oiuy,refactor/ui"
  '
}

it_returns_empty_array_when_no_new_branches() {
  # init_repo already creates two branches: master and bogus
  local repo=$(init_repo)

  local branches=$(check_uri_with_branches $repo | jq -r '.[0].branches')

  check_uri_with_branches_from $repo "$branches" | jq -e '. == []'
}

it_returns_none_when_no_branches_found() {
  local repo=$(init_repo)

  # only master and bogus branch exist, therefore no matching branches should be found
  check_uri_with_branch_filters $repo "issue/*" | jq -e '
    .[0].branches == "NONE"
  '
}

run it_returns_all_branches
run it_sorts_branches
run it_errors_if_branch_filters_and_branch_regex_are_set
run it_uses_all_branch_filters
run it_uses_branch_regex
run it_returns_empty_array_when_no_new_branches
run it_returns_none_when_no_branches_found
