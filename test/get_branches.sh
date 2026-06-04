#!/bin/bash

set -e

source $(dirname $0)/helpers.sh

it_saves_the_given_branches() {
  local dest=$TMPDIR/destination
  mkdir -p $dest

  get_branches "some-uri" "feat/foo,feat/bar,issue/qwerty" $dest | jq -e '
    .version.branches == "feat/foo,feat/bar,issue/qwerty"
  '

  jq -e '. == ["feat/foo","feat/bar","issue/qwerty"]' < $dest/branches.json
}

it_saves_a_single_branch() {
  local dest=$TMPDIR/destination
  mkdir -p $dest

  get_branches "some-uri" "feat/foo" $dest | jq -e '
    .version.branches == "feat/foo"
  '

  jq -e '. == ["feat/foo"]' < $dest/branches.json
}

it_saves_empty_array_when_version_is_none() {
  local dest=$TMPDIR/destination
  mkdir -p $dest

  get_branches "some-uri" "NONE" $dest

  jq -e '. == []' < $dest/branches.json
}

it_saves_metadata_as_multiline_string() {
  local dest=$TMPDIR/destination
  mkdir -p $dest

  get_branches "some-uri" "feat/foo,feat/bar,issue/qwerty" $dest | jq -e '
    (.metadata[] | select(.name == "branches") | .value) == "feat/foo\nfeat/bar\nissue/qwerty"
  '
}

run it_saves_the_given_branches
run it_saves_a_single_branch
run it_saves_empty_array_when_version_is_none
run it_saves_metadata_as_multiline_string
