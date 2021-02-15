#!/usr/bin/env bash
# shellcheck source=/dev/null

###################################################
# Default curl command used for gdrive api requests.
###################################################
_api_request() {
    # shellcheck disable=SC2086
    curl -e "https://drive.google.com" --compressed ${CURL_PROGRESS} \
        "${API_URL}/drive/${API_VERSION}/${1:?}&key=${API_KEY}&supportsAllDrives=true&includeItemsFromAllDrives=true" || return 1
    _clear_line 1 1>&2
}

###################################################
# A simple wrapper to check tempfile for access token and make authorized oauth requests to drive api
###################################################
_api_request_oauth() {
    . "${TMPFILE}_ACCESS_TOKEN"

    # shellcheck disable=SC2086
    curl --compressed ${CURL_PROGRESS} \
        -H "Authorization: Bearer ${ACCESS_TOKEN}" \
        "${API_URL}/drive/${API_VERSION}/${1:?}&supportsAllDrives=true&includeItemsFromAllDrives=true" || return 1
    _clear_line 1 1>&2
}

###################################################
# Check if the file ID exists and determine it's type [ folder | Files ].
# Todo: write doc
###################################################
_check_id() {
    [[ $# = 0 ]] && printf "%s: Missing arguments\n" "${FUNCNAME[0]}" && return 1
    "${EXTRA_LOG}" "justify" "Validating URL/ID.." "-"
    declare id="${1}" json && unset NAME SIZE
    if json="$("${API_REQUEST_FUNCTION}" "files/${id}?alt=json&fields=name,size,mimeType")"; then
        if ! _json_value code 1 1 <<< "${json}" 2>| /dev/null 1>&2; then
            NAME="$(_json_value name 1 1 <<< "${json}" || :)"
            mime="$(_json_value mimeType 1 1 <<< "${json}" || :)"
            _clear_line 1
            if [[ ${mime} =~ folder ]]; then
                FOLDER_ID="${id}"
                _print_center "justify" "Folder Detected" "=" && _newline "\n"
            else
                SIZE="$(_json_value size 1 1 <<< "${json}" || :)"
                FILE_ID="${id}"
                _print_center "justify" "File Detected" "=" && _newline "\n"
            fi
            export NAME SIZE FILE_ID FOLDER_ID
        else
            _clear_line 1 && "${QUIET:-_print_center}" "justify" "Invalid URL/ID" "=" && _newline "\n"
            return 1
        fi
    else
        _clear_line 1
        "${QUIET:-_print_center}" "justify" "Error: Cannot check URL/ID" "="
        printf "%s\n" "${json}"
        return 1
    fi
    return 0
}

###################################################
# Extract ID from a googledrive folder/file url.
# Arguments: 1
#   ${1} = googledrive folder/file url.
# Result: print extracted ID
###################################################
_extract_id() {
    [[ $# = 0 ]] && printf "%s: Missing arguments\n" "${FUNCNAME[0]}" && return 1
    declare LC_ALL=C ID="${1}"
    case "${ID}" in
        *'drive.google.com'*'id='*) ID="${ID##*id=}" && ID="${ID%%\?*}" && ID="${ID%%\&*}" ;;
        *'drive.google.com'*'file/d/'* | 'http'*'docs.google.com'*'/d/'*) ID="${ID##*\/d\/}" && ID="${ID%%\/*}" && ID="${ID%%\?*}" && ID="${ID%%\&*}" ;;
        *'drive.google.com'*'drive'*'folders'*) ID="${ID##*\/folders\/}" && ID="${ID%%\?*}" && ID="${ID%%\&*}" ;;
    esac
    printf "%b" "${ID:+${ID}\n}"
}

###################################################
# Method to regenerate access_token ( also updates in config ).
# Make a request on https://www.googleapis.com/oauth2/""${API_VERSION}""/tokeninfo?access_token=${ACCESS_TOKEN} url and check if the given token is valid, if not generate one.
# Result: Update access_token and expiry else print error
###################################################
_get_access_token_and_update() {
    RESPONSE="${1:-$(curl --compressed -s -X POST --data "client_id=${CLIENT_ID}&client_secret=${CLIENT_SECRET}&refresh_token=${REFRESH_TOKEN}&grant_type=refresh_token" "${TOKEN_URL}")}" || :
    if ACCESS_TOKEN="$(_json_value access_token 1 1 <<< "${RESPONSE}")"; then
        ACCESS_TOKEN_EXPIRY="$(($(printf "%(%s)T\\n" "-1") + $(_json_value expires_in 1 1 <<< "${RESPONSE}") - 1))"
        _update_config ACCESS_TOKEN "${ACCESS_TOKEN}" "${CONFIG}"
        _update_config ACCESS_TOKEN_EXPIRY "${ACCESS_TOKEN_EXPIRY}" "${CONFIG}"
    else
        "${QUIET:-_print_center}" "justify" "Error: Something went wrong" ", printing error." 1>&2
        printf "%s\n" "${RESPONSE}" 1>&2
        return 1
    fi
    return 0
}
