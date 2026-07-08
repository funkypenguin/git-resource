#!/bin/bash

set -e

source $(dirname $0)/helpers.sh

it_gets_all_tags() {
    local repo=$(init_repo)
    make_annotated_tag $repo foo   "tag foo"   true >/dev/null
    make_annotated_tag $repo bar   "tag bar"   true >/dev/null
    make_annotated_tag $repo wasd  "tag wasd"  true >/dev/null
    make_lightweight_tag $repo other true >/dev/null

    check_uri_with_tags $repo | jq -e 'map(.tag) == ["foo","bar","wasd","other"] and all(.[]; (.ref // "") != "")'
}

it_uses_tag_filter() {
    local repo=$(init_repo)
    make_annotated_tag $repo foo-1 "tag foo-1" true >/dev/null
    make_annotated_tag $repo foo-2 "tag foo-2" true >/dev/null
    make_annotated_tag $repo wasd  "tag wasd"  true >/dev/null
    make_annotated_tag $repo 3-foo "tag 3-foo" true >/dev/null
    make_lightweight_tag $repo foo-4 true >/dev/null
    make_lightweight_tag $repo qwerty true >/dev/null
    make_lightweight_tag $repo 5-foo true >/dev/null

    check_uri_with_tags_filter $repo "foo-*" | jq -e 'map(.tag) == ["foo-1","foo-2","foo-4"] and all(.[]; (.ref // "") != "")'
}

it_uses_tag_filters() {
    local repo=$(init_repo)
    make_annotated_tag $repo foo-1 "tag foo-1" true >/dev/null
    make_annotated_tag $repo foo-2 "tag foo-2" true >/dev/null
    make_annotated_tag $repo wasd  "tag wasd"  true >/dev/null
    make_annotated_tag $repo 3-foo "tag 3-foo" true >/dev/null
    make_lightweight_tag $repo foo-4 true >/dev/null
    make_lightweight_tag $repo qwerty true >/dev/null
    make_lightweight_tag $repo 5-foo true >/dev/null

    check_uri_with_tags_filter $repo "foo-*" | jq -e 'map(.tag) == ["foo-1","foo-2","foo-4"] and all(.[]; (.ref // "") != "")'
}

it_combines_tag_filter_and_tag_filters() {
    local repo=$(init_repo)
    make_annotated_tag $repo foo-1 "tag foo-1" true >/dev/null
    make_annotated_tag $repo foo-2 "tag foo-2" true >/dev/null
    make_annotated_tag $repo wasd  "tag wasd"  true >/dev/null
    make_annotated_tag $repo 3-foo "tag 3-foo" true >/dev/null
    make_lightweight_tag $repo foo-4 true >/dev/null
    make_lightweight_tag $repo qwerty true >/dev/null
    make_lightweight_tag $repo 5-foo true >/dev/null

    check_uri_with_tags_filter_and_filters $repo "*-foo" "foo-*" \
        | jq -e 'map(.tag) == ["foo-1","foo-2","3-foo","foo-4","5-foo"] and all(.[]; (.ref // "") != "")'
}

it_uses_tag_regex() {
    local repo=$(init_repo)
    make_annotated_tag $repo foo-1 "tag foo-1" true >/dev/null
    make_annotated_tag $repo foo-2 "tag foo-2" true >/dev/null
    make_annotated_tag $repo wasd  "tag wasd"  true >/dev/null
    make_annotated_tag $repo 3-foo "tag 3-foo" true >/dev/null
    make_lightweight_tag $repo foo-4 true >/dev/null
    make_lightweight_tag $repo qwerty true >/dev/null
    make_lightweight_tag $repo 5-foo true >/dev/null

    check_uri_with_tags_regex $repo "foo-.*" | jq -e 'map(.tag) == ["foo-1","foo-2","foo-4"] and all(.[]; (.ref // "") != "")'
}

it_sorts_by_version() {
    local repo=$(init_repo)
    make_annotated_tag $repo v1.1.0 "tag v1.1.0" >/dev/null
    make_annotated_tag $repo v1.2.0 "tag v1.2.0" >/dev/null
    make_annotated_tag $repo v1.1.1 "tag v1.1.1" >/dev/null
    make_annotated_tag $repo v1.1.2 "tag v1.1.2" >/dev/null
    make_annotated_tag $repo v1.2.1 "tag v1.2.1" >/dev/null
    make_lightweight_tag $repo v1.3.0 true >/dev/null
    make_lightweight_tag $repo v1.3.1 true >/dev/null

    check_uri_with_tags_sort $repo "version" \
        | jq -e 'map(.tag) == ["v1.1.0","v1.1.1","v1.1.2","v1.2.0","v1.2.1","v1.3.0","v1.3.1"] and all(.[]; (.ref // "") != "")'
}

it_returns_new_tags() {
    local repo=$(init_repo)
    make_annotated_tag $repo v1.1.0 "tag v1.1.0" >/dev/null
    make_annotated_tag $repo v1.2.0 "tag v1.2.0" >/dev/null
    make_annotated_tag $repo v1.1.1 "tag v1.1.1" >/dev/null
    make_annotated_tag $repo v1.1.2 "tag v1.1.2" >/dev/null
    make_annotated_tag $repo v1.2.1 "tag v1.2.1" >/dev/null
    make_lightweight_tag $repo v1.3.0 true >/dev/null
    make_lightweight_tag $repo v1.3.1 true >/dev/null

    check_uri_with_tags_sort_from $repo "version" "v1.2.0" \
        | jq -e 'map(.tag) == ["v1.2.0","v1.2.1","v1.3.0","v1.3.1"] and all(.[]; (.ref // "") != "")'
}

it_finds_no_tags() {
    local repo=$(init_repo)

    check_uri_with_tags $repo | jq -e '. == []'
}

it_returns_no_tags_due_to_filtering() {
    local repo=$(init_repo)
    make_annotated_tag $repo foo-1 "tag foo-1" true >/dev/null

    check_uri_with_tags_filter $repo "nomatch*" | jq -e '. == []'
}

run it_gets_all_tags
run it_uses_tag_filter
run it_uses_tag_filters
run it_combines_tag_filter_and_tag_filters
run it_uses_tag_regex
run it_sorts_by_version
run it_returns_new_tags
run it_finds_no_tags
run it_returns_no_tags_due_to_filtering
