#!/usr/bin/env bash
# Unit test for function_unit_misc_join_by

# Source test utilities
if [[ ! -v B_SOURCED_LIB_TEST ]] || (( 0 == B_SOURCED_LIB_TEST )); then
  : "${gs_root_path:=$(dirname "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")")}"
  # shellcheck disable=SC1091  # Not following
  source "$gs_root_path/test/lib_test.sh"
fi

# Silence shellcheck
: "${g_dispatch_i_res:=0}"

# Declare dependencies
depend


test_unit_misc_join_by(){
  : 'Test function_unit_misc_join_by'
  # -- 1: No space in delimiter
  out=$(join_by , a b c); equal 0 $? 'join_by never fails 1'
  equal a,b,c "$out" 'join by out 1'

  # -- 2: Space in delimiter
  out=$(join_by ' , ' a b c); equal 0 $? 'join_by never fails 2'
  equal 'a , b , c' "$out" 'join by 2'

  # -- 3: Weird delimiter
  out=$(join_by ')|(' a b c); equal 0 $? 'join_by never fails 3'
  equal 'a)|(b)|(c' "$out" 'join by 3'

  # -- 4: Percent-like delimiter
  out=$(join_by ' %s ' a b c); equal 0 $? 'join_by never fails 4'
  equal 'a %s b %s c' "$out" 'join by 4'

  # -- 5: Newline delimiter
  out=$(join_by $'\n' a b c); equal 0 $? 'join_by never fails 5'
  equal $'a\nb\nc' "$out" 'join by 5'

  # -- 5: Newline in delimiter
  out=$(join_by $'dd\nee' a b c); equal 0 $? 'join_by never fails 5'
  equal $'add\neebdd\neec' "$out" 'join by 5'

  # -- 6: Minus delimiter
  out=$(join_by - a b c); equal 0 $? 'join_by never fails 6'
  equal 'a-b-c' "$out" 'join by 6'

  # -- 7: backslash delimiter
  out=$(join_by "\\" a b c); equal 0 $? 'join_by never fails 7'
  equal 'a\b\c' "$out" 'join by 7'

  # -- 8: Minus arguments
  out=$(join_by '-n' '-e' '-E' '-n'); equal 0 $? 'join_by never fails 8'
  equal '-e-n-E-n-n' "$out" 'join by 8'

  # -- 9: Argument missing => nothing
  out=$(join_by ,); equal 0 $? 'join_by never fails 9'
  equal '' "$(join_by ,)" 'join by 9'

  # -- 10: Only one argument
  out=$(join_by , a); equal 0 $? 'join_by never fails 10'
  equal 'a' "$(join_by , a)" 'join by 10'
}


test_unit_misc_join_by || g_dispatch_i_res=1


>&2 echo -e "\n<= $0 returned: $g_dispatch_i_res"
exit "$g_dispatch_i_res"
