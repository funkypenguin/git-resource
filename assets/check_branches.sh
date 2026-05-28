branch_filters=$(jq '.source.branch_filters // []' <<< "$payload")
branch_regex=$(jq -r '.source.branch_regex // ""' <<< "$payload")
prev_branches=$(jq -r '.version.branches // ""' <<< "$payload")

if [[ $(jq 'length' <<< "$branch_filters") -ge 1 && -n "$branch_regex" ]]; then
    echo "only one of branch_filters or branch_regex can be specified"
    exit 1
fi

all_branches=$(git ls-remote --heads "$uri" | awk '{sub("refs/heads/", "", $2); print $2}')

filtered_branches=""
filtered=false
if [[ $(jq 'length' <<< "$branch_filters") -ge 1 ]]; then
    filtered=true
    while IFS= read -r branch; do
        while IFS= read -r filter; do
            if [[ "$branch" == $filter ]]; then
                filtered_branches+="${branch}"$'\n'
                break
            fi
        done <<< "$(jq -r '.[]' <<< "$branch_filters")"
    done <<< "$all_branches"
fi

if [[ -n "$branch_regex" ]]; then
    filtered=true
    filtered_branches=$(echo "$all_branches" | grep -E "$branch_regex" -)
fi

if [[ "$filtered" == "false" ]]; then
    filtered_branches=$all_branches
fi

sorted_branches=$(echo "$filtered_branches" | sort | paste -sd ',' -)
sorted_branches=${sorted_branches#,}
sorted_branches=${sorted_branches%,}

if [[ -z "$sorted_branches" ]]; then
    echo "No matching branches found. Setting empty version."
    sorted_branches="EMPTY"
fi

if [[ "$sorted_branches" == "$prev_branches" ]]; then
    echo "No change from previous version"
    echo "[]" >&3
    exit 0
fi

jq -n \
    --arg branches "$sorted_branches" \
    --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%S)" \
    '[{branches: $branches, timestamp: $timestamp}]' >&3
