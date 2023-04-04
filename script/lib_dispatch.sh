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
  : "${gs_root_path:=$(dirname "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")")}"

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
    declare -g cfend=$'\e[39m'           # Normal foreground
    declare -g cend=$'\e[0m'             # Reset all
    declare -g cbold=$'\e[1m'            # Bold, can be added to colors
    declare -g cunderline=$'\e[4m'       # Underline, can be added to colors
    declare -g cred=$'\e[38;5;124m'      # Error
    declare -g cgreen=$'\e[38;5;34m'     # Ok
    declare -g cyellow=$'\e[1m\e[38;5;208m'   # Warning, Code
    declare -g cblue=$'\e[38;5;39m'      # Info, Bold
    declare -g cpurple=$'\e[38;5;135m'   # Titles
  }

  reset_color(){
    # shellcheck disable=SC2034  # cfend appears unused
    declare -g cfend=''
    declare -g cend=''
    # shellcheck disable=SC2034  # cfend appears unused
    declare -g cbold=''
    # shellcheck disable=SC2034  # cfend appears unused
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
    g_dispatch_d_fct[$cmd]=$(cat <&"${d_fd[$cmd]}")
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
  log "Dispatch:$#|$*! (complete=$g_dispatch_b_complete, help=$g_dispatch_b_help, first=$gi_first_dispatch)"
  #log "$(print_stack)"

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


  # Loop: Parse each user input argument
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
        # Run now so that it is set before calling target_fct
        "$target_fct" "$@"; ((ret=$?))
        ((i_to_skip+=ret))
        # Completing case
        # If custom completion
        if ((g_dispatch_b_complete)) \
            && declare -F "__complete_${target_fct}" > /dev/null \
            && (( $# <= ret )); then
              # Commented out from time where I ran option even at complete
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
      echo -e "$cpurple${arg}$cend"
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

########################
# 2/ Low level utilities <= Only depends on logger

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

print_stack(){
  : 'Print current stack trace, tested
    Depends on: join_by
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
        a_argv[argc-j]=${BASH_ARGV[k++]}
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
      echo -e "$cyellow$line$cend"
      printf "%${i_indent}s" ""
      printf "        %b\n" "$msg"
    fi
  done
}


join_by(){
  : 'Join array string elements (args[2:]) with (by) a delimiter (arg1)
    Standalone
    Used by: print_stack
    From: https://stackoverflow.com/a/17841619/2544873
    Ex: join_by , a b c => a,b,c
  '
  local d=${1-} f=${2-}
  if shift 2; then
    printf %s "$f" "${@/#/$d}"
  fi
}


log(){
  : 'Helper for debug (completion): Log to /tmp/irm_jenkins_log.log'
  echo "$@" >> /tmp/lib_dispatch.log
}


is_sourced(){
  : 'Returns 0 if script is sourced and not executed, ToTest'
  [[ -v BASH_SOURCE ]] && (( ${#BASH_SOURCE[@]} > 0 )) && [[ "${BASH_SOURCE[0]}" == "$0" ]]
  return $(( ! $? ))
}



# If sourced: Declare functions to hide (after) the potencial call
if is_sourced; then
  readarray -t g_dispatch_a_fct_to_hide < <(declare -F -p | cut -d " " -f 3)
fi

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

  # Check In: Arguments
  if [[ -z "$at" ]]; then
    perr "--at option requires a user@host value" \
      "Tip: dispatch --at $USER@$HOSTNAME example succeed"
    return "$E_REQ"
  fi
  
  # Clause: required commands
  local -a a_err_cmd=()
  for cmd in ping scp ssh; do
    if ! command -v "$cmd" > /dev/null; then
      a_err_cmd+=("$cmd")
    fi
  done
  if (( ${#a_err_cmd[@]} )); then
    perr "Command[s] ${a_err_cmd[*]} are note present" \
      "Tip: sudo apt install ${a_err_cmd[*]}"
    return "$E_REQ"
  fi

  local userathost=$at  # Legacy, used to expand host alias

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
        "$gs_root_path/script/lib_alma.sh" \
        "$subcmd_file"
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
  printf '%b\n' {"","${USER:-$USERNAME}"@}{"$HOSTNAME",""}
}


# In order to single source as ssh (see --at)
# shellcheck disable=SC2034
gi_source_lib_dispatch=1
# If executed: Print self doc
# -- Better than the return technique for executing --at: (if ! (return 0 2>/dev/null))
if ! is_sourced; then
  dispatch "$@"; exit $?;
fi
