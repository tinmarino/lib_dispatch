#!/usr/bin/env bash
# Test dispatch self execution and sourcing

# shellcheck disable=SC2030,SC2031  # OK: subshell related + tests

# Source test utilities
  export gs_root_path="$(readlink -f "${BASH_SOURCE[0]}")"
  gs_root_path="$(dirname "$gs_root_path")"
  gs_root_path="$(dirname "$gs_root_path")"
  # shellcheck disable=SC1091  # Not following
  source "$gs_root_path/test/lib_test.sh"

# Unexport is_in_array for my personal laptop (mtourneb)
  if [[ funtion == "$(type -t is_in_array)" ]]; then
    export -nf is_in_array
  fi
  fcp is_in_array save_is_in_array
  unset is_in_array 2> /dev/null

start_test_function "Dispatch: Source code to test"

  out=$("$gs_root_path/script/lib_dispatch.sh")
  equal 0 $? "Executing lib_dispatch should return 0"
  readarray -t a_key < <(echo "$out" | grep --color=never -oE $'^(\e[^m]*m)?[-0-9A-Za-z_]+' | sed $'s/^\e[^m]*m//')
  save_is_in_array --complete "${a_key[@]}"; equal 0 $? "Executing lib_dispatch shows --complete"
  save_is_in_array is_in_array "${a_key[@]}"; equal 0 $? "Executing lib_dispatch shows is_in_array"


start_test_function "Dispatch: Execute self"
  out=$("$gs_root_path/script/lib_dispatch.sh"); equal 0 $? "Executing lib_dispatch should return 0"
  grep -qF 'Shell dispatcher library' <<< "$out"; equal 0 $? "lib_disptach header 1"
  grep -qF 'For example write the following code' <<< "$out"; equal 0 $? "lib_disptach header 2"
  grep -qF 'Call the function with the name of the argument' <<< "$out"; equal 0 $? "lib_disptach dispatch docstring 1"
  grep -qF 'is_in_array' <<< "$out"; equal 0 $? "lib_disptach dispatch is_in_array present"


start_test_function "Dispatch: Parse and check output"
  readarray -t a_key < <(echo "$out" | grep --color=never -oE $'^(\e[^m]*m)?[-0-9A-Za-z_]+' | sed $'s/^\e[^m]*m//')
  save_is_in_array is_in_array "${a_key[@]}"; equal 0 $? "Executing lib_disptach shows is_in_array"
  save_is_in_array perr "${a_key[@]}"; equal 0 $? 'present perr'
  save_is_in_array dispatch "${a_key[@]}"; equal 0 $? 'present dispatch'


>&2 echo -e "\n<= $0 returned: $g_dispatch_i_res"
exit "$g_dispatch_i_res"
