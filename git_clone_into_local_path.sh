# Clones given git url to a predefined folder in your machine.
#
# Usage:
#   clone git@gitlab.workfront.tech:visibility/titan-solr-search.git
# 
# If you don't want to open editor autmatically, pass --no-open flag:
#   clone --no-open git@gitlab.workfront.tech:visibility/titan-solr-search.git
# 
# Links from github.com are also supported:
#   clone git@github.com:bvaughn/react-window.git
#
git_clone_into_local_path() {
    set -euo pipefail
    local git_extension=".git"
    
    # Which editor to use
    local editor="webstorm"   
    
    # Where to clone projects from work gitlab instance
    local local_work_gitlab_dir="${HOME}/dev/gitlab/"

    # Where to clone projects from github.com
    local local_personal_github_dir="${HOME}/Projects/github/"

    # loop through command-line args and fill local variables accordingly
    local open=1
    local url
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            --no-open) open=0 ;;
            *) url=$1 ;;
        esac
        shift
    done

    if [[ $url == git@* ]]
    then
        # Determine path from git url
        local path=${url#*@}
        local host=${path%:*}
        path=${path#*:}
        if [[ $path == *${git_extension} ]]
        then
            path=${path%${git_extension}}
        fi

        # Build local directory path to clone repo into
        case $host in
        "gitlab.workfront.tech") path="${local_work_gitlab_dir}${path}" ;;
        "github.com") path="${local_personal_github_dir}${path}" ;;
        esac

        echo "Cloning ${url} ..."
        git clone "${url}" "${path}"
        
        if [[ $open == 1 ]]
        then
            echo "Opening ${path} in editor ..."
            command $editor "${path}"
        fi
    else
        echo "Don't know what to do with ${url}. Please pass a valid git url, starting with 'git@'."
        return 1
    fi
}
