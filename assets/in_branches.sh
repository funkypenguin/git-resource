branches=$(jq -r '.version.branches // ""' <<< "$payload")

if [[ "$branches" == "NONE" ]]; then
    echo "[]" > "${destination}/branches.json"
    jq -n \
        --argjson version "$(jq -r '.version' <<< "$payload")" \
        --arg branches_value "EMPTY" \
        '{version: $version, metadata: [{name: "branches", value: $branches_value}]}' >&3
    exit 0
fi

echo "$branches" | jq -Rc 'split(",")' > "${destination}/branches.json"

# Format branches as a multi-line string for nicely printing in metadata
branches_metadata=$(echo "$branches" | jq -Rrc 'split(",") | join("\n")')

jq -n \
    --argjson version "$(jq -r '.version' <<< "$payload")" \
    --arg branches_value "$branches_metadata" \
    '{version: $version, metadata: [{name: "branches", value: $branches_value}]}' >&3
