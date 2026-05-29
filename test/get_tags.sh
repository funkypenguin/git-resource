#!/bin/bash

set -e

source $(dirname $0)/helpers.sh

it_clones_the_repo_at_the_given_tag() {
    local repo=$(init_repo)
    make_commit $repo >/dev/null
    make_annotated_tag $repo v1 "tag v1" >/dev/null
    local tag_ref=$(git -C $repo rev-parse v1^{commit})

    local dest=$TMPDIR/destination

    get_tags $repo v1 $dest | jq -e '.version.tag == "v1"'

    ! git -C $dest symbolic-ref -q HEAD

    test "$(git -C $dest rev-parse HEAD)" = "$tag_ref"
}

it_saves_the_tag_metadata() {
    local repo=$(init_repo)
    make_commit $repo >/dev/null
    make_annotated_tag $repo v1 "tag v1" >/dev/null

    local dest=$TMPDIR/destination

    get_tags $repo v1 $dest

    jq -e 'any(.name == "tag" and .value == "v1")' < $dest/.git/metadata.json
}

run it_clones_the_repo_at_the_given_tag
run it_saves_the_tag_metadata
