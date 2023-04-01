#!/usr/bin/env bash
# Test dispatch main functionality (to dipatch on cmdline arguments)

# Source test utilities
  if [[ ! -v B_SOURCED_LIB_TEST ]] || (( 0 == B_SOURCED_LIB_TEST )); then
    export gs_root_path="$(readlink -f "${BASH_SOURCE[0]}")"
    gs_root_path="$(dirname "$gs_root_path")"
    gs_root_path="$(dirname "$gs_root_path")"
    # shellcheck disable=SC1091  # Not following
    source "$gs_root_path/test/lib_test.sh"
  fi


go(){
  local res=''

  local -a a_fct_to_test=(
    test_function_main_argument_at_end
    test_function_main_dry_and_silent
    test_function_main_help
    test_function_example_help
    test_function_irm_example_doc
    test_function_irm_fork
    test_function_irm_example_calls
    test_function_main_optional_argument
    test_function_optional_argument_order
  )

  #art_parallel_suite Self/DispatchMain "${a_fct_to_test[@]}"
  for fct in "${a_fct_to_test[@]}"; do
    echo
    echo -e "${cpurple}Testing function $fct$cend"
    "$fct"
    (( res += $? ))
  done

  return "$res"
}


test_function_main_argument_at_end(){
  g_dispatch_i_res=0

  description="Argument at end of command (ICT-20529)"
  out=$(command dispatch example succeed --silent --value toto)
  equal 0 $? "argument at end exit status"
  [[ "$out" =~ toto ]]; equal 0 $? "argument toto is set"

  return "$g_dispatch_i_res"
}


test_function_main_dry_and_silent(){
  g_dispatch_i_res=0

  description="Argument -s (silent) and -d (dry_run)"
  out=$(command dispatch -sd example fail); equal 42 $? 'command dispatch -sd status'
  equal '' "$out" "command dispatch -sd get no stdout"
  out=$(command dispatch example -sd fail); equal 42 $? 'command dispatch -ds status bis'
  equal '' "$out" "command dispatch example  -sd get no stdout"

  return "$g_dispatch_i_res"
}


test_function_main_help(){
  g_dispatch_i_res=0

  # command Dispatch
  out1=$(command dispatch); equal 0 $? 'command dispatch  execution status'

  # Doc
  out=$(command dispatch --doc); equal 0 $? 'command dispatch -doc status'

  # Help
  out2=$(command dispatch --help)
  [[ "$out1" == "$out2" ]]; equal 0 $? "--help: 'command dispatch' and 'command dispatch --help' same output (hidden as large)"
  # Warning was grep perl '^(\e.*?m)?\K\-*[a-z_]+'
  readarray -t a_help_key < <(echo "$out" | grep --color=never -oE $'^(\e[^m]*m)?[-0-9A-Za-z_]+' | sed $'s/^\e[^m]*m//')
  is_in_array example "${a_help_key[@]}"; equal 0 $? "command dispatch --help with example key=${a_help_key[*]})"
  is_in_array --complete "${a_help_key[@]}"; equal 0 $? "command dispatch --help with --complete"
  is_in_array --help "${a_help_key[@]}"; equal 0 $? "command dispatch --help with --help"
  is_in_array --doc "${a_help_key[@]}"; equal 0 $? "command dispatch --help with --doc"
  is_in_array --silent "${a_help_key[@]}"; equal 0 $? "command dispatch --help with --silent"
  is_in_array --dry_run "${a_help_key[@]}"; equal 0 $? "command dispatch --help with --dry_run"

  return "$g_dispatch_i_res"
}


test_function_example_help(){
  g_dispatch_i_res=0

  out=$(command dispatch example --help); equal 0 $? 'command dispatch example --help status OK'
  readarray -t a_example_help_key <  <(echo "$out" | grep --color=never -oE $'^(\e[^m]*m)?[-0-9A-Za-z_]+' | sed $'s/^\e[^m]*m//')
  is_in_array example "${a_example_help_key[@]}"; equal 1 $? "command dispatch example --help without example"
  is_in_array --complete "${a_example_help_key[@]}"; equal 1 $? "command dispatch example --help without --complete"
  is_in_array --help "${a_example_help_key[@]}"; equal 1 $? "command dispatch example --help without --help"
  is_in_array --doc "${a_example_help_key[@]}"; equal 1 $? "command dispatch example --help without --doc"
  is_in_array --silent "${a_example_help_key[@]}"; equal 1 $? "command dispatch example --help without --silent"
  is_in_array --dry_run "${a_example_help_key[@]}"; equal 1 $? "command dispatch example --help without --dry_run"
  is_in_array succeed "${a_example_help_key[@]}"; equal 0 $? "command dispatch example --help with succeed"
  is_in_array --value "${a_example_help_key[@]}"; equal 0 $? "command dispatch example --help with --value"
  is_in_array fail "${a_example_help_key[@]}"; equal 0 $? "command dispatch example --help with fail"

  return "$g_dispatch_i_res"
}


test_function_irm_example_doc(){
  g_dispatch_i_res=0

  out=$(command dispatch example --doc); equal 0 $? 'command dispatch --doc status OK'
  [[ "$out" =~ 'Fail with status 42' ]]; equal 0 $? "--doc: First function documentation present"
  [[ "$out" =~ 'EXAMPLE environment variable content' ]]; equal 0 $? "--doc -> Long function docuemntation showed"
  [[ "$out" =~ 'example' ]]; equal 0 $?  "--doc: First file documentation present"
  [[ "$out" =~ 'Examples draw where precept fails' ]]; equal 0 $?  "--doc -> Long file documentation showed"
  grep -q 'EXAMPLE.*-*.*default_example_value' <<< "$out"; equal 0 $?  "--doc -> environment doc showed"

  return "$g_dispatch_i_res"
}


test_function_irm_fork(){
  g_dispatch_i_res=0

  description="fork -> source of subcommand via --complete"
  out=$(command dispatch example -sd fail); equal 42 $? 'command dispatch example -sd fail status again 42'
  equal '' "$out" "Must have no output with -sd (silent dry_run)"

  # Test also complete at end
  readarray -t a_irm_command < <(command dispatch --complete | grep -o '^[a-z]*')
  is_in_array example "${a_irm_command[@]}"; equal 0 $? "Subcommand example must be in command dispatch --complete"

  readarray -t a_irm_example_key < <(command dispatch example --complete | grep -o '^-*[a-z]*')
  is_in_array fail "${a_irm_example_key[@]}"; equal 0 $? "Subcommand fail must be in command dispatch example --complete -> ${a_irm_example_key[*]}"
  is_in_array example "${a_irm_example_key[@]}"; equal 1 $? "Subcommand 'example' must not be in command dispatch example --complete"
  is_in_array --value "${a_irm_example_key[@]}"; equal 0 $? "Option '--value' must not in command dispatch example --complete"

  return "$g_dispatch_i_res"
}


test_function_irm_example_calls(){
  g_dispatch_i_res=0

  command dispatch &> /dev/null; equal 0 $? 'command dispatch succeed (again)'
  out=$(command dispatch example) &> /dev/null; equal 0 $? 'command dispatch example status'
  out=$(command dispatch example succeed 2> /dev/null) &> /dev/null; equal 0 $? 'command dispatch example succeed staus'
  out=$(command dispatch example fail 2> /dev/null) &> /dev/null; equal 42 $? 'command dispatch example fail status'
  err=$(command dispatch example fail 2>&1 > /dev/null); equal 42 $? 'command dispatch example fail status'
  # Legacy used to be grep -cP '^(\e.*?m)?\K<--'
  num=$(grep -cE $'^(\e[^m]*m)?<--' <<< "$out"); echo 0 $? 'command dispatch example grep 1'
  equal 0 "$num" "no print_script_end in stdout"
  num=$(grep -cE $'^(\e[^m]*m)?<--' <<< "$err"); echo 0 $? 'command dispatch example grep 2'
  equal 1 "$num" "only one print_script_end in stderr"

  return "$g_dispatch_i_res"
}


###########################
# STARTUP
# A sample file as subshell
  # shellcheck disable=SC1091  # Not following
  source "$gs_root_path/script/lib_dispatch.sh"

  m_t(){ echo -n t; }
  m_u(){ echo -n u; }
  m_v(){ echo -n v; }

  mm_two(){ echo "$1:$2"; return 2; }

  mm_zero(){
    for var in "$@"; do
      echo -n "$var:"; ((i++))
    done
    return 0
  }

  count=0
  m_c(){ ((count++)); return 0; }
  mm_count(){ ((count=$1)); return 1; }
  fct_count(){ ((tmp=count, count=0)); return "$tmp"; }

  fct_42(){ return 42; }


test_function_main_optional_argument(){
  g_dispatch_i_res=0

  description="optional argument '--two one two' and '-t -u fct'"
  # -- 1:
  out=$(dispatch --two one two fct_42)
  equal 42 $? 'dispatch status 1'
  equal one:two "$out" 'dispatch out 1'

  # -- 2:
  out=$(dispatch -t -u fct_42)
  equal 42 $? 'dispatch status 2'
  equal tu "$out" 'dispatch out 2'

  # -- 3:
  out=$(dispatch -tuvt -uv -t -u -v fct_42)
  equal 42 $? 'dispatch status 3'
  equal tuvtuvtuv "$out" 'dispatch out 3'

  # -- 4:
  out=$(dispatch -tuwtu fct_42)
  equal 42 $? 'dispatch status 4'
  equal tu "${out:0:2}" 'dispath out 4 / 1'
  equal tu "${out:0:2}" 'dispath out 4 / 2'
  equal tu "${out: -2}" "Output string from -tuwtu will start and end by 'tu' with potential warning in between for unknown parameter 'w'"

  return "$g_dispatch_i_res"
}


test_function_optional_argument_order(){
  g_dispatch_i_res=0

  description="optional argument keep context: '-c' and '--count' modify same variable"
  dispatch --count 0 -ccc fct_count; equal 3 $? 'disaptch count 1'
  dispatch -ccc --count 0 -c -c fct_count; equal 2 $? 'disaptch count 2'
  dispatch fct_count -c -c; equal 2 $? 'ParamEnd 1: ICT-20530: Now argument parser accepts param at end'
  dispatch --count 10 fct_count --count 40; equal 40 $? 'ParamEnd 2'
  dispatch fct_count -ccc --count 40 -cc; equal 42 $? 'ParamEnd 3'
  dispatch -ccwwcwcc -w -cc -c -c -c fct_count &> /dev/null ; equal 10 $? 'disaptch count 10'

  return "$g_dispatch_i_res"
}

: "$description"

go || g_dispatch_i_res=1

>&2 echo -e "\n<= $0 returned: $g_dispatch_i_res"
exit "$g_dispatch_i_res"
