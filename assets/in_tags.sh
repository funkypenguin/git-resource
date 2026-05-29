tag=$(jq -r '.version.tag // ""' <<< "$payload")
ref=$(jq -r '.version.ref // ""' <<< "$payload")
submodules=$(jq -r '(.params.submodules // "all")' <<< "$payload")
submodule_recursive=$(jq -r '(.params.submodule_recursive // true)' <<< "$payload")
submodule_remote=$(jq -r '(.params.submodule_remote // false)' <<< "$payload")
disable_git_lfs=$(jq -r '(.params.disable_git_lfs // false)' <<< "$payload")
commit_verification_key_ids=$(jq -r '(.source.commit_verification_key_ids // [])[]' <<< "$payload")
commit_verification_keys=$(jq -r '(.source.commit_verification_keys // [])[]' <<< "$payload")
gpg_keyserver=$(jq -r '.source.gpg_keyserver // "hkp://keyserver.ubuntu.com/"' <<< "$payload")
short_ref_format=$(jq -r '(.params.short_ref_format // "%s")' <<< "$payload")
timestamp_format=$(jq -r '(.params.timestamp_format // "iso8601")' <<< "$payload")

if [ "$disable_git_lfs" == "true" ]; then
  # skip the fetching of LFS objects for all following git commands
  export GIT_LFS_SKIP_SMUDGE=1
fi

git config --global advice.detachedHead false
git clone --progress --depth 1 --branch "$tag" "$uri" "$destination"

cd $destination

configure_git_local "${git_config_payload}"

invalid_key() {
  echo "Invalid GPG key in: ${commit_verification_keys}"
  exit 2
}

commit_not_signed() {
  commit_id=$(git rev-parse ${ref})
  echo "The commit ${commit_id} is not signed"
  exit 1
}

if [ ! -z "${commit_verification_keys}" ] || [ ! -z "${commit_verification_key_ids}" ] ; then
  if [ ! -z "${commit_verification_keys}" ]; then
    echo "${commit_verification_keys}" | gpg --batch --import || invalid_key "${commit_verification_keys}"
  fi
  if [ ! -z "${commit_verification_key_ids}" ]; then
    echo "${commit_verification_key_ids}" | \
      xargs --no-run-if-empty -n1 gpg --batch --keyserver $gpg_keyserver --recv-keys
  fi
  git verify-commit $(git rev-list -n 1 $ref) || commit_not_signed
fi

git log -1 --oneline
git clean --force --force -d
git submodule sync

if [ -f $GIT_CRYPT_KEY_PATH ]; then
  echo "unlocking git repo"
  git-crypt unlock $GIT_CRYPT_KEY_PATH
fi

submodule_parameters=""
if [ "$submodule_remote" != "false" ]; then
  submodule_parameters+=" --remote "
fi
if [ "$submodule_recursive" != "false" ]; then
  submodule_parameters+=" --recursive "
fi

if [ "$submodules" != "none" ]; then
  value_regexp="."
  if [ "$submodules" != "all" ]; then
    value_regexp="$(echo $submodules | jq -r 'map(. + "$") | join("|")')"
  fi

  {
    git config --file .gitmodules --name-only --get-regexp '\.path$' "$value_regexp" |
      sed -e 's/^submodule\.\(.\+\)\.path$/\1/'
  } | while read submodule_name; do
    submodule_path="$(git config --file .gitmodules --get "submodule.${submodule_name}.path")"
    submodule_url="$(git config --file .gitmodules --get "submodule.${submodule_name}.url")"

    if ! [ -e "$submodule_path" ]; then
      echo $'\e[31m'"warning: skipping missing submodule: $submodule_path"$'\e[0m'
      continue
    fi

    # check for ssh submodule_credentials
    submodule_cred=$(jq --arg submodule_url "${submodule_url}" '.source.submodule_credentials // [] | [.[] | select(.url==$submodule_url)] | first // empty' <<< "${payload}")

    if [[ -z ${submodule_cred} ]]; then

      # update normally
      git submodule update --init --no-fetch $submodule_parameters "$submodule_path"

    else

      # create or re-initialize ssh-agent
      init_ssh_agent

      private_key=$(jq -r '.private_key' <<< ${submodule_cred})
      passphrase=$(jq -r '.private_key_passphrase // empty' <<< ${submodule_cred})

      private_key_path=$(mktemp -t git-resource-submodule-private-key.XXXXXX)
      echo "${private_key}" > ${private_key_path}
      chmod 0600 ${private_key_path}

      # add submodule private_key identity
      SSH_ASKPASS_REQUIRE=force SSH_ASKPASS=$(dirname $0)/askpass.sh GIT_SSH_PRIVATE_KEY_PASS="$passphrase" DISPLAY= ssh-add $private_key_path > /dev/null

      git submodule update --init --no-fetch $submodule_parameters "$submodule_path"

      # restore main ssh-agent (if needed)
      load_pubkey "${payload}"

    fi

  done
fi

if [ "$ref" == "HEAD" ]; then
  return_ref=$(git rev-parse HEAD)
else
  return_ref=$ref
fi

# Store committer email in .git/committer. Can be used to send email to last committer on failed build
# Using https://github.com/mdomke/concourse-email-resource for example
git --no-pager log -1 --pretty=format:"%ae" > .git/committer

git --no-pager log -1 --pretty=format:"%an" > .git/committer_name

# Store git-resource returned version ref .git/ref. Useful to know concourse
# pulled ref in following tasks and resources.
echo "${return_ref}" > .git/ref

metadata=$(git_metadata)
echo "${metadata}" | jq '.' > .git/metadata.json

# Store short ref with templating. Useful to build Docker images with
# a custom tag
echo "${return_ref}" | cut -c1-7 | awk "{ printf \"${short_ref_format}\", \$1 }" > .git/short_ref

# Write individual metadata fields to separate files

# .git/commit - full SHA hash
echo "${metadata}" | jq -r '.[] | select(.name == "commit") | .value' > .git/tag
# .git/author - commit author name
echo "${metadata}" | jq -r '.[] | select(.name == "author") | .value' > .git/author
# .git/author_date - timestamp when the author originally created the commit
echo "${metadata}" | jq -r '.[] | select(.name == "author_date") | .value' > .git/author_date
# .git/url - web URL to view commit (if applicable)
echo "${metadata}" | jq -r '.[] | select(.name == "url") | .value // ""' > .git/url
# .git/committer_date - timestamp when the commit was created in the repository
echo "${metadata}" | jq -r '.[] | select(.name == "committer_date") | .value // ""' > .git/committer_date

# Store commit message in .git/commit_message. Can be used to inform about
# the content of a successful build.
# Using https://github.com/cloudfoundry-community/slack-notification-resource
# for example
git log -1 --format=format:%B > .git/commit_message

# Store commit date in .git/commit_timestamp. Can be used for tagging builds
git log -1 --format=%cd --date=${timestamp_format} > .git/commit_timestamp


jq -n \
  --arg ref "$return_ref" \
  --arg tag "$tag" \
  --argjson metadata "$metadata" \
  '{
  version: {ref: $ref, tag: $tag},
  metadata: $metadata
}' >&3
