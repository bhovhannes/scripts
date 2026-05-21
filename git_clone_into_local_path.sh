# Clones given git url to a predefined folder in your machine.
#
# Usage:
#   ./git_clone_into_local_path.sh git@gitlab.workfront.tech:visibility/titan-solr-search.git
#
# 
# If you don't want to open editor automatically, pass --no-open flag:
#   ./git_clone_into_local_path.sh --no-open git@gitlab.workfront.tech:visibility/titan-solr-search.git
#
# At the end of a successful run the script prints a summary block delimited
# by "=====" lines that reports the resulting folder (the worktree path when
# --worktree is set, otherwise the main clone path). Automation can parse the
# "Folder:" line inside this block as a stable contract.
#
# To specify a different editor, use --editor flag or shorthand flags:
#   ./git_clone_into_local_path.sh --editor=cursor git@github.com:bvaughn/react-window.git
#   ./git_clone_into_local_path.sh --cursor git@github.com:bvaughn/react-window.git
#   ./git_clone_into_local_path.sh --zed git@github.com:bvaughn/react-window.git
#   ./git_clone_into_local_path.sh --webstorm git@github.com:bvaughn/react-window.git
#
# To control behavior when the target directory already exists, use --if-exists:
#   --if-exists=prompt   (default) Ask interactively what to do.
#   --if-exists=reuse    Treat the existing directory as success; skip the clone
#                        and continue the normal flow (open editor unless --no-open).
#   --if-exists=replace  'rm -rf' the existing directory and re-clone.
#   --if-exists=fail     Exit with a non-zero status (strict/CI mode).
# --if-exists always applies to the main clone directory.
#
# To work in an isolated sibling worktree instead of the main clone, pass
# --worktree. The main clone is cloned if missing (or reused/replaced/etc.
# per --if-exists), and a worktree is created at "<repo>.worktrees/<branch>"
# checked out to the requested branch. With --worktree the worktree path is
# what the summary reports and what the editor opens.
#
# To control behavior when the worktree directory already exists, use
# --if-worktree-exists (only valid together with --worktree):
#   --if-worktree-exists=replace  (default) Wipe the worktree and recreate it
#                                 so each run starts from a clean state.
#   --if-worktree-exists=reuse    Keep the existing worktree; fetch origin and
#                                 check out the requested branch inside it.
#
# To pick the branch to check out, pass --branch. It works with or without
# --worktree:
#   * Without --worktree: after the clone (or on reuse), the branch is fetched
#     and checked out inside the main clone.
#   * With --worktree: the branch determines the worktree directory name and
#     the worktree is checked out to it.
# If --branch is omitted and --worktree is set, the repository's default
# branch (HEAD of origin) is used.
#   ./git_clone_into_local_path.sh --branch=feature/x git@github.com:org/repo.git
#   ./git_clone_into_local_path.sh --worktree --branch=feature/x \
#       git@github.com:org/repo.git
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

# The list of editors which can be used with --editor flag or shorthand flags.
# Add your editor here if you want to use it with --editor flag or with --<your-editor> flag.
supported_editors="cursor zed webstorm"

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
_open_explicit=0
_editor="${default_editor}"
_if_exists="prompt"
_if_exists_explicit=0
_supported_if_exists="prompt reuse replace fail"
_branch=""
_worktree=0
_if_worktree_exists="replace"
_if_worktree_exists_explicit=0
_supported_if_worktree_exists="replace reuse"
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --no-open) _open=0; _open_explicit=1 ;;
        --editor=*) _editor="${1#*=}"; _open_explicit=1 ;;
        --if-exists=*) _if_exists="${1#*=}"; _if_exists_explicit=1 ;;
        --branch=*) _branch="${1#*=}" ;;
        --worktree) _worktree=1 ;;
        --if-worktree-exists=*) _if_worktree_exists="${1#*=}"; _if_worktree_exists_explicit=1 ;;
        --*)
            # Check if argument matches any supported editor
            _flag="${1#--}"
            if [[ " ${supported_editors} " == *" ${_flag} "* ]]; then
                _editor="${_flag}"
                _open_explicit=1
            else
                _url=$1
            fi
            ;;
        *) _url=$1 ;;
    esac
    shift
done

# Validate --if-exists value
if [[ " ${_supported_if_exists} " != *" ${_if_exists} "* ]]; then
    echo "Invalid value for --if-exists: '${_if_exists}'. Supported: ${_supported_if_exists}." >&2
    exit 2
fi

# Validate --if-worktree-exists value
if [[ " ${_supported_if_worktree_exists} " != *" ${_if_worktree_exists} "* ]]; then
    echo "Invalid value for --if-worktree-exists: '${_if_worktree_exists}'. Supported: ${_supported_if_worktree_exists}." >&2
    exit 2
fi

# --if-worktree-exists is only meaningful with --worktree.
if [[ $_if_worktree_exists_explicit == 1 && $_worktree == 0 ]]; then
    echo "--if-worktree-exists is only supported together with --worktree." >&2
    exit 2
fi

# When running without a controlling terminal (e.g. invoked by an agent or CI),
# switch to non-interactive defaults unless the user set them explicitly:
#   --if-exists=reuse  (don't prompt; treat existing dir as success)
#   --no-open          (don't launch a GUI editor no one will see)
if [[ ! -t 1 ]]; then
    if [[ $_if_exists_explicit == 0 && $_if_exists == "prompt" ]]; then
        _if_exists="reuse"
        echo "No TTY detected; --if-exists defaulting to reuse." >&2
    fi
    if [[ $_open_explicit == 0 && $_open == 1 ]]; then
        _open=0
        echo "No TTY detected; not opening editor." >&2
    fi
fi

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
        # Check if first segment contains Adobe- or -Adobe, or is exactly OneAdobe (case-insensitive)
        shopt -s nocasematch
        if [[ $_first_segment == *"Adobe-"* ]] || [[ $_first_segment == *"-Adobe"* ]] || [[ $_first_segment == "OneAdobe" ]]; then
            _is_adobe_org=1
        else
            _is_adobe_org=0
        fi
        shopt -u nocasematch
        if [[ $_is_adobe_org -eq 1 ]]; then
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

    # The effective path is what the final summary reports and the editor
    # opens. It points at the main clone by default, or at the worktree when
    # --worktree is set and the worktree path has been resolved.
    _effective_path="${_path}"

    # --if-exists always governs the main clone directory, regardless of
    # --worktree. After this block, ${_path} is guaranteed to be a usable git
    # clone (either freshly created or preserved/reused).
    _skip_clone=0
    if [[ -d "${_path}" ]]
    then
        case $_if_exists in
            reuse)
                _skip_clone=1
                ;;
            replace)
                printf "\nDirectory \"%s\" already exists. Removing it and re-cloning.\n\n" "${_path}"
                rm -rf "${_path}" "${_path}.worktrees"
                ;;
            fail)
                echo "Directory \"${_path}\" already exists." >&2
                exit 1
                ;;
            prompt)
                while true; do
                    printf "\nDirectory \"%s\" already exists.\n" "${_path}"
                    if [[ $_open == 1 ]]
                    then
                        # shellcheck disable=SC2162
                        read -p "Do you wish to remove it and clone from scratch? [y/n/oO] " yn
                        case $yn in
                            [Yy]* ) printf "Sounds good, I will 'rm -rf' it now.\n\n"; rm -rf "${_path}" "${_path}.worktrees"; break;;
                            [Nn]* ) exit;;
                            [oO]* ) _skip_clone=1; break;;
                            * ) echo "Please answer yes (y), no (n), or open (oO).";;
                        esac
                    else
                        # shellcheck disable=SC2162
                        read -p "Do you wish to remove it and clone from scratch? [y/n] " yn
                        case $yn in
                            [Yy]* ) printf "Sounds good, I will 'rm -rf' it now.\n\n"; rm -rf "${_path}" "${_path}.worktrees"; break;;
                            [Nn]* ) exit;;
                            * ) echo "Please answer yes (y) or no (n).";;
                        esac
                    fi
                done
                ;;
        esac
    fi

    if [[ $_skip_clone == 0 ]]
    then
        echo "Cloning ${_url} ..."
        (cd "${_base_dir}" && git clone "${_url}" "${_path}")
    fi

    if [[ $_worktree == 1 ]]
    then
        # Worktree flow: the main clone is left on whatever branch it was on;
        # a sibling worktree is (re)created for the requested branch so the
        # agent gets a clean working tree without disturbing the main clone.
        if [[ ! -d "${_path}/.git" && ! -f "${_path}/.git" ]]
        then
            echo "Directory \"${_path}\" exists but is not a git repository." >&2
            exit 1
        fi

        echo "Fetching latest refs in ${_path} ..."
        git -C "${_path}" fetch --prune origin

        if [[ -z "${_branch}" ]]
        then
            # Resolve default branch from the remote HEAD symbolic ref.
            _remote_head=$(git -C "${_path}" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || true)
            if [[ -z "${_remote_head}" ]]
            then
                git -C "${_path}" remote set-head origin --auto >/dev/null
                _remote_head=$(git -C "${_path}" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || true)
            fi
            if [[ -z "${_remote_head}" ]]
            then
                echo "Could not resolve default branch of origin in ${_path}." >&2
                exit 1
            fi
            _branch="${_remote_head#origin/}"
            echo "Using default branch: ${_branch}"
        fi

        _sanitized_branch="${_branch//\//-}"
        _worktree_path="${_path}.worktrees/${_sanitized_branch}"
        _effective_path="${_worktree_path}"

        mkdir -p "${_path}.worktrees"

        if [[ -d "${_worktree_path}" && $_if_worktree_exists == "reuse" ]]
        then
            # Reuse the existing worktree: fetch and check out the requested
            # branch inside it. Any uncommitted changes in the worktree may
            # block the checkout, which preserves in-progress work.
            echo "Reusing existing worktree at ${_worktree_path} ..."
            git -C "${_worktree_path}" fetch --prune origin
            if git -C "${_worktree_path}" show-ref --verify --quiet "refs/heads/${_branch}"
            then
                git -C "${_worktree_path}" checkout "${_branch}"
            else
                git -C "${_worktree_path}" checkout -b "${_branch}" --track "origin/${_branch}"
            fi
            git -C "${_worktree_path}" pull --ff-only origin "${_branch}" || \
                echo "Warning: fast-forward pull failed; leaving worktree at its current commit." >&2
        else
            # Always recreate the worktree so the agent starts from a clean
            # state. Uncommitted changes in the worktree are discarded; the
            # main clone is untouched.
            if [[ -d "${_worktree_path}" ]]
            then
                echo "Removing existing worktree at ${_worktree_path} ..."
                git -C "${_path}" worktree remove --force "${_worktree_path}" 2>/dev/null || true
                rm -rf "${_worktree_path}"
                git -C "${_path}" worktree prune
            fi

            echo "Creating worktree at ${_worktree_path} for branch '${_branch}' ..."
            if git -C "${_path}" show-ref --verify --quiet "refs/heads/${_branch}"
            then
                git -C "${_path}" worktree add --force "${_worktree_path}" "${_branch}"
                # Align the (possibly stale) local branch with origin/<branch>
                # so a freshly-created worktree always reflects the remote tip.
                git -C "${_worktree_path}" reset --hard "origin/${_branch}"
            else
                git -C "${_path}" worktree add --force -b "${_branch}" "${_worktree_path}" "origin/${_branch}"
            fi
        fi
    elif [[ -n "${_branch}" ]]
    then
        # No worktree: switch the main clone to the requested branch.
        # Refuse to proceed when there are uncommitted changes so that
        # in-progress edits cannot be silently carried into another branch.
        # Users who need an isolated working tree should pass --worktree.
        if ! git -C "${_path}" diff --quiet --ignore-submodules HEAD 2>/dev/null
        then
            echo "Working tree in ${_path} has uncommitted changes." >&2
            echo "Refusing to switch to '${_branch}' in the main clone; pass --worktree to work in a sibling worktree." >&2
            exit 1
        fi

        echo "Fetching latest refs in ${_path} ..."
        git -C "${_path}" fetch --prune origin
        echo "Checking out branch '${_branch}' ..."
        if git -C "${_path}" show-ref --verify --quiet "refs/heads/${_branch}"
        then
            git -C "${_path}" checkout "${_branch}"
        else
            git -C "${_path}" checkout -b "${_branch}" --track "origin/${_branch}"
        fi
    fi

    # Final summary block. Delimited so humans can spot the result quickly and
    # automation can parse the "Folder:" line as a stable contract.
    if [[ $_worktree == 1 ]]
    then
        _summary_kind="worktree"
    else
        _summary_kind="clone"
    fi
    printf '\n'
    printf '=====================================================================\n'
    printf 'Summary\n'
    printf '  Kind:   %s\n' "${_summary_kind}"
    printf '  Folder: %s\n' "${_effective_path}"
    printf '=====================================================================\n'
    printf '\n'

    if [[ $_open == 1 ]]
    then
        echo "Opening ${_effective_path} in editor ..."
        (exec "${_editor}" "${_effective_path}")
    fi
else
    echo "Don't know what to do with ${_url}. Please pass a valid git url, starting with 'git@'."
    exit 1
fi
