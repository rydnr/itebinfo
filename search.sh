#!/bin/bash dry-wit
# Copyright 2013-today Automated Computing Machinery S.L.
# Distributed under the terms of the GNU General Public License v3

function usage() {
    cat <<EOF
$SCRIPT_NAME [-v[v]] [-q|--quiet] [-b|--batch] query
$SCRIPT_NAME [-h|--help]
(c) 2014-today Automated Computing Machinery S.L.
    Distributed under the terms of the GNU General Public License v3
 
Retrieves the urls for all ebooks matching given query.

Where:
  * query: the query
  * -b|--batch: change the output format for automation purposes.
EOF
}

# Requirements
function checkRequirements() {
    checkReq curl CURL_NOT_INSTALLED;
    checkReq jsawk JSAWK_NOT_INSTALLED;
    checkReq cat CAT_NOT_INSTALLED;
    checkReq tr TR_NOT_INSTALLED;
}

# Error messages
function defineErrors() {
    export INVALID_OPTION="Unrecognized option";
    export CURL_NOT_INSTALLED="curl is not installed";
    export JSAWK_NOT_INSTALLED="jsawk is not installed";
    export CAT_NOT_INSTALLED="cat is not installed";
    export TR_NOT_INSTALLED="tr is not installed";
    export QUERY_IS_MANDATORY="The search query is mandatory";
    export NO_MATCHES_FOUND="no matches found for given criteria";
    export API_LIMIT_EXCEEDED="API limit exceeded";

    ERROR_MESSAGES=(\
        INVALID_OPTION \
        CURL_NOT_INSTALLED \
        JSAWK_NOT_INSTALLED \
        CAT_NOT_INSTALLED \
        TR_NOT_INSTALLED \
        QUERY_IS_MANDATORY \
        NO_MATCHES_FOUND \
        API_LIMIT_EXCEEDED \
    );

    export ERROR_MESSAGES;
}

# Checking input
function checkInput() {

    local _flags=$(extractFlags $@);
    local _flagCount;
    local _currentCount;
    logDebug -n "Checking input";

    BATCH=1;
    
    # Flags
    for _flag in ${_flags}; do
        _flagCount=$((_flagCount+1));
        case ${_flag} in
            -h | --help | -v | -vv | -q)
                shift;
                ;;
            -b | --batch)
                BATCH=0;
                shift;
                ;;
            *) exitWithErrorCode INVALID_OPTION ${_flag};
               ;;
        esac
    done
    
    # Parameters
    if [ "x${QUERY}" == "x" ]; then
        QUERY="$@";
        shift;
    fi

    if [ "x${QUERY}" == "x" ]; then
        logDebugResult FAILURE "fail";
        exitWithErrorCode QUERY_IS_MANDATORY;
    else
        logDebugResult SUCCESS "valid";
    fi 
}

function countEbooks() {
    local _query="${1}";
    local _jsonSearch;
    local _result=0;
    local _curlExitCode;
    createTempFile;
    _jsonSearch="${RESULT}";

    logInfo -n "Searching for ${_query} ebooks";
    
    curl -s "${SEARCH_URL}"/"${_query}" > "${_jsonSearch}";
    _curlExitCode=$?;
    
    _result="$(cat "${_jsonSearch}" 2> /dev/null | jsawk 'return this.Error;' 2> /dev/null)";
    if [ "x${_result}" == "x0" ]; then
        _result="$(cat "${_jsonSearch}" | jsawk 'return this.Total;')";
        logInfoResult SUCCESS "${_result}";
    else
        logInfoResult FAILURE "${_result}";
        exitWithErrorCode API_LIMIT_EXCEEDED;
    fi

    export RESULT="${_result}";
}

function countPages() {
    local _total=${1};
    local _itemsPerPage=${2};
    local _result;
    if [ "x${_total}" == "" ]; then
        _result=0;
    elif [ "x${_itemsPerPage}" == "" ]; then
        _result=$((${_total} / 10));
    else
       _result=$((${_total} / ${_itemsPerPage}));
    fi
    
    export RESULT=${_result};
}

function searchEbooks() {
    local _query="${1}";
    local _page=${2};
    local _totalPages=${3};
    local _jsonSearch;
    local _result;
    createTempFile;
    _jsonSearch="${RESULT}";

    logInfo -n "Retrieving page ${_page}/${_totalPages} for '${_query}'";
    curl -s "${SEARCH_URL}"/"${_query}/page/${_page}" > "${_jsonSearch}";
    if [ $? -eq 0 ]; then
        _result="${_result}$(cat "${_jsonSearch}" | jsawk 'return this.Books;' | jsawk 'return this.ID;' | tr -d '[' | tr -d ']' | tr -s ',' ' ')";
        logInfoResult SUCCESS "done";
    else
        logInfoResult FAILURE "error";
    fi

    export RESULT="${_result}";
}

function retrieveEbookInfo() {
    local _id="${1}";
    local _title;
    local _result;
    local _jsonResult;
    createTempFile;
    _jsonResult="${RESULT}";

    logInfo -n "Retrieving data for ebook ${_id}";
    curl -s "${EBOOK_URL}"/"${_id}"  > "${_jsonResult}";

    if [ $? -eq 0 ]; then
        _title="$(cat "${_jsonResult}" | jsawk 'return this.Title;')";
        if [ "${_title}" == "" ]; then
            logInfoResult WARNING "not found";
        else
            logInfoResult SUCCESS "$(cat "${_jsonResult}" | jsawk 'return this.Title;')";
            _result="$(cat "${_jsonResult}" | jsawk 'return this.Download + "#" + this.Year + "#" + this.ISBN + "#" + this.Publisher + "#" + this.Title + "#" + this.SubTitle;')";
        fi
    else
        logInfoResult FAILURE "error";
    fi

    export RESULT="${_result}";
}

[ -e "$(basename ${SCRIPT_NAME} .sh).inc.sh" ] && source "$(basename ${SCRIPT_NAME} .sh).inc.sh"

function main() {
    local _results;
    local _total;
    local _totalPages;
    local _page;
    local _url;
    local _year;
    local _isbn;
    local _publisher;
    local _title;
    local _subtitle;
    local _filename;

    countEbooks "${QUERY}";
    _total=${RESULT};
    countPages ${_total} ${ITEMS_PER_PAGE};
    _totalPages=${RESULT};

    for _page in $(seq 1 ${_totalPages}); do
        searchEbooks "${QUERY}" ${_page} ${_totalPages};
        _results="${RESULT}";

        for _result in ${_results}; do
            retrieveEbookInfo ${_result};
            _url="$(echo "${RESULT}" | cut -d'#' -f 1)";
            _year="$(echo "${RESULT}" | cut -d'#' -f 2)";
            _isbn="$(echo "${RESULT}" | cut -d'#' -f 3)";
            _publisher="$(echo "${RESULT}" | cut -d'#' -f 4)";
            _title="$(echo "${RESULT}" | cut -d'#' -f 5)";
            _subtitle="$(echo "${RESULT}" | cut -d'#' -f 6)";
            if    [ "${_url}" != "" ] \
               && [ "${_url}" != "undefined" ]; then
                logInfo -n "${_publisher}-${_title}.${_subtitle}.${_year}.${_isbn}";
                logInfoResult SUCCESS "${_url}";
                if [ $BATCH -eq 0 ]; then
                    _filename="${_publisher}-${_title}.${_subtitle}.${_year}.${_isbn}${DEFAULT_FILE_EXTENSION}";
                    echo "[ -e \"${_filename}\" ] && echo \"${_title} already downloaded. Skipping...\"";
                    echo "[ ! -e \"${_filename}\" ] && echo \"Downloading ${_title}\" && curl -s --location --referer ${WEB_BASE_URL}${_result}/ -o \"${_filename}\" \"${_url}\"";
                fi
            fi
        done
    done
}
