#! /usr/bin/env bash
#
# Makes a deep or shallow clone of all customer repositories across ucroo and ucroo-community organizations.
#
# Running this script will create a directory structure like this (but with all repos listed):
# .
# ├── ucroo
# │   ├── ihub-partner-1
# │   ├── ihub-partner-2
# │   ├── ihub-partner-3
# │   ├── ihub-partner-4
# │   ├── ihub-partner-5
# │   ├── ihub-partner-6
# └── ucroo-community
#     ├── ihub-community-1
#     ├── ihub-community-2
#     ├── ihub-community-3
#     ├── ihub-partner-4
#     ├── ihub-partner-5
#     ├── ihub-partner-6
#     └── ihub-partner-7
#

function quit() {
    >&2 echo "$*"
    exit 1
}

function usage() {
    message=$(
        cat <<'EOF'
usage: clone_customer_repo.sh GITHUB_USER DIRECTORY DEPTH

    GITHUB_USER - the GitHub user account name that your GitHub Personal Access Token was
                  created for.
    DIRECTORY   - the directory that will be created and where all repositories will be
                  cloned to.
    DEPTH       - (deep|shallow) - deep makes a full clone of the repository, shallow
                  makes a shallow clone of the repository (which takes up less disk space).
EOF
)
    quit "$message"
}

function find_command() {
    command -v $1 > /dev/null
}

function org_clone_urls() {
    org_name=$1
    # -sS will turn off the progress bar
    curl -sS -H "Authorization: token $GITHUB_API_TOKEN" https://api.github.com/orgs/$org_name/repos?per_page=500 | jq '.[] | .clone_url' | grep -e "partner-\|community-\|customer-"
}

function clone_or_update_org_repos() {
    org=$1
    directory=$2
    mkdir -p "$directory/$org"
    for url in `org_clone_urls $org`; do
        # If the repository directory already exists, just attempt to pull.
        repo_dir="$directory/$org/"`echo $url | sed "s:.*/::  ; s/.git// ; s/\"//g"`
        if [ -d "$repo_dir" ]; then
            echo "Pulling in $repo_dir ..."
            git -C "$repo_dir" pull > /dev/null
            # Print a warning if the repository directory is not clean.
            [[ -z $(git -C "$repo_dir" status -uno --porcelain) ]] || echo "  warning: $repo_dir workspace is not clean."
        else
            # Inject the user name and token into the clone url and remove double quotes.
            url=`echo $url | sed "s://://$user_name\:$GITHUB_API_TOKEN@: ; s/\"//g"`
            if [ "$depth" = "deep" ]; then
                git -C "$directory/$org" clone $url
            elif [ "$depth" = "shallow" ]; then
                git -C "$directory/$org" clone --depth 1 $url
            fi
         fi
    done
}

[ "$#" = "3" ] || usage
user_name=$1
directory=$2
depth=$3

[ "$depth" = "shallow" ] || [ "$depth" = "deep" ] || usage

[ ! -z "$GITHUB_API_TOKEN" ] || quit "Please export an environment variable with the name GITHUB_API_TOKEN and a value of your GitHub API Token."

find_command jq    || quit "error: jq must be installed and in your PATH to parse API responses."
find_command curl  || quit "error: curl must be installed and in your PATH to make API requests."

mkdir -p "$directory"    || quit "Could not create '$directory' directory."

clone_or_update_org_repos ucroo "$directory"
clone_or_update_org_repos ucroo-community "$directory"
