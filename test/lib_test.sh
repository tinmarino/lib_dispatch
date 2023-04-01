#!/usr/bin/env bash

# shellcheck disable=SC1091  # Not following
source "$gs_root_path/script/lib_dispatch.sh"


start_test_function(){
  local rest=''
  (( 2 <= $# )) && rest=" ${*:2}"
  >&2 echo -e "\n-- Testing ${cpurple}$1$cend$rest"
  export g_junit_function=$*
  export gi_junit_n=1
  # TODO latter this will register failure to get easyer navigation
}


mkdir -p /tmp/ART
g_tmp_root=$(mktemp --directory "/tmp/ART/XXXXXXX")
mkdir -p "$g_tmp_root"


art_parallel_suite(){
  : 'Namespace fcts'
  local tmp_bank="$g_tmp_root/$1"
  shift

  mkdir -p "$tmp_bank"

  # Helper clause
  function_worker(){
    : 'Arg1: name of the function
      Called asyn
    '

    g_junit_file="$tmp_bank"/junit_"$1".xml
    : > "$g_junit_file"
    test_function_"$1"
  }

  for function; do
    # shellcheck disable=SC2034  # gd_bash_parallel_command appears unused
    gd_bash_parallel_command[$function]="function_worker \"$function\""
    #function_worker "$function"
  done

  bash_parallel
  return $?
}


# Do not source twice, in case I was sourced in parent
# shellcheck disable=SC2034  # B_SOURCED_LIB_TEST appears unused
declare -gi B_SOURCED_LIB_TEST=1
