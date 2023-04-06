#!/usr/bin/env bash
  # shellcheck disable=SC2016  # Expressions don't expand in single quotes, use double quotes for that

# Find root path in case self executing
: "${gs_root_path:=$(dirname "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")")}"

# Source the dipatcher utility
# shellcheck disable=SC1091  # Not following
[[ ! -v gi_source_lib_dispatch ]] && source "$gs_root_path/script/lib_dispatch.sh"

# Declare version
# shellcheck disable=SC2034  # VERSION_DISPATCH appears unused
declare -g VERSION_DISPATCH=0.1.0
# shellcheck disable=SC2016  # Expressions don't expand in single quotes, use double quotes for that
: "${gs_root_path:=$(dirname "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")")}"

: "${cfend:=''}" "${cend:=''}" "${cbold:=''}" "${cunderline:=''}" "${cred:=''}" "${cgreen:=''}" "${cyellow:=''}" "${cblue:=''}" "${cpurple:=''}" "${g_dispatch_a_dispach_args:=}" "${g_dispatch_project_name:=Misc}"


: "${g_dispatch_b_complete:=0}"


# Globals
  declare -gi g_dispatch_b_run=1  # Do run command in run
  # --silent) g_dispatch_b_print=0;;
  # s) g_dispatch_b_print=0;;
  declare -gi g_dispatch_b_print=1  # Do print command before run in run

##########
# 4/ High level: Completion, Help, Doc


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
  return

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

# 3.1 Run

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
    # If a single assignment, use the declare trick
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




# 3.2 Helper

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

  # Calculate time
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


file_to_dic(){
  : '305/ Read file to a bash associative array, tested
    -- file lines must look like value=potencialy quoted fields to
    -- Must copy array to get a reference to it
    -- -- to be compatible with before Bash < 4.3 (without the declare -n feature)
    -- Not asynchronous safe

    Depends on: perr vcp
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

read_file_as_array(){
  : 'Read array <- file, tested
    -- Remove empty lines and # comments
    -- Note: if "-" or not existing, read from stdin
    Arg1: (out) array name
    Arg2: (in)  file name
    Depends on: perr
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
  : 'Remove first line indentation to all lines of string (arg1), tested
    Depends on: perr
    Requires awk
  '
  local in=$1
  if [[ ! -t 0 ]] && { (( $# == 0 )) || [[ "-" == "$in" ]]; }; then
    in=$(</dev/stdin)
  fi

  # Check: awk command must be present
  if ! command -v awk > /dev/null; then
    perr "print_unindent function requires awk command" \
      "Tip: apt install gawk"
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
  : 'Wait for all pid in array in, tested
    Return: 0 <= All OK
    Standalone
    From: https://stackoverflow.com/a/43776775/2544873
    From: https://stackoverflow.com/a/356154/2544873  # also
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
  : 'Print USER@HOSTNAME, tested
    Standalone
  '
  local user_at_host=localhost
  local user=${USER:-$USERNAME}
  [[ -n "$user" ]] && user+=@
  [[ -v HOSTNAME ]] && [[ -n "$HOSTNAME" ]] && user_at_host=$HOSTNAME
  user_at_host="${user}$user_at_host"
  echo "$user_at_host"
}


ask_confirmation(){
  : 'Print out message and wait for yes/no user confirmation, tested
    Arg1: optional string message of what to confirm
    Return: 0 -> continue: 1 -> user did not confirm
    Standalone
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


trim(){
  : 'Trim leading and trailing space, tested
    Standalone
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
    Depends on: perr get_opt
    Requires: awk
    Arg --col: coma separated list of column size len except the last column. Defaults to 20,30,30,30...
    Arg --ofs --ifs --fs: Output, Input, and generic Field Separator. The generic sets OFS and IFS. These defined how cells are split or join
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

  # Clause requires awk
  if ! command -v awk > /dev/null; then
    perr "columnize function requires awk command" \
      "Tip: apt install gawk"
  fi

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

    # Measure line length
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
  command -v "$1" &> /dev/null
  return $?
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

  # Get optional ssh
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
  : 'Pipe Util: The "backslash R" trick: Only print stdout last line updating itself, tested
    Standalone
  '
  {
    # turn of automatic margins
    # see man terminfo
    [[ -v TERM && -n "$TERM" && ! -v GITHUB_ACTION ]] \
      && command -v tput > /dev/null \
      && tput rmam

    # The or -n line trick is to cnsider EOF is only 1 line
    # -- See: https://stackoverflow.com/a/12919766/2544873
    while read -r line || [ -n "$line" ]; do
      printf "\r\e[K%s" "$line"
    done < "${1:-/dev/stdin}"

    [[ -v TERM && -n "$TERM" && ! -v GITHUB_ACTION ]] \
      && command -v tput > /dev/null \
      && tput smam
  }
  return 0
}


pipe_10(){
  : 'Pipe util: Print first 10 lines of stdin and 1/100 lines and last 10 lines, tested
    Depends on: perr
    Requires: awk command
  '
  if ! command -v awk > /dev/null; then
    perr "pipe_10 function requires awk command" \
      "Tip: apt install gawk"
  fi
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


# 0/ To place somewhere
#########
check_requirement(){
  : 'Utility to check if requirements are present on the machine
    Call: before running a command
    Side Effect: may exit
    :param: alma_sw -> ALMA Software present in ALMA_SW directory
    :param: alma_branch -> ALMA Software is in BRANCH branch (called with alma_sw)
    :param: alma_root -> ALMA Software compiled in /alma
    :param: docker -> Docker is installed on the machine
    :param: variable:VAR1:var2 -> VAR1 and var2 variables exist and is not void
    :param: command:python:docker -> python and docker commands exist
  '
  local -i res=0
  local arg='' s_varname=''
  local -a a_variable_name=()

  # Check each argument
  for arg in "$@"; do
    case "$arg" in
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


###################################
# 1/ Very Lowest level => internal log helpers


declare -gA gd_bash_parallel_command=() gd_bash_parallel_stdout=() gd_bash_parallel_status=()
bash_parallel(){
  : 'Run job in parallel and harvest output and status
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
    local stdout=$(cat <&"${d_fd[$id]}")  # Wait for stdout
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


# Depends on nothing, not even logger
# No undesired side, effect
# A jewel
# shellcheck disable=SC2142,SC2139,SC2034  # Aliases can't use positional, unused
# shellcheck disable=SC2154  # Last_arg referenced but not assigned false +
alias get_all_opt_alias='
  local arg=""
  local last_arg=""
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
    -- Print long argument <arg1:string> options from parameters following arguments
    -- In case of duplication, the last defined option wins
    Depends on: perr
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


print_args(){
  : 'Helper for debug (parameters): Print input arguments, one per line, tested
    Standalone
  '
  local -i i=1; local arg=''
  for arg; do echo "$((i++))/ $arg"; done
}

vcp(){
  : 'Variable CoPy, tested
    -- Can copy integer, string, array or dictionary
    WARNING: Do not declare destination variable as local before, as it will be global
    -- do not even declare it at all for bash <= 4.2 (RH7)!
    Arg1: Name of existing Source-Variable
    Arg2: Name for the Copy-Target
    Ex: toto=42; vcp toto titi; echo dollar_titi
    From: https://stackoverflow.com/a/52651361/2544873
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


: 'Create a filedescriptor attached to no file
  Cannot put in function as getting its output creates a subshell
  Let the kernel manage it
  Standalone
  Called by: bash_sleep
'
# shellcheck disable=SC2142,SC2139,SC2034  # Aliases can't use positional, unused
# shellcheck disable=SC2154  # Last_arg referenced but not assigned false +
alias get_dummy_fd_alias='
  local -i fd=0
  if [[ "$OSTYPE" == linux* ]]; then
    exec {fd}<> <(:) || return 2
  else
    local fifo
    fifo=$(mktemp -u) || return 11
    mkfifo -m 700 "$fifo" || return 12
    exec {fd}<>"$fifo" || return 13
    rm "$fifo" || return 14
  fi
'


bash_sleep(){
  : 'Sleep arg1 seconds. Like the sleep command but pure bash
  Arg1: Sleep time <float as string with dot> (ex: 2.3)
  Global: gfd_bash_sleep  # Global file descriptor to lock on
  Depends on: get_dummy_fd
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
    get_dummy_fd_alias
    # shellcheck disable=SC2154  # fd is referenced but not assigned
    gfd_bash_sleep=$fd
  fi

  # Wait finally
  read -r -t "$f_time" -u "$gfd_bash_sleep"

  return 0
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


bash_timeout(){
  : "Run a command with a timeout, async, tested
    -- Like timeout command but supports functions
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

###################################
# 0/ Log and equal

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
    Arg1: First frame number
    Arg2: Last frame number
    Depends on: join_by
    From: https://stackoverflow.com/a/2990533/254487
  '
  local -i i_init=${1:-0}  # Frame number where I'll start
  local -i i_end=${2:-10}  # Frame number where I'll stop
  local -i i_indent=-2  # Indentation size, start at -2 as everything is in a function
  local -i i_lnum=5  # Number of lines for the first frame
  local -i b_first_loop=1  # Are we in first loop
  local -i j=0 k=0 i_frame=0

  # Clean argument in
  if (( i_end < 0 )); then
    i_end=99
  fi

  # Warn can see more
  shopt -q extdebug || echo "# Note: run 'shopt -s extdebug' to see call arguments"
  # For each frame
  for i_frame in "${!FUNCNAME[@]}"; do
    # Clause for not work after stack size
    [[ ! -v BASH_LINENO ]] && break
    (( i_frame > ${#BASH_LINENO[@]} )) && break
    (( i_frame > ${#FUNCNAME[@]} )) && break
    (( i_frame > i_end )) && break

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

    # Prepare next loop
    ((i_indent+=2))
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


declare -gi g_dispatch_i_res=0  # Global response for the equal
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
      --fix   => message only printed if failed

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
  local -i i_depth=1  # Depth of the assert call, inited at 1 supposing the worker directly calls assert
  local stack=''  # Stack trace in case of failure
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
        && command -v git > /dev/null \
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
  #[[ -z "$brief" ]] && brief="from $(print_stack 2 2 | tr '\n' ' ')"
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

  # Potential verbose additional lines
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

  # Append error verbose
  if (( ! b_succeed )); then
    stdout_line+="  -- Namespace: $ART_NAMESPACE\n"
    stack=$(print_stack 2)
    stdout_line+="  -- Stacktrace:\n$stack"
    stdout_line+="\n\n"
  fi
    
  # And stdout line
  if (( ! b_succeed )); then
    # Append to summary fd
    if [[ -v gi_summary_write_fd ]] && (( gi_summary_write_fd != 0)); then
      DISPATCH_EQUAL_ERR+="$stdout_line"
      # shellcheck disable=SC2064  # Use single quotes, I know what I do
      trap "echo -e \"\$DISPATCH_EQUAL_ERR\" >&$gi_summary_write_fd" EXIT
    fi
  fi
  
  # Finally print to stderr
  >&2 echo -en "$stdout_line\n"

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
      elt+="    Stacktrace: $(reset_color; export g_dispatch_b_complete=1; print_stack | remove_ansi_code)"$'\n'
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


# If executed and not sourced, print self doc
if [[ -v BASH_SOURCE ]] && (( ${#BASH_SOURCE[@]} > 0 )) && [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  dispatch "$@"; exit $?;
fi

# Declare functions to hide (after) the potential call
if [[ ( -v arg && dispatch == "$arg" ) \
    || ( -v IRM_JENKINS_SSH_SUBCOMMAND && dispatch == "$IRM_JENKINS_SSH_SUBCOMMAND" ) \
    ]]; then
  # TODO should hide function defined before alma sourcing, like in bashrc
  declare -ag g_dispatch_a_fct_to_hide=()
else
  # shellcheck disable=SC2034  # unused variable
  readarray -t g_dispatch_a_fct_to_hide < <(declare -F -p | cut -d " " -f 3)
  readarray -t g_dispatch_a_fct_to_hide < <(subtract_array "${g_dispatch_a_fct_to_hide[@]}" -- mm_doc_api mm_at __complete_mm_at)
fi

# In order to single source as ssh (see --at, ICT-18899)
# shellcheck disable=SC2034
gi_source_lib_misc=1
