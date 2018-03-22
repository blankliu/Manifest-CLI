#!/bin/bash -e

export PS4='+ [$(basename ${BASH_SOURCE})] [${LINENO}] '
SCRIPT_NAME=$(basename $0)

# Create 4 associative arrays
# -------------------------------------------------------
# ArrayName             Key             Value
# -------------------------------------------------------
# PR_MAPPING            revision        project name
# CMD_OPTION_MAPPING    sub-command     options
# CMD_USAGE_MAPPING     sub-command     function name
# CMD_FUNCTION_MAPPING  sub-command     function name
# -------------------------------------------------------
declare -A PR_MAPPING
declare -A CMD_OPTION_MAPPING
declare -A CMD_USAGE_MAPPING
declare -A CMD_FUNCTION_MAPPING
DEFAULT_REVISON=

# Define error codes
ERROR_CODE_INVALID_MANIFEST_FILE=1
ERROR_CODE_FILE_NOT_FOUND=2

function log_i() {
    echo -e "Info : $*"
}

function log_e() {
    echo -e "Error: $*"
}

# > Get default revision of a manifest file
#   @Param
#      1st: manifest file 
function __get_default_revision() {
    local _MF_FILE=
    local _EXPR=

    _MF_FILE="$1"
    _EXPR="/manifest/default/@revision"
    DEFAULT_REVISON=$(xmllint --xpath "$_EXPR" $_MF_FILE 2> /dev/null || true)
    if [ -n "$DEFAULT_REVISON" ]; then
        DEFAULT_REVISON=$(echo "$DEFAULT_REVISON" |
            xargs | \
            cut -d"=" -f2)
    else
        log_e "no default revision found in manifest file: $_MF_FILE"
        log_e "is this a valid manifest file?"

        exit $ERROR_CODE_INVALID_MANIFEST_FILE
    fi
}

# > Get revisions of all projects of a manifest file
#   @Param
#      1st: manifest file 
function __get_project_revisions() {
    local _MF_FILE=
    local _EXPR=
    local _PJ_REVISIONS=

    _MF_FILE="$1"
    _EXPR="//project/@revision"
    _PJ_REVISIONS=$(xmllint --xpath "$_EXPR" $_MF_FILE | \
        xargs -n1 | \
        sort | \
        uniq | \
        cut -d"=" -f2)

    echo "$_PJ_REVISIONS"
}

# > Get name of projects by their attribute revision
#   @Param
#      1st: manifest file 
#      2nd: value of attribute revision
function __get_projects_by_revision() {
    local _MF_FILE=
    local _REVISION=
    local _EXPR=
    local _PJ_NAMES=

    _MF_FILE="$1"
    _REVISION=$2
    _EXPR="//project[@revision=\"$_REVISION\"]/@name"
    _PJ_NAMES=$(xmllint --xpath "$_EXPR" $_MF_FILE | \
        xargs -n1 | \
        sort | \
        cut -d"=" -f2 | \
        sed "s|.git||g")

    PR_MAPPING["$_REVISION"]="$_PJ_NAMES"
}

# > Get name of projects which have no revision attribute
#   @Param
#      1st: manifest file 
function __get_projects_without_revision() {
    local _MF_FILE=
    local _EXPR=
    local _PJ_NAMES=

    _MF_FILE="$1"
    _EXPR="//project[not(@revision)]/@name"
    _PJ_NAMES=$(xmllint --xpath "$_EXPR" $_MF_FILE 2> /dev/null || true)
    if [ -n "$_PJ_NAMES" ]; then
        _PJ_NAMES=$(echo "$_PJ_NAMES" | \
            xargs -n1 | \
            sort | \
            cut -d"=" -f2 | \
            sed "s|.git||g")

        PR_MAPPING["$DEFAULT_REVISON"]="$_PJ_NAMES"
    else
        PR_MAPPING["$DEFAULT_REVISON"]=""
    fi
}

# > Show related the names of projects which share a same revision
#   @Param
#      1st: value of a revision
function __show_projects_by_revision() {
    local _TITLE=
    local _REVISION=
    local _COUNT=

    _REVISION="$1"
    _COUNT=$(echo ${PR_MAPPING[$_REVISION]} | wc -w)
    _TITLE="Projects with Revision: $_REVISION ($_COUNT)"
    echo "$_TITLE"
    printf "%-${#_TITLE}s\n" "-" | sed "s| |-|g"
    echo "${PR_MAPPING[$_REVISION]}" | xargs -n1
}

function __decompose_manifest() {
    local _MF_FILE=

    _MF_FILE="$1"

    __get_default_revision "$_MF_FILE"
    for I in $(__get_project_revisions "$_MF_FILE"); do
        __get_projects_by_revision "$_MF_FILE" "$I"
    done
    __get_projects_without_revision "$_MF_FILE"
}

function __print_usage_of_classify() {
    cat << EOU
SYSNOPSIS
    1. $SCRIPT_NAME classify -f <MANIFEST>

DESCRIPTION
    It classifies Git projects in a manifest file together by their revisions.

OPTIONS
    -f|--file
        Specify the path of a manifest file.
EOU
}

function __classify() {
    local _SUB_CMD=
    local _MF_FILE=
    local _REVISIONS=
    local _RET_VALUE=

    _SUB_CMD="classify"
    _RET_VALUE=0

    if [ $# -eq 0 ]; then
        eval "${CMD_USAGE_MAPPING[$_SUB_CMD]}"
        return $_RET_VALUE
    fi

    _ARGS=$(getopt ${CMD_OPTION_MAPPING[$_SUB_CMD]} -- $@)
    eval set -- "$_ARGS"
    while [ $# -gt 0 ]; do
        case $1 in
            -f|--file)
                _MF_FILE="$2"
                ;;
            -h|--help)
                eval "${CMD_USAGE_MAPPING[$_SUB_CMD]}"
                return $_RET_VALUE
                ;;
            --)
                shift
                break
                ;;
        esac
        shift
    done

    if [ -f "$_MF_FILE" ]; then
        __decompose_manifest "$_MF_FILE"
        _REVISIONS=$(echo "${!PR_MAPPING[@]}" | xargs -n1 | sort)
        for I in $(echo "$_REVISIONS"); do
            __show_projects_by_revision "$I"
            echo
        done
    else
        log_e "file not found: $_MF_FILE"
        _RET_VALUE=$ERROR_CODE_FILE_NOT_FOUND
    fi

    return $_RET_VALUE
}

function __print_usage_of_fork() {
    cat << EOU
SYSNOPSIS
    1. $SCRIPT_NAME fork -f <MANIFEST> -b <BRANCH> --batch-mode
    2. $SCRIPT_NAME fork -f <MANIFEST> -b <BRANCH>

DESCRIPTION
    It provides two modes to generate a configuration file for creating new
    branches.
    - Batch Mode (1st form)
      Used to generate configuration basing on a given static manifest file.
    - Interactive Mode (2nd form)
      Used to generate configuration basing on a manifest file using branches as
      revisions.

OPTIONS
    -f|--file
        Specify the path of a manifest file.

    -b|--branch
        Specify the name of a new branch.

    --batch-mode
        Specify using batch mode.

    -o|--output
        Specify a file to keep configuration of branch creation.
        If not specified, a file named 'branches.config' under the execution
        path will be created by default.
EOU
}

function __fork() {
    local _SUB_CMD=
    local _MF_FILE=
    local _BRANCH=
    local _BATCH_MODE=
    local _OUTPUT_FILE=
    local _PROMPT=
    local _CHOICE=
    local _FORK_BRANCH=
    local _RET_VALUE=

    _SUB_CMD="fork"
    _BATCH_MODE="false"
    _OUTPUT_FILE="$PWD/branches.config"
    _RET_VALUE=0

    if [ $# -eq 0 ]; then
        eval "${CMD_USAGE_MAPPING[$_SUB_CMD]}"
        return $_RET_VALUE
    fi

    _ARGS=$(getopt ${CMD_OPTION_MAPPING[$_SUB_CMD]} -- $@)
    eval set -- "$_ARGS"
    while [ $# -gt 0 ]; do
        case $1 in
            -f|--file)
                _MF_FILE="$2"
                ;;
            -b|--branch)
                _BRANCH="$2"
                ;;
            --batch-mode)
                _BATCH_MODE="true"
                ;;
            -o|--output)
                _OUTPUT_FILE="$2"
                ;;
            -h|--help)
                eval "${CMD_USAGE_MAPPING[$_SUB_CMD]}"
                return $_RET_VALUE
                ;;
            --)
                shift
                break
                ;;
        esac
        shift
    done

    __get_default_revision "$_MF_FILE"

    for I in $(__get_project_revisions "$_MF_FILE"); do
        __get_projects_by_revision "$_MF_FILE" "$I"
    done
    __get_projects_without_revision "$_MF_FILE"

    if [ -f "$_OUTPUT_FILE" ]; then
        log_i "overwriting existing file: $_OUTPUT_FILE"
        rm "$_OUTPUT_FILE"
    fi
    touch "$_OUTPUT_FILE"

    if eval "$_BATCH_MODE"; then
        for R in ${!PR_MAPPING[@]}; do
            __show_projects_by_revision "$R"

            log_i "generating branch creation configuration for them"
            for P in $(echo ${PR_MAPPING[$R]}); do
                echo "$P $_BRANCH $R" >> "$_OUTPUT_FILE"
            done

            printf "\n%-13s\n\n" ":" | sed "s| |:|g"
        done
    else
        for R in ${!PR_MAPPING[@]}; do
            __show_projects_by_revision "$R"
            _PROMPT="Create new branch '$_BRANCH' for these projects (y/n): "
            echo
            _FORK_BRANCH="false"
            while true; do
                read -p "$_PROMPT" _CHOICE
                case "$_CHOICE" in
                    y|Y)
                        _FORK_BRANCH="true"
                        break
                        ;;
                    n|N)
                        _FORK_BRANCH="false"
                        break
                        ;;
                    *)
                        echo -e "Invalid input: '$_CHOICE'"
                        ;;
                esac
            done

            if eval "$_FORK_BRANCH"; then
                for P in $(echo ${PR_MAPPING[$R]}); do
                    echo "$P $_BRANCH $R" >> "$_OUTPUT_FILE"
                done
            else
                log_i "skip generating branch creation configuration for them"
            fi

            printf "\n%-13s\n\n" ":" | sed "s| |:|g"
        done
    fi
    log_i "check branch creation configuration from file: '$_OUTPUT_FILE'"

    return $_RET_VALUE
}

function __print_cli_usage() {
    cat << EOU
Usage: $SCRIPT_NAME [-v] <SUB_COMMAND> [<args>]

A CLI tool takes manifest files as input and performs operation basing on given
<SUB_COMMAND>.

There are sub-commands supported by this manifest CLI tool.
1. classify
   Classifies Git projects according to their revisions.
2. fork
   Creates a configuration file for branch creation.

To show usage of a <SUB_COMMAND>, use following command:
   manifest_cli help <SUB_COMMAND>

Options:
   -v|--verbose     Verbose mode with full execution trace
   -h|--help        Print usage of this CLI tool
EOU
}

function enable_verbose_mode() {
    set -x
}

function init_command_context() {
    # Maps sub-commands to their usage
    CMD_USAGE_MAPPING["classify"]="__print_usage_of_classify"
    CMD_USAGE_MAPPING["fork"]="__print_usage_of_fork"

    # Maps sub-commands to their options
    CMD_OPTION_MAPPING["classify"]="-o f:h \
        -l file:,help"
    CMD_OPTION_MAPPING["fork"]="-o f:b:o:h \
        -l file:,branch:,batch-mode,output:,help"

    # Maps sub-commands to the implementations of their functions
    CMD_FUNCTION_MAPPING["classify"]="__classify"
    CMD_FUNCTION_MAPPING["fork"]="__fork"
}

function run_cli() {
    local _SUB_CMD=
    local _CMD_FOUND=
    local _RET_VALUE=

    _CMD_FOUND="false"
    _RET_VALUE=0

    VERBOSE_MODE="false"
    while true; do
        case "$1" in
            -h|--help)
                __print_cli_usage
                return $_RET_VALUE
                ;;
            -v|--verbose)
                VERBOSE_MODE="true"
                shift
                ;;
            *)
                break
                ;;
        esac
    done

    eval "$VERBOSE_MODE" && enable_verbose_mode

    _SUB_CMD="$1"
    if [ -z "$_SUB_CMD" ]; then
        __print_cli_usage
    elif [ "$_SUB_CMD" = "--help" ]; then
        __print_cli_usage
    else
        for I in ${!CMD_FUNCTION_MAPPING[@]}; do
            if [ "$I" = "$_SUB_CMD" ]; then
                _CMD_FOUND="true"
                break
            fi
        done

        if eval "$_CMD_FOUND"; then
            shift
            eval "${CMD_FUNCTION_MAPPING[$_SUB_CMD]}" $* || \
                _RET_VALUE=$?
        else
            if [ "$_SUB_CMD" = "help" ]; then
                shift
                _SUB_CMD="$1"

                _CMD_FOUND="false"
                for I in ${!CMD_FUNCTION_MAPPING[@]}; do
                    if [ "$I" = "$_SUB_CMD" ]; then
                        _CMD_FOUND="true"
                        break
                    fi
                done

                if eval "$_CMD_FOUND"; then
                    eval "${CMD_USAGE_MAPPING[$_SUB_CMD]}"
                else
                    if [ -z "$_SUB_CMD" ]; then
                        __print_cli_usage
                    else
                        _RET_VALUE=$ERROR_CODE_COMMAND_NOT_SUPPORTED
                        log_e "unsupported sub-command: '$_SUB_CMD'"
                    fi
                fi

            else
                _RET_VALUE=$ERROR_CODE_COMMAND_NOT_SUPPORTED
                log_e "unsupported sub-command: '$_SUB_CMD'"
            fi
        fi
    fi
}


############# ENTRY POINT #############
init_command_context && run_cli $*

# vim: set shiftwidth=4 tabstop=4 expandtab
