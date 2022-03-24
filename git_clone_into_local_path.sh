# Clones given git url to a predefined folder in your machine.
#
# Usage:
#   ./git_clone_into_local_path.sh git@gitlab.workfront.tech:visibility/titan-solr-search.git
# 
# If you don't want to open editor automatically, pass --no-open flag:
#   ./git_clone_into_local_path.sh --no-open git@gitlab.workfront.tech:visibility/titan-solr-search.git
# 
# Links from github.com are also supported:
#   ./git_clone_into_local_path.sh git@github.com:bvaughn/react-window.git
#
# As zsh alias:
#   alias clone="~/Projects/github/bhovhannes/scripts/git_clone_into_local_path.sh"
#

set -euo pipefail
_git_extension=".git"

# Which editor to use
_editor="webstorm"   

# Where to clone projects from work gitlab instance
local_work_gitlab_dir="${HOME}/dev/gitlab/"

# Where to clone projects from github.com
local_personal_github_dir="${HOME}/Projects/github/"

# loop through command-line args and fill variables accordingly
_open=1
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --no-_open) _open=0 ;;
        *) _url=$1 ;;
    esac
    shift
done

if [[ $_url == git@* ]]
then
    # Determine _path from git _url
    _path=${_url#*@}
    _host=${_path%:*}
    _path=${_path#*:}
    if [[ $_path == *${_git_extension} ]]
    then
        _path=${_path%${_git_extension}}
    fi

    # Build directory _path to clone repo into
    case $_host in
    "gitlab.workfront.tech") _path="${local_work_gitlab_dir}${_path}" ;;
    "github.com") _path="${local_personal_github_dir}${_path}" ;;
    esac
    
    # Ask what to do if directory exists
    if [[ -d "${_path}" ]]
    then
        while true; do
            printf "\nDirectory \"%s\" already exists.\n" "${_path}"
            # shellcheck disable=SC2162
            read -p "Do you wish to remove it and clone from scratch? " yn
            case $yn in
                [Yy]* ) echo "Sounds good, I will 'rm -rf' it now.\n"; rm -rf "${_path}"; break;;
                [Nn]* ) exit;;
                * ) echo "Please answer yes or no.";;
            esac
        done
    fi

    echo "Cloning ${_url} ..."
    git clone "${_url}" "${_path}"
    
    if [[ $_open == 1 ]]
    then
        echo "Opening ${_path} in editor ..."
        (exec $_editor "${_path}")
    fi
else
    echo "Don't know what to do with ${_url}. Please pass a valid git url, starting with 'git@'."
fi
