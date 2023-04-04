#!/usr/bin/env bash
# Utilities scripts
# -- IDEA: Get list for the bands to filter like 3,5,7 or even 3410 for 3,4,10

set -u

[[ ! -v gi_source_lib_misc ]] && {
  [[ ! -v gs_root_path ]] && { gs_root_path=$(readlink -f "${BASH_SOURCE[0]}"); gs_root_path=$(dirname "$gs_root_path"); gs_root_path=$(dirname "$gs_root_path"); }
  # shellcheck disable=SC1091  # Not following
  source "$gs_root_path"/script/lib_misc.sh
}
: "${cfend:=''}" "${cend:=''}" "${cbold:=''}" "${cunderline:=''}" "${cred:=''}" "${cgreen:=''}" "${cyellow:=''}" "${cblue:=''}" "${cpurple:=''}"


# Main options default


unit_test(){
  : '--/ Check current code (dispatch)'
  local -i res=0

  export ART_NAMESPACE="dispatch self"
  export ART_VERBOSE=1

  # Go to local dir
  pushd "$gs_root_path"/test &> /dev/null || return "$E_CD"

  # Declare output filename and clear it
  export g_junit_file="$gs_root_path"/junit_last_result.xml
  : > "$g_junit_file"

  # Write report head
  local title=${JOB_NAME:-"Custom from $(user_at_host) at $(date '+%Y-%m-%dT%H:%M:%S')"}
  # Ref: https://llg.cubic.org/docs/junit/
  print_unindent "
    <?xml version=\"1.0\" encoding=\"UTF-8\"?>
    <testsuites name=\"$title\" tests=\"\" errors=\"\" failures=\"\" time=\"\">
    " >> "$g_junit_file"

  # Run the test
  run ./run_test.sh "$@"; res=$?

  # Write report tail
  echo '</testsuites>' >> "$g_junit_file"

  # Go back
  popd &> /dev/null || return "$E_CD"

  return "$res"
}


__complete_unit_test(){
  : "Internal for completion of lib_dispatch master unit_test"
  pushd "$gs_root_path"/test &> /dev/null || return "$E_CD"

  # Echo all test file
  for test_file in async test_*.sh; do
    if [[ async == "$test_file" ]]; then
      local desc="Run asynchronously all tests (faster)"
    else
      local desc=$(get_file_docstring "$test_file")
    fi
    echo -e "$test_file : $desc"
  done

  popd &> /dev/null || return "$E_CD"
}


make_temp_dir(){
  : 'Just mktemp -d'
  mktemp -d "/tmp/art_$(date '+%Y-%m-%dT%H:%M:%S.%3N')_XXXXXX"
  return $?
}


doc_api(){
  : '99/ Helper to create recursive doc
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
  elif [[ html == "$format" ]]; then
    # Redirect stdout
    touch "$cmd_name"_doc_api.html
    exec 1> "$cmd_name"_doc_api.html
    echo -e "$(print_unindent '
      <!DOCTYPE html>
      <html>
      <head>
      <title>'"$cmd_name"' functions</title>
      <style>
      '"$(<"$gs_root_path"/res/table.css)"'
      </style>
      </head>
      <body>
      <table>
      <tr>
        <th>Sub Command</th>
        <th>Tail Function</th>
        <th>Description</th>
      </tr>
      ')"
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
      | sed "s/'/\\&#39;/g"
    )

    # Print hi: current subcommand head
    if [[ xml == "$format" ]]; then
      echo -e '
        <tr></tr>
        <tr>
          <td value="'"${subcmd^^}"'" bgcolor="LightGrey" fontcolor="black" fontattribute="bold" align="left" width="200"/>
          <td value="" bgcolor="LightGrey" fontcolor="black" fontattribute="bold" align="left" width="200"/>
          <td value="'"$subcomment"'" bgcolor="LightGrey" fontcolor="black" fontattribute="bold" align="left" width="200"/>
        </tr>
        '
    elif [[ html == "$format" ]]; then
      echo -e "$(print_unindent '
        <tr></tr>
        <tr>
          <th>'"${subcmd^^}"'</th>
          <th></th>
          <th>'"$subcomment"'</th>
        </tr>
      ')"
    else  # Including if [[ stdout == "$format" ]]; then
      echo "# $line_cmd"
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
        | sed "s/'/\\&#39;/g"
      )
      if [[ xml == "$format" ]]; then
        echo -e '
          <tr></tr>
          <tr>
            <td value="'"$subcmd"'" bgcolor="white" fontcolor="black" fontattribute="normal" align="left" width="200"/>
            <td value="'"$function"'" bgcolor="white" fontcolor="black" fontattribute="normal" align="left" width="200"/>
            <td value="'"$comment"'" bgcolor="white" fontcolor="black" fontattribute="normal" align="left" width="200"/>
          </tr>
        '
      elif [[ html == "$format" ]]; then
        echo -e "$(print_unindent '
          <tr></tr>
          <tr>
            <td>'"$subcmd"'</td>
            <td>'"$function"'</td>
            <td>'"$comment"'</td>
          </tr>
        ')"
      else  # including if [[ stdout == "$format" ]]; then
        echo "$cmd $subcmd $function  # $comment"
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
  elif [[ html == "$format" ]]; then
    echo -e "$(print_unindent '
      </table>
      </body>
      </html>
    ')"
    exec 1>&-
  fi

  # It consumes an argument
  return 1
}


__complete_doc_api(){
  # From GSiringo presentation: https://confluence.alma.cl/display/ESG/ALMA+Band+Integration
  echo "
    stdout : in text format to stdout
    xml : in xml to local file: ${cmd_name}_doc_api.xml
    html : in html to local file: ${cmd_name}_doc_api.html
  "
  return 1
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
  local msg="  ${s_indent}${cblue}Host ---- :$cend ${USER:-USERNAME}@$HOSTNAME
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
    GITHUB_WORKSPACE=
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
  [[ ! -v gi_source_lib_misc ]] && source "$gs_root_path/script/lib_misc.sh"

  # Set completion
  complete -C dispatch dispatch

  # PS1
  parse_git_branch() {
    # shellcheck disable=SC2317  # (info): Command appears to be unreachable
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
    # shellcheck disable=SC2317  # (info): Command appears to be unreachable
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
  export PATH="$(dirname "$(dirname "${BASH_SOURCE[0]}")"):$PATH"

  unset lib_alma
}


new_test_file(){
  # Check in: one arg
  if (( $# < 1 )); then
    perr "function new_test_file must receive one argument, the filename" \
      "Tip: new_test_file unit_is_in_array"
    return "$E_REQ"
  fi

  # Parse arg in
  local arg=$1
  
  # Create filename and funcname
  local funcname=$arg
  if [[ ! "$funcname" =~ ^unit_ ]]; then
    funcname=${funcname##unit_}
  fi
  if [[ ! "$funcname" =~ ^function_ ]]; then
    funcname="function_$funcname"
  fi
  local filename=$arg
  if [[ ! "$filename" =~ ^test_ ]]; then
    filename="test_$filename"
  fi
  if [[ ! "$filename" =~ \.sh$ ]]; then
    filename="$filename.sh"
  fi

  # Clause: filename must not exist
  local path="$gs_root_path/test/$filename"
  if [[ -e "$path" ]]; then
    perr "new_test_file: file $path already exist, please create a new test file or delete this file" \
      "Tip: new_test_file unit_not_already_exisiting"
    return "$E_REQ"
  fi

  # Craft content
  local content=$(<"$gs_root_path"/res/test_template.sh)
  content=${content//placehodler_funcname/$funcname/}
  content=${content//placehodler_filename/$filename/}
  
  # Write file
  echo "$content" > "$path"
  chmod +x "$path"
}


__at_init(){ print_script_start "$@"; }
__at_finish(){ print_script_end "$@"; }

if [[ -v BASH_SOURCE ]] && (( ${#BASH_SOURCE[@]} > 0 )) && [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  dispatch "$@"; exit $?;
fi
