#!/usr/bin/env bash
# 91/ Play 🤹: Example dummy for development, documentation
# Ex: dispatch example --value 30 succeed
#
# ==> Examples draw where precept fails, and sermons are less read than tales (Matt Prior) <==

set -u
[[ ! -v gi_source_lib_dispatch ]] && {
  [[ ! -v gs_root_path ]] && { gs_root_path=$(readlink -f "${BASH_SOURCE[0]}"); gs_root_path=$(dirname "$gs_root_path"); gs_root_path=$(dirname "$gs_root_path"); }
  # shellcheck disable=SC1091  # Not following
  source "$gs_root_path"/script/lib_dispatch.sh
}


succeed(){
  : 'Succeed with status 0
    Print: EXAMPLE environment variable content (EXAMPLE=$EXAMPLE)
  '
  run echo "I will succeed. And EXAMPLE=$EXAMPLE"
  return 0
}


fail(){
  : 'Fail with status 42
    Print: EXAMPLE environment variable content (EXAMPLE=$EXAMPLE)
  '
  run echo "I will fail. And EXAMPLE=$EXAMPLE"
  return 42
}


mm_value(){
  : 'Change EXAMPLE variable to the argument it consumes
    Return: 1 <= consume one parameter
  '
  # Clause must not work and consume 1 argument if completing
  ((g_dispatch_b_complete)) && return 1

  export EXAMPLE=$1
  return 1
}


__set_env(){
  : 'Internal helper to set environment variables'
  set -a
  : "${EXAMPLE:=default_example_value}"
  set +a
}


__complete_succeed(){
  : 'Called when completing: "dispatch example succeed <CursorHere>"'
  echo "
    example_one : Comment for example one
    example_two : Comment for example two
  "
}


__complete_mm_value(){
  : 'Called when completing: "dispatch example --value <CursorHere>"'
  echo "
    first_value  : Comment for value one
    second_value : Comment for value one
  "
}


__at_init(){ __set_env; print_script_start "$@"; }

__at_finish(){ print_script_end "$@"; }

if [[ -v BASH_SOURCE ]] && (( ${#BASH_SOURCE[@]} > 0 )) && [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  dispatch "$@"; exit $?;
fi
