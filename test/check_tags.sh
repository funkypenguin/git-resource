#!/bin/bash

set -e

source $(dirname $0)/helpers.sh

it_gets_all_tags() {
    local repo=$(init_repo)
    make_annotated_tag $repo foo   "tag foo"   true >/dev/null
    make_annotated_tag $repo bar   "tag bar"   true >/dev/null
    make_annotated_tag $repo wasd  "tag wasd"  true >/dev/null
    make_annotated_tag $repo other "tag other" true >/dev/null

    check_uri_with_tags $repo | jq -e 'map(.tag) == ["foo","bar","wasd","other"]'
}

it_uses_tag_filter() {
    local repo=$(init_repo)
    make_annotated_tag $repo foo-1 "tag foo-1" true >/dev/null
    make_annotated_tag $repo foo-2 "tag foo-2" true >/dev/null
    make_annotated_tag $repo wasd  "tag wasd"  true >/dev/null
    make_annotated_tag $repo 3-foo "tag 3-foo" true >/dev/null

    check_uri_with_tags_filter $repo "foo-*" | jq -e 'map(.tag) == ["foo-1","foo-2"]'
}

it_uses_tag_filters() {
    local repo=$(init_repo)
    make_annotated_tag $repo foo-1 "tag foo-1" true >/dev/null
    make_annotated_tag $repo foo-2 "tag foo-2" true >/dev/null
    make_annotated_tag $repo wasd  "tag wasd"  true >/dev/null
    make_annotated_tag $repo 3-foo "tag 3-foo" true >/dev/null

    check_uri_with_tags_filters $repo "foo-*" | jq -e 'map(.tag) == ["foo-1","foo-2"]'
}

it_combines_tag_filter_and_tag_filters() {
    local repo=$(init_repo)
    make_annotated_tag $repo foo-1 "tag foo-1" true >/dev/null
    make_annotated_tag $repo foo-2 "tag foo-2" true >/dev/null
    make_annotated_tag $repo wasd  "tag wasd"  true >/dev/null
    make_annotated_tag $repo 3-foo "tag 3-foo" true >/dev/null

    check_uri_with_tags_filter_and_filters $repo "*-foo" "foo-*" \
        | jq -e 'map(.tag) == ["foo-1","foo-2","3-foo"]'
}

it_uses_tag_regex() {
    local repo=$(init_repo)
    make_annotated_tag $repo foo-1 "tag foo-1" true >/dev/null
    make_annotated_tag $repo foo-2 "tag foo-2" true >/dev/null
    make_annotated_tag $repo wasd  "tag wasd"  true >/dev/null
    make_annotated_tag $repo 3-foo "tag 3-foo" true >/dev/null

    check_uri_with_tags_regex $repo "foo-.*" | jq -e 'map(.tag) == ["foo-1","foo-2"]'
}

it_sorts_by_semver() {
    local repo=$(init_repo)
    make_annotated_tag $repo v1.1.0 "tag v1.1.0" >/dev/null
    make_annotated_tag $repo v1.2.0 "tag v1.2.0" >/dev/null
    make_annotated_tag $repo v1.1.1 "tag v1.1.1" >/dev/null
    make_annotated_tag $repo v1.1.2 "tag v1.1.2" >/dev/null
    make_annotated_tag $repo v1.2.1 "tag v1.2.1" >/dev/null

    check_uri_with_tags_sort $repo "semver" \
        | jq -e 'map(.tag) == ["v1.1.0","v1.1.1","v1.1.2","v1.2.0","v1.2.1"]'
}

it_returns_new_tags() {
    local repo=$(init_repo)
    make_annotated_tag $repo v1.1.0 "tag v1.1.0" >/dev/null
    make_annotated_tag $repo v1.2.0 "tag v1.2.0" >/dev/null
    make_annotated_tag $repo v1.1.1 "tag v1.1.1" >/dev/null
    make_annotated_tag $repo v1.1.2 "tag v1.1.2" >/dev/null
    make_annotated_tag $repo v1.2.1 "tag v1.2.1" >/dev/null

    check_uri_with_tags_sort_from $repo "semver" "v1.2.0" \
        | jq -e 'map(.tag) == ["v1.2.0","v1.2.1"]'
}

run it_gets_all_tags
run it_uses_tag_filter
run it_uses_tag_filters
run it_combines_tag_filter_and_tag_filters
run it_uses_tag_regex
run it_sorts_by_semver
run it_returns_new_tags
