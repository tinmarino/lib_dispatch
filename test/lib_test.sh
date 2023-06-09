#!/usr/bin/env bash

# Kcov helper <= Forking is removing the set -x set by kcov
[[ -v KCOV_BASH_COMMAND ]] && set -x

: "${gs_root_path:=$(dirname "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")")}"
# shellcheck disable=SC1091  # Not following
source "$gs_root_path/script/lib_misc.sh"

# Silence shellcheck
: "${cpurple:=}" "${cend:=}"

start_test_function(){
  local rest=''
  (( 2 <= $# )) && rest=" ${*:2}"
  >&2 echo -e "\n-- Testing ${cpurple}$1$cend$rest"
  export g_junit_function=$*
  export gi_junit_n=1
  # TODO latter this will register failure to get easier navigation
}


mkdir -p /tmp/ART
g_tmp_root=$(mktemp -d "/tmp/ART/XXXXXXX")
mkdir -p "$g_tmp_root"


system_timeout(){
  : 'Mac do not have the timeout command
    To use on GITHUB_ACTION
    Ref: https://stackoverflow.com/questions/3504945/timeout-command-on-mac-os-x
    Returns:
      - Function result if no timeout
      - 137 if timedout
  '
  # TODO add a gret_os function
  if [[ -v MATRIX_OS && "$MATRIX_OS" == macos-latest ]]; then
    perl -e 'alarm shift; exec @ARGV' "$@";
    res=$?

    # This is returning 124 is timedout but I want 137 = 128 + killed
    (( res == 124 )) && (( res = 137 ))

    return "$res"
  fi

  command timeout "$@"
}


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
    gd_bash_parallel_command[function]="function_worker \"$function\""
    #function_worker "$function"
  done

  bash_parallel
  return $?
}


startup(){
  : 'To clean state between test'
  unset mm_opt m_f toto titi &> /dev/null
  declare -ga g_dispatch_a_fct_to_hide=()  # Array of already defined function to hide (Filled by lib_dispatch)
  declare -ga g_dispatch_a_dispach_args=()  # Array of arguments given by the first user command
  declare -gA g_dispatch_d_fct_default=()  # Default functions defined by hardcode
  readarray -t g_dispatch_a_fct_to_hide < <(declare -F -p | cut -d " " -f 3)
  : "${g_dispatch_a_dispach_args[*]}"
  : "${g_dispatch_d_fct_default[*]}"
  : "${g_dispatch_a_fct_to_hide[*]}"
  mm_opt(){
    : 'Option'
    declare -g OPT=$1; : "$OPT"
    return 1
  }
  m_f(){
    : 'Flag'
    declare -g FLAG=flag; : "$FLAG"
    return 0
  }
  toto(){
    : 'Doc  toto
      two lines
    '
    echo "grepme-toto:$OPT:$FLAG:$*|"
    return 0
  }
  titi(){
    : 'Doc  titi'
    echo "grepme-titi:$OPT:$FLAG:$*|"
    return 42
  }
  declare -g OPT='' FLAG=''
}


depend(){
  pinfo "Depend is not implemented already" \
    "-- But this would depends on $*"
}


# Do not source twice, in case I was sourced in parent
# shellcheck disable=SC2034  # B_SOURCED_LIB_TEST appears unused
declare -gi B_SOURCED_LIB_TEST=1
