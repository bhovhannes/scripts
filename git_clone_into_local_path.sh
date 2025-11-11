# Clones given git url to a predefined folder in your machine.
#
# Usage:
#   ./git_clone_into_local_path.sh git@gitlab.workfront.tech:visibility/titan-solr-search.git
#
# 
# If you don't want to open editor automatically, pass --no-open flag:
#   ./git_clone_into_local_path.sh --no-open git@gitlab.workfront.tech:visibility/titan-solr-search.git
# 
# To specify a different editor, use --editor flag:
#   ./git_clone_into_local_path.sh --editor=cursor git@github.com:bvaughn/react-window.git
#   ./git_clone_into_local_path.sh --editor=zed git@github.com:bvaughn/react-window.git
# 
# Links from github.com are also supported:
#   ./git_clone_into_local_path.sh git@github.com:bvaughn/react-window.git
#
#
# Enterprise GitHub repositories (Adobe-*, *-Adobe, OneAdobe) are automatically
# detected and cloned using 'ghec' host alias:
#   ./git_clone_into_local_path.sh git@github.com:Adobe-dxue/unified-shell.git
#   (will be cloned as git@ghec:Adobe-dxue/unified-shell.git)
#
# This assumes SSH config has a 'ghec' host alias configured for enterprise GitHub:
# > more ~/.ssh/config
#   
#   Host github.com
#     AddKeysToAgent yes
#     UseKeychain yes
#     IdentityFile ~/.ssh/github-personal/id_ed25519
#
#   Host ghec
#     HostName github.com
#     AddKeysToAgent yes
#     UseKeychain yes
#     IdentityFile ~/.ssh/ghec/id_ed25519
#
#
# As zsh alias:
#   alias clone="~/Projects/github/bhovhannes/scripts/git_clone_into_local_path.sh"
#

set -euo pipefail
_git_extension=".git"

# Default editor to use
default_editor="webstorm"   

# Where to clone projects from work gitlab instance
local_work_gitlab_dir="${HOME}/dev/gitlab/"

# Where to clone projects from github.com
local_personal_github_dir="${HOME}/Projects/github/"

# Where to clone projects from git.corp.adobe.com
local_corp_github_dir="${HOME}/dev/github/"

# Where to clone projects from enterprise github.com
# Note: Assumes SSH config has a 'ghec' host alias configured for enterprise GitHub
local_ghec_dir="${HOME}/dev/ghec/"


# loop through command-line args and fill variables accordingly
_open=1
_editor="${default_editor}"
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --no-_open) _open=0 ;;
        --editor=*) _editor="${1#*=}" ;;
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

    # Determine base directory and build full path to clone repo into
    case $_host in
    "gitlab.workfront.tech")
        _base_dir="${local_work_gitlab_dir}"
        _path="${local_work_gitlab_dir}${_path}"
        ;;
    "github.com")
        # Extract first path segment (organization/user name)
        _first_segment=${_path%%/*}
        # Check if first segment contains Adobe- or -Adobe, or is exactly OneAdobe
        if [[ $_first_segment == *"Adobe-"* ]] || [[ $_first_segment == *"-Adobe"* ]] || [[ $_first_segment == "OneAdobe" ]]; then
            _base_dir="${local_ghec_dir}"
            _path="${local_ghec_dir}${_path}"
            _url=${_url/github.com/ghec}
        else
            _base_dir="${local_personal_github_dir}"
            _path="${local_personal_github_dir}${_path}"
        fi
        ;;
    "git.corp.adobe.com")
        _base_dir="${local_corp_github_dir}"
        _path="${local_corp_github_dir}${_path}"
        ;;
    esac
    
    # Ask what to do if directory exists
    _skip_clone=0
    if [[ -d "${_path}" ]]
    then
        while true; do
            printf "\nDirectory \"%s\" already exists.\n" "${_path}"
            if [[ $_open == 1 ]]
            then
                # shellcheck disable=SC2162
                read -p "Do you wish to remove it and clone from scratch? [y/n/oO] " yn
                case $yn in
                    [Yy]* ) printf "Sounds good, I will 'rm -rf' it now.\n\n"; rm -rf "${_path}"; break;;
                    [Nn]* ) exit;;
                    [oO]* ) _skip_clone=1; break;;
                    * ) echo "Please answer yes (y), no (n), or open (oO).";;
                esac
            else
                # shellcheck disable=SC2162
                read -p "Do you wish to remove it and clone from scratch? [y/n] " yn
                case $yn in
                    [Yy]* ) printf "Sounds good, I will 'rm -rf' it now.\n\n"; rm -rf "${_path}"; break;;
                    [Nn]* ) exit;;
                    * ) echo "Please answer yes (y) or no (n).";;
                esac
            fi
        done
    fi

    if [[ $_skip_clone == 0 ]]
    then
        echo "Cloning ${_url} ..."
        (cd "${_base_dir}" && git clone "${_url}" "${_path}")
    fi
    
    if [[ $_open == 1 ]]
    then
        echo "Opening ${_path} in editor ..."
        (exec $_editor "${_path}")
    fi
else
    echo "Don't know what to do with ${_url}. Please pass a valid git url, starting with 'git@'."
fi
