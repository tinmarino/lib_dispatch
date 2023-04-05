#!/usr/bin/env bash
# Unit test for function_register_subcommand_from_gd_cmd

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


test_function_register_subcommand_from_gd_cmd(){
  : 'Test function_register_subcommand_from_gd_cmd'
  startup
  # -- 1: no dict no work
  declare -A g_dispatch_d_fct=()
  declare -A g_dispatch_d_cmd=(); : "${!g_dispatch_d_cmd[@]}"
  register_subcommand_from_gd_cmd; equal 0 $? 'register_subcommand_from_gd_cmd status (1)'
  equal 0 ${#g_dispatch_d_fct[@]} 'register_subcommand_from_gd_cmd did not add function'

  # -- 2: basic
  declare -A g_dispatch_d_fct=()
  file1=$(mktemp)
  file2=$(mktemp)

  print_unindent '
    #!/usr/bin/env bash
    # Docstring  command 1
    echo true
  ' > "$file1"
  print_unindent '
    #!/usr/bin/env bash
    # Docstring  command 2
    #
    # Multiple lines
    echo true
  ' > "$file2"

  declare -A g_dispatch_d_cmd=(
    [cmd1]=$file1
    [cmd2]=$file2
  )
  register_subcommand_from_gd_cmd; equal 0 $? 'register_subcommand_from_gd_cmd status (2)'
  equal 2 ${#g_dispatch_d_fct[@]} 'register_subcommand_from_gd_cmd added 2 functions (file commands)'
  equal $'Docstring  command 1' "${g_dispatch_d_fct[cmd1]}" 'register_subcommand_from_gd_cmd cmd1 description'
  equal $'Docstring  command 2\n\nMultiple lines' "${g_dispatch_d_fct[cmd2]}" 'register_subcommand_from_gd_cmd cmd2 description'
}


test_function_register_subcommand_from_gd_cmd


>&2 echo -e "\n<= $0 returned: $g_dispatch_i_res"
exit "$g_dispatch_i_res"
