#!/usr/bin/env bash
# Test dispatch subcmd are not broken links


# Source test utilities
if [[ ! -v B_SOURCED_LIB_TEST ]] || (( 0 == B_SOURCED_LIB_TEST )); then
  : "${gs_root_path:=$(dirname "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")")}"
  # shellcheck disable=SC1091  # Not following
  source "$gs_root_path/test/lib_test.sh"
fi

# Silence shellcheck
: "${g_dispatch_i_res:=0}" "${g_dispatch_d_cmd:=0}"


# -- 1: source
# shellcheck disable=SC1091  # Not following
source "$gs_root_path"/dispatch
equal 0 $? "dispatch can be sourced: status"
#equal "" "$out" "dispatch can be sourced: stdout"

# -- 2: execute all subcommand
for subcmd in "${!g_dispatch_d_cmd[@]}"; do
  : "$subcmd"
  # Clause: do not work for shell
  [[ shell == "$subcmd" ]] && continue

  "$gs_root_path"/dispatch "$subcmd" &> /dev/null
  equal 0 $? "${subcmd^}: is a subcommand of dispatch"

  # Get command
  file_to_execute=${g_dispatch_d_cmd[$subcmd]}
  filename=${file_to_execute##*/}
  
  # Check x permission
  [[ -x "$file_to_execute" ]]
  equal 0 $? "${filename^}: is executable"

  # Execute file
  "$file_to_execute" &> /dev/null
  equal 0 $? "${filename^}: could be executed"

  # Execute file
  # shellcheck disable=SC1090  # Cannot follow
  out=$(source "$file_to_execute")
  equal 0 $? "${filename^}: could be sourced: status"
  equal "" "$out" "${filename^}: could be sourced: stdout"
done


>&2 echo -e "\n<= $0 returned: $g_dispatch_i_res"
exit "$g_dispatch_i_res"
