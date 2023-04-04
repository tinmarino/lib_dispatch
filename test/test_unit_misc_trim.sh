#!/usr/bin/env bash
# Unit test for function_unit_misc_trim

# Source test utilities
if [[ ! -v B_SOURCED_LIB_TEST ]] || (( 0 == B_SOURCED_LIB_TEST )); then
  : "${gs_root_path:=$(dirname "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")")}"
  # shellcheck disable=SC1091  # Not following
  source "$gs_root_path/test/lib_test.sh"
fi

# Silence shellcheck
: "${g_dispatch_i_res:=0}"

# Declare dependencies
depend ""


test_function_unit_misc_trim(){
  : 'Test function_unit_misc_trim'
  equal "" "$(trim "")" "trim nothing"
  equal "" "$(trim "     ")" "trim pure space"
  equal "a b" "$(trim "  a b ")" "trim both side"
  equal "a b  c d" "$(trim "  a b  c d")" "trim left"
  equal "a bbb  d" "$(trim "a bbb  d    ")" "trim right"
  equal "a b  c d" "$(trim "a b  c d")" "trim no trim"
  equal 'aa bb' "$(trim $'	 \n   	 		\n aa bb \n 	')" "trim mixed with tab and newlines"
  equal $'aa  	 \n 	 bb' "$(trim $'	 \n   	 		\n aa  	 \n 	 bb \n 	')" "trim mixed with tab and newlines, even inside"
}


test_function_unit_misc_trim


>&2 echo -e "\n<= $0 returned: $g_dispatch_i_res"
exit "$g_dispatch_i_res"
