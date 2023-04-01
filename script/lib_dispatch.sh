#!/usr/bin/env bash
  # Shell dispatcher library
  # Include me, declare some user functions and then call:
  #
  # * dipatch      call at end of script
  # * register_subcommand  call to register a subcommand
  # * __default    autocalled if no argument
  # * __at_init    autocalled before
  # * __at_finish  autocalled after
  # * __set_env    parsed for documentation, call it yourself
  # * __complete_toto   autocalled when completing toto subcommand
  #
  # For example write the following code in a file:
  # ```bash
  # # File main.sh
  # source lib_dispatch.sh
  # toto(){
  #   : "Docstring to claim that toto is innocent"
  #   echo toto; return 0
  # }
  # titi(){ echo titi; return 1; }
  # dispatch "$@"
  # ```
  #
  # Then call it like:
  # ```bash
  # main.sh toto; echo \$?  # Prints toto; 0
  # main.sh titi; echo \$?  # Prints titi; 1
  # main.sh --help  # or --complete, --doc
  # EOF
  # ```
  # ==> No matter the altitude, what counts is the slope <==

  # shellcheck disable=SC2016  # Expressions don't expand in single quotes, use double quotes for that

##########
# Global

  # Capute epoch of sourcing
  declare -g g_dispatch_start_time  # Epoch of sourcing
  # shellcheck disable=SC2034  # g_dispatch_start_time appears unused
  printf -v g_dispatch_start_time '%(%s)T' -1  # Faster than date command

  export DISPATCH_EQUAL_ERR=''
  export DISPATCH_SELF_COMMIT=''

  # Capture main caller name
  declare -g gs_main_file=$0  # Main caller (can be the file of a subcmd)

  # Project name to prefix some log
  if [[ ! -v g_dispatch_project_name || -z "$g_dispatch_project_name" ]]; then
    export g_dispatch_project_name=${gs_main_file##*/}  # Name of the project as a prfix to run log
    g_dispatch_project_name=${g_dispatch_project_name^^}
  fi

  # Init some default global
  declare -gi g_dispatch_b_print=1  # Do print command before run in run
  declare -gi g_dispatch_b_run=1  # Do run command in run
  declare -gi g_dispatch_i_res=0  # Global response for the equal
  declare -gi g_dispatch_b_help=0  # Is asking for help
  declare -gi g_dispatch_b_doc=0  # Is asking for doc
  declare -gi g_dispatch_b_complete=0  # Is completing (or asking for complete):  0: no, 1: yes, 2: yes but already done
  [[ -v COMP_TYPE ]] && [[ -n "$COMP_TYPE" ]] && [[ "$COMP_TYPE" != "0" ]] && g_dispatch_b_complete=1


  declare -gA g_dispatch_d_fct_default=(  # Default functions defined by hardcode
    [mm_silent]="🤫 Do not print executed commands (-s) [available for subcmd]"
    [mm_dry_run]="🖨️ Only print command instead of executing (-d) [available for subcmd]"
    [mm_complete]="❓Print lines with 'subcommand : comment' [available for subcmd]"
    [mm_help]="❓Print this message (-h) [available for subcmd]"
    [mm_doc]="❓Print this message [available for subcmd]"
  )
  declare -gA g_dispatch_d_fct=()  # Fct dictionnary: the tail to call (no dispatch)
  declare -gA g_dispatch_d_cmd=()  # Subcommand dictionnary (these subcommand mus tcall dispatch)
  declare -ga g_dispatch_a_fct_to_hide=()  # Array of already defined function to hide (Filled by lib_dispatch)
  declare -ga g_dispatch_a_dispach_args=()  # Array of arguments given by the first user command
  readarray -t g_dispatch_a_fct_to_hide < <(declare -F -p | cut -d " " -f 3)

  # Error values
  # shellcheck disable=SC2034  # E_CD appears unused
  set_error_enum(){
    declare -g E_CD=82        # Cannot change directory => does it exists, are env var ok ?
    declare -g E_ARG=83       # Bad arguments given => read usage
    declare -g E_USER=84      # Bad user => sudo run me ?
    declare -g E_GIT=85       # Git failed somehow => bug in code, someone added ?
    declare -g E_GREP=86      # Error detected grepping it in build.log => Read log
    declare -g E_PYTHON=87    # Python configuration => pyenv -g
    declare -g E_REQ=88       # Some requirements are not found => Read the log/doc
    declare -g E_CANCEL=89    # Cancelled (by user)
    declare -g E_CMD=90       # Previous command failed, cannot go further
    declare -g E_TIMEOUT=91   # The command has timedout
    declare -g E_UNKNOWN=92   # Unpredicted behavior
    declare -g E_ONE=93       # One child have failed at least, used by bash_parallel
    declare -g E_HTTP=94      # Cannot reach host, maybe bad url or VPN not opened
  }
  set_error_enum

  can_color(){
    : "Test if stdoutput supports color (void -> bool)"
    # Clause: Github actions web interface supports ansi escape
    [[ -v GITHUB_ACTION ]] && return 0

    # Clause: Tty terminal supports ansi escape
    (( ! g_dispatch_b_complete )) \
      && command -v tput &> /dev/null \
      && tput colors &> /dev/null \
      && return 0

    # IDK where I am, so I do not colorize
    return 1
  }

  set_color(){
    : 'Gruvbox: https://github.com/alacritty/alacritty/wiki/Color-schemes#gruvbox'
    declare -g cfend="\e[39m"           # Normal foreground
    declare -g cend="\e[0m"             # Reset all
    declare -g cbold="\e[1m"            # Bold, can be added to colors
    declare -g cunderline="\e[4m"       # Underline, can be added to colors
    declare -g cred="\e[38;5;124m"      # Error
    declare -g cgreen="\e[38;5;34m"     # Ok
    declare -g cyellow="\e[1m\e[38;5;208m"   # Warning, Code
    declare -g cblue="\e[38;5;39m"      # Info, Bold
    declare -g cpurple="\e[38;5;135m"   # Titles
  }

  reset_color(){
    # shellcheck disable=SC2034  # cfend appears unused
    declare -g cfend=''
    declare -g cend=''
    declare -g cbold=''
    declare -g cunderline=''
    declare -g cred=''
    declare -g cgreen=''
    declare -g cyellow=''
    declare -g cblue=''
    declare -g cpurple=''
  }

  if can_color "$@"; then
    set_color
    # Changed the yellow to orange so can be seen on whit bg
  else
    reset_color
  fi

  declare -gi gi_first_dispatch=0  # Is it the first time dispatch or better say (call_fct_arg) is called, 0 not called, 1 called, 2 called and returned
  declare -g ga_dispatch_command_line=()  # The command line stored at init and used for reporting, in case

  if (( ! g_dispatch_b_complete )); then
    shopt -s extdebug  # To get function argument in stacktrace
    set -o errtrace  # If set, the ERR trap is inherited by shell functions.
    # TODO test with minimal exmaple (2H)
    #trap 'perr "Info: abnormal status raised (ERR)"' ERR
    #trap 'perr "Info: abnormal exit"' EXIT
    shopt -s expand_aliases
  fi

##########
# 5/ Dispatch

dispatch(){
  : '101/ Call the function with the name of the argument, tested
    Depends on: fill_fct_dic, call_fct_arg  # Actually just calls those 2
    Return: the called function return value
  '

  # Clause: do not work if caller script have been sourced (this kicks out debugger)
  [[ -v BASH_SOURCE ]] && (( ${#BASH_SOURCE[@]} > 0 )) && [[ -n "${BASH_SOURCE[*]}" ]] && [[ "$(basename "$0")" != bash ]] && [[ "${BASH_SOURCE[-1]}" != "$0" ]] && return 0

  fill_fct_dic
  call_fct_arg "$@"

  return $?
}

register_subcommand_from_gd_cmd(){
  : '102/ Register subcommands and their docstring, tested
    Depends on: get_file_docstring
    Global: g_dispatch_d_fct (out)
    Global: g_dispatch_d_cmd (in)
    From: https://stackoverflow.com/a/20018504/2544873
    # The sync version
    for cmd in "${!g_dispatch_d_cmd[@]}"; do
      local file=${g_dispatch_d_cmd[$cmd]}
      g_dispatch_d_fct[$cmd]=$(get_file_docstring "$file" long)
    done
  '
  local -A d_fd=()
  local -i i_fd=0
  local cmd=''

  # Spawn a thread per file
  # -- For all command
  # -- Get value -> file -> docstring -> fd
  for cmd in "${!g_dispatch_d_cmd[@]}"; do
    local file=${g_dispatch_d_cmd[$cmd]}
    eval "exec {i_fd}< <(get_file_docstring \"$file\" long)"
    d_fd[$cmd]=$i_fd
  done

  # Join thread and append docstring -> dictionarie
  for cmd in "${!g_dispatch_d_cmd[@]}"; do
    g_dispatch_d_fct[$cmd]=$(cat <&${d_fd[$cmd]})
    ((i_fd++))
  done

  # Close file descriptor
  for cmd in "${!g_dispatch_d_cmd[@]}"; do
    eval "exec ${d_fd[$cmd]}<&-"
  done
}

fill_fct_dic(){
  : 'Internal: Fill g_dispatch_d_fct the Global Dictionary of defined functions, tested
    -- coded with asyncronic pipe redirection (fork-join)
    Depends on: substract_array and get_fct_docstring
    Global: g_dispatch_d_fct (out) dict<functions,docstring> where functions are the ones declared in calling script
    Global: g_dispatch_d_fct_default (in) dict<functions,docstring> where default functions are defined
    Global: g_dispatch_a_fct_to_hide (in) array<functions> where function already defined in parent shell must be hideen
  '
  local -a a_fct_all="($(declare -F -p | cut -d " " -f 3))"
  local -a a_fct_see=()
  local fct=''

  # Hide function: a_fct_all - g_dispatch_a_fct_to_hide => a_fct_see
  readarray -t a_fct_see < <(substract_array "${a_fct_all[@]}" -- "${g_dispatch_a_fct_to_hide[@]}")

  # For visible function: get functions docstring
  ## -- Safe expansion to avoid: a_fct_see[@]: unbound variable
  # -- From: https://stackoverflow.com/a/61551944/2544873
  for fct in "${a_fct_see[@]+"${a_fct_see[@]}"}"; do
    g_dispatch_d_fct[$fct]="$(get_fct_docstring "$fct")"
  done

  # Append defaults functions and string (like --help)
  for fct in "${!g_dispatch_d_fct_default[@]}"; do
    g_dispatch_d_fct[$fct]=${g_dispatch_d_fct_default[$fct]}
  done

  return 0
}

call_fct_arg(){
  : 'Main Call function with trailing arguments (after options), TODO test and document
    -- This is where the magic happens
    Args: functions to call
    Global: gi_first_dispatch (in)
    Global: g_dispatch_b_complete (in)
    Return: same as next call
    ==> Here is the big command line parser, crafter <==
  '
  local -a args=("$@")
  local arg=''
  local -i res=0 ret=0 b_will_finish=0
  local -i i_to_skip=0  # Named option are consuming next option
  local target_fct=''  # The function user request  # For help or call
  local subcmd_file=''  # Name of the file set if clling subcommand

  # Log helper for completion
  # log "Dispatch:$#|$*! (complete=$g_dispatch_b_complete, help=$g_dispatch_b_help)"

  # Here I start, pre-parse
  if (( gi_first_dispatch < 1 )); then
    gi_first_dispatch=1
    # shellcheck disable=SC2034  # ga_dispatch_command_line appears unused
    ga_dispatch_command_line=("$0" "$@")

    # Clause: is completing
    if (( g_dispatch_b_complete )); then
      print_complete_main
      return 0
    fi

    # Pre parse -> Set global flags
    # -- Safe expansion to avoid: a_fct_see[@]: unbound variable
    # -- From: https://stackoverflow.com/a/61551944/2544873
    for arg in "${args[@]+"${args[@]}"}"; do
      case "$arg" in
        --complete) g_dispatch_b_complete=1;;
        --help) g_dispatch_b_help=1;;
        --doc) g_dispatch_b_doc=1;;
        --silent) g_dispatch_b_print=0;;
        --dry_run) g_dispatch_b_run=0;;
        -[^-]*)
          while read -r -n1 chr; do
            case $chr in
              h) g_dispatch_b_help=1;;
              s) g_dispatch_b_print=0;;
              d) g_dispatch_b_run=0;;
            esac
          done < <(printf '%s' "${arg:1}")
          ;;
      esac
    done
  fi

  # Clause: Do not work without argument
  if [[ -z "$*" ]] && ! { ((g_dispatch_b_complete)) || ((g_dispatch_b_help)) || ((g_dispatch_b_doc)); }; then
    if declare -F __default > /dev/null; then
      __default
    else
      print_usage_main --help
    fi
    return 0
  fi

  # Clause: if --at, send the payload at
  # TODO test me and refactor me
  if is_in_array --at "${args[@]}" && ! { ((g_dispatch_b_complete)) || ((g_dispatch_b_help)) || ((g_dispatch_b_doc)); }; then
    local a_new_arg=()
    local a_new_opt=()
    local target_host=''
    while (( 0 != $# )); do
      case "$1" in
        --at)
          target_host=$2
          shift; shift
          ;;
        -*)
          if (( 0 == ${#a_new_arg[@]} )); then
            a_new_opt+=("$1")
          else
            a_new_arg+=("$1")
          fi
          shift
          ;;

        *)
          if (( 0 == ${#a_new_arg[@]} )); then
            a_new_arg+=("$1")
          else
            if (( 0 != ${#a_new_opt[@]} )); then
              a_new_arg+=("${a_new_opt[@]}")
              a_new_opt=()
            else
              a_new_arg+=("$1")
            fi
          fi
          shift
      esac
    done
    mm_at "$target_host" "${a_new_arg[@]}"
    return $?
  fi

  # Save first arguments for diplay
  if (( ! ${#g_dispatch_a_dispach_args[@]} )); then
    g_dispatch_a_dispach_args=("$@")
  fi

  # Parse each user input argument
  declare -a a_fct_to_run=()
  for arg in "$@"; do
    shift  # So that $@ contains the rest of arguments

    # log "call_fct_arg: arg=$arg, skip=$i_to_skip: rest=$*|"

    # Consume parameters already used
    if ((i_to_skip > 0)); then
      ((i_to_skip--))
      continue
    fi

    # Clause: Pass if void
    [[ -z "$arg" ]] && continue

    ########################
    # Discriminate argument:

    # Named option. Consume as much argument as fct return status
    if [[ '--' == "${arg:0:2}" ]]; then
      target_fct="${arg:2}"
      target_fct="mm_${target_fct//-/_}"

      # Clause: pass known option flag
      if is_in_array "$target_fct" "${!g_dispatch_d_fct_default[@]}"; then
        continue
      fi

      if is_in_array "$target_fct" "${!g_dispatch_d_fct[@]}"; then
        "$target_fct" "$@"; ((ret=$?))  # Run now so that it is set before calling target_fct
        ((i_to_skip+=ret))
        # If custom completion
        if ((g_dispatch_b_complete)) \
            && declare -F "__complete_${target_fct}" > /dev/null \
            && (( $# <= ret )); then
          (( g_dispatch_b_complete = 2 ))
          a_fct_to_run=("__complete_$target_fct")
          # Do not add default completion if custom
        fi
      fi

    # Letter option. Never consume other argument. Call each letter
    elif [[ '-' == "${arg:0:1}" ]] && [[ "${arg:1:1}" != "-" ]]; then
      while read -r -n1 chr; do
        # Sanitization, -s -d and -h are reserved
        if is_in_array "$chr" s d h; then
          continue
          #perr "Arguments -h, -p and -s are reserved by lib_dispatch => Ciao!" \
          #     "Tip: remove the function m_$chr from your script or edit lib_dispatch"
          #exit "$E_ARG"
        elif ! is_in_array "m_$chr" "${!g_dispatch_d_fct[@]}"; then
          echo "Warning: lib_dispatch: unknown -$chr argument => ignoring"
          continue
        fi

        "m_$chr" "$@";
      done < <(printf '%s' "${arg:1}")

    # Subcommand file. With register_subcommand
    elif is_in_array "$arg" "${!g_dispatch_d_cmd[@]}"; then
      local subcmd_file="${g_dispatch_d_cmd["$arg"]}"

      # Hide currently defined fuction (by dispatch for example) so enters an empty namespace
      declare -gA g_dispatch_d_fct=()
      declare -gA g_dispatch_d_cmd=()
      if [[ alma != "$arg" ]]; then
        readarray -t g_dispatch_a_fct_to_hide < <(declare -F -p | cut -d " " -f 3)
      fi
      gs_main_file=$subcmd_file

      # Source subcmd file
      # shellcheck disable=SC1090  # ShellCheck can't follow non-constant
      source "$subcmd_file"

      # TODO clean that
      # Call dispatch
      if [[ -v g_tmp_dir ]]; then
        export g_junit_file=${g_tmp_dir}/junit_${arg}_last_restult.xml
      fi
      dispatch "$@"; res=$?
      break

    # Function to call
    # -- Must be after subcommand bebause it has cmd doc too
    # -- May be preceded by a '_' to prevent hiding command and builtin
    elif { target_fct="$arg" && is_in_array "$target_fct" "${!g_dispatch_d_fct[@]}"; } \
        || { target_fct="_$arg" && is_in_array "$target_fct" "${!g_dispatch_d_fct[@]}"; }; then
      # If completing
      if ((g_dispatch_b_complete)) || ((g_dispatch_b_help)) || ((g_dispatch_b_doc)); then
        # If custom completion
        if ((g_dispatch_b_complete)) && declare -F "__complete_$arg" > /dev/null; then
          a_fct_to_run=("__complete_$arg")
        fi
      # If executing
      else
        a_fct_to_run=("$target_fct" "$@")
      fi

    # Pass if completing and do not know what to do
    elif ((g_dispatch_b_complete)) || ((g_dispatch_b_help)) || ((g_dispatch_b_doc)); then
      :

    # ICT-20530: If a function exists, it may be a positional parameter of it
    # -- Dont worry, it will be called later
    elif (( ${#a_fct_to_run[@]} )); then
      :

    # Panic if Unknown argument
    else
      perr "Dispatch: $(basename "$0"): unknown argument: '$arg' => Ciao!" \
           "-------------------------------------------------"
      return "$E_ARG"
    fi
  done

  # Call __at_init
  (( ${#args[@]} > 0 )) \
    && ! ((g_dispatch_b_help)) \
    && ! ((g_dispatch_b_complete)) \
    && ! ((g_dispatch_b_doc)) \
    && [[ -z "$subcmd_file" ]]
  # shellcheck disable=SC2181  # Check exit code directly
  ((b_can_call_at=!$?))
  if ((b_can_call_at)) && declare -F __at_init > /dev/null; then
    __at_init "${args[@]}"; ((res|=$?))
  fi
  if ((b_can_call_at)) && declare -F __at_finish > /dev/null; then
    b_will_finish=1
  fi

  # Run the save function now that its parameters are set
  if (( ${#a_fct_to_run[@]} )); then
    "${a_fct_to_run[@]}"; res=$?
  fi

  # Print Bye, only onces (the first one)
  if ((gi_first_dispatch < 2)); then
    gi_first_dispatch=2
    # Print
    if ((g_dispatch_b_complete)); then
      if ((g_dispatch_b_complete == 1 && ${#a_fct_to_run[@]} == 0 )); then
        print_usage_main --complete; g_dispatch_b_complete=2
      fi

    elif ((g_dispatch_b_help)); then
      ((g_dispatch_b_help == 1)) && {
        if [[ -n "$target_fct" && mm_help != "$target_fct" ]]; then
          print_usage_fct --doc all "$target_fct"
        elif declare -F __default > /dev/null; then
          __default
        else
          print_usage_main --help
        fi
        g_dispatch_b_help=2;
      }

    elif ((g_dispatch_b_doc)); then
      ((g_dispatch_b_doc == 1)) && { print_usage_main --doc; g_dispatch_b_complete=2; }
    fi

    # Finish
    if ((b_will_finish)); then
      __at_finish "$res" "${args[*]}"; ((res+=$?))
    fi
  fi

  # Return
  return "$res"
}


##########
# 4/ High level: Completion, Help, Doc

print_usage_main(){
  : 'Print Usage Tail: Fct, Option, Env, TODO test with example
    Depends on: print_usage_fct, print_usage_env, print_title
    Arg1: format: --complete --help --doc --html
  '
  local format="${1:---help}"
  local -a a_fct_unsorted=() a_fct_num_yes=() a_fct_num_noo=()

  # Get all fct doc dictionary
  readarray -t a_fct_unsorted < <(
    for key in "${!g_dispatch_d_fct[@]}"; do
      # Clause: do not print magic commands for subcmd
      # -- it would be redundant, noisy
      [[ --complete != "$format" ]] \
          && [[ "$0" != "$gs_main_file" ]] \
          && is_in_array "$key" "${!g_dispatch_d_fct_default[@]}" \
          && continue
      printf "%s\n" "$key ${g_dispatch_d_fct[$key]//$'\n'/}"
    done | sed -e 's/\${[^}]*}//g'
  )

  # Grep function with number in their comment or no
  local re='^\S+ +\d+\/'
  readarray -t a_fct_num_yes < <(printf '%s\n' "${a_fct_unsorted[@]}" | grep    "$re" | sort -nk2 -k1 | cut -d' ' -f1)
  readarray -t a_fct_num_noo < <(printf '%s\n' "${a_fct_unsorted[@]}" | grep -v "$re" | sort -k1      | cut -d' ' -f1)

  # Sort function name inteligently: argument last and if number in comment, respect order
  local is_mm="^mm_"
  readarray -t ga_fct_sorted < <(
    # Without mm_ => normal function
    (( ${#a_fct_num_yes[@]} )) && printf '%s\n' "${a_fct_num_yes[@]}" | grep -v "$is_mm"
    (( ${#a_fct_num_noo[@]} )) && printf '%s\n' "${a_fct_num_noo[@]}" | grep -v "$is_mm"
    # With mm_ => print arguments at end
    (( ${#a_fct_num_yes[@]} )) && printf '%s\n' "${a_fct_num_yes[@]}" | grep "$is_mm"
    (( ${#a_fct_num_noo[@]} )) && printf '%s\n' "${a_fct_num_noo[@]}" | grep "$is_mm"
  )

  # log "Fct sorted: ${ga_fct_sorted[*]}"
  # log "Fct unsorted: ${a_fct_unsorted[*]}"
  # log "Fct yes: $(print_args "${a_fct_num_yes[@]}")"
  # log "Fct noo: $(print_args "${a_fct_num_noo[@]}")"

  # Clause: leave early if completing
  if [[ --complete == "$format" ]]; then
    print_usage_fct --complete all "${ga_fct_sorted[@]}"
    return 0
  fi

  # Clause: user feined usage ?
  if declare -F __usage > /dev/null; then
    __usage "$@"
  fi

  if [[ -e "$gs_main_file" ]]; then
    # Title
    print_title "$gs_main_file"

    # Description
    local desc=$(get_file_docstring "$gs_main_file" long)
    printf "%b" "$desc\n\n"
  fi

  # Usage
  local msg="${cblue}Usage:$cend ${cpurple}$(basename "$0")$cend [options] subcommand\n"

  # Function
  local list="$(print_usage_fct "$format" function "${ga_fct_sorted[@]}")"
  if [[ -n "$list" ]]; then
    msg+="${cblue}Subcommand list:\n"
    msg+="--------------$cend\n"
    msg+="$list\n\n"
  fi

  # Option
  local list="$(print_usage_fct "$format" option "${ga_fct_sorted[@]}")"
  if [[ -n "$list" ]]; then
    msg+="${cblue}Option list:\n"
    msg+="------------$cend\n"
    msg+="$list\n\n"
  fi

  # Environment
  local list="$(print_usage_env "$@")"
  if [[ -n "$list" ]]; then
    msg+="${cblue}Environment variable:\n"
    msg+="---------------------$cend\n"
    msg+="$list\n\n"
  fi

  # Return
  echo -ne "$msg"
}

print_usage_fct(){
  : 'Print functon description, tested
    Big formating BaZar
    Depends on: colorize_docstring
    Arg1: format <string>: complete, help, doc
    Arg2: type <string>: option, function, all
    Global: g_dispatch_d_fct (in:dict) containing functions (key) and their docstring (value)
  '
  local format="${1:---help}"
  local type="${2:-function}"
  local -a a_fct=("${@:3}")
  local arg='' fct=''

  # Check in: g_dispatch_d_fct must exist or error
  if [[ ! "$(declare -p g_dispatch_d_fct 2> /dev/null)" =~ ^declare[[:space:]]-A ]]; then
    perr 'The dictionary g_dispatch_d_fct must exist (and be filled)' \
      'Tip: declare -gA gf_fct=(); fill_fct_fic'
    return "$E_REQ"
  fi

  # Check in: Format
  if ! is_in_array "$format" --complete --help --doc; then
    perr "The function print_usage_fct received an unknown format: $format" \
      "Tip: print_usage_fct --complete --help or --doc"
    return "$E_REQ"
  fi

  # For all function, echo what must
  for fct in "${a_fct[@]}"; do
    # log "Usage loop: fct:$fct| type:$type!"

    # # Clause: The function must be in g_dispatch_d_fct or silently pass
    # if [[ ! -v g_dispatch_d_fct[$fct] ]]; then
    #   pwarn "In function print_usage_fct which was a bad function name: \"$fct\" is not stored in g_dispatch_d_fct, ignoring" \
    #     "Tip: print_usage_fct a_good_function_registered_in_gd_dic" \
    #     "Note: g_dispatch_d_fct contains (${!g_dispatch_d_fct[*]})"
    #   continue
    # fi

    local docstring=${g_dispatch_d_fct[$fct]}

    # Clause: Pass -h, --help and __set_env
    if [[ __set_env == "$fct" ]]; then
      continue

    # First, parse
    ##############

    # Long option parameter
    elif [[ mm_ == "${fct:0:3}" ]]; then
      if [[ option == "$type" || all == "$type" || --complete ==  "$format" ]]; then
        arg="--${fct:3}"
      else
        continue
      fi

    # Shoft option -h
    elif [[ m_ == "${fct:0:2}" ]]; then
      if [[ option == "$type" || all == "$type" || --complete == "$format" ]]; then
        arg="-${fct:2}"
      else
        continue
      fi

    # Prefix removel
    elif [[ _ == "${fct:0:1}" ]]; then
      if [[ function == "$type" || all == "$type" || --complete == "$format" ]]; then
        # Removes _ prefix
        arg="${fct:1}"
      else
        continue
      fi

    # No more possible options
    elif [[ option == "$type" ]]; then
      continue

    # Normal named function
    else
      arg="$fct"
    fi

    # Now print
    ##############

    if [[ --complete == "$format" ]]; then
      read -r line < <(echo "$docstring")
      line=$(colorize_docstring "$line")
      echo "$arg : $line"

    elif [[ --help == "$format" ]]; then
      read -r line < <(echo "$docstring")
      line=$(colorize_docstring "$line")
      printf "$cpurple%-13s$cend  $line\n" "${arg}"

    elif [[ --doc == "$format" ]]; then
      add_tag "placeholder_tag a href=\"#$arg\">"
      echo -e "$cpurple${arg}$cend"
      add_tag "placeholder_tag /a"
      line=$(colorize_docstring "$docstring")
      printf "%s\n" "$line"
      # Add new (empty) line in case more than one description
      (( ${#a_fct[@]} > 1 )) && echo
    fi
  done
  return 0
}

print_usage_env(){
  : 'Print Environment variables used, TODO test
    -- That is why they must be set in __set_env
    Arg3: indent
    Arg4: value: can be default, current to print default or current value (default: default)
    Global: __set_env function <in>
  '
  local i_indent="${3:-0}"
  local value="${4:-default}"
  local indent="$(printf "%${i_indent}s" "")"

  # Check in: (silent) __set_env function must be defined
  [[ function != "$(type -t __set_env)" ]] && return 0

  declare -f __set_env \
    | awk -v cpurple="\\$cpurple" -v cend="\\$cend" \
      -v indent="$indent" -v value="$value" '
      BEGIN { FS=":=" }
      /: "\$/ {
        # Required trick
        num = gsub("^ *`#", "", $0);

        # Remove lead and trail
        gsub("^ *: *\"\\$\\{|\\}\" *`?; *$", "", $0);

        # Was it required?
        if (num > 0) gsub("$", "  [Required]", $0);

        # Padding
        slen = 20-length($1); if(slen < 2) slen=2;
        pad = sprintf("%-*s", slen , " ");
        gsub(/ /, "-", pad);

        # Over
        if (value == "current") {
          printf("%s%s%s%s  %s  %s\n", indent, cpurple, $1, cend, pad, ENVIRON[$1]);
        } else {
          printf("%s%s%s%s  %s  %s\n", indent, cpurple, $1, cend, pad, $2);
        }
      }
    '
}

print_complete_main(){
  : 'Main Print for completion, TODO test
    First completion call, calls the rest
    From: https://stackoverflow.com/questions/7267185
  '

  set --  # For shellcheck

  # Remove the line trail for the completion (ignore it)
  COMP_LINE=${COMP_LINE:0:$COMP_POINT}

  # Add last argument if cursor is one space after last word
  # -- So that we know an other argument is expected
  [[ ${COMP_LINE:COMP_POINT-1:1} == " " ]] && COMP_LINE+='""'

  # Parse command line
  eval "set -- $COMP_LINE"
  # shellcheck disable=SC2124  # assigning array to string false positive
  local arg_prefix="${@: -1}"
  local pad_raw='-----------------'

  # Launch command with complete
  readarray -t lines < <(dispatch --complete "${@:2}")

  # Pretty print
  # Lines are keyword : comment
  COMPREPLY=()
  for line in "${lines[@]}"; do
    local possible_arg="${line%% : *}"
    # Chomp: Trail leading and trailing spaces
    # From: https://unix.stackexchange.com/a/360648/257838
    shopt -s extglob
    possible_arg=${possible_arg##+([[:space:]])}
    possible_arg=${possible_arg%%+([[:space:]])}

    # Clause do not work if empty
    [[ -z "$possible_arg" ]] && continue

    # If match current argument prefix: add it to COMPREPLY
    if [[ "$possible_arg" == "$arg_prefix"* ]]; then
      local comment="${line#* : }"
      local pad=${pad_raw:${#possible_arg}}
      # Safe: make pad be at least one '-' in order to split it well and get only the fct name
      # -- when autocompletion put the result in the command line
      [[ -z "$pad" ]] && pad='-'
      printf -v line "%s  %s  %s" "$possible_arg" "$pad" "$comment"
      COMPREPLY+=("$line")
    fi
  done

  # If Only one completion: clean it
  if [[ ${#COMPREPLY[*]} -eq 1 ]]; then
    # Remove ' ---- ' and everything after
    COMPREPLY[0]="${COMPREPLY[0]%%  -*}"
  fi

  # Print solutions
  printf "%s\n" "${COMPREPLY[@]}"
}

get_file_docstring(){
  : 'Read first lines of script to retrieve it header, tested
    Arg1: <string> filename
    Arg2: <string> format: long or short (default)
  '
  local filename="$1"
  local format="${2:-short}"

  # Check in: file must exist, for example with --at the filename is "bash"
  # -- Prevents error: awk: fatal: cannot open file `bash' for reading (No such file or directory)
  if [[ ! -r "$filename" ]]; then
    perr "The function get_fct_docstring requires a file as first parameter (got $*)" \
      "Tip: get_fct_docstring \"$gs_main_file\""
    return "$E_REQ"
  fi

  # Check in: black list bash
  if is_in_array "$filename" /bin/bash /usr/bin/bash "$(which bash)" "$SHELL"; then
    printf "%s" "Sourced file cannot be introspeted => no doc header, sorry."
    return 0
  fi

  # Craft awk command
  # -- If short: Print only one line
  local awk_cmd='NR == 2'
  # -- Else as long as can
  if [[ ! short == "$format" ]]; then
    awk_cmd='
      # Small trick to remove binary files
      # -- which can lead to bugs, Ex: /bin/bash
      NR==1 && substr($0,1,4) ~ "ELF" {
        print FILENAME, "is a binary file => not parsing doc in it"
        exit
      }

      # End of parsing
      /^ *$|^ *[^# ]|^ *#######/ { exit; }

      # Print those lines (remove the shband)
      NR>=2 { print; }
    '
  fi

  # Echo extracted header
  # -- Fetch header from file
  local header="$(awk "$awk_cmd" "$filename" | sed -E 's/^ *# ?//')"
  # -- Expand header
  header="$(colorize_docstring "$header")"
  # -- Print header to caller
  printf "%s" "$header"

  return 0
}

get_fct_docstring(){
  : 'Get the docstring of one function (arg1), tested
    -- Fetching comment like this very docstring (: "comment")
    Arg1: name of the function to get docstring from (it must be declared)
    Ex: toto(){ :; }; get_fct_docstring toto
  '
  local fct=$1
  local doc=''  # outputs
  local -i b_is_last_line=0 i_line=-2 i_indent=0

  # Check in: function must be defined
  # -- From: https://stackoverflow.com/a/85903/2544873
  if [[ -z "$fct" ]] || [[ function != "$(type -t "$fct")" ]]; then
    perr "Function get_fct_docstring must receive a defined function as first argument" \
      "Tip: toto(){ :; } get_fct_docstring toto"
    return "$E_REQ"
  fi

  # A typical declare -f lloks like that:
  # -- $ declare -f print_args
  # -- print_args ()
  # -- {
  # --     : "Helper for debug (parameters): Print input arguments, one per line,
  # --   tested";
  # --     local -i i=1;
  # --     local arg='';
  # Read exact lines, no trimming
  # -- From: https://stackoverflow.com/a/29689199/2544873
  while IFS= read -r line; do
    (( i_line++ ))
    # Pass: if head
    (( i_line <= -1 )) && [[ "$line" =~ ^$fct ]] && continue

    # Pass: if first open bracket
    (( i_line <= 0 )) && [[ "${line:0:1}" == '{' ]] && continue

    # Clause: Stop if not docstring
    (( 1 == i_line )) && [[ ! "$line" =~ ^[[:space:]]*:[[:space:]]+[\'\"] ]] && break

    # Remove the ': "' like head
    (( 1 == i_line )) && {
      local shop_extglob=$(shopt -p extglob); shopt -s extglob
      line=${line/#*([[:space:]]):*([[:space:]])[\"\']*([[:space:]])/}
      $shop_extglob
    }

    # Get indentation level (starting with second line)
    (( 2 == i_line )) && {
      local space_prefix=${line/%[^[:space:]]*/}
      i_indent=${#space_prefix}
    }

    # Check if is last line, before modifying line
    # Doing this b_is_last_line trick in case there is only one line
    [[ "$line" =~ [[:space:]]*[\'\"]\;?$ ]] && b_is_last_line=1

    # Remove leading space indent
    line=${line:$i_indent}

    # Remove trailing ';' potencially  added by parser
    line="${line//\\\"/placeholder-quote-double}"  # ICT-20554: Save escaped \"
    line="${line//\\\'/placeholder-quote-single}"  # ICT-20554: Save escaped \'
    line=${line//[\"\'];/}
    line=${line//[\"\']/}
    line="${line//placeholder-quote-single/\\\'}"  # Replace back
    line="${line//placeholder-quote-double/\\\"}"

    # Add newline potencially
    [[ -n "$doc" ]] && doc+=$'\n'

    # Concat: finally, will be evaluated later
    doc+=$line

    # End
    (( b_is_last_line )) && break
  done < <(declare -f "$fct")

  printf "%s" "$doc"
}

get_os_name(){
  : 'Internal to print hi, tested
    Depends on: file_to_dic
  '
  local msg=Unknown

  # Clause if /etc/os-release not exists
  if ! file_to_dic /etc/os-release; then
    echo "$msg"
    return 1
  fi

  # shellcheck disable=SC2102  # Ranges can only match
  if [[ -v gd_from_file[PRETTY_NAME] ]]; then
    msg=${gd_from_file[PRETTY_NAME]}
    echo "$msg"
    return 0
  fi

  if [[ -v gd_from_file[NAME] ]]; then
    msg=${gd_from_file[NAME]}
    [[ -v gd_from_file[VERSION] ]] && msg+=" ${gd_from_file[NAME]}"
    echo "$msg"
    return 0
  fi

  echo "$msg"
  return 1
}


########################
# 3/ Mid level utilities <= Depends on other utilities

run(){
  : '301/ Print to stderr and run command passed as array reference, tested
    Depends: escape_array
    Argument: The full argument array $@ is used as a command to run
    Global: g_dispatch_b_print: (in) print if not 0
    Global: g_dispatch_b_run: (in) run if not 0
    Return: executed command output
  '
  local cmd_msg=$(escape_array "$@")
  local -i res=0

  IFS=" " read -r -a info <<< "$(caller 0)"
  set +u
  local line="${info[0]}"
  local fct="${info[1]}"
  local file="$(basename "${info[2]}")"

  # Craft message
  local msg=''
  msg+="${cpurple}$g_dispatch_project_name: Running:$cend $cyellow$cmd_msg$cend"
  msg+="\n      #"
  msg+=" ${cblue}Pwd:$cend '$PWD'"
  msg+=" ${cblue}Time:$cend '$(date "+%Y-%m-%dT%H:%M:%S")'"
  msg+=" ${cblue}Function:$cend '$fct'"
  msg+=" ${cblue}File:$cend '$file:$line'"

  # Print
  ((g_dispatch_b_print)) && >&2 echo -e "$msg"

  # Clause to not run nothing
  [[ "$cmd_msg" =~ ^[[:space:\']]*$ ]] && return 0

  # Exec
  if ((g_dispatch_b_run)); then
    # If a single assigment, use the declare trick
    # -- Avoid: bash: line 899: array=Array1-BLC: command not found
    # -- Ref: https://stackoverflow.com/questions/229551
    if (( 1 == $# )) && [[ ! "$cmd_msg" =~ [[:space:]] ]] && [[ "$cmd_msg" =~ = ]]; then
      # Remove surrounding quotes
      cmd_msg=${cmd_msg:1:-1}
      declare -g "$cmd_msg"
    else
      eval "$cmd_msg"  # ; ((PIPESTATUS[0]==0))"
      res=$?
    fi
  fi

  return "$res"
}


print_title(){
  : '302/ Print string and underline, no test needed
    Arg1: [Required] title to print
    Arg2: color or prefix to print (default purple)
    Arg3: <int> indentation level (default 0)
  '
  # Link: https://stackoverflow.com/questions/5349718/how-can-i-repeat-a-character-in-bash
  local chrlen=${#1}
  local indent="${2:-0}"

  # First line
  printf "%${indent}s" ""
  echo -e "${cpurple}$1"

  # Subtitle
  printf "%${indent}s" ""
  eval printf '%.0s-' "{1..$chrlen}"

  # End colorize
  echo -e "$cend"
}

print_script_start(){
  : '303/ Print: script starting => for log, tested
    Global: g_dispatch_start_time <out> used by companion function print_script_end
    Global: g_dispatch_a_dispach_args <in> to print, set by dispatcher
    Global: g_dispatch_b_print <in> do not print if set to 0
  '
  # Clause
  ((g_dispatch_b_print==0)) && return 0

  # This one is global so that script end can get it
  declare -g g_dispatch_start_time=$(date +%s)

  # Hi
  >&2 echo -e "${cgreen}--------------------------------------------------------"
  >&2 echo -e "--> $g_dispatch_project_name: Starting: ${g_dispatch_a_dispach_args[*]} at: $(date "+%Y-%m-%dT%H:%M:%S")"
  >&2 echo -e "--------------------------------------------------------$cend"
}

print_script_end(){
  : '304/ Print: script ending + time elapsed => for log, tested
    Arg1: return_status
    Arg[2:]: rest of command line to print
    Global: g_dispatch_start_time <uin> set by companion function print_script_start
    Global: g_dispatch_b_print <in> do not print if set to 0
  '
  # Clause
  ((g_dispatch_b_print==0)) && return 0

  # Calcultate time
  local -i i_ret=${1:--1}
  shift
  local sec_time=-1
  if [[ -v g_dispatch_start_time ]]; then
    local end_time=$(date +%s)
    sec_time=$((end_time - g_dispatch_start_time))
  fi

  # Set color <- error parameter
  local cmsg="$cgreen"
  ((i_ret != 0)) && cmsg="$cred"

  # Hi
  >&2 printf -v script_time '%dh:%dm:%ds' $((sec_time/3600)) $((sec_time%3600/60)) $((sec_time%60))
  >&2 echo -e "${cmsg}------------------------------------------------------"
  >&2 echo -e "<-- $g_dispatch_project_name: $(basename "$0"): Ending subcommand \"$*\" with status: $i_ret at: $(date "+%Y-%m-%dT%H:%M:%S")$cend"
  >&2 echo -e "  # After: $script_time"
  >&2 echo -e "${cmsg}------------------------------------------------------$cend"
}

colorize_docstring(){
  : 'Colorize function docstring with ANSI escape, ToTest'
  # TODO
  echo "$*"
}

add_tag(){
  : "Internal: Add html tag, not really used, no test needed
  In: \$filetype"
  # TODO not used <= refaction of complete, help, doc
  # Only if html
  [[ ! -v filetype ]] && return
  [[ -v filetype ]] && [[ ! html == "$filetype" ]] && return
  # Close ansi escape pre
  echo "placeholder_tag /pre"
  # Add my tag
  echo "$1"
  # Reopen ansi escape pre tag
  echo "placeholder_tag pre class=\"ansi2html-content\""
}

file_to_dic(){
  : '305/ Read file to a bash associative array, TODO test
    -- file lines must look like value=potencialy quoted fields to
    -- Must copy array to get a reference to it
    -- -- to be compatible with before Bash < 4.3 (without the declare -n feature)
    -- Not asynchronous safe

    Depends on: vcp
    Arg1: (in) file path name
    Arg2: <opt> (out) dictionary bash variable name (must declare it before with declare -A)
    Glogal: gd_from_file <output>
    Return: 1 if error
    Ex: file_to_dic /etc/os-release; echo "${!gd_from_file[PRETTY_NAME]}"
    From: https://unix.stackexchange.com/a/562943/257838
  '
  local k='' v=''
  declare -gA gd_from_file=()

  # Clause: File must be readable
  if [[ ! -r "$1" ]]; then
    perr "File '$1' is not readable" \
      "Tip: file_to_dic /etc/os-release"
    return 1
  fi

  while IFS='=' read -d $'\n' -r k v; do
    # Clause: Skip lines starting with sharp or lines containing only space or empty lines
    [[ "$k" =~ ^([[:space:]]*|[[:space:]]*#.*)$ ]] && continue
    # Clause: Skip if no key
    [[ -z "$k" ]] && continue

    # Remove quotes
    v=${v#\"}; v=${v%\"}

    # Store key value into assoc array
    # shellcheck disable=SC2034  # gd_from_file appears unused
    gd_from_file[$k]="$v"
  done < "$1"

  # Copy to arg2 if specified
  if (( $# > 1 )) && [[ -z "$2" ]] \
      && [[ "$(declare -p "$2" 2> /dev/null)" =~ -A ]]; then
    vcp gd_from_file "$2"
  fi
}


########################
# 2/ Low level utilities <= Only depends on logger

# shellcheck disable=SC2120  # Optional argument can be not passed
read_file_as_array(){
  : 'Read array <- file, tested
    -- Remove empty lines and # comments
    -- Note: if "-" or not existing, read from stdin
    Arg1: (out) array name
    Arg2: (in)  file name
    Ex: read_file_as_array array <(echo -e "a\nb b\nccc cc")
    Ex2: set +m; shopt -p lastpipe; echo -e "a\nb b\nccc cc" | read_file_as_array array
  '
  local varname=$1
  local filename=$2

  # Check in: Arg1 is variable name
  if [[ -z "$varname" ]]; then
    perr "Missing array variable name (arg1)"
    return 1
  fi

  # If filename do not exist, read from stdin
  if [[ ! -e "$filename" ]]; then
    # Clause: if must be nothing or - and we must be in pipe
    if [[ -t 0 || ('' != "$filename" && '-' != "$filename") ]]; then
      perr "Missing file '$filename' to read array from (arg2)"
      return 1
    fi
    filename=/dev/stdin
  fi

  # Parse file
  readarray -t "$varname" < <(sed -re 's/^ *#.*$//g' "$filename" | grep -v '^$')
}

print_unindent(){
  : 'Remove first line indentation to all lines of string (arg1), tested'
  local in=$1
  if [[ ! -t 0 ]] && { (( $# == 0 )) || [[ "-" == "$in" ]]; }; then
    in=$(</dev/stdin)
  fi

  awk '{
    if (NR == 1 && $0 ~ /^$/) { next; }
    if (NR <= 2 && !b_done) { match($0, /^ +/); n=RLENGTH; b_done=1; }
    if (substr($0, 0, n) ~ /^ *$/) {
      print substr($0, n+1)
    } else {
      print $0
    }
  }' <<< "$in"
}

wait_pid_array(){
  : 'Wait for all pid in array in, TODO refactor async API
    From: https://stackoverflow.com/a/43776775/2544873
    From: https://stackoverflow.com/a/356154/2544873  # also
    Return: 0 <= All OK
  '
  local -i res=0 ret=0 pid=0
  for pid; do
    wait "$pid" &> /dev/null; ret=$?
    (( 0 == ret )) && continue
    (( 127 == ret )) && break
    ((res|=ret))
  done
  return "$res"
}

user_at_host(){
  : 'Print $USER@$HOSTNAME, tested'
  local user_at_host=localhost
  [[ -v HOSTNAME ]] && [[ -n "$HOSTNAME" ]] && user_at_host=$HOSTNAME
  [[ -v USER ]] && [[ -n "$USER" ]] && user_at_host="$USER@$user_at_host"
  echo "$user_at_host"
}

ask_confirmation(){
  : 'Print out message and wait for yes/no user confirmation, tested
    Arg1: optional string message of what to confirm
    Return: 0 -> continue: 1 -> user did not confirm
  '
  (( ${#@} > 1 )) && >&2 echo -e "$1"
  >&2 read -p "Do you confirm (y or n)? " -n 1 -r
  >&2 echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    >&2 echo "OK go"; return 0
  else
    >&2 echo "NO, maybe next time"; return 1
  fi
}

# shellcheck disable=SC2120  # Optional argument can be not passed
trim(){
  : 'Trim leading and trailing space, tested
    From: https://github.com/dylanaraps/pure-bash-bible
    Ex: trim "  a b " -> "a b"
  '
  (( $# )) && [[ -z "$1" ]] && return
  local s=${1:-$(</dev/stdin)};
  s=${s#"${s%%[![:space:]]*}"};
  s=${s%"${s##*[![:space:]]}"};
  printf '%s' "$s"
}

remove_newline(){
  : 'Remove newlines and leading spaces to only one space, ToTest'
  local res=${1//$'\n'/}
  local shop_extglob=$(shopt -p extglob); shopt -s extglob
  res=${res//+([[:blank:]])/ }
  $shop_extglob
  printf '%s' "$res"
}

columnize(){
  : 'Pipe util Format inteligently columns but with more user input than columns command, tested
    Arg --col: coma separated list of column size len except the last column. Defaults to 20,30,30,30...
    Arg --ofs --ifs --fs: Output, Input, and generic Field Separator. The generic sets OFS and IFS. These defined how celles are split or join
  '
  # Get in: Field separators
  local fs=$(get_opt --fs "$@")
  local ifs=$fs
  local ofs=$fs
  : "${ifs:=$(get_opt --ifs "$@")}"
  : "${ofs:=$(get_opt --ofs "$@")}"
  : "${ifs:=|}"
  : "${ofs:=|}"

  # Get in: Columns
  local col=$(get_opt --col "$@")

  # Ok Go
  awk -F "$ifs" -v col="$col" -v ofs="$ofs" '
    function max(num1, num2){
       if (num1 > num2) {
         return num1
       }
       return num2
    }


    {
    # Skip space only lines
    if ($0 ~ /^[[:blank:]]*$/){ next }

    # Get default col variable
    if (0 == length(col)){
      for (i=1; i<=NF-1; i++){
        if (1 == i) {
          col = col "20,"
        }
        else {
          col = col "30,"
        }
      }
      col = substr(col, 1, length(col)-1)
    }

    # Read column desired length from user
    if (0 == i_col){
      i_col = split(col , a_desired, ",")
      i_col++
    }

    # Remove spaces
    # -- Leading spaces
    gsub(/^[[:blank:]]*/, "", $0);
    # -- Trailing spaces
    gsub(/[[:blank:]]*$/, "", $0);
    # -- In cell spaces
    gsub(/[[:blank:]]*\|[[:blank:]]*/, "|", $0);


    # Calculate cumulated
    for (i=1; i<=i_col; i++) {
      if (i == 1) { a_cumulated[i] = a_desired[i]; continue; }
      a_cumulated[i] = a_desired[i] + a_cumulated[i-1]
    }

    # Mesure line lengh
    for (i=1; i<=i_col; i++) {
      a_len[i] = length($i);
    }

    # Calculate breakstop: max(desired, real) => the distance from start to this real breakstop
    for (i=1; i<=i_col; i++) {
      if (i == 1) {
        a_breakstop[i] = max(a_cumulated[i], a_len[i])
      } else {
        a_breakstop[i] = max(a_cumulated[i], a_breakstop[i-1] + a_len[i])
      }
    }

    # Calculate diff => the size of this cell
    format = ""
    for (i=1; i<=i_col; i++) {
      if (i == 1) {
        a_len[i] = a_breakstop[i]
      } else {
        a_len[i] = a_breakstop[i] - a_breakstop[i-1]
      }
      format = format "%-" a_len[i] "s"
      if ( i == i_col ){
        format = format "\n"
      } else {
        format = format " | "
      }

      printf format, $i
      format = ""
    }
    }
  '
}


is_integer(){
  : 'Helper: Check if arg1 is an integer before retrning an unreadable error on local -i
    From: https://stackoverflow.com/questions/806906
  '
  [[ "$1" =~ ^[0-9]+$ ]]; return $?
}


is_command(){
  : 'Helper: check if command exists'
  command -v "$1" &> /dev/null; return $?
}


# 2.3/ Network utils

ping_all_fork(){
  : 'Ping all host async, faster, ToTest
    -- Used by check.sh for ART
    Args: host list and can include --callback fct_to_call
  '
  local -i res=0
  local -A d_pid=()
  local host=''

  # Get optional callback
  local callback=$(get_opt --callback "$@")
  if [[ -n "$callback" ]]; then
    shift; shift
  else
    callback=__ping_all_callback
  fi

  # Get optinal ssh
  local b_ssh=$(get_opt --ssh "$@")
  local b_ssh=${b_ssh%% *}
  if [[ -n "$b_ssh" ]]; then
    shift; shift
  else
    b_ssh=0
  fi

  # -- Fork
  for host; do
    if (( b_ssh )); then
      ssh -o ConnectTimeout=2 "$host" uptime &> /dev/null & d_pid[$host]=$!
    else
      ping -c1 -W1 "$host" &> /dev/null & d_pid[$host]=$!
    fi
  done
  # -- Join
  for host; do
    wait "${d_pid[$host]}"; ret=$?
    $callback
  done
  return "$res"
}


__ping_all_callback(){
  : 'Default callback for ping_all_fork
    Global: <in> ret
    Global: <in> host
    Global: <out> res
  '
  local msg=''
  if [[ -v b_ssh ]] && (( b_ssh )); then
    msg="ssh $host"
  else
    msg="ping $host"
  fi
  equal 0 "$ret" "$msg"
  ((res|=ret))
}


ping_all(){
  : 'Ping every host (args) given in argument, ToTest
    Return: 0 if all host respond
  '
  local host=''; local -i res=0
  for host; do
    if ping -c1 -W1 "$host" &>/dev/null; then
      echo -e "\e[32mOK $host responds to ping\e[0m"
    else
      echo -e "\e[31mNO $host do not respond to ping\e[0m"
      (( res |= 1 ))
    fi
  done
  return "$res"
}


# 2.2/ Pipe Utils

pipe_one_line(){
  : 'Pipe Util: The "backslash R" trick: Only print stdout last line updating itself, tested'
  {
    # turn of automatic margins
    # see man terminfo
    [[ -v TERM && -n "$TERM" && ! -v GITHUB_ACTION ]] && tput rmam

    # The or -n line trick is to cnsider EOF is only 1 line
    # -- See: https://stackoverflow.com/a/12919766/2544873
    while read -r line || [ -n "$line" ]; do
      printf "\r\e[K%s" "$line"
    done < "${1:-/dev/stdin}"

    [[ -v TERM && -n "$TERM" && ! -v GITHUB_ACTION ]] && tput smam
  }
  return 0
}

pipe_10(){
  : 'Pipe util: Print first 10 lines of stdin and 1/100 lines and last 10 lines, tested'
  <"${1:-/dev/stdin}" awk '
    { a[NR]=$0 }  # Backup all lines, you never know when it ends
    NR <= i_head { print }  # If in head: print
    NR % i_step == 0 { print }  # If in a step: print
    END {
      if (NR <= i_head) i_head = 0
      else if (NR < 2 * i_head) i_head = NR - i_head
      for (i=NR-i_head+1; i<=NR; i++) print a[i]  # Print the backuped tail
    }
  ' i_head=10 i_step=100
}

# 2.2/ Array utils

filter_array(){
  : 'Filter array in args[1:] with pattern in arg1, ToTest
    From: https://unix.stackexchange.com/a/328714/257838
  '
  local regex=$1
  shift

  for elt; do
    # shellcheck disable=SC2254  # Quote expansions in pattern
    case "$elt" in
      $regex) printf '%s\n' "$elt";;
    esac
  done
}


is_in_array(){
  : 'Check if arg1 <string> is in rest of args, tested
    Ex: is_in_array search-me in those arguments  # Status: 1 as-search me is not in args
    Return: 1 if error
    From: https://stackoverflow.com/a/8574392/2544873
  '
  local element='' match="$1"; shift
  for element; do [[ "$element" == "$match" ]] && return 0; done
  return 1
}

substract_array(){
  : 'Print the elements of array1 except those in array2, tested
    Do not expect ordered output <= using a dictionnary
    Args: element of array 1 -- args of array2
    Ex: substract_array toto titi tata -- titi  # Out: toto<br>tata
    From: https://stackoverflow.com/a/2313279/2544873
  '
  local -i b_is_second=0
  local element=''
  local -A temp1=() temp2=() temp3=()

  # Parse args -> temp1 and temp2
  for element; do
    # Ignore function with no name
    if [[ -z "$element" ]]; then
      :

    # Ignore function starting with `__`
    elif [[ __ == "${element:0:2}" ]]; then
      :

    # Fill second
    elif (( b_is_second )); then
      (( temp2[$element]=1 ))

    # Set gap
    elif [[ -- == "$element" ]]; then
      (( b_is_second=1 ))

    # Fill first
    else
      (( temp1[$element]=1 ))
    fi
  done

  # Create temp3 <- temp1 - temp2
  for element in "${!temp1[@]}"; do
    # Do not append empty keys
    [[ -z "$element" ]] && continue
    if (( temp2[$element] < 1 )); then
      (( temp3[$element]=1 ))
    fi
  done

  # Print out
  (( 0 == ${#temp3[@]} )) && return 0
  printf "%s\n" "${!temp3[@]}"

  return 0
}

escape_array(){
  : 'Unquote special bash symbols, tested
    -- Note: The ${var@Q} expansion quotes the variable such that it can be parsed back by bash. Since bash 4.4: 17 Sep 2016
    -- ALMA RH7 has Bash 4.2: 2011
    -- ALMA RH8 has Bash 4.4.20(1)
    -- Link: https://stackoverflow.com/questions/12985178
    Return: 0  # always and is always silent
  '
  # Clause: no argument no work
  (( 0 == $# )) && return

  local -a a_arg=()
  local arg=''

  for arg; do
    arg=${arg//\'/\'\"\'\"\'}
    a_arg+=("$arg")
  done

  printf " '%s'" "${a_arg[@]}" |
    { read -r -n1; cat -; } |
    sed -e "s/';'/;/g" |
    sed -e "s/'|'/|/g" |
    sed -e "s/'|&'/|\&/g" |
    sed -e "s/'>'/>/g" |
    sed -e "s/'&>'/\&>/g" |
    sed -e "s/'>&'/>\&/g" |
    sed -e "s/'>>'/>>/g" |
    sed -e "s/'2>'/2>/g" |
    sed -e "s/'<'/</g" |
    sed -e "s/'&&'/\&\&/g" |
    sed -e "s/'||'/||/g" |
    sed -e "s/'2>&1'/2>\&1/g" |
    sed -e "s/'<(/<('/g" |
    # Warning, this one is dangerous
    #sed -e "s/)'/')/g" |
    # Avoid find: missing argument to -exec'
    sed -e "s/'\\\;'/\\\;/g" |
    cat
}

# 2.1/ Bash utils

command_not_found_handle(){
  : 'Print stack trace and return error
    Bash calls this function automatically when a command is not found
  '
  perr "Command not found '$*'"
  return 127
}

shell_execute(){
  : 'Helper to debug functions and alias'
  "$@"; return $?
}


# shellcheck disable=SC2142,SC2139,SC2034  # Aliases can't use positional, unused
alias get_all_opt_alias='
  local arg="" last_arg="";
  local -a a_out=();
  for arg; do
    case "$arg" in
      --*)
        last_arg=${arg#--};;
      *)
        if [[ -n "$last_arg" ]]; then
          eval "local $last_arg='"'"'$arg'"'"'";
          last_arg="";
        else
          a_out+=("$1");
        fi;;
    esac;
  done;
  set -- "${a_out[@]}"
'

get_opt(){
  : 'Get named parameter, initial function, tested
    -- Print long argument <arg1:string> options from paramters following arguments
    -- In case of duplication, the last defined option wins
    Ex: get_opt --param arg1 arg2 --param arg3 arg4 --param2 arg5 # Out: arg3 arg4
  '
  local a_out=()
  local s_arg=$1
  local -i b_is_parsing=0

  # Clause: check if s_arg starts with --
  if [[ ! "$s_arg" =~ ^-- ]]; then
    perr 'Function get_opt needs a long argument name as input' \
      'Tip: get_opt --title git_update --tile AlmaSw'
    return "$E_REQ"
  fi

  # Eat the first argument <= already consumed
  shift

  # Loop argument index
  while (( ${#@} )); do
    case "$1" in
      "$s_arg")
        (( b_is_parsing = 1 ))
        shift
        ;;
      --*)
        (( b_is_parsing = 0 ))
        shift
        ;;
      *)
        if (( b_is_parsing == 1 )); then
          a_out+=("$1")
        fi
        shift
    esac
  done

  # Output if something
  (( ${#a_out[@]} )) && echo -n "${a_out[*]}"
}


declare -gA gd_bash_parallel_command=() gd_bash_parallel_stdout=() gd_bash_parallel_status=()
bash_parallel(){
  : 'Run job in parrallel and harvest output and status
    Global <in>  gd_bash_parallel_command: id->command
    Global <out> gd_bash_parallel_stdout: id->stdout
    Global <out> gd_bash_parallel_status: id->status
  '
  local id=''
  local -A d_pid=() d_fd=()
  local -i i_fd=0
  local -i res=0

  # Delete previous answers
  gd_bash_parallel_stdout=() gd_bash_parallel_status=()

  # Fork
  for id in "${!gd_bash_parallel_command[@]}"; do
    # -- From: https://unix.stackexchange.com/questions/128560/how-do-i-capture-the-exit-code-handle-errors-correctly-when-using-process-subs
    exec {i_fd}< <(eval "${gd_bash_parallel_command[$id]}"; echo -n "$?")
    d_pid[$id]=$!
    d_fd[$id]=$i_fd
  done

  # Fork and harvest
  # -- From: https://stackoverflow.com/questions/43230731/how-to-remove-the-last-line-from-a-variable-in-bash-or-sh
  # -- For bash > 4.2  Would just be: wait "${d_pid[$id]}"
  for id in "${!gd_bash_parallel_command[@]}"; do
    local stdout=$(cat <&${d_fd[$id]})  # Wait for stdout
    local last_line=${stdout##*$'\n'}
    stdout=${stdout%"$last_line"}
    # shellcheck disable=SC2034  # Unused
    gd_bash_parallel_stdout[$id]=${stdout%$'\n'}
    # shellcheck disable=SC2034  # Unused
    gd_bash_parallel_status[$id]=$last_line
  done

  # Close
  for id in "${!gd_bash_parallel_command[@]}"; do
    eval "exec ${d_fd[$id]}<&-"
  done

  # Inspect output
  for id in "${!gd_bash_parallel_command[@]}"; do
    if (( ${gd_bash_parallel_status[$id]} )); then
      res=$E_ONE
      break
    fi
  done

  # # Log for dev
  # for id in "${!gd_bash_parallel_command[@]}"; do
  #   >&2 echo "$id => status=${gd_bash_parallel_status[$id]} | stdout=${gd_bash_parallel_stdout[$id]}"
  # done

  return "$res"
}


print_args(){
  : 'Helper for debug (parameters): Print input arguments, one per line, tested'
  local -i i=1; local arg=''
  for arg; do echo "$((i++))/ $arg"; done
}

vcp(){
  : 'Variable CoPy, tested
    -- Can copy integer, string, array or dictionnary
    WARNING: Do not declare destination variable as local before, as it will be global
    -- do not even declare it at all for bash <= 4.2 (RH7)!
    Arg1: Name of existing Source-Variable
    Arg2: Name for the Copy-Target
    Ex: toto=42; vcp toto titi; echo dollar_titi
    From: https://stackoverflow.com/a/52651361/2544873
    TODO test with example in web
  '
  local var=$(declare -p "$1")
  var=${var/declare /declare -g }
  eval "${var/$1=/$2=}"
}

fcp(){
  : 'Function CoPy, tested
    Arg1: (in) source function name
    Arg2: (out) destination function name
    Ex: toto(){ echo 42; }; vcp toto titi; titi
    From: https://stackoverflow.com/a/18839557/2544873
  '
  # Check in
  (( 2 != $# )) && { perr "Fcp function must receive 2 arguments (got $#)" "Tip: fcp toto titi"; return 1; }
  test -n "$(declare -f "$1")" || { perr "Fcp first argument must be a defined funciotn (is $1)" "Tip: fcp toto titi"; return 1; }

  # Expanding last argument which is declare -f $1
  eval "${_/$1/$2}"
}

bash_sleep(){
  : 'Sleep arg1 seconds. Like the sleep command but pure bash
  Arg1: Sleep time <float as string with dot> (ex: 2.3)
  Global: gfd_bash_sleep  # Global file descripor to lock on
  Ex: bash_sleep 0.03
  From: https://github.com/dylanaraps/pure-bash-bible#use-read-as-an-alternative-to-the-sleep-command
  From: https://blog.dhampir.no/content/sleeping-without-a-subprocess-in-bash-and-how-to-sleep-forever
  '
  local f_time=${1:-}

  # Clause: Check arg1 in
  if [[ -z "$f_time" || ! "$f_time" =~ ^[0-9.]+$ ]]; then
    perr "Wrong argument: expecting a float like arg1 and got ($f_time)" \
      "Tip: bash_sleep 2.3"
    return "$E_REQ"
  fi

  # Open a file descriptor to wait on
  if [[ ! -v gfd_bash_sleep || -z "$gfd_bash_sleep" || ! "$gfd_bash_sleep" =~ ^[0-9]+$ ]]; then
    if [[ "$OSTYPE" == linux* ]]; then
      exec {gfd_bash_sleep}<> <(:)
    else
      # The above trick is not suported in windows, maybe nor mac
      local fifo
      fifo=$(mktemp -u)
      mkfifo -m 700 "$fifo"
      exec {gfd_bash_sleep}<>"$fifo"
      rm "$fifo"
    fi
  fi

  # Wait finally
  read -r -t "$f_time" -u "$gfd_bash_sleep"

  return 0
}


###################################
# 1/ Very Lowest level => internal log helpers

pok(){
  : 'Print success message (args) to stderr'
  __phelper "$cgreen" "[S] Succeed: " "$@"
}

pinfo(){
  : 'Print info message (args) to stderr'
  __phelper "$cblue" "[I] Info: " "$@"
}

pwarn(){
  : 'Print info message (args) to stderr'
  __phelper "$cyellow" "[W] Warning: " "$@"
}

perr(){
  : 'Print args, red to stderr plus a stack trace, tested
    Use: pstree command if present
  '

  # Hi: Print error
  __phelper "$cred" "[E] Error: " "$@"

  # Print process Tree
  if command -v pstree &> /dev/null; then
    # From: https://askubuntu.com/a/1012277
    local tree=$(pstree -pal -s $$)
    [[ -n "$tree" ]] && >&2 printf "\n${cred}Process tree:${cend} (parent first)\n%s\n" "$tree"
  fi

  # Print stack
  local stack="$(print_stack 2)"
  [[ -n "$stack" ]] && >&2 printf "\n${cred}Stack trace:${cend} (last call first)\n%s\n" "$stack"

  # Bye: Print error, again
  __phelper
  __phelper "$cred" "[E] Error: " "$@"
}

__phelper(){
  : 'Internal helper: used to print info, warning or error, ToTest
    Standalone
    arg1: Color
    arg2: Prefix
    arg[2:]: Message lines
  '
  # Parse in
  local color=${1:-} prefix=${2:-} color_end=''
  local -a a_line=("${@:3}")

  # Append prefix to first line
  a_line[0]="$prefix${a_line[0]:-}"

  # Add end color
  [[ -n "$color" ]] && color_end=$cend

  # Say it!
  local oifs="$IFS"; IFS='';
  >&2 printf "${color}%b$color_end\n" "${a_line[@]}"
  IFS="$oifs"
}

bash_timeout(){
  : "Run a command with a timeout, async, tested
    -- Like timeout command but suports functions
    Standalone
    Warning do not put single-quote for easier test
    Side-effect, the function is run in subshell
    From: https://stackoverflow.com/a/24416732/2544873
    Arg1: Time to wait <int>
    Return: 137=128 + SIGKILL if timedout, command run status otherwise
    Ex: toto(){ return 42; }; bash_timeout 1 toto; echo \$?  # Out 42
  "
  local timeout=$1 cmd=${*:2}
  local -i res=0

  # Clause: timeout must be fractional
  if [[ ! "$timeout" =~ [0-9]+\.?[0-9]*$ ]]; then
    echo "Error: bash_timeout function requires a float-like first argument"
    return "$E_REQ"
  fi

  (
    eval "$cmd" &
    child=$!
    trap -- "" SIGKILL
    (
      sleep "$timeout"
      # Kill -9 in case child is waiting
      # Redirect to null to avoid: environment: line 23: kill: (219814) - No such process
      kill -s SIGKILL "$child" 2> /dev/null
    ) &
    wait "$child"
  )
  res=$?

  (( res == 124 )) && (( res = 137 ))
  return "$res"
}


equal(){
  : 'Check 2 first parameters for string equality and report, tested
    -- if no argument is given, it will return 0
    Depends on: print_stack

    Global:
      g_dispatch_i_res <out> also set for easier follow up
      g_junit_file <in /opt> the path of the file to write report line
      g_junit_function <in /opt> name of the function tested
      g_junit_suite <in /opt> name of the suite tested TO Implement
      gi_junit_n <in /opt> Number of test

    Arguments:
      1 => reference <string> expected
      2 => obtained <string> to test against the expected
      3 => brief commentary <string, optional>
      --desc  => long description
      --tip   => tip to fix if test fails
      --not   => reverse the condition (no argument)
      --quiet => only print if fails (no argument)

    Return: 0 if OK.
  '
  local -i res=0
  # Take less than 0.1ms, date takes 5ms
  # -- -1, to explicit to  bash4.2  that the current date is expected
  local timestamp; printf -v timestamp '%(%Y-%m-%dT%H:%M:%S)T' -1
  local -a a_positional=()
  if [[ -v ART_VERBOSE ]] && (( ART_VERBOSE > 0 )); then
    local -i b_is_verbose=$ART_VERBOSE
  else
    local -i b_is_verbose=0
  fi

  # Parse argument in
  # -- Parse optional parameters
  local -a a_desc=()  # Long descriptions, array with multiple possible entries, one per line in stdout
  local -a a_tip=()  # Long tips if fails
  local -i b_not=0  # Not boolean if condition reversed
  local -i b_quiet=0  # DO not print in case os success
  local -i i_depth=1  # Depth of the asssert call, inited ot 1 supposing the worker directly calls assert
  while (( 0 != $# )); do
    case $1 in
      --desc)
        a_desc+=("$2")
        shift; shift;;
      --tip)
        a_tip+=("$2")
        shift; shift;;
      --depth)
        i_depth=$2
        shift; shift;;
      --not)
        b_not=1
        shift;;
      --quiet)
        b_quiet=1
        shift;;
      *)
        a_positional+=("$1");
        shift;;
    esac;
  done;

  # -- Parse positional parameters
  local expected=${a_positional[0]:-}
  local got=${a_positional[1]:-}
  local brief=${a_positional[2]:-""}  # The

  # Instrospect URL of caller
  # -- Should look like
  # -- https://github.com/tinmarino/lib_dispatch/blob/8e3da35/dispatch#L8

  # -- 1/ Declare prefix
  local url='https://github.com/tinmarino/lib_dispatch/blob/'
  # -- 2/ Get commit id (once)
  if [[ ! -v DISPATCH_SELF_COMMIT || -z "$DISPATCH_SELF_COMMIT" ]]; then
    export DISPATCH_SELF_COMMIT=master
    if [[ -v gs_root_path && -d "$gs_root_path" ]] \
        && is_command git \
        && local commit_id=$(git -C "$gs_root_path" rev-parse HEAD) \
        && [[ -n "$commit_id" ]]; then
      DISPATCH_SELF_COMMIT=${commit_id::12}
    fi
  fi
  # -- 3/ Get Line and file
  local line_nr="${BASH_LINENO[$i_depth-1]}"
  local file="${BASH_SOURCE[$i_depth]:-terminal}"
  file=${file##"$gs_root_path"/}
  # -- 4/ Craft
  url+="${DISPATCH_SELF_COMMIT}/${file}#L${line_nr}"

  # Craft default line content
  [[ -z "$brief" ]] && brief="from $(print_stack 2 2 | tr '\n' ' ')"
  if ((b_is_verbose)); then
    local brief_start="$cbold$cunderline"
    local brief_end=$cend
  else
    local brief_start=''
    local brief_end=''
  fi
  brief="$brief_start$brief$brief_end"

  # Set succeed variable
  [[ "$expected" == "$got" ]]
  # If b_not is set, this flip the condition, prefix by not as we want 1 for true and not 0
  local b_succeed=$(( ! b_not ^ $? ))

  # Discriminate echo green Vs Red
  if ((b_succeed)); then
    # Clause: leave here if quiet
    ((b_quiet)) && return 0
    if ((b_not)); then local expect_prefix="expected not ${cgreen}'$expected'$cend and "; else local expect_prefix=''; fi
    local stdout_line="${cgreen}[+] Success:$cend $brief (${expect_prefix}got: $cgreen'$got'$cend) [$timestamp]"
    res=0
  else
    local expect_prefix="expected: $( ((b_not)) && echo "not " )${cred}'$expected'$cend and "
    local stdout_line="${cred}[-] Error  :$cend $brief (${expect_prefix}got: ${cred}'$got'$cend) [$timestamp]"
    res=1
  fi

  # Remove newlines
  stdout_line="${stdout_line//$'\n'/;}\n"

  # Potencial verbose additional lines
  if [[ -v ART_VERBOSE ]] && (( ART_VERBOSE > 0 )); then
    # Add description
    local desc
    for desc in "${a_desc[@]+"${a_desc[@]}"}"; do
      stdout_line+="  $cblue-- Desc:$cend $desc\n"
    done

    # Add tip
    local tip
    for tip in "${a_tip[@]+"${a_tip[@]}"}"; do
      stdout_line+="  $cyellow-- Tip:$cend $tip\n"
    done

    # Add url
    stdout_line+="  -- Url: $url\n"
  fi

  # Finally print to stderr
  >&2 echo -en "$stdout_line\n"
  
  # And save it to print in the end
  if (( ! b_succeed )); then
    stdout_line+="  -- Namespace: $ART_NAMESPACE\n"
    # TODO reduced stack => add argument
    #stdout_line+="$(print_stack 2 2 | sed -e 's/^/  -- Stack:/')\n"
    stdout_line+="\n\n"
    
    DISPATCH_EQUAL_ERR+="$stdout_line"
    # TODO remove the 42 hardcode
    trap "echo -e \"\$DISPATCH_EQUAL_ERR\" >&42" EXIT
  fi
  

  # Write junit line if requested
  if [[ -v g_junit_file && -w "$g_junit_file" ]]; then
    : "${g_junit_function:=Unknown}"
    : "${gi_junit_n:=1}"
    local msg_status=$( ((0 == res)) && echo "Success" || echo "Error  ")
    # Craft message
    local xml_msg=$(echo "$msg_status: $brief (expected: '$expected' and got: '$got')" | remove_ansi_code)

    local elt=""
    elt+="    <testcase name=\"$ART_NAMESPACE: $g_junit_function $((gi_junit_n++))\">"$'\n'
    elt+="    <timestamp>$timestamp</timestamp>"$'\n'
    elt+="    <system-out><![CDATA[$xml_msg]]></system-out>"$'\n'
    elt+="    <system-err><![CDATA[Desc:${a_desc[*]}, Tip:${a_tip[*]}]]></system-err>"$'\n'

    if (( res )); then
      elt+="    <error message=\"Test $g_junit_function $gi_junit_n failed\">Failed test $g_junit_function $gi_junit_n"$'\n'
      # shellcheck disable=SC2030  # Modification of g_dispatch_b_complete
      elt+="    Stacktrace: $(reset_color; g_dispatch_b_complete=1; print_stack | remove_ansi_code)"$'\n'
      elt+="    </error>"$'\n'
    fi
    elt+="    </testcase>"; elt+=$'\n'

    echo "$elt" >> "$g_junit_file"
  fi

  # Update global out
  ((g_dispatch_i_res|=res))

  return "$res"
}

remove_ansi_code(){
  : 'Remove ansi escape code from stdin, ToTest
    Used by equal for test report to avoid: parser error : PCDATA invalid Char value 27
  '
  sed -e "
    s/\x1B\[[0-9;]*[a-zA-Z]//g
    s/\x1B//g
  "
}


print_stack(){
  : 'Print current stack trace, tested
    Depends on: join_by, abat
    From: https://stackoverflow.com/a/2990533/254487
  '
  local -i i_init=${1:-0}  # Frame number where I'll start
  local -i i_end=${2:-10}  # Frame number where I'll stop
  local -i i_indent=-4  # Indentation size
  local -i i_lnum=5  # Number of lines for the first frame
  local -i b_first_loop=1  # Are we in first loop
  local -i j=0 k=0 i_frame=0

  # Warn can see more
  shopt -q extdebug || echo "# Note: run 'shopt -s extdebug' to see call arguments"
  # For each frame
  for i_frame in "${!FUNCNAME[@]}"; do
    # Clause fo not work after stack size
    [[ ! -v BASH_LINENO ]] && break
    (( i_frame > ${#BASH_LINENO[@]} )) && break
    (( i_frame > ${#FUNCNAME[@]} )) && break
    (( i_frame > i_end )) && break

    ((i_indent+=2))

    # Get lines number of code to print
    local line_nr="${BASH_LINENO[$i_frame-1]}"
    if (( i_frame >= i_init )) && (( b_first_loop )); then
      # Take the lnum lines above for the first call in stack
      line_nr="$(( ret = line_nr - i_lnum, ret > 1 ? ret : 1 )),$line_nr"
      b_first_loop=0
    fi

    # Inspect
    local pad="$(printf "%${i_indent}s" "")"
    local fct="${FUNCNAME[$i_frame]:-main}"
    local file="${BASH_SOURCE[$i_frame]:-terminal}"
    local line=""
    ((line_nr != 0)) && {
      line="$({ [[ -r "$file" ]] && cat "$file" || echo "# No line info"; } \
      | sed -nE "${line_nr}s/^ */$pad/gp")"
    }

    # Inspect argument
    local -a a_argv=()
    if shopt -q extdebug; then
      local argc=${BASH_ARGC[i_frame]}
      for ((j=0; j<argc; j++)); do
        (( k >= ${#BASH_ARGV[@]} )) && break
        a_argv[$((argc-j))]=${BASH_ARGV[$((k++))]}
      done
    fi
    local argv=$(join_by ', ' "${a_argv[@]}")

    if (( i_frame >= i_init )); then
      # Craft message
      local msg="in "
      msg+="${cblue}Function:$cend $fct($argv), "
      msg+="${cblue}File:$cend $file, "
      msg+="${cblue}Line:$cend $line_nr\n"
      #msg+="${cblue}Frame:$cend $i_frame\n"

      # Print
      printf "%s" "$(abat "" "$line")"
      printf "%${i_indent}s" ""
      printf "        %b\n" "$msg"
    fi
  done
}

join_by(){
  : 'Join array string elements (args[2:]) with (by) a delimiter (arg1)
    Standalone
    From: https://stackoverflow.com/a/17841619/2544873
    Ex: join_by , a b c => a,b,c
  '
  local d=${1-} f=${2-}
  if shift 2; then
    printf %s "$f" "${@/#/$d}"
  fi
}


abat(){
  : 'Filter to color code from stdin in language (arg1), tested
    Standalone but better install bat and perl commands or define colors variable
    Ex: echo true bash code | bash
  '
  local lang=${1:-bash}
  if (( $# >=2 )); then
    local msg=$2
  else
    # Clause: there must be a stdin attached (not from terminal) or I will freeze
    if [[ -t 0 ]]; then
      >&2 echo -e "${cred}Error: Function abat need to be run in a pipe\n" \
        "Tip: echo \"sed 's/1/42/g'\" | abat$cend"
      return 1
    fi
    local msg=$(</dev/stdin)
  fi

  # Declare all null in case set -u is used
  : "${cyellow:=}"; : "${cred:=}"; : "${cend:=}";

  # If command bat do not exist, just print in yellow
  if ! command -v bat &> /dev/null || ! command -v perl &> /dev/null; then
    echo -en "$cyellow$msg$cend"
    return 0
  fi

  # It can be alias or function. In my case bat is aliased to: PAGER= bat'
  bat --style plain --color always --pager "" --theme zenburn --language "$lang" <(echo "$msg") | perl -p -e 'chomp if eof'
}

log(){
  : 'Helper for debug (completion): Log to /tmp/irm_jenkins_log.log'
  echo "$@" >> /tmp/irm_jenkins_log.log
}

is_sourced(){
  : 'Returns 0 if script is sourced and not executed, ToTest'
  [[ -v BASH_SOURCE ]] && (( ${#BASH_SOURCE[@]} > 0 )) && [[ "${BASH_SOURCE[0]}" == "$0" ]]
  return $(( ! $? ))
}


get_os(){
  : '
  From: https://stackoverflow.com/questions/394230/how-to-detect-the-os-from-a-bash-script
  '
  case "$OSTYPE" in
    solaris*) echo solaris ;;
    darwin*)  echo osx ;; 
    linux*)   echo linux ;;
    bsd*)     echo bsd ;;
    msys*)    echo windows ;;
    cygwin*)  echo windows ;;
    *)        echo unknown ;;
  esac
}


# 0/ move me out of here
check_requirement(){
  : 'Utility to check if requirements are present on the machine
    Call: before runnning a command
    Side Effect: may exit
    :param: alma_sw -> ALMA Software present in \$ALMA_SW directory
    :param: alma_branch -> ALMA Software is in \$BRANCH branch (called with alma_sw)
    :param: alma_root -> ALMA Software compiled in /alma
    :param: docker -> Docker is installed on the machine
    :param: variable:VAR1:var2 -> \$VAR1 and \$var2 variables exist and is not void
    :param: command:python:docker -> python and docker commands exist
  '
  # TODO create an helper function to safely retrieve variable with readarray
  local -i res=0
  local arg s_varname s_in_name
  local -a a_variable_name=()

  # Check each argument
  for arg in "$@"; do
    case "$arg" in
      alma_sw)
        # Alma Software
        # -- Read input: argument or environment
        s_varname=ALMA_SW
        arg="$(echo "$*" | grep -o "alma_sw:[^[:space:]]*")"
        # -- Parse input
        if [[ -n "$arg" ]]; then
          IFS=':' read -r -a a_variable_name <<< "$arg"
          if (( ${#a_variable_name[@]} >=1 )); then
          for s_in_name in "${a_variable_name[@]:1}"; do
            [[ -z "${s_in_name}" ]] && continue
            s_varname=$s_in_name
          done
          fi
        fi
        local alma_sw="${!s_varname}"
        # -- Check: Is environment variable present
        if [[ -z "$alma_sw" ]]; then
          perr "Requirement: \$ALMA_SW must be set to Alma Sotware directory (s_varname=$s_varname)" \
               "Tip: export ALMA_SW=~/AlmaSw"
          res=1
        fi
        # -- Check: Is directory present?
        if [[ ! -d "$alma_sw" ]]; then
          perr "Requirement: ALMA_SW='$alma_sw' directory not found (PWD=$PWD)" \
               "Tip: export WORKSPACE=~jenkins/workspace/2021_04_APR/COMMON-2021APR-B"
          res=1
        fi
        # -- Check: Is ACS in directory?
        if [[ ! -f "$alma_sw/ACS/LGPL/acsBUILD/config/.acs/.bash_profile.acs" ]]; then
          perr "Requirement: AlmaSw directory seems to not contain Alma Software (in $alma_sw)" \
               "Tip: irm sync almasw  # API may change"
          res=1
        fi
        # -- Check: Is SUBSYSTEM in directory
        # -- -- Fill directory name
        local a_diretory=()
        local s_dir
        for s_dir in "$alma_sw"/*/; do
          a_diretory+=("$(basename "$s_dir")")
        done
        # -- -- Check each SUBSYSTEM dir is here
        local s_subsystem
        # shellcheck disable=SC2206  # Quote to prevent
        local a_subsystem=($SUBSYSTEMS)
        # TODO not in bash 4.2
        #readarray -d " " -t a_subsystem <<< "$SUBSYSTEMS"
        for s_subsystem in $SUBSYSTEMS; do
          if ! is_in_array "$s_subsystem" "${a_subsystem[@]}"; then
            perr "Requirement: AlmaSw directory do not contain subsystem directory" \
              "Description: $s_subsystem not in $alma_sw which contains: (${a_diretory[*]})" \
              "Tip: Check that $alma_sw is well cloned"
            res=1
          fi
        done
        ;;

      # Alma branch
      alma_branch)
        # Is environment variable present
        if [[ -z "$BRANCH" ]]; then
          pwarn "LibAlma: better specify \$BRANCH environment variable for AlmaSw"
        else
          pushd "$ALMA_SW" > /dev/null || res=1
          branch_present=$(git rev-parse --abbrev-ref HEAD)
          if [[ ! "$BRANCH" == "$branch_present" ]]; then
            perr "Requirement: AlmaSw on branch $branch_present and wanted branch $BRANCH"
            res=1
          fi
          popd > /dev/null || res=1
        fi
        ;;

    # Alma Root
    alma_root)
      local filepath="/alma/ACS-current/ACSSW/config/.acs/.bash_profile.acs"
      if [[ ! -f "$filepath" ]]; then
        perr "Requirement: AlmaSw not compiled in /alma <= $filepath not present"
        res=1
      fi
      ;;

    # Command
    command:*)
      arg="$(echo "$*" | grep -o "command:[^[:space:]]*")"
      [[ -z "$arg" ]] && continue
      IFS=':' read -r -a a_variable_name <<< "$arg"
          if (( ${#a_variable_name[@]} >=1 )); then
      for cmd in "${a_variable_name[@]:1}"; do
        if ! command -v "$cmd" > /dev/null; then
          perr "Requirement $cmd command not found, I will not install it for you" \
               "Tip: yum install $cmd  # or pip"
          res=$E_REQ
        fi
      done
          fi
      ;;

    # Variable
    variable:*)
      arg="$(echo "$*" | grep -o "variable:[^[:space:]]*")"
      [[ -z "$arg" ]] && continue
      IFS=':' read -r -a a_variable_name <<< "$arg"
          if (( ${#a_variable_name[@]} >=1 )); then
      for s_varname in "${a_variable_name[@]:1}"; do
        if [[ ! -v "$s_varname" ]] || [[ -z "${!s_varname}" ]]; then
          perr "Requirement variable '$s_varname' must be set" \
               "Tip: if UPPER_CASE: Set the environment variable before calling" \
               "Tip: if lower_case: Set the sae with upper case or read doc for arguments"
          res=1
        fi
      done
          fi
      ;;

    # Release
    release*)
      # -- Read input: argument or environment
      local arg="$(echo "$*" | grep -o "release:[^[:space:]]*")"
      IFS=':' read -r -a a_variable_name <<< "$arg"
      # -- Parse input (safely)
      s_varname=RELEASE
          if (( ${#a_variable_name[@]} >=1 )); then
      for s_in_name in "${a_variable_name[@]:1}"; do
        [[ -z "${s_in_name}" ]] && continue
        s_varname=$s_in_name
      done
          fi
      local release="${!s_varname}"

      # Check match regex
      if [[ ! "$release" =~ ^[0-9]{4}[A-Z]{3}$ ]] && [[ ! "$release" =~ CYCLE* ]]; then
        perr "Incorrect \$RELEASE value: '$release'" \
             "Tip: export RELEASE=2021NOV"
             "Tip: export RELEASE=CYCLE8"
        res=1
      fi
      ;;

    acs_version*)
      # -- Read input: argument or environment
      local arg="$(echo "$*" | grep -o "acs_version:[^[:space:]]*")"
      IFS=':' read -r -a a_variable_name <<< "$arg"
      # -- Parse input (safely)
      s_varname=ACS_VERSION
          if (( ${#a_variable_name[@]} >=1 )); then
      for s_in_name in "${a_variable_name[@]:1}"; do
        [[ -z "${s_in_name}" ]] && continue
        s_varname=$s_in_name
      done
          fi
      local acs_version="${!s_varname}"

      # Check match regex
      if [[ ! "${acs_version}" =~ ^ACS-[0-9]{4}(FEB|APR|JUN|AUG|OCT|DEC)$ ]]; then
        perr "Incorrect \$ACS_VERSION value: '$acs_version'" \
             "Tip: export ACS_VERSION=2021OCT"
        res=1
      fi
      ;;
    esac
  done

  # Time to leave
  if (( res != 0 )); then
    perr "Missing requirement $*" \
         "See previous error log above"
    return "$E_REQ"
  fi
  return 0
}


expand_user_at_host(){
  : 'Expand USER@HOST from command line
    Called by --at, tested
    Arg1: reduced user@host, ex: acse2, 707, almamgr@acse2
  '
  local at=$1
  local host=${at#*@}
  local user="" userat=""

  # Split string
  if [[ "$at" =~ .*@.* ]]; then
    user="${at%%@*}"
  fi

  # Set option: case insensitive
  s_cmd_shopt_save=$(shopt -p nocasematch)
  shopt -s nocasematch

  # Expand host
  case "$host" in
    acse?)
      host="${host}-gns.sco.alma.cl"
      : "${user:=almaop@}"
      ;;
    ape?)
      host="${host}-gns.osf.alma.cl"
      : "${user:=almaop@}"
      ;;
    hil)
      host="ape-hil-gns.osf.alma.cl"
      : "${user:=almaop@}"
      ;;
    7[0-9][0-9])
      host="v-bfnode${host}.sco.alma.cl"
      : "${user:=jenkins@}"
      ;;
    v-bfnode???)
      host="${host}.sco.alma.cl"
      : "${user:=jenkins@}"
      ;;
    farm|buildfarm)
      host='buildfarm.sco.alma.cl'
      : "${user:=jenkins@}"
      ;;
  esac

  # Expand user
  case "$user" in
    op)
      user=almaop
      ;;
    mgr)
      user=almamgr
      ;;
    proc)
      user=almaproc
      ;;
  esac

  # Reset option: case insensitive
  $s_cmd_shopt_save

  # Fill userat <= user . "@"
  [[ -n "$user" ]] && userat="${user%%@*}@"

  # Print out
  echo "$userat$host"
}


hi(){
  : '2/ 👋 Print: System information
  -- And some jusdicious environment variables
  -- Can be used as jenkins debug command, or for stamping logs
  '
  local -i i_indent="${3:-0}"
  local s_indent="$(printf "%${i_indent}s" "")"
  local tip=''
  print_title "System Information" "" "$i_indent"

  # Retrieve resource usage
  # From: https://askubuntu.com/questions/941949/one-liner-to-show-cpu-ram-and-hdd-usage
  local usage=''
  if command -v top > /dev/null; then
    usage+="CPU $(LC_ALL=C top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')%"
  else
    usage+="CPU ??"
    tip+="- Install top command for CPU usage\n"
  fi
  if command -v free > /dev/null; then
    usage+=" RAM $(free -m | awk '/Mem:/ { printf("%3.1f%%", $3/$2*100) }')"
  else
    usage+="  RAM ??"
    tip+="- Install free command for RAM usage\n"
  fi
  if command -v df > /dev/null; then
    usage+=" HDD $(df -h / | awk '/\// {print $(NF-1)}')"
  else
    usage+=" HDD ??"
    tip+="- Install df command for HDD usage\n"
  fi

  # From: https://askubuntu.com/questions/988440/how-do-i-get-the-model-name-of-my-processor
  local cpu_msg=''
  if command -v lscpu > /dev/null; then
    local cpu_model=$(lscpu | grep "Model name:" | sed -r 's/Model name:\s{1,}//g')
    local cpu_core=$(lscpu | sed -nr '/^CPU\(s\)/ s/.*:\s*(.*)/\1/p')
    local cpu_freq=$(lscpu | sed -nr '/^CPU max MHz/ s/.*:\s*(.*),.*/\1/p')
    local cpu_arch=$(lscpu | sed -nr '/^Architecture/ s/.*:\s*(.*)/\1/p')
    cpu_msg="$cpu_arch with $cpu_core cores at $cpu_freq [$cpu_model]"
  else
    cpu_msg="??"
    tip+="- Install lscpu command for CPU info\n"
  fi

  # Craft full message
  local msg="  ${s_indent}${cblue}Host ---- :$cend $USER@$HOSTNAME
  ${s_indent}${cblue}Kernel -- :$cend $(uname -a)
  ${s_indent}${cblue}OS Name - :$cend $(get_os_name)
  ${s_indent}${cblue}Capability:$cend color:$(can_color && echo yes || echo no)
  ${s_indent}${cblue}Date ---- :$cend $(date "+%Y-%m-%dT%H:%M:%S")
  ${s_indent}${cblue}Cpu ----- :$cend $cpu_msg
  ${s_indent}${cblue}Usage --- :$cend $usage
  ${s_indent}${cblue}Process --- :$cend $$
  "
  echo -e "$msg" | sed -e 's/^[[:space:]]\{2\}//'

  # TDDO reate specific hi for ART
  a_env=(
    "---  Github  ---"
    "---  Machine  ---"
    OSTYPE
    "---  Run  ---"
  )
  local v_env=''
  for v_env in "${a_env[@]}"; do
    # Separator
    if [[ "$v_env" =~ - ]]; then
      echo -e "${s_indent}${cpurple}$v_env$cend"

    # Not defined
    elif [[ ! -v "$v_env" ]]; then
      echo -e "${s_indent}${cblue}$v_env=$cend"

    # Key value
    else
      local value="${!v_env}"
      [[ "$v_env" == RELEASE ]] \
        && value="${cpurple}$value$cend"
      echo -e "${s_indent}${cblue}$v_env=$cend\"$value\""
    fi
  done;

  # Tip
  if [[ -n "$tip" ]]; then
    echo -e "\n${cpurple}TIP$cend"
    echo -e "---$cend"
    echo -e "$tip"
  fi

  echo
  return 0
}


_shell(){
  : '💻 Enter: the IRM shell
    -- To get variable and functions as scripts have
    -- Run shell with __rc local function content
  '
  # The old monk trick
  # Avoid: bash: ./lib_alma.sh: No such file or directory
  export source_lib_alma
  # -- Avoid: bash: _parse_usage: line 16: ` -?(\[)+([a-zA-Z0-9?]))'
  # --------- bash: error importing function definition for `_parse_usage'
  unset _parse_usage

  # Export all function
  # shellcheck disable=SC2046  # Quote this to prevent word splitting.
  declare -fx $(compgen -A function)

  bash --noprofile --init-file <(
    declare -f __rc | sed -n -e '$d; 3,$p'
  ) -i
  return $?
}


__rc(){
  : 'Bashrc for the IRM shell'
  # Source lib_alma
  # shellcheck disable=SC1091  # Not following
  [[ ! -v gi_source_lib_alma ]] && source "$gs_root_path/script/lib_alma.sh"
  magic

  # Set completion
  complete -C irm irm

  # PS1
  parse_git_branch() {
    git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/(\1)/' 2> /dev/null;
  }
  export -f parse_git_branch
  # (Green) Host: Cwd (git branch)
  PS1='\[\e[32m\]\h: \w '
  # Git Branch (yellow)
  PS1+='\[\e[33m\]`parse_git_branch`'
  # End color
  PS1+='\[\e[0m\]'
  # New line
  PS1+='\n$ '

  # Prepend sitename
  [[ "$PS1" == "\\s-\\v\\\$ " ]] && PS1="[\u@\h \W]\\$ "
  if [[ -e /alma/ste/etc/sitename ]]; then
      sitename="$(cat /alma/ste/etc/sitename)"
      case "$sitename" in
          AP*)  prefix="\[\033[31m\]" ;;  # Red if APE
          *)    prefix="\[\033[32m\]" ;;  # Green otherwise
      esac
      prefix+="${sitename}:\[\033[0m\] "
      PS1="${prefix}${PS1#"$prefix"}"
      unset prefix
  fi
  export PS1

  # Trap exit
  __at_exit(){
    echo "Bye from IRM SHELL"
  }
  trap __at_exit EXIT

  # Hi
  cat << 'EOF'
    WELCOME TO THE GREAT
        ,-.
       / \  `.  __..-,O
      :   \ --''_..-'.'
      |    . .-' `. '.
      :     .     .`.'
       \     `.  /  ..
        \      `.   ' .
         `,       `.   \
        ,|,`.        `-.\
       '.||  ``-...__..-`
        |  |
        |__|
        /||\
       //||\\
      // || \\
   __//__||__\\__
  '--------------' SSt
EOF
  print_unindent "${cgreen}IRM SHELL$cend
    Use: copy paste commands from irm_jenkins

    Example:
    echo \$RELEASE
    irm alma hi
    run tar -czf dashboard-frontend-angular.tgz -C angularapp .
    compgen -A function
  "

  # Prepend irm file path to PATH to ensure executing this one
  # shellcheck disable=SC2031  # PATH was modified in a subshell.
  export PATH="$(dirname "$(dirname "$lib_alma")"):$PATH"

  unset lib_alma
}


#########
# 6/ Exported as subcommand

# If sourced: Declare functions to hide (after) the potencial call
if is_sourced; then
  readarray -t g_dispatch_a_fct_to_hide < <(declare -F -p | cut -d " " -f 3)
fi

mm_doc_api(){
  : '❓Helper to create recursive doc
  From: for the jenkins xml: https://bitbucket.sco.alma.cl/projects/ALMA/repos/adc-sw/browse/GIT/scripts/integrator/integrator.py (tk @camilo.saldias)
  '
  format=${1:-stdout}  # xml, stdout (maybe text in futur)

  local a_subcmd line_cmd line_fct

  # Check current script
  if [[ ! -e "$0" ]]; then
    perr "Cannot execute file $0 for retrieving the api doc"
    return "$E_REQ"
  fi

  local cmd=$0
  local cmd_name=${cmd##*/}

  # Fill a_subcmd
  readarray -t a_subcmd < <(
    "$cmd" --complete "$cmd_name" | grep -v '^-'
  )

  # If Xml: Print hi: main head
  if [[ xml == "$format" ]]; then
    # Redirect stdout
    touch "$cmd_name"_doc_api.xml
    exec 1> "$cmd_name"_doc_api.xml
    echo -e '
      <section name="dispatch online buildfarm API" fontcolor="">

      <table sorttable="yes">
      <tr>
      <td value="Sub Command" bgcolor="white" fontcolor="black" fontattribute="bold" align="left" width="200"/>
      <td value="Tail Function" bgcolor="white" fontcolor="black" fontattribute="bold" align="left" width="200"/>
      <td value="Description" bgcolor="white" fontcolor="black" fontattribute="bold" align="left" width="200"/>
      </tr>
    '
  fi

  # For all subcommand
  for line_cmd in "${a_subcmd[@]}"; do
    local subcmd="${line_cmd%% *}"
    local subcomment="${line_cmd#*:}"
    subcomment=$(echo -e "$subcomment" \
      | sed 's/\x1b[^m]*m *//g' \
      | sed 's/&/\&amp;/g' \
      | sed 's/</\&lt;/g' \
      | sed 's/>/\&gt;/g' \
      | sed 's/"/\&quot;/g' \
      | sed "s/'/\&#39;/g"
    )

    # Print hi: current subcommand head
    if [[ stdout == "$format" ]]; then
      echo "# $line_cmd"
    else
      echo -e '
        <tr></tr>
        <tr>
          <td value="'"${subcmd^^}"'" bgcolor="LightGrey" fontcolor="black" fontattribute="bold" align="left" width="200"/>
          <td value="" bgcolor="LightGrey" fontcolor="black" fontattribute="bold" align="left" width="200"/>
          <td value="'"$subcomment"'" bgcolor="LightGrey" fontcolor="black" fontattribute="bold" align="left" width="200"/>
        </tr>
      '
    fi

    # Get tail workers (aka subsub)
    readarray -t a_subsub < <(
      "$cmd" --complete "$subcmd" | grep -v '^-'
    )

    # Print current function
    for line_fct in "${a_subsub[@]}"; do
      local function=${line_fct%% :*}
      local comment=${line_fct#*: }
      # Delete escape colors
      # shellcheck disable=SC2001  # See if you can use ${variable//search/replace}
      comment=$(echo -e "$comment" \
        | sed 's/\x1b[^m]*m *//g' \
        | sed 's/&/\&amp;/g' \
        | sed 's/</\&lt;/g' \
        | sed 's/>/\&gt;/g' \
        | sed 's/"/\&quot;/g' \
        | sed "s/'/\&#39;/g"
      )
      if [[ stdout == "$format" ]]; then
        echo "$cmd $subcmd $function  # $comment"
      else
        echo -e '
          <tr></tr>
          <tr>
            <td value="'"$subcmd"'" bgcolor="white" fontcolor="black" fontattribute="normal" align="left" width="200"/>
            <td value="'"$function"'" bgcolor="white" fontcolor="black" fontattribute="normal" align="left" width="200"/>
            <td value="'"$comment"'" bgcolor="white" fontcolor="black" fontattribute="normal" align="left" width="200"/>
          </tr>
        '
      fi
    done

    # Print Bye
    echo
  done

  # Print Bye: close main head
  if [[ xml == "$format" ]]; then
	  echo -e '
      </table>
	    </section>
    '
    # Close stdout redirection
    exec 1>&-
  fi

  # It consumes an argument
  return 1
}


mm_at(){
  : '🎯 Set computer which will run the subcommand (ex: acse2), tested
    Arg1: host
    Arg2: subcmd
    Arg[3:]: rest of the command
    Ex: dispatch --at acse2 alma hi
    Use internals of lib_dispatch (g_dispatch_d_cmd)
  '

  # Clause must not work and consume 1 argument if completing
  # shellcheck disable=SC2031  # false positive as I modify it in a subshell
  ((g_dispatch_b_complete)) && return 1

  # Parse In
  local at=$1
  local subcmd=$2
  shift; shift

  local -i ret=0

  # Check In
  check_requirement variable:at command:ping:scp:ssh || return "$E_REQ"

  local userathost=$(expand_user_at_host "$at")

  # Clause: Remote host must reachable
  local host=${userathost#*@}
  if ! ping -c1 -W1 "$host" &> /dev/null; then
    perr "Cannot contact server '$host' with ping" \
      "Tip: Give me a --at option which I can read" \
      "Tip: Connect to the VPN (vpn.alma.cl)"
    exit "$E_ARG"  # In --at
  fi

  # Clause: next argument must be present
  # -- Otherwise, log help locally
  if [[ -z "$subcmd" ]] \
      || { is_in_array "$subcmd" --help --doc --complete && (( 0 == $# )); }; then
    dispatch "$@"
    exit 0  # In --at
  fi

  # If present, it must exists
  if ! is_in_array "$subcmd" "${!g_dispatch_d_cmd[@]}"; then
    perr "Subcommand '$subcmd' does not exist" \
         "Tip: replace it with 'example' like: dispatch --at localhost example succeed"
    exit "$E_ARG"  # In --at
  fi

  # Get associated file
  local subcmd_file="${g_dispatch_d_cmd["$subcmd"]}"

  # Clause: CHeck file is readable (should be)
  if [[ ! -r "$subcmd_file" ]]; then
    perr "Internal: dispatch --at: local file '$subcmd_file' do not readable" \
      "Tip: Give me a subcommand I know, other than '$subcmd'"
    exit "$E_ARG"  # In --at
  fi

  # Declare socket path template string
  local ssh_socket_template="/tmp/ssh-socket-%r@%h-%p"

  control_master(){
    : 'Helper for ssh reuse
      Fix: /usr/bin/ssh: Argument list too long
      From: ssh -tt "userathost" "s_bash_script"  # Used before
      Because: getconf ARG_MAX 2097152
      LogLevel Quiet to Avoid the message: Connection to localhost closed
    '
    "$1" \
      -o LogLevel=QUIET \
      -o AddressFamily=inet \
      -o ControlMaster=auto \
      -o ControlPersist=10h \
      -o ControlPath="$ssh_socket_template" \
      "${@:2}"
  }

  # Create temporary file, locally as faster
  local tmp_file=$(mktemp /tmp/dispatch-ssh-XXXXXXXX.sh)

  # Create code to send
  cp <(
    # Source libraries (in current shell)
    echo "export IRM_JENKINS_SSH_SUBCOMMAND='$subcmd'"
    echo "export g_dispatch_project_name='$g_dispatch_project_name'"
    cat "$gs_root_path/script/lib_dispatch.sh" \
        "$gs_root_path/script/lib_dispatch.sh"

    # Source subfile
    cat "$subcmd_file"
  ) "$tmp_file"

  # Get its hash
  local hash=$(md5sum "$tmp_file")

  # Copy to remote host (sync if first time)
  local -a a_cmd=(control_master scp "$tmp_file" "$userathost:$tmp_file")
  #if ssh -o ControlPath="$ssh_socket_template" -O check "$userathost" 2> /dev/null; then
    "${a_cmd[@]}" > /dev/null &
  #else
    #"${a_cmd[@]}" > /dev/null
  #fi

  # Remote execute
  control_master ssh -tt "$userathost" "
    # Sleep until file created
    until [[ -r \"$tmp_file\" && \"$hash\" == \"\$(md5sum \"$tmp_file\")\" ]]; do
      sleep 0.01
    done
    source \"$tmp_file\"
    dispatch $(escape_array "$@")
    exit \$?  # In ssh
  "

  exit $?  # In --at which is doing all by itself
}

__complete_mm_at(){
  printf '%b\n' {"",op@,root@}{acse1,acse2}
}



# In order to single source as ssh (see --at)
# shellcheck disable=SC2034
gi_source_lib_dispatch=1
# If executed: Print self doc
# -- Better than the return technique for executing --at: (if ! (return 0 2>/dev/null))
if ! is_sourced; then
  dispatch "$@"; exit $?;
fi
