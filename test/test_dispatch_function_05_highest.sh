#!/usr/bin/env bash
# Unit test for dispatch function level 5, the top level


# Source test utilities
  if [[ ! -v B_SOURCED_LIB_TEST ]] || (( 0 == B_SOURCED_LIB_TEST )); then
    export gs_root_path="$(readlink -f "${BASH_SOURCE[0]}")"
    gs_root_path="$(dirname "$gs_root_path")"
    gs_root_path="$(dirname "$gs_root_path")"
    # shellcheck disable=SC1091  # Not following
    source "$gs_root_path/test/lib_test.sh"
  fi


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

start_test_function fill_fct_dic function
  unset toto &> /dev/null
  unset titi &> /dev/null
  declare -ga g_dispatch_a_fct_to_hide=()  # Array of already defined function to hide (Filled by lib_dispatch)
  declare -ga g_dispatch_a_dispach_args=()  # Array of arguments given by the first user command
  declare -gA g_dispatch_d_fct_default=()  # Default functions defined by hardcode
  readarray -t g_dispatch_a_fct_to_hide < <(declare -F -p | cut -d " " -f 3)
  : "${g_dispatch_a_dispach_args[*]}"
  : "${g_dispatch_d_fct_default[*]}"
  : "${g_dispatch_a_fct_to_hide[*]}"

  # --1: With nothing gets nothing
  out=$(fill_fct_dic); equal 0 $? "fill_fct_dic succeed 1"
  equal '' "$out" "fill_fct_dic null in null out"
  fill_fct_dic &> /dev/null
  equal 0 "${#g_dispatch_d_fct[@]}" "fill_fct_dic dictionarry out should be empty (keys=${!g_dispatch_d_fct[*]})"

  # --2: Define toto and titi
  startup
  out=$(fill_fct_dic); equal 0 $? "fill_fct_dic succeed 2"
  equal '' "$out" "fill_fct_dic null in null out"
  fill_fct_dic &> /dev/null
  equal 4 "${#g_dispatch_d_fct[@]}" "fill_fct_dic no out in dict (keys=${!g_dispatch_d_fct[*]})"
  equal $'Doc  toto\ntwo lines' "${g_dispatch_d_fct[toto]}" "fill_fct_dic toto and his doc"
  equal $'Doc  titi' "${g_dispatch_d_fct[titi]}" "fill_fct_dic titi and his doc"


start_test_function call_fct_arg function
  startup
  fill_fct_dic &> /dev/null; equal 0 $? 'fill_fct_dic status 0'

  # -- 1: void
  out=$(call_fct_arg); equal 0 $? 'call_fct_arg status (1)'
  # TODO
  # THis is still not well formalised
  # "$out" 'call_fct_arg void out'

  # -- 2: toto
  out=$(call_fct_arg toto); equal 0 $? 'call_fct_arg status (2)'
  equal 'grepme-toto:::|' "$out" 'call_fct_arg toto out'

  # -- 3: titi
  out=$(call_fct_arg titi); equal 42 $? 'call_fct_arg status (3)'
  equal 'grepme-titi:::|' "$out" 'call_fct_arg toto out'

  # -- 4: --opt value titi
  out=$(call_fct_arg --opt value titi); equal 42 $? 'call_fct_arg status (4)'
  equal 'grepme-titi:value::|' "$out" 'call_fct_arg toto out'

  # -- 5: titi --opt value
  out=$(call_fct_arg titi --opt value); equal 42 $? 'call_fct_arg status (5)'
  equal 'grepme-titi:value::--opt value|' "$out" 'call_fct_arg toto out'

  # -- 6: --opt value
  out=$(call_fct_arg --opt value); equal 0 $? 'call_fct_arg status (6). Must return 0 (as argumnet passing succeded) or could have side effect'
  equal '' "$out" 'call_fct_arg --opt value no out'

  # -- 7: -f 1
  out=$(call_fct_arg titi --opt value -f); equal 42 $? 'call_fct_arg status (7)'
  equal 'grepme-titi:value:flag:--opt value -f|' "$out" 'call_fct_arg toto out'

  # -- 8: -f 2
  out=$(call_fct_arg -f titi --opt value ); equal 42 $? 'call_fct_arg status (8)'
  equal 'grepme-titi:value:flag:--opt value|' "$out" 'call_fct_arg toto out'


start_test_function register_subcommand_from_gd_cmd function
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



start_test_function dispatch function
  startup
  # -- 1: bad
  out=$(dispatch function_not_existing 2> /dev/null); equal "$E_ARG" $? 'dispatch status (1) <= bad function name'
  equal '' "$out" 'dispatch fails silently on stdout'

  # -- 2: no arg
  out=$(dispatch 2> /dev/null); equal 0 $? 'dispatch status (2) <= no arg'
  # TODO should be stderr
  # equal '' "$out" 'dispatch explains silently on stdout'

  # -- 3: basic function
  out=$(dispatch toto); equal 0 $? 'dispatch status (3)'
  equal 'grepme-toto:::|' "$out" 'dispatch '

  # -- 4: function option
  out=$(dispatch --opt value titi); equal 42 $? 'dispatch status (4)'
  equal 'grepme-titi:value::|' "$out" 'dispatch '

  # -- 5: function flag option
  out=$(dispatch titi -f --opt value); equal 42 $? 'dispatch status (5)'
  equal 'grepme-titi:value:flag:-f --opt value|' "$out" 'dispatch '


>&2 echo -e "\n<= $0 returned: $g_dispatch_i_res"
exit "$g_dispatch_i_res"
