#!/usr/bin/env bash
# Download file/folder from google drive.
# shellcheck source=/dev/null

_usage() {
    printf "%b" "
The script can be used to download file/directory from google drive.\n
Usage:\n ${0##*/} [options.. ] <file_[url|id]> or <folder[url|id]>\n
Options:\n
  -aria | --aria-flags 'flags' - Use aria2c to download. '-aria' does not take arguments.\n
      To give custom flags as argument, use long flag, --aria-flags. e.g: --aria-flags '-s 10 -x 10'\n
      Note 1: aria2c can only resume google drive downloads if '-k/--key' or '-o/--oauth' option is used, otherwise, it will use curl.\n
      Note 2: aria split downloading won't work in normal mode ( without '-k' or '-o' flag ) because it cannot get the remote server size. Same for any other feature which uses remote server size.\n
      Note 3: By above notes, conclusion is, aria is basically same as curl in normal mode, so it is recommended to be used only with '--key' and '--oauth' flag.\n
  -o | --oauth - Use this flag to trigger oauth authentication.\n
      Note: If both --oauth and --key flag is used, --oauth flag is preferred.\n
  -k | --key 'API KEY' ( optional arg ) - To download with api key. If api key is not specified, then the predefined api key will be used.\n
      To save your api key in config file, use 'gdl --key default=your api key'.
      API key will be saved in '${HOME}/.gdl.conf' and will be used from now on.\n
      Note: If both --key and --key oauth is used, --oauth flag is preferred.\n
  -c | --config 'config file path' - Override default config file with custom config file. Default: ${HOME}/.gdl.conf\n
  -d | --directory 'foldername' - option to _download given input in custom directory.\n
  -s | --skip-subdirs - Skip downloading of sub folders present in case of folders.\n
  -p | --parallel 'no_of_files_to_parallely_upload' - Download multiple files in parallel.\n
  --speed 'speed' - Limit the download speed, supported formats: 1K and 1M.\n
  -R | --retry 'num of retries' - Retry the file upload if it fails, postive integer as argument. Currently only for file uploads.\n
  -l | --log 'file_to_save_info' - Save downloaded files info to the given filename.\n
  -q | --quiet - Supress the normal output, only show success/error upload messages for files, and one extra line at the beginning for folder showing no. of files and sub folders.\n
  -V | --verbose - Display detailed message (only for non-parallel uploads).\n
  --skip-internet-check - Do not check for internet connection, recommended to use in sync jobs.\n
  -u | --update - Update the installed script in your system.\n
  --version | --info - Show detailed info, only if script is installed system wide.\n
  --uninstall - Uninstall script, remove related files.\n
  -D | --debug - Display script command trace.\n
  -h | --help - Display usage instructions.\n"
    exit 0
}

_short_help() {
    printf "No valid arguments provided, use -h/--help flag to see usage.\n"
    exit 0
}

###################################################
# Automatic updater, only update if script is installed system wide.
# Arguments: None
# Result: On
#   Update if AUTO_UPDATE_INTERVAL + LAST_UPDATE_TIME less than printf "%(%s)T\\n" "-1"
###################################################
_auto_update() {
    export REPO
    command -v "${COMMAND_NAME}" 1> /dev/null &&
        if [[ -n "${REPO:+${COMMAND_NAME:+${INSTALL_PATH:+${TYPE:+${TYPE_VALUE}}}}}" ]]; then
            current_time="$(printf "%(%s)T\\n" "-1")"
            [[ $((LAST_UPDATE_TIME + AUTO_UPDATE_INTERVAL)) -lt ${current_time} ]] && _update
            _update_value LAST_UPDATE_TIME "${current_time}"
        fi
    return 0
}

###################################################
# Install/Update/uninstall the script.
# Arguments: 1
#   ${1} = uninstall or update
# Result: On
#   ${1} = nothing - Update the script if installed, otherwise install.
#   ${1} = uninstall - uninstall the script
###################################################
_update() {
    declare job="${1:-update}"
    [[ ${GLOBAL_INSTALL} = true ]] && ! [[ $(id -u) = 0 ]] && printf "%s\n" "Error: Need root access to update." && return 0
    [[ ${job} = uninstall ]] && job_string="--uninstall"
    _print_center "justify" "Fetching ${job} script.." "-"
    declare repo="${REPO:-akianonymus/gdrive-downloader}" type_value="${TYPE_VALUE:-master}" cmd="${COMMAND_NAME:-gdl}" path="${INSTALL_PATH:-${HOME}/.gdrive-downloader}"
    if script="$(curl --compressed -Ls "https://github.com/${repo}/raw/${type_value}/install.sh")"; then
        _clear_line 1
        printf "%s\n" "${script}" | bash -s -- ${job_string:-} --skip-internet-check --cmd "${cmd}" --path "${path}"
        current_time="$(printf "%(%s)T\\n" "-1")"
        [[ -z ${job_string} ]] && _update_value LAST_UPDATE_TIME "${current_time}" &
    else
        _clear_line 1
        "${QUIET:-_print_center}" "justify" "Error: Cannot download ${job} script." "=" 1>&2
        exit 1
    fi
    exit "${?}"
}

###################################################
# Update in-script values
###################################################
_update_value() {
    declare command_path="${INSTALL_PATH:?}/${COMMAND_NAME}" \
        value_name="${1:-}" value="${2:-}" script_without_value_and_shebang
    script_without_value_and_shebang="$(grep -v "${value_name}=\".*\".* # added values" "${command_path}" | sed 1d)"
    new_script="$(
        sed -n 1p "${command_path}"
        printf "%s\n" "${value_name}=\"${value}\" # added values"
        printf "%s\n" "${script_without_value_and_shebang}"
    )"
    chmod +w "${command_path}" && printf "%s\n" "${new_script}" >| "${command_path}" && chmod -w "${command_path}"
    return 0
}

###################################################
# Print info if installed
###################################################
_version_info() {
    if command -v "${COMMAND_NAME}" 1> /dev/null && [[ -n "${REPO:+${COMMAND_NAME:+${INSTALL_PATH:+${TYPE:+${TYPE_VALUE}}}}}" ]]; then
        for i in REPO INSTALL_PATH INSTALLATION TYPE TYPE_VALUE LATEST_INSTALLED_SHA; do
            printf "%s\n" "${i}=\"${!i}\""
        done | sed -e "s/=/: /g"
    else
        printf "%s\n" "gdrive-downloader is not installed system wide."
    fi
    exit 0
}

##################################################
# Process all arguments given to the script
###################################################
_setup_arguments() {
    [[ $# = 0 ]] && printf "%s: Missing arguments\n" "${FUNCNAME[0]}" && return 1
    # Internal variables
    # De-initialize if any variables set already.
    unset LOG_FILE_ID OAUTH_ENABLED API_KEY_DOWNLOAD CONFIG FOLDERNAME SKIP_SUBDIRS NO_OF_PARALLEL_JOBS PARALLEL_DOWNLOAD
    unset DOWNLOAD_WITH_ARIA ARIA_EXTRA_FLAGS ARIA_SPEED_LIMIT_FLAG
    unset DEBUG QUIET VERBOSE VERBOSE_PROGRESS SKIP_INTERNET_CHECK RETRY SPEED_LIMIT
    unset ID_INPUT_ARRAY FINAL_INPUT_ARRAY
    CURL_PROGRESS="-s" CURL_SPEED_LIMIT_FLAG="--limit-rate" CURL_EXTRA_FLAGS="-Ls"
    EXTRA_LOG=":"
    CONFIG="${HOME}/.gdl.conf"

    # API
    API_KEY="AIzaSyD2dHsZJ9b4OXuy5B_owiL8W18NaNOM8tk"
    API_URL="https://www.googleapis.com"
    API_VERSION="v3"
    SCOPE="${API_URL}/auth/drive"
    REDIRECT_URI="urn:ietf:wg:oauth:2.0:oob"
    TOKEN_URL="https://accounts.google.com/o/oauth2/token"

    _check_longoptions() {
        [[ -z ${2} ]] &&
            printf '%s: %s: option requires an argument\nTry '"%s -h/--help"' for more information.\n' "${0##*/}" "${1}" "${0##*/}" &&
            exit 1
        return 0
    }

    while [[ ${#} -gt 0 ]]; do
        case "${1}" in
            -h | --help) _usage ;;
            -D | --debug) DEBUG="true" && export DEBUG ;;
            -u | --update) _check_debug && _update ;;
            -U | --uninstall) _check_debug && _update uninstall ;;
            --version | --info) _version_info ;;
            -l | --log)
                _check_longoptions "${1}" "${2}"
                LOG_FILE_ID="${2}" && shift
                ;;
            -aria | --aria-flags)
                DOWNLOAD_WITH_ARIA="true"
                [[ ${1} = "--aria-flags" ]] && {
                    _check_longoptions "${1}" "${2}"
                    ARIA_EXTRA_FLAGS=" ${ARIA_EXTRA_FLAGS} ${2} " && shift
                }
                ;;
            -o | --oauth) OAUTH_ENABLED="true" ;;
            -k | --key)
                API_KEY_DOWNLOAD="true"
                _API_KEY="${2##default=}"
                # https://github.com/l4yton/RegHex#Google-Drive-API-Key
                if [[ ${_API_KEY} =~ AIza[0-9A-Za-z_-]{35} ]]; then
                    API_KEY="${_API_KEY}" && shift
                    [[ -z ${2##default=*} ]] && UPDATE_DEFAULT_API_KEY="_update_config"
                fi
                ;;
            -c | --config)
                _check_longoptions "${1}" "${2}"
                CONFIG="${2}" && shift
                ;;
            -d | --directory)
                _check_longoptions "${1}" "${2}"
                FOLDERNAME="${2}" && shift
                ;;
            -s | --skip-subdirs)
                SKIP_SUBDIRS="true"
                ;;
            -p | --parallel)
                _check_longoptions "${1}" "${2}"
                if [[ ${2} -gt 0 ]]; then
                    NO_OF_PARALLEL_JOBS="${2}"
                else
                    printf "\nError: -p/--parallel value ranges between 1 to 10.\n"
                    exit 1
                fi
                PARALLEL_DOWNLOAD="parallel" && shift
                ;;
            --speed)
                _check_longoptions "${1}" "${2}"
                regex='^([0-9]+)([k,K]|[m,M])+$'
                if [[ ${2} =~ ${regex} ]]; then
                    SPEED_LIMIT="${2}" && shift
                else
                    printf "Error: Wrong speed limit format, supported formats: 1K and 1M.\n" 1>&2
                    exit 1
                fi
                ;;
            -R | --retry)
                _check_longoptions "${1}" "${2}"
                if [[ ${2} -gt 0 ]]; then
                    RETRY="${2}" && shift
                else
                    printf "Error: -R/--retry only takes positive integers as arguments, min = 1, max = infinity.\n"
                    exit 1
                fi
                ;;
            -q | --quiet) QUIET="_print_center_quiet" ;;
            -V | --verbose)
                VERBOSE="true"
                ;;
            --skip-internet-check)
                SKIP_INTERNET_CHECK=":"
                ;;
            '' | *)
                [[ -n ${1} ]] && {
                    # Check if user meant it to be a flag
                    if [[ ${1} = -* ]]; then
                        printf '%s: %s: Unknown option\nTry '"%s -h/--help"' for more information.\n' "${0##*/}" "${1}" "${0##*/}" && exit 1
                    else
                        ID_INPUT_ARRAY+=("$(_extract_id "${1}")")
                    fi
                }
                ;;
        esac
        shift
    done

    # If no input
    [[ -z ${ID_INPUT_ARRAY[*]} ]] && _short_help

    [[ -n ${OAUTH_ENABLED} ]] && unset API_KEY_DOWNLOAD

    [[ -n ${DOWNLOAD_WITH_ARIA} ]] && {
        command -v aria2c 1>| /dev/null || { printf "%s\n" "Error: aria2c not installed." && exit 1; }
        ARIA_SPEED_LIMIT_FLAG="--max-download-limit"
        ARIA_EXTRA_FLAGS="${ARIA_EXTRA_FLAGS} -q --file-allocation=none --auto-file-renaming=false --continue"
    }

    _check_debug

    return 0
}

###################################################
# Check Oauth credentials and create/update config file
# Client ID, Client Secret, Refesh Token and Access Token
# Arguments: None
# Result: read description
###################################################
_check_credentials() {
    # Config file is created automatically after first run
    [[ -r ${CONFIG} ]] && . "${CONFIG}"

    if [[ -n ${OAUTH_ENABLED} ]]; then
        ! [[ -t 1 ]] && [[ -z ${CLIENT_ID:+${CLIENT_SECRET:+${REFRESH_TOKEN}}} ]] && {
            printf "%s\n" "Error: Script is not running in a terminal, cannot ask for credentials."
            printf "%s\n" "Add in config manually if terminal is not accessible. CLIENT_ID, CLIENT_SECRET and REFRESH_TOKEN is required." && return 1
        }

        # Following https://developers.google.com/identity/protocols/oauth2#size
        CLIENT_ID_REGEX='[0-9]+-[0-9A-Za-z_]{32}\.apps\.googleusercontent\.com'
        CLIENT_SECRET_REGEX='[0-9A-Za-z_-]+'
        REFRESH_TOKEN_REGEX='[0-9]//[0-9A-Za-z_-]+'     # 512 bytes
        ACCESS_TOKEN_REGEX='ya29\.[0-9A-Za-z_-]+'       # 2048 bytes
        AUTHORIZATION_CODE_REGEX='[0-9]/[0-9A-Za-z_-]+' # 256 bytes

        until [[ -n ${CLIENT_ID} && -n ${CLIENT_ID_VALID} ]]; do
            [[ -n ${CLIENT_ID} ]] && {
                if [[ ${CLIENT_ID} =~ ${CLIENT_ID_REGEX} ]]; then
                    [[ -n ${client_id} ]] && _update_config CLIENT_ID "${CLIENT_ID}" "${CONFIG}"
                    CLIENT_ID_VALID="true" && continue
                else
                    { [[ -n ${client_id} ]] && message="- Try again"; } || message="in config ( ${CONFIG} )"
                    "${QUIET:-_print_center}" "normal" " Invalid Client ID ${message} " "-" && unset CLIENT_ID client_id
                fi
            }
            [[ -z ${client_id} ]] && printf "\n" && "${QUIET:-_print_center}" "normal" " Enter Client ID " "-"
            [[ -n ${client_id} ]] && _clear_line 1
            printf -- "-> "
            read -r CLIENT_ID && client_id=1
        done

        until [[ -n ${CLIENT_SECRET} && -n ${CLIENT_SECRET_VALID} ]]; do
            [[ -n ${CLIENT_SECRET} ]] && {
                if [[ ${CLIENT_SECRET} =~ ${CLIENT_SECRET_REGEX} ]]; then
                    [[ -n ${client_secret} ]] && _update_config CLIENT_SECRET "${CLIENT_SECRET}" "${CONFIG}"
                    CLIENT_SECRET_VALID="true" && continue
                else
                    { [[ -n ${client_secret} ]] && message="- Try again"; } || message="in config ( ${CONFIG} )"
                    "${QUIET:-_print_center}" "normal" " Invalid Client Secret ${message} " "-" && unset CLIENT_SECRET client_secret
                fi
            }
            [[ -z ${client_secret} ]] && printf "\n" && "${QUIET:-_print_center}" "normal" " Enter Client Secret " "-"
            [[ -n ${client_secret} ]] && _clear_line 1
            printf -- "-> "
            read -r CLIENT_SECRET && client_secret=1
        done

        [[ -n ${REFRESH_TOKEN} ]] && {
            ! [[ ${REFRESH_TOKEN} =~ ${REFRESH_TOKEN_REGEX} ]] &&
                "${QUIET:-_print_center}" "normal" " Error: Invalid Refresh token in config file, follow below steps.. " "-" && unset REFRESH_TOKEN
        }

        [[ -z ${REFRESH_TOKEN} ]] && {
            printf "\n" && "${QUIET:-_print_center}" "normal" "If you have a refresh token generated, then type the token, else leave blank and press return key.." " "
            printf "\n" && "${QUIET:-_print_center}" "normal" " Refresh Token " "-" && printf -- "-> "
            read -r REFRESH_TOKEN
            if [[ -n ${REFRESH_TOKEN} ]]; then
                "${QUIET:-_print_center}" "normal" " Checking refresh token.. " "-"
                if [[ ${REFRESH_TOKEN} =~ ${REFRESH_TOKEN_REGEX} ]]; then
                    { _get_access_token_and_update && _update_config REFRESH_TOKEN "${REFRESH_TOKEN}" "${CONFIG}"; } || check_error=true
                else
                    check_error=true
                fi
                [[ -n ${check_error} ]] && "${QUIET:-_print_center}" "normal" " Error: Invalid Refresh token given, follow below steps to generate.. " "-" && unset REFRESH_TOKEN
            else
                "${QUIET:-_print_center}" "normal" " No Refresh token given, follow below steps to generate.. " "-"
            fi

            [[ -z ${REFRESH_TOKEN} ]] && {
                printf "\n" && "${QUIET:-_print_center}" "normal" "Visit the below URL, tap on allow and then enter the code obtained" " "
                URL="https://accounts.google.com/o/oauth2/auth?client_id=${CLIENT_ID}&redirect_uri=${REDIRECT_URI}&scope=${SCOPE}&response_type=code&prompt=consent"
                printf "\n%s\n" "${URL}"
                until [[ -n ${AUTHORIZATION_CODE} && -n ${AUTHORIZATION_CODE_VALID} ]]; do
                    [[ -n ${AUTHORIZATION_CODE} ]] && {
                        if [[ ${AUTHORIZATION_CODE} =~ ${AUTHORIZATION_CODE_REGEX} ]]; then
                            AUTHORIZATION_CODE_VALID="true" && continue
                        else
                            "${QUIET:-_print_center}" "normal" " Invalid CODE given, try again.. " "-" && unset AUTHORIZATION_CODE authorization_code
                        fi
                    }
                    { [[ -z ${authorization_code} ]] && printf "\n" && "${QUIET:-_print_center}" "normal" " Enter the authorization code " "-"; } || _clear_line 1
                    printf -- "-> "
                    read -r AUTHORIZATION_CODE && authorization_code=1
                done
                RESPONSE="$(curl --compressed "${CURL_PROGRESS}" -X POST \
                    --data "code=${AUTHORIZATION_CODE}&client_id=${CLIENT_ID}&client_secret=${CLIENT_SECRET}&redirect_uri=${REDIRECT_URI}&grant_type=authorization_code" "${TOKEN_URL}")" || :
                _clear_line 1 1>&2

                REFRESH_TOKEN="$(_json_value refresh_token 1 1 <<< "${RESPONSE}" || :)"
                { _get_access_token_and_update "${RESPONSE}" && _update_config REFRESH_TOKEN "${REFRESH_TOKEN}" "${CONFIG}"; } || return 1
            }
            printf "\n"
        }

        [[ -z ${ACCESS_TOKEN} || ${ACCESS_TOKEN_EXPIRY:-0} -lt "$(printf "%(%s)T\\n" "-1")" ]] || ! [[ ${ACCESS_TOKEN} =~ ${ACCESS_TOKEN_REGEX} ]] &&
            { _get_access_token_and_update || return 1; }
        printf "%b\n" "ACCESS_TOKEN=\"${ACCESS_TOKEN}\"\nACCESS_TOKEN_EXPIRY=\"${ACCESS_TOKEN_EXPIRY}\"" >| "${TMPFILE}_ACCESS_TOKEN"

        # launch a background service to check access token and update it
        # checks ACCESS_TOKEN_EXPIRY, try to update before 5 mins of expiry, a fresh token gets 60 mins
        # process will be killed when script exits or "${MAIN_PID}" is killed
        {
            until ! kill -0 "${MAIN_PID}" 2>| /dev/null 1>&2; do
                . "${TMPFILE}_ACCESS_TOKEN"
                CURRENT_TIME="$(printf "%(%s)T\\n" "-1")"
                REMAINING_TOKEN_TIME="$((ACCESS_TOKEN_EXPIRY - CURRENT_TIME))"
                if [[ ${REMAINING_TOKEN_TIME} -le 300 ]]; then
                    # timeout after 30 seconds, it shouldn't take too long anyway, and update tmp config
                    CONFIG="${TMPFILE}_ACCESS_TOKEN" _timeout 30 _get_access_token_and_update || :
                else
                    TOKEN_PROCESS_TIME_TO_SLEEP="$(if [[ ${REMAINING_TOKEN_TIME} -le 301 ]]; then
                        printf "0\n"
                    else
                        printf "%s\n" "$((REMAINING_TOKEN_TIME - 300))"
                    fi)"
                    sleep "${TOKEN_PROCESS_TIME_TO_SLEEP}"
                fi
                sleep 1
            done
        } &
        ACCESS_TOKEN_SERVICE_PID="${!}"

    elif [[ -n ${API_KEY_DOWNLOAD} ]]; then
        "${UPDATE_DEFAULT_API_KEY:-:}" API_KEY "${API_KEY}" "${CONFIG}"
    fi

    return 0
}

###################################################
# Process all the values in "${FINAL_INPUT_ARRAY[@]}"
###################################################
_process_arguments() {
    export DEBUG LOG_FILE_ID VERBOSE API_KEY API_URL API_VERSION \
        FOLDERNAME SKIP_SUBDIRS NO_OF_PARALLEL_JOBS PARALLEL_DOWNLOAD SKIP_INTERNET_CHECK \
        COLUMNS TMPFILE CURL_PROGRESS EXTRA_LOG RETRY QUIET SPEED_LIMIT \
        DOWNLOAD_WITH_ARIA ARIA_EXTRA_FLAGS ARIA_SPEED_LIMIT_FLAG CURL_SPEED_LIMIT_FLAG CURL_EXTRA_FLAGS \
        OAUTH_ENABLED API_KEY_DOWNLOAD

    export -f _actual_size_in_bytes _bytes_to_human _count _api_request _api_request_oauth _json_value _print_center _print_center _newline _clear_line _move_cursor \
        _download_file _download_file_main _download_folder _log_in_file

    ${FOLDERNAME:+mkdir -p ${FOLDERNAME}}
    cd "${FOLDERNAME:-.}" 2>| /dev/null 1>&2 || exit 1

    unset Aseen && declare -A Aseen
    for id in "${ID_INPUT_ARRAY[@]}"; do
        { [[ ${Aseen[${id}]} ]] && continue; } || Aseen[${id}]=x
        _check_id "${id}" || continue
        if [[ -n ${FOLDER_ID} ]]; then
            _download_folder "${FOLDER_ID}" "${NAME}" "${PARALLEL_DOWNLOAD:-}"
        else
            _download_file_main noparse "${FILE_ID}" "${NAME}" "${SIZE}"
        fi
    done
    return 0
}

main() {
    [[ $# = 0 ]] && _short_help

    [[ -z ${SELF_SOURCE} ]] && {
        UTILS_FOLDER="${UTILS_FOLDER:-${PWD}}"
        { . "${UTILS_FOLDER}"/common-utils.bash && . "${UTILS_FOLDER}"/download-utils.bash && . "${UTILS_FOLDER}"/drive-utils.bash; } || { printf "Error: Unable to source util files.\n" && exit 1; }
    }

    _check_bash_version && set -o errexit -o noclobber -o pipefail

    TMPFILE="$(command -v mktemp 1>| /dev/null && mktemp -u)" || TMPFILE="$(pwd)/.$(_t="$(printf "%(%s)T\\n" "-1")" && printf "%s\n" "$((_t * _t))").tmpfile"

    _setup_arguments "${@}"
    "${SKIP_INTERNET_CHECK:-_check_internet}"

    _cleanup() {
        # unhide the cursor if hidden
        [[ -n ${SUPPORT_ANSI_ESCAPES} ]] && printf "\e[?25h\e[?7h"
        {
            [[ -n ${OAUTH_ENABLED} ]] && {
                [[ -f ${TMPFILE}_ACCESS_TOKEN ]] && {
                    # update the config with latest ACCESS_TOKEN and ACCESS_TOKEN_EXPIRY only if changed
                    . "${TMPFILE}_ACCESS_TOKEN"
                    [[ ${INITIAL_ACCESS_TOKEN} = "${ACCESS_TOKEN}" ]] || {
                        _update_config ACCESS_TOKEN "${ACCESS_TOKEN}" "${CONFIG}"
                        _update_config ACCESS_TOKEN_EXPIRY "${ACCESS_TOKEN_EXPIRY}" "${CONFIG}"
                    }
                } 1>| /dev/null

                # grab all chidren processes of access token service
                # https://askubuntu.com/a/512872
                [[ -n ${ACCESS_TOKEN_SERVICE_PID} ]] && {
                    token_service_pids="$(ps --ppid="${ACCESS_TOKEN_SERVICE_PID}" -o pid=)"
                    # first kill parent id, then children processes
                    kill "${ACCESS_TOKEN_SERVICE_PID}"
                } 1>| /dev/null
            }

            # grab all script children pids
            script_children_pids="$(ps --ppid="${MAIN_PID}" -o pid=)"

            # kill all grabbed children processes
            # shellcheck disable=SC2086
            kill ${token_service_pids} ${script_children_pids} 1>| /dev/null

            rm -f "${TMPFILE:?}"*

            export abnormal_exit && if [[ -n ${abnormal_exit} ]]; then
                printf "\n\n%s\n" "Script exited manually."
                kill -- -$$ &
            else
                _auto_update
            fi
        } 2>| /dev/null || :
        return 0
    }

    trap 'abnormal_exit="1"; exit' INT TERM
    trap '_cleanup' EXIT

    export MAIN_PID="$$"

    if [[ -n ${OAUTH_ENABLED} ]]; then
        "${EXTRA_LOG}" "justify" "Checking credentials.." "-"
        { _check_credentials && _clear_line 1; } ||
            { "${QUIET:-_print_center}" "normal" "[ Error: Credentials checking failed ]" "=" && exit 1; }
        _print_center "justify" "Required credentials available." "="

        export API_REQUEST_FUNCTION="_api_request_oauth"
    else
        export API_REQUEST_FUNCTION="_api_request"
    fi

    START="$(printf "%(%s)T\\n" "-1")"

    # hide the cursor if ansi escapes are supported
    [[ -n ${SUPPORT_ANSI_ESCAPES} ]] && printf "\033[?25l"

    _process_arguments

    END="$(printf "%(%s)T\\n" "-1")"
    DIFF="$((END - START))"
    "${QUIET:-_print_center}" "normal" " Time Elapsed: ""$((DIFF / 60))"" minute(s) and ""$((DIFF % 60))"" seconds. " "="
}

{ [[ -z ${SOURCED_GDL} ]] && main "${@}"; } || :
