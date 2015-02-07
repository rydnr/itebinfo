#!/bin/bash dry-wit
# Copyright 2013-today Automated Computing Machinery S.L.
# Distributed under the terms of the GNU General Public License v3

function usage() {
cat <<EOF
$SCRIPT_NAME [-v[v]] [-q|--quiet] query
$SCRIPT_NAME [-h|--help]
(c) 2014-today Automated Computing Machinery S.L.
    Distributed under the terms of the GNU General Public License v3
 
Retrieves the urls for all ebooks matching given query.

Where:
  * query: the query
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

  ERROR_MESSAGES=(\
    INVALID_OPTION \
    CURL_NOT_INSTALLED \
    JSAWK_NOT_INSTALLED \
    CAT_NOT_INSTALLED \
    TR_NOT_INSTALLED \
    QUERY_IS_MANDATORY \
    NO_MATCHES_FOUND \
  );

  export ERROR_MESSAGES;
}
 
# Checking input
function checkInput() {

  local _flags=$(extractFlags $@);
  local _flagCount;
  local _currentCount;
  logDebug -n "Checking input";

  # Flags
  for _flag in ${_flags}; do
    _flagCount=$((_flagCount+1));
    case ${_flag} in
      -h | --help | -v | -vv | -q)
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

function searchEbooks() {
    local _query="${1}";
    local _jsonSearch;
    createTempFile;
    _jsonSearch="${RESULT}";

    logInfo -n "Searching for ${_query} ebooks";
    
    curl -s "${SEARCH_URL}"/"${_query}" > "${_jsonSearch}";
    if [ $? -eq 0 ]; then
      logInfoResult SUCCESS $(cat "${_jsonSearch}" | jsawk 'return this.Total;');
    else
      logInfoResult FAILURE "error";
    fi

    export RESULT="$(cat "${_jsonSearch}" | jsawk 'return this.Books;' | jsawk 'return this.ID;' | tr -d '[' | tr -d ']' | tr -s ',' ' ')";
#    echo $RESULT;
}

function retrieveEbookInfo() {
    local _id="${1}";
    local _jsonResult;
    createTempFile;
    _jsonResult="${RESULT}";

    logInfo -n "Retrieving data for ebook ${_id}";
    curl -s "${EBOOK_URL}"/"${_id}"  > "${_jsonResult}";

    if [ $? -eq 0 ]; then
      logInfoResult SUCCESS "$(cat "${_jsonResult}" | jsawk 'return this.Title;')";
      RESULT="$(cat "${_jsonResult}" | jsawk 'return this.Download + "#" + this.Year + "#" + this.ISBN + "#" + this.Publisher + "#" + this.Title + "#" + this.SubTitle;')";
      export RESULT;
    else
      logInfoResult FAILURE "error";
    fi    
}

[ -e "$(basename ${SCRIPT_NAME} .sh).inc.sh" ] && source "$(basename ${SCRIPT_NAME} .sh).inc.sh"

function main() {
  local _results;
  local _url;
  local _year;
  local _isbn;
  local _publisher;
  local _title;
  local _subtitle;

  searchEbooks "${QUERY}";
  _results="${RESULT}";
  for _result in ${_results}; do
    retrieveEbookInfo ${_result};
    _url="$(echo "${RESULT}" | cut -d'#' -f 1)";
    _year="$(echo "${RESULT}" | cut -d'#' -f 2)";
    _isbn="$(echo "${RESULT}" | cut -d'#' -f 3)";
    _publisher="$(echo "${RESULT}" | cut -d'#' -f 4)";
    _title="$(echo "${RESULT}" | cut -d'#' -f 5)";
    _subtitle="$(echo "${RESULT}" | cut -d'#' -f 6)";
    logInfo -n "${_publisher}-${_title}.${_subtitle}.${_year}.${_isbn}";
    logInfoResult SUCCESS "${_url}";
  done
}