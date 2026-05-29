tag_filters=$(jq '(.source.tag_filters // []) + (if .source.tag_filter then [.source.tag_filter] else [] end)' <<< "$payload")
tag_regex=$(jq -r '.source.tag_regex // ""' <<< "$payload")
tag_sort=$(jq -r '.source.tag_sort // "creatordate"' <<< "$payload")
prev_tag=$(jq -r '.version.tag // ""' <<< "$payload")

if [[ $(jq 'length' <<< "$tag_filters") -ge 1 && -n "$tag_regex" ]]; then
    echo "only one of tag_filters or tag_regex can be specified"
    exit 1
fi

if [[ ! -d "$destination" ]]; then
    git init --bare --quiet "$destination"
fi

cd "$destination"

git fetch --depth=1 \
    --filter=tree:0 \
    --no-tags \
    "$uri" \
    '+refs/tags/*:refs/tags/*'

# get all tags, sorting by creation-date
all_tags=$(git for-each-ref \
    --sort=creatordate \
    --format='%(refname:short)%09%(objectname)%09%(*objectname)' \
    refs/tags/)

filtered_tags=""
filtered=false
if [[ $(jq 'length' <<< "$tag_filters") -ge 1 ]]; then
    filtered=true
    while IFS= read -r tag; do
        while IFS= read -r filter; do
            # $tag is the tag name and refs joined by tabs. We only want to
            # match against the tag name, so strip everything from the first
            # tab onward.
            if [[ "${tag%%$'\t'*}" == $filter ]]; then
                filtered_tags+="${tag}"$'\n'
                break
            fi
        done <<< "$(jq -r '.[]' <<< "$tag_filters")"
    done <<< "$all_tags"
fi

if [[ -n "$tag_regex" ]]; then
    filtered=true
    while IFS= read -r tag; do
        if echo "${tag%%$'\t'*}" | grep -E "$tag_regex" >/dev/null; then
            filtered_tags+="${tag}"$'\n'
        fi
    done <<< "$all_tags"
fi

if [[ "$filtered" == "false" ]]; then
    filtered_tags=$all_tags
fi

sorted_tags=""
sorted=false
if [[ "$tag_sort" == "semver" ]]; then
    sorted=true
    sorted_tags=$(echo "$filtered_tags" | sort -V)
fi

if [[ "$sorted" == "false" ]]; then
    sorted_tags=$filtered_tags
fi
sorted_tags=$(echo "$sorted_tags" | grep -v '^[[:space:]]*$')

jtags=$(echo "$sorted_tags" | jq -Rn \
    --arg prevtag "$prev_tag" \
    '[inputs | (./"\t") | {tag: .[0], ref: .[1]}] | .[(map(.tag) | index($prevtag)):]')

echo "$jtags" >&3
