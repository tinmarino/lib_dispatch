#!/usr/bin/env bash
# 92/ Utilities scripts
# -- IDEA: Get list for the bands to filter like 3,5,7 or even 3410 for 3,4,10

set -u

[[ ! -v gi_source_lib_dispatch ]] && {
  [[ ! -v gs_root_path ]] && { gs_root_path=$(readlink -f "${BASH_SOURCE[0]}"); gs_root_path=$(dirname "$gs_root_path"); gs_root_path=$(dirname "$gs_root_path"); }
  # shellcheck disable=SC1091  # Not following
  source "$gs_root_path"/script/lib_dispatch.sh
}


# Main options default


unit_test(){
  : '--/ Check current code (dispatch)'
  local -i res=0

  export ART_NAMESPACE="dispatch self"
  export ART_VERBOSE=1

  # Go to local dir
  pushd "$gs_root_path"/test &> /dev/null || return "$E_CD"

  # Declare output filename and clear it
  export g_junit_file="$gs_root_path"/junit_last_result.xml
  : > "$g_junit_file"

  # Write report head
  local title=${JOB_NAME:-"Custom from $(user_at_host) at $(date '+%Y-%m-%dT%H:%M:%S')"}
  # Ref: https://llg.cubic.org/docs/junit/
  print_unindent "
    <?xml version=\"1.0\" encoding=\"UTF-8\"?>
    <testsuites name=\"$title\" tests=\"\" errors=\"\" failures=\"\" time=\"\">
    " >> "$g_junit_file"

  # Run the test
  run ./run_test.sh "$@"; res=$?

  # Write report tail
  echo '</testsuites>' >> "$g_junit_file"

  # Go back
  popd &> /dev/null || return "$E_CD"

  return "$res"
}


__complete_unit_test(){
  : "Internal for completion of lib_dispatch master unit_test"
  pushd "$gs_root_path"/test &> /dev/null || return "$E_CD"

  # Echo all test file
  for test_file in async test_*.sh; do
    if [[ async == "$test_file" ]]; then
      local desc="Run asynchronously all tests (faster)"
    else
      local desc=$(get_file_docstring "$test_file")
    fi
    echo -e "$test_file : $desc"
  done

  popd &> /dev/null || return "$E_CD"
}


make_temp_dir(){
  : 'Just mktemp -d'
  mktemp -d "/tmp/art_$(date '+%Y-%m-%dT%H:%M:%S.%3N')_XXXXXX"
  return $?
}


__at_init(){ print_script_start "$@"; }
__at_finish(){ print_script_end "$@"; }


if [[ -v BASH_SOURCE ]] && (( ${#BASH_SOURCE[@]} > 0 )) && [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  dispatch "$@"; exit $?;
fi
