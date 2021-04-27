#! /bin/bash -i
TIMELINE_VERSION='1.8-8-g87310e6'
## vim:ft=sh

# fun: [E=code] fatal <message>
# txt: print fatal message to stderr, if environment variable `$E` is
#      present, then exists with specified error code in `$E` (only if
#      non-interactive)
fatal ()
{
  E="${E:-1}" error "$@"
}

# fun: error <message>
# txt: print error message to stderr
error ()
{
  if [ "$E" ]; then
    local err_kind="fatal"
  else
    local err_kind="error"
  fi

  format_compose "timeline.$err_kind" name \
    "$(config_get timeline.${err_kind}.name)"
  format_compose "timeline.$err_kind" date "$(timestamp)"
  # shellcheck disable=SC2059
  format_compose "timeline.$err_kind" mesg "$(printf -- "$@")"
  format_dumps "timeline.$err_kind" >&2

  if [ "$E" ]; then
    exit "$E"
  fi
}
## vim:ft=sh

declare -xa TERMINAL_COLORS_FG=()
declare -xa TERMINAL_COLORS_BG=()

COLORS="$(tput colors)"
case "$COLORS" in
  8|256)
    for ((i=0; i<"${COLORS}"; i++)); do
      TERMINAL_COLORS_FG[$i]="$(tput setaf "$i")"
      TERMINAL_COLORS_BG[$i]="$(tput setab "$i")"
    done;;
esac

# fun: color_consistent <color> <item>
# txt: get a consistent color from color preference passed as argument. If
#      preference is `CONSISTENT`, then color is chosen randomly, but
#      consistenly with the item to be colorized. To choose colors use the
#      `colors` configuration variable
color_consistent ()
{
  if [[ "$1" != "CONSISTENT" ]]; then
    echo "$1"
  else
    local key=$((0x$(oid "$2")0))
    echo "${AVAIL_COLORS[$((key % ${#AVAIL_COLORS[@]}))]}"
  fi
}

# fun: color_eval <fg,bg> <dfg,dbg> <message>
# txt: print a message between colors defined in two first arguments.
color_eval ()
{
  local fg bg dfg dbg

  fg="${CONFIG["$1"]%,*}"; bg="${CONFIG["$1"]#*,}"; shift
  dfg="${CONFIG["$1"]%,*}"; dbg="${CONFIG["$1"]#*,}"; shift

  fg="$(color_consistent "$fg" "$1")"; dfg="$(color_consistent "$dfg" "$1")"
  bg="$(color_consistent "$bg" "$1")"; dbg="$(color_consistent "$dbg" "$1")"

  echo -n "${TERMINAL_COLORS_FG[${fg:-${dfg:-1000}}]}"
  echo -n "${TERMINAL_COLORS_BG[${bg:-${dbg:-1000}}]}"
  echo -e "\n$1"
  echo -n "${TERMINAL_COLORS_FG[${dfg:-1000}]}"
  echo -n "${TERMINAL_COLORS_BG[${dbg:-1000}]}"
}
## vim:ft=sh

# fun: complete_alternatives <level> <prefix>
# txt: print a list of valid alternatives for specific prefix.
complete_alternatives ()
{
  local level="$1" prefix="$2"
  local -A items=()

  while read -r _ _ cmd; do
    case "$cmd" in
      command_${prefix}*)
        cmd="${cmd#command_}"
        for ((i=0;i<level;i++)); do
          cmd="${cmd#*_}"
        done

        items["${cmd%%_*}"]=1
    esac
  done < <(declare -F)

  echo "${!items[@]}"
}


# fun: complete_item
# txt: print list of available completion
complete_item ()
{
  read -ra words <<< "${READLINE_LINE}"
  local cur=$((${#words[@]}-1))
  read -ra alts <( complete_alternatives "$cur" )
  local -a values

  if [[ $cur -eq -1 ]]; then
    values=( "${alts[@]}" )
  else
    read -ra values < <( compgen -W "${alts[*]}" "${words[$cur]}" )
  fi
  
  if [[ ${#values[@]} -eq 0 ]]; then
    values=( "${alts[@]}" )
  fi

  if [[ ${#values[@]} -eq 1 ]]; then
    if [[ "${READLINE_LINE}" = "${values[0]} " ]]; then
      complete_alternatives $((cur +1)) "${values[0]}_"
    else
      READLINE_LINE="${words[*]:0:$cur}"
      [[ "$READLINE_LINE" ]] && READLINE_LINE+=" "
      READLINE_LINE+="${values[*]} "
      READLINE_POINT=${#READLINE_LINE}
    fi
  else
    echo "${values[@]}"
  fi
}

# fun: complete_load
# txt: set tab completion
complete_load ()
{
  set -o vi
  bind 'set completion-ignore-case on'
  bind -x '"\t":"complete_item"';
}
## vim:ft=sh

# fun: info <message>
# txt: print informational message on stdout
info ()
{
  format_compose timeline.info name "${CONFIG[timeline.info.name]}"
  format_compose timeline.info date "$(printf "%(%s)T")"
  # shellcheck disable=SC2059
  format_compose timeline.info mesg "$(printf -- "$@")"
  format_dumps timeline.info
}

# fun: info_multi
# txt: get messages from stdint and print informational messages to stdout
info_multi ()
{
  format_compose timeline.info name "${CONFIG[timeline.info.name]}"
  format_compose timeline.info date "$(printf "%(%s)T")"
  _i() {
    format_compose timeline.info mesg "${2%$'\n'}"
    format_dumps timeline.info
  }
  # shellcheck disable=SC2034
  mapfile -c 1 -C _i
}
## vim:ft=sh

# env: REQUIREMENTS: array which contains requirements to satisfy to run the
#      application. If requirement is prefixed with + means that program is
#      mandatory, if prefixed with ? means that it's recommended.
REQUIREMENTS=(
  "+tput"
  "+git"
)

# fun: reqs_eval
# txt: ensure that requirements defined in `$REQUIREMENTS` are present in
#      the system, otherwise exists with fatal error.
reqs_eval ()
{
  local req kind

  for req in "${REQUIREMENTS[@]}"; do
    kind="${req:0:1}"; req="${req#$kind}"

    mute type -P "$req" ||
      case "$kind" in
        "+") E=1 fatal $"Binary '%s' is a mandatory dependency" "$req";;
        "?") error $"Binary '%s' is recommended, but not found" "$req";;
        *) E=1 fatal $"Unknown depedency kind '%s'" "$kind";;
      esac
  done
}
## vim:ft=sh

# fun: history_load
# txt: if is defined prompt_history and prompt_history_file configuration
#      file, load from there the history of the commands.
history_load ()
{
  hist_enabled="$(config_get history.enabled)"
  hist_file="${CONFIG[history.file]}"

  history -c

  if [ "${hist_enabled}" = "true" ] &&
     [ "${hist_file}" ] && 
     [ -r "${hist_file}" ]; then
    history -r "${hist_file}"
  fi
}

# fun: history_save
# txt: if defined history_file configuration file, save history to that
#      file.
history_save ()
{
  hist_enabled="$(config_get history.enabled)"
  hist_file="${CONFIG[history.file]}"

  [ "${hist_enabled}" = "true" ] && [ "${hist_file}" ] &&
    history -w "${hist_file}"
}

# fun: history_append <command>
# txt: append command into history line if history is enabled
history_append ()
{
  hist_enabled="$(config_get history.enabled)"
  [ "${hist_enabled}" = "true" ] && history -s "$1"
}
## vim:ft=sh


help_prefix=$"


████████╗██╗███╗   ███╗███████╗██╗     ██╗███╗   ██╗███████╗
╚══██╔══╝██║████╗ ████║██╔════╝██║     ██║████╗  ██║██╔════╝
   ██║   ██║██╔████╔██║█████╗  ██║     ██║██╔██╗ ██║█████╗
   ██║   ██║██║╚██╔╝██║██╔══╝  ██║     ██║██║╚██╗██║██╔══╝
   ██║   ██║██║ ╚═╝ ██║███████╗███████╗██║██║ ╚████║███████╗
   ╚═╝   ╚═╝╚═╝     ╚═╝╚══════╝╚══════╝╚═╝╚═╝  ╚═══╝╚══════╝



Timeline is a plain-text based distributed social network build on top of
git configuration manager. Timeline is:


- Distributed / Descentralized
- Secure / Solid / Spam aware
- GPL3 licensed
- Fun!


----- Commands ----------------------------------------------------------------
"

help_suffix=$"

Type help <command> for more information about the command

-------------------------------------------------------------------------------
"

help_commands ()
{
  local hide_help_banner
  hide_help_banner="${CONFIG[general.hide-help-banner]}"

  [[ "$hide_help_banner" = "true" ]] || echo "$help_prefix"

  _i(){
    case "$2" in
      "# help:fun: "*) 
        printf "\n    %s"  "${2#\# help:fun: }";;
      "# help:txt: "*)
        printf "        %s" "${2#\# help:txt: }";;
    esac
  }

  # shellcheck disable=SC2034
  mapfile -c 1 -C _i < "$0"

  [[ "$hide_help_banner" = "true" ]] || echo "$help_suffix"
}

help_subcommand ()
{
  local cmd="$1"

  _j() {
    case "$2" in
      "# help:$cmd:fun: "*) 
        echo -n "${2#\# help:$cmd:fun: }";;
      "# help:$cmd:txt: "*)
        echo -n "    ${2#\# help:$cmd:txt: }";;
    esac
  }

  # shellcheck disable=SC2034
  mapfile -c 1 -C _j < "$0"
}
## vim:ft=sh

# env: DAEMON_LOG_FILE: Internal variable where file redirections are saved.
DAEMON_LOG_FILE=
# env: DAEMON_LOG_LEVEL: Internal variable to store daemon log level.
DAEMON_LOG_LEVEL=
# env: DAEMON_INTERVAL: Internal variable to store daemon interval time.
DAEMON_INTERVAL=
# env: DAEMON_COMMANDS: Internal variable to store commands to run in bg.
DAEMON_COMMANDS=

# env: NOLOG: if true do not log anything
NOLOG=false
# env: PIDFILE: Internal variable where pidfile path is saved.
PIDFILE=

# fun: daemon_reload_config
# txt: reload daemon config from config file
daemon_reload_config ()
{
  PIDFILE="$(config_get daemon.pidfile)"
  DAEMON_LOG_FILE="${CONFIG[daemon.log.file]}"
  case "$DAEMON_LOG_FILE" in
    none) NOLOG=true;;
    stdout|STDOUT|stderr|STDERR) DAEMON_LOG_FILE="";;
    *) DAEMON_LOG_FILE=">> ${DAEMON_LOG_FILE}";;
  esac
  DAEMON_LOG_LEVEL="${CONFIG[daemon.log.level]}"
  case "${DAEMON_LOG_LEVEL}" in
    error) DAEMON_LOG_FILE+=" 2>&1 >/dev/null";;
    info) DAEMON_LOG_FILE+=" 2>&1";;
  esac
  DAEMON_INTERVAL="${CONFIG[daemon.interval]}"
  DAEMON_COMMANDS="${CONFIG[daemon.commands]}"
}

# fun: daemon_run <pidfile>
# txt: Run the commands configured for the daemon every interval.
daemon_run ()
{
  daemon_reload_config

  PIDFILE="$1"

  trap daemon_reload_config HUP
  trap daemon_remove_pid TERM

  # while sleep ...
  while sleep "${DAEMON_INTERVAL:-300}"
  do
    if ! ${NOLOG:-false}; then
      eval "main_standalone ${DAEMON_COMMANDS} ${DAEMON_LOG_FILE}"
    fi
  done
}

# fun: daemon_start
# txt: Start daemon in background.
daemon_start ()
{
  local pid
  daemon_reload_config

  [ -r "${PIDFILE}" ] && pid="$(<"${PIDFILE}")"

  if [[ "$pid" ]]; then
    fatal $"There are another daemon running. Force quit with daemon kill"
  else
    daemon_run "${PIDFILE}" &
    echo "$!" > "${PIDFILE}"
    disown
    info $"Starting daemon at pid %d" "$!"
  fi
}

# fun: daemon_stop <signal>
# txt: Stop daemon running in background with signal passed as argument.
daemon_stop ()
{
  local pid
  daemon_reload_config

  [ -r "${PIDFILE}" ] && pid="$(<"${PIDFILE}")"

  if [[ "$pid" ]]; then
    pkill "-$1" -P "$pid" && rm "${PIDFILE}"
  fi
}

# fun: daemon_list
# txt: print if the daemon is currently running.
daemon_list ()
{
  local pid
  daemon_reload_config

  [ -r "${PIDFILE}" ] && pid="$(<"${PIDFILE}")"

  if [[ "$pid" ]]; then
    info $"Daemon running at pid: %d" "$pid"
  else
    info $"There is no daemon running"
  fi
}
## vim:ft=sh

# fun: markdown_generate
# txt: this function will generate the CONTENT.md file in the repo and commit
#      it.
markdown_generate ()
{
  if [[ ! -r "${ACCOUNT_PATH}/CONTENT.md}" ]]; then
    echo -e "# CONTENT\n\n" > "${ACCOUNT_PATH}/CONTENT.md"
    while read -r d k p; do
      if [[ "$k" == 'P' ]]; then
        {
          printf "## %(%c)T\n\n" "$d"
          echo "${p}" | fold -s | while read -r line; do
            echo "> $line"
          done
          printf "\n\n"
        } >> "${ACCOUNT_PATH}/CONTENT.md"
      fi
    done < "${ACCOUNT_PATH}/CONTENT"
  fi
}
## vim:ft=sh

# env: NETWORK: an associative array which contains all network information
declare -A NETWORK_SCORE=()
declare -A NETWORK_PARENTS=()
declare -A NETWORK_ITEMS=()
declare -A NETWORK_UPDATED=()

NETWORK_PATH_PREFIX="network"

# fun: network_list
# txt: print the current discovered network
network_list ()
{
  local -a sort_score=()
  local max=0

  # first sort scores
  for items in "${!NETWORK_SCORE[@]}"; do
    sort_score[${NETWORK_SCORE["$items"]}]+=" $items "
    if [[ "${NETWORK_SCORE["$items"]}" -gt $max ]]; then
      max=${NETWORK_SCORE["$items"]}
    fi
  done


  # reverse score array and print results
  for ((;max>0; max--)); do
    items="${sort_score[$max]}"

    for item in $items; do
      format_compose network.list date "$(timestamp)"
      format_compose network.list name "NETWORK"
      format_compose network.list score "$max"
      format_compose network.list user "$(username "$item")"
      format_compose network.list url "${NETWORK_ITEMS["$item"]}"
      format_dumps network.list
      for follow in ${NETWORK_PARENTS["$item"]}; do
        format_compose network.list date "$(timestamp)"
        format_compose network.list name "NETWORK"
        format_compose network.follower user "$(username "$follow")"
        format_dumps network.follower
      done
    done
  done
}

# fun: network_load_repo <uid> <url> [parent]
# txt: load the repo follows
network_load_repo ()
{
  local uid="$1" url="$2" parent="$3" active_oid
  local path="${CACHE_DIR}/${NETWORK_PATH_PREFIX}/$1"
  active_oid="${ACCOUNT_OID}"

  [[ "$uid" = "$active_oid" ]] && return

  [[ "$parent" ]] && NETWORK_PARENTS["$parent"]+=" $uid "

  while read -r fuid furl; do
    [[ "$fuid" = "$active_oid" ]] && continue
    NETWORK_ITEMS["$fuid"]="$furl"
    NETWORK_SCORE["$fuid"]="$((${NETWORK_SCORE["$fuid"]:-0}+1))"
    NETWORK_PARENTS["$fuid"]+=" $uid "
  done < <(follow_list "${path}")
}

# fun: network_load <path>
# txt: load network in cache to in-memory structure
network_load ()
{
  local path="$1" active_oid
  local cache="${CACHE_DIR}/${NETWORK_PATH_PREFIX}"
  active_oid="${ACCOUNT_OID}"

  while read -r  uid url; do
    [[ "$active_oid" = "$uid" ]] && continue

    if [[ -d "${cache}/$uid" ]]; then
      network_load_repo "$uid" "$url"
    else
      error $"Unable to load repository '%s'. Try network refresh first." \
        "$uid"
    fi
  done < <(follow_list "${ACCOUNT_PATH}")
}

# fun: network_refresh_repo <uid> <url> [count]
# txt: Refresh the network, looking for new followers in the graph.
network_refresh_repo ()
{
  local uid="$1" url="$2" count="${3:-0}" max_depth=
  local cache="${CACHE_DIR}/${NETWORK_PATH_PREFIX}"
  max_depth="$(config_get network.depth)"

  mkdir -p "${cache}"

  if [[ "$count" -gt "$max_depth" ]]; then
    error $"Max depth reached (%s) for uid '%s'" "$count" "$uid"
    return
  fi

  # This uid is already updated
  if [[ "${NETWORK_UPDATED["$uid"]}" = "true" ]]; then
    return
  fi

  if [[ -d "${cache}/$uid" ]]; then
    # repo already exists, just rebase
    if ! command git -C "${cache}/$uid" pull --rebase 2>&1; then
      error $"Unable to pull repository '%s' from '%s'" "$uid" "$url"
      return 1
    fi
  else
    # repo does not exists yet, cloning...
    if ! command git clone --depth 1 "$url" "$cache/$uid" 2>&1; then
      error $"Unable to clone repository '%s' from '%s'" "$uid" "$url"
      return 1
    fi
  fi

  NETWORK_UPDATED["$uid"]=true

  while read -r uid url; do
    network_refresh_repo "$uid" "$url" "$((count++))"
  done < <(follow_list "${cache}/$uid")
}

# fun: network_refresh <path>
# txt: from initial path refresh the network
network_refresh ()
{
  local path="$1"
  NETWORK_UPDATED=()
  while read -r uid url; do
    network_refresh_repo "$uid" "$url"
  done < <(follow_list "$path")
}
## vim:ft=sh

# fun: directory_requirements
# txt: ensure that specific requirements for directory management are
#      present in the system
directory_requirements ()
{
  REQUIREMENTS+=( "+curl" "+grep" )
  reqs_eval
}

# fun: directory_refresh [name]
# txt: download directory files for specific directory or for all directories
#      listed in config.
directory_refresh ()
{
  local dir
  directory_requirements

  for dir in "${!CONFIG[@]}"; do
    case "$dir" in
      "directory.$1"*)
        curl -qsSL -o "${CACHE_DIR}/$dir" --fail "${CONFIG[$dir]}" 2>&1 ||
          E=1 error "Unable to refresh directory: ${dir#directory.}"
        ;;
    esac
  done
}
# fun: directory_add [--force] <name> <url>
# txt: add a directory to the config
directory_add ()
{
  if [[ "$1" == "--force" ]]; then
    local force=true; shift
  else
    local force=false
  fi

  [[ "$1" ]] || E=2 error $"Name is required for add a directory"
  [[ "$2" ]] || E=2 error $"URL is required for add a directory"

  if ! $force && [[ "${CONFIG["directory.$1"]}" ]]; then
    error "Already exists a directory registered with name $1"
    E=1 error "Use --force to override"
  fi

  CONFIG["directory.$1"]="$2"
}

# fun: directory_del <name>
# txt: del a directory to the config
directory_del ()
{
  [[ "$1" ]] || E=2 error $"Name is required for del a directory"a
  CONFIG["directory.$1"]=''
}

# fun: directory_list
# txt: list all directories in config
directory_list ()
{
  for dir in "${!CONFIG[@]}"; do
    case "$dir" in
      directory.*)
        echo "${dir#directory.}: ${CONFIG["$dir"]}"
        ;;
    esac
  done
}

# fun: directory_search [pattern]
# txt: search a pattern in directories
directory_search ()
{
  local dir
  for dir in "${CACHE_DIR}"/directory.*; do
    grep -v -e '^#' -e '^[ ]*$' "$dir" | grep -w "$1"
  done
}
## vim:ft=sh

# fun: follow_list <path>
# txt: given a path get the submodules into FOLLOW directory
follow_list ()
{
  local line path="$1"

  while read -r line; do
    line="${line#*${TIMELINE_FOLLOW}/}"
    case "$line" in
      *'.url='*)
        echo "${line%.url=*}" "${line#*.url=}"
      ;;
    esac
  done < <(command git -C "$path" config -f .gitmodules -l 2>/dev/null)
}


# fun: follow_add <pull_url> [name]
# txt: Add new following using pull_url passed as argument. Optional name
#      will add a config entry for user alias to this name.
follow_add ()
{
  local pull_url="${1}" name="$2"
  oid "$pull_url"
  
  command git -C "${ACCOUNT_PATH}" submodule add \
    "$pull_url" "${TIMELINE_FOLLOW}/${OID_CACHE["$pull_url"]}"
  command git -C "${ACCOUNT_PATH}" submodule init
  command git -C "${ACCOUNT_PATH}" submodule update --remote

  account_commit "follow: add ${OID_CACHE["${pull_url}"]}"
  account_push

  if [[ "$name" ]]; then
    config_set "user.alias-${OID_CACHE["$pull_url"]}" "$name"
    config_save "${CONFIG_FILE}"
  fi

}

# fun: follow_del <uid>
# txt: remove following for user identified by specific UID
follow_del ()
{
  local uid="$1"

  mpath="${TIMELINE_FOLLOW}/$uid"

  # remove gitconfig sections
  mute command git -C "$ACCOUNT_PATH" config -f .git/config \
    --remove-section "submodule.$mpath"

  mute command git -C "$ACCOUNT_PATH" config -f .gitmodules \
    --remove-section "submodule.$mpath"

  account_commit "follow: del ${uid}"

  command git -C "$ACCOUNT_PATH" rm --cached "$mpath"
  rm -rf "${ACCOUNT_PATH:?}/.git/modules/$mpath"
 
  if [[ -d "$ACCOUNT_PATH/$mpath" ]]; then
    rm -rf "${ACCOUNT_PATH:?}/${mpath:?}"
  fi

  account_push
}
## vim:ft=sh

if [[ "${COLORS}" ]]; then
  smso="$(tput smso)"
  rmso="$(tput rmso)"
  sgr0="$(tput sgr0)"
  sitm="$(tput sitm)"
  ritm="$(tput ritm)"
  smul="$(tput smul)"
  rmul="$(tput rmul)"
fi

# env: FORMAT: interal variable which contains the format to be printed with
#      `format_dumps`. Do not use this variable directly, instead use
#      `formaT_compose` function.
declare -A FORMAT=()

# fun: format_stype <style_config> <item>
# txt: stylize a message called item with style provided in config addressed
#      by key style_config.
format_style ()
{
  local style="${CONFIG["$1"]}"

  case "$style" in
    italic) echo "$sitm$2$ritm";;
    underline) echo "$smul$2$rmul";;
    *) echo "$2";;
  esac
}

# fun: format_compose <kind> <field> <value>
# txt: compose a new format for kind passed as argument, setting the field
#      provided with specified value.
# use: format_compose timeline username "me"
if ( test -t 1 || ${T:-false} ) && ${COLOR:-true}; then
  format_compose ()
  {
    local out match;

    case "${CONFIG["${1}.style-${2}"]}" in
      italic) out="$sitm$3$ritm";;
      underline) out="$smul$3$rmul";;
      *) out="$3";;
    esac

    if [[ "$out" =~ ${CONFIG["${1}.highlight-${2}"]} ]]; then
      for match in "${BASH_REMATCH[@]}"; do
        out="${out//$match/$smso$match$rmso}"
      done
    fi

    FORMAT["$2"]="$(color_eval "${1}.color-${2}" "${1}.color" "$out")"
  }
else
  format_compose () {
    FORMAT["$2"]=$'\n'"$3"$'\n'
  }
fi

# fun: format_dumps <kind>
# txt: dumps to stdout the format composed previously with `format_compose`.
format_dumps ()
{
  local format fields
  local -a args=()

  format="${CONFIG["${1}.format"]}"
  fields="${CONFIG["${1}.fields"]}"

  [ "$format" ] || format=''

  local IFS=','
  for field in ${fields}; do
    mapfile -t -O "${#args[@]}" args <<< "${FORMAT["$field"]}"
  done

  # shellcheck disable=SC2059
  printf "${format}%b\n" "${args[@]}" "$sgr0"
}
## vim:ft=sh

# fun: usage
# txt: print help screen
usage ()
{
  printf $"tl: [options] [command [args]]\n\n"
  printf $"Options:\n"
  printf $"  -h           Show this help screen\n"
  printf $"  -a <account> Use specified account\n"
  printf $"  -C <file>    Load specified config file\n"
  printf $"  -V           Print version\n"
  printf $"See all available commands with command 'help'\n"
}

# fun: args_eval <arg>+
# txt: parse and evaluate program arguments
args_eval ()
{
  OPTERR=1
  while getopts "hC:a:V" opt; do
    case $opt in
      h)
        usage; exit 0
      ;;
      C)
        export CONFIG_FILE="$OPTARG"
      ;;
      a)
        export ACCOUNT_NAME="$OPTARG"
      ;;
      V)
        command_version; exit 0
      ;;
    *)
      usage; exit 2
      ;;
    esac
  done
  return $((OPTIND-1))
}
## vim:ft=sh

NOSUBCMD=$"No valid subcomand '%s' for command '%s'"
INVALIDURL=$"Invalid URL '%s'"



# help:fun: account {create|delete|clone|list|refresh|active|preview} {args...}
# help:txt: Manage timeline local and remote accounts.
command_account ()
{
  local cmd="$1"; shift
  if fun "command_account_$cmd"; then
    "command_account_$cmd" "$@"
  else
    E=1 error "$NOSUBCMD" "$cmd" "account"
  fi
}

# help:account:fun: account create [--keyid <keyi>] <name> <push_url> <pull_url> [path]
# help:account:txt: Create a new account (aka git repository) which will
# help:account:txt: push data to specified push_url and publish public url
# help:account:txt: as specified pull_url. Optionally, you can set the path
# help:account:txt: where repository lives, if omit, uses default path for
# help:account:txt: accounts. The '--keyid' flag sets a GPG keyid for
# help:account:txt: signing commits.
command_account_create ()
{
  local keyid=

  case "$1" in
    --keyid)
        keyid="$2"
        if ! [[ "$keyid" ]]; then
          E=2 error "Account create with --keyid flag requires keyid argument"
        fi
        shift 2
        ;;
  esac

  local name="$1" push_url="$2" pull_url="$3" path="$4"

  if [[ -z "$1" ]]; then
    E=1 error $"Account command create requires 'name'."
  else
    if ! valid_url "$push_url"; then
      E=1 error "$INVALIDURL" "$push_url"
    elif ! valid_url "$pull_url"; then
      E=1 error "$INVALIDURL" "$pull_url"
    else
      account_create "$name" "$push_url" "$pull_url" "$keyid" "$path" |
        info_multi
      config_load "${CONFIG_FILE}"
      command_account_active "$name"
    fi
  fi
}

# help:account:fun: account delete [--force] <name>
# help:account:txt: Delete the account with name passed as argument.
# help:account:txt: If '--force' parameter is present, then ignore if
# help:account:txt: account path exists or not, otherwise account delete
# help:account:txt: will not delete anything if path does not exists.
# help:account:txt: CAUTION: this action cannot be undone.
command_account_delete ()
{
  if [[ "$1" == "--force" ]]; then
    local force=true
    local name="$2"
  else
    local force=false
    local name="$1"
  fi

  if [[ -z "$name" ]]; then
    E=1 error $"Account command delete requires 'name',"
  elif ! account_exists "$name" && ! ${force}; then
    E=1 error $"Account '%s' does not exists." "$name"
  else
    account_delete "$name" | info_multi
  fi
}

# help:account:fun: account rebuild <name>
# help:account:txt: Recreate an account previously created. This command will
# help:account:txt: use config data to regenerate the account.
command_account_rebuild ()
{
  local name="$1" keyid push_url pull_url path

  if [[ -z "$1" ]]; then
    E=1 error $"Account command rebuild requires 'name'."
  else
    keyid="${CONFIG["account.$name.keyid"]}"
    push_url="${CONFIG["account.$name.push-url"]}"
    pull_url="${CONFIG["account.$name.pull-url"]}"
    path="${CONFIG["account.$name.path"]}"

    if [[ -z "$path" ]] || [[ -z "$push_url" ]] || [[ -z "$pull_url" ]]; then
      E=1 error $"Unable to rebuild. Account '$name' was not configured yet."
    fi

    account_clone --force "$name" "$push_url" "$pull_url" "$keyid" "$path" |
        info_multi
      config_load "${CONFIG_FILE}"
      command_account_active "$name"
    # shellcheck disable=SC2119
    command_timeline_refresh
  fi
}

# help:account:fun: account clone [--keyid <keyid>] <name> <push_url> <pull_url> [path]
# help:account:txt: Clone an account (aka git repository) from specified
# help:account:txt: push_url passed as argument, and also configure the
# help:account:txt: provided pull_url, like 'account create' does.
command_account_clone ()
{
  local keyid=

  case "$1" in
    --keyid)
        keyid="$2"
        if ! [[ "$keyid" ]]; then
          E=2 error "Account clone with --keyid flag requires keyid argument"
        fi
        shift 2
        ;;
  esac

  local name="$1" push_url="$2" pull_url="$3" path="$4"

  if [[ -z "$1" ]]; then
    E=1 error $"Account command clone requires 'name'."
  else
    if ! valid_url "$push_url"; then
      E=1 error "$INVALIDURL" "$push_url"
    elif ! valid_url "$pull_url"; then
      E=1 error "$INVALIDURL" "$pull_url"
    else
      account_clone "$name" "$push_url" "$pull_url" "$keyid" "$path" |
        info_multi
      config_load "${CONFIG_FILE}"
      command_account_active "$name"
    fi
  fi
}

# help:account:fun: account list
# help:account:txt: List all accounts registered in the configuration.
command_account_list ()
{
  account_list | info_multi
}

# help:fun: help [command]
# help:txt: show help about the command passed as argument, or, if none,
# help:txt: show all available commands.
command_help ()
{
  local data

  if [[ $# -eq 0 ]]; then
    info_multi < <(help_commands)
  else
    data="$(help_subcommand "$1")"

    if [[ "$data" ]]; then
      info_multi <<<"$data"
    else
      E=1 error $"Not found help about '%s'" "$1"
    fi
  fi
}

# help:account:fun: account active [name]
# help:account:txt: Switch to account passed as argument, or, if none, load
# help:account:txt: the default account. Default account when more than one
# help:account:txt: is created will be specified by configuration parameter
# help:account:txt: called 'account.default'.
command_account_active ()
{
  if ! account_load "$1"; then
    error $"There are no defined accounts."
    error $"Please create account: %s account create <name> <push> <pull>" "$0"
    error $"Or clone an existent one: %s account clone <name> <push> <pull>" "$0"
    E=1 error $"Account does not exist yet"
  else
    timeline_index_load
  fi
}

# help:account:fun: account keyid <keyid>
# help:account:txt: Set keydi for signing commits in the current enabled
# help:account:txt: account.
command_account_keyid ()
{
  if [[ $# -ne 1 ]]; then
    E=2 error "Account keyid requires one argument: keyid"
  else
    command_account_active "${ACCOUNT_NAME}"
    account_set_keyid "$ACCOUNT_NAME" "$1"
    config_save "${CONFIG_FILE}"
  fi
}

# help:account:fun: account refresh
# help:account:txt: Pull changes from the remote repository. This action
# help:account:txt: should be automatically and you should not use it
# help:account:txt: manually. But, if you need it, here it is.
command_account_refresh ()
{
  command_account_active "${ACCOUNT_NAME}"
  {
    account_commit "refresh: commit before pull" 2>&1 | info_multi
    account_refresh "${ACCOUNT_PATH}" 2>&1 | info_multi
    account_push "origin" 2>&1 | info_multi
  } ||
      E=1 error $"Unable to refresh local account"
}

# help:account:fun: account preview <url>
# help:account:txt: Preview a remote account without following it.
command_account_preview ()
{
  [[ "$1" ]] || E=2 error $"Account url must be provided"
  account_preview "$1"
}

# help:fun: git <command>...
# help:txt: Execute raw git commands in the active account.
command_git ()
{
  command_account_refresh
  command git -C "${ACCOUNT_PATH}" "$@"
}

# help:fun: timeline {list|refresh|info} {args...}
# help:txt: Show the current timeline
command_timeline ()
{
  local cmd="$1"; shift
  if fun "command_timeline_$cmd"; then
    "command_timeline_$cmd" "$@"
  else
    E=1 error "$NOSUBCMD" "$cmd" "timeline"
  fi
}

# help:timeline:fun: timeline list [filter]
# help:timeline:txt: Show current available timeline, but not refresh it from
# help:timeline:txt: the internet. Usually you want ot use this if you are
# help:timeline:txt: offline, else use 'timeline refresh' instead.
# help:timeline:txt: When filter is passed then only show events which match
# help:timeline:txt: with filter.
# help:timeline:txt: Valid syntax for filter is:
# help:timeline:txt:   [not] [tag|mesg|user]:[glob expr] [and|or] [filter]
command_timeline_list ()
{
  command_account_active "$ACCOUNT_NAME"
  timeline_load
  timeline_list "$@"
}

# help:timeline:fun: timeline refresh [filter]
# help:timeline:txt: Pull changes in the current enabled timeline and show
# help:timeline:txt: the results.
# shellcheck disable=SC2120
command_timeline_refresh ()
{
  command_account_refresh
  timeline_load
  timeline_list "$@"
}

# help:timeline:fun: timeline edit
# help:timeline:txt: Interactively edit your timeline. It's an advanced mode,
# help:timeline:txt: use with careful.
command_timeline_edit ()
{
  command_account_active "$ACCOUNT_NAME"
  command_account_refresh
  timeline_edit
}

# help:timeline:fun: timeline orphans
# help:timeline:txt: show the events in the timeline which are marked as
# help:timeline:txt: orphans, usually these are events that hmac does not
# help:timeline:txt: match.
command_timeline_orphans ()
{
  command_account_active "$ACCOUNT_NAME"
  timeline_load
  timeline_orphans
}

# help:fun: config {list|get|set|save|edit} {args...}
# help:txt: Change configuration settings
command_config ()
{
  local cmd="$1"; shift
  if fun "command_config_$cmd"; then
    "command_config_$cmd" "$@"
  else
    E=1 error "$NOSUBCMD" "$cmd" "config"
  fi
}

# help:config:fun: config list
# help:config:txt: List all configuration values.
command_config_list ()
{
  config_list | info_multi
}

# help:config:fun: config get <key>
# help:config:txt: Show the value of specific configuration key
command_config_get ()
{
  if [[ $# -ne 1 ]]; then
    E=1 error $"Config get requires an arguments: key"
  else
    local var
    var="${CONFIG["$*"]}"
    if [[ "$var" ]]; then
      info "%s=%s" "$*" "$var"
    else
      error $"Configuration key %s is not defined" "$*"
    fi
  fi
}

# help:config:fun: config set <key> <value>
# help:config:txt: Set a new configuration value
command_config_set ()
{
  if [[ $# -ne 2 ]]; then
    E=1 error $"Config set requires two arguments: key and value"
  else
    local key="$1"; shift
    config_set "$key" "$*"
    info "%s=%s" "$key" "$*"
    config_save "${CONFIG_FILE}"
  fi
}

# help:config:fun: config save
# help:config:txt: Save configuration into configuration file
command_config_save ()
{
  config_save "${CONFIG_FILE}"
}

# help:config:fun: config edit
# help:config:txt: Edit the configuration file using `$EDITOR`
command_config_edit ()
{
  "${EDITOR:-vi}" "${CONFIG_FILE}"
}

# help:fun: alias [<name> <value>]
# help:txt: Show aliases (if no argument provided) or created a new one
# help:txt  named as argument, and replaced by value.
command_alias ()
{
  case $# in
    0)
      for key in $(config_iter alias.); do
        info "%s=%s" "${key}" "$(config_get "${key}")"
      done
      ;;
    2)
      local name="$1"; shift
      command_config_set "alias.$name" "$*"
      ;;
    *)
      E=2 error $"Alias command requires zero or two arguments"
      ;;
  esac
}


# help:fun: user [<name> <uid>]
# help:txt: Show user aliases registered in configuration if not arguments
# help:txt: provided. If two arguments passed create a new user aliases,
# help:txt: replacing UID by nickname in timeline.
command_user ()
{
  case $# in
    0)
      for key in $(config_iter user.alias-); do
        info "%s=%s" "${key#user.alias-}" "$(config_get "${key}")"
      done
      ;;
    2)
      command_config_set "user.alias-$2" "$1"
      ;;
    *)
      E=2 error $"User command requires zero or two arguments"
      ;;
  esac
}

# help:fun: event {post|reply|tag} {args...}
# help:txt: Create new event or show information about existent one
command_event ()
{
  local cmd="$1"; shift
  if fun "command_event_$cmd"; then
    "command_event_$cmd" "$@"
  else
    E=1 error "$NOSUBCMD" "$cmd" "event"
  fi
}

# help:event:fun: event post <message> [<tags>+]
# help:event:txt: Post a new message in our timeline
command_event_post ()
{
  if [[ $# -eq 0 ]]; then
    E=2 error $"Event post required an argument: message"
  else
    local eid tag msg="$1" ts; shift
    ts="$(timestamp)"
    command_account_active "${ACCOUNT_NAME}"
    command_account_refresh
    {
      event_create "$ts" P "$msg" 2>&1
      eid="$EID"
      for tag in "$@"; do
        sleep 1  # Because we can only post one event per second.
        event_create "$ts" T "$eid" "$tag" 2>&1
      done
    } | info_multi
    timeline_load
    timeline_index_save
  fi
}

# help:event:fun: event reply [--eid] <num/eid> <message>
# help:event:txt: Post a reply to post indexed with num passed as argument,
# help:event:txt: or, if '--eid' flag is present, the EID passed as
# help:event:txt: argument.
command_event_reply ()
{
  if [[ $# -eq 0 ]]; then
    E=2 error $"Event reply requires almost two parameters: num/eid, message"
    return 1
  elif [[ "$1" = "--eid" ]]; then
    if [[ "$2" ]]; then
      eid="$2"; shift 2;
    else
      E=2 error \
        $"Event reply with --eid required almost two arguments: eid, message"
      return 1
    fi
  fi

  command_account_active "${ACCOUNT_NAME}"

  if [[ -z "$eid" ]]; then
    if ! is_decimal "$1"; then
      E=2 error $"Invalid index number '%s'" "$1"
      return 1
    else
      eid="$(timeline_index_get "$1")" || return 1
      shift
    fi
  fi

  if [[ $# -eq 0 ]]; then
    E=2 error $"Event reply required an argument: message"
  else
    local tag mesg="$1" ts; ts="$(timestamp)"; shift
    command_account_refresh
    {
      timeline_load
      event_create "$ts" R "$eid" "$mesg" 2>&1
      eid="$EID"
      for tag in "$@"; do
        sleep 1  # Because we can only post one event per second.
        event_create "$ts" T "$eid" "$tag" 2>&1
      done
    } | info_multi
    timeline_load
    timeline_index_save
  fi
}

# help:event:fun: event tag [--eid] <num/eid> <tags>
# help:event:txt: Tag a post passed as argument by index num or eid if
# help:event:txt: '--eid' flag is present.
command_event_tag ()
{
  local eid

  if [[ $# -eq 0 ]]; then
    E=2 error $"Event tag requires almost two parameters: num/eid, tags"
    return 1
  elif [[ "$1" = "--eid" ]]; then
    if [[ "$2" ]]; then
      eid="$2"; shift 2;
    else
      E=2 error \
        $"Event tag with --eid required almost two arguments: eid, tags"
      return 1
    fi
  fi

  command_account_active "${ACCOUNT_NAME}"

  if [[ -z "$eid" ]]; then
    if ! is_decimal "$1"; then
      E=2 error $"Invalid index number '%s'" "$1"
      return 1
    else
      eid="$(timeline_index_get "$1")" || return 1
      shift
    fi
  fi

  if [[ $# -eq 0 ]]; then
    E=2 error $"Event tag required an argument: tags"
  else
    command_account_refresh
    timeline_load
    event_create "$(timestamp)" T "$eid" "$*" 2>&1 | info_multi
  fi
}

# help:event:fun: event score [--eid] <num/eid> {up|down}
# help:event:txt: Score up or down an specific id. Please note that you can
# help:event:txt: only vote once fer EID, other votes will be ignored
command_event_score ()
{
  local eid score

  if [[ $# -eq 0 ]]; then
    E=2 error $"Event score requires almost two parameters: num/eid, up/down"
    return 1
  elif [[ "$1" = "--eid" ]]; then
    if [[ "$2" ]]; then
      eid="$2"; shift 2;
    else
      E=2 error \
        $"Event reply with --eid required almost two arguments: eid, up/down"
      return 1
    fi
  fi

  command_account_active "${ACCOUNT_NAME}"

  if [[ -z "$eid" ]]; then
    if ! is_decimal "$1"; then
      E=2 error $"Invalid index number '%s'" "$1"
      return 1
    else
      eid="$(timeline_index_get "$1")" || return 1
      shift
    fi
  fi

  if [[ $# -eq 0 ]]; then
    E=2 error $"Event score required an argument: up/down"
  else

    case "$1" in
      up)   score="1";;
      down) score="-1";;
    esac

    command_account_refresh
    timeline_load
    event_create "$(timestamp)" S "$eid" "$score" 2>&1 | info_multi
  fi
}

# help:event:fun: event info [--eid] <num/eid>
# help:event:txt: Given the index number of an event in the timeline,
# help:event:txt: display internal information about the event.
# help:event:txt: If '--eid' is present, then use the argument as valid
# help:event:txt: EID instead of index number.
command_event_info ()
{
  local eid

  if [[ $# -eq 0 ]]; then
    E=2 error $"Timeline info requires one parameter: num"
    return 1
  elif [[ "$1" = "--eid" ]]; then
    if [[ "$2" ]]; then
      eid="$2"
    else
      E=2 error $"Timeline info with --eid required argument: eid"
      return 1
    fi
  fi

  command_account_active "${ACCOUNT_NAME}"

  if [[ -z "$eid" ]]; then
    if ! is_decimal "$1"; then
      E=2 error $"Invalid index number '%s'" "$1"
      return 1
    else
      eid="$(timeline_index_get "$1")" || return 1
    fi
  fi

  timeline_load
  event_info "$eid" | info_multi
}

# help:fun: follow {list|add|del} {args...}
# help:txt: Manage your followings.
command_follow ()
{
  local cmd="$1"; shift
  if fun "command_follow_$cmd"; then
    "command_follow_$cmd" "$@"
  else
    E=1 error "$NOSUBCMD" "$cmd" "follow"
  fi
}

# help:follow:fun: follow list
# help:follow:txt: Lists your followings.
command_follow_list ()
{
  command_account_active "${ACCOUNT_NAME}"
  follow_list "${ACCOUNT_PATH}" | info_multi
}

# help:follow:fun: follow add <pull_url> [name]
# help:follow:txt: Add new following whose repository is available in
# help:follow:txt: 'pull_url' passed as argument.
# help:follow:txt: Optionally if name is provided, create a user alias for
# help:follow:txt: that account.
command_follow_add ()
{
  local pull_url="$1" name="$2"

  if [[ -z "$pull_url" ]]; then
    E=2 error $"Follow add require almost one argument: pull_url"
    return 2
  else
    command_account_active "${ACCOUNT_NAME}"
    follow_add "$pull_url" "$name" 2>&1 | info_multi
  fi
}

# help:follow:fun: follow del [--url] <uid/pull_url> 
# help:follow:txt: Delete a following which specific uid, or specific
# help:follow:txt: pull_url if '--url' flag is set.
command_follow_del ()
{
  local uid

  case "$1" in
    --url)
      if [[ -z "$2" ]]; then
        E=2 error $"Follow del with --urll flag requires argument: pull_url"
        return 2
      else
        uid="$(oid "$2")"
      fi;;
    *) uid="$1";;
  esac

  command_account_active "${ACCOUNT_NAME}"
  follow_del "$uid" 2>&1 | info_multi
}

# help:fun: network {list|refresh} {args...}
# help:txt: Manage the network graph and discover new users.
command_network ()
{
  local cmd="$1"; shift
  if fun "command_network_$cmd"; then
    "command_network_$cmd" "$@"
  else
    E=1 error "$NOSUBCMD" "$cmd" "network"
  fi
}

# help:network:fun: network list
# help:network:txt: Display current discovered network, but not search for
# help:network:txt: new users or update current ones.
command_network_list ()
{
  command_account_active "${ACCONT_NAME}"
  network_load "${ACCOUNT_PATH}"
  network_list
}

# help:network:fun: network refresh
# help:network:txt: Looking for new users creating network graph and print
# help:network:txt: the results into screen.
# help:network:txt: The refreshing action could take a while. This command
# help:network:txt: will traverse the timeline network from your repository,
# help:network:txt: trying to discover new users that you don't follow but
# help:network:txt: are related with people you actually follow.
command_network_refresh ()
{
  command_account_active "$ACCOUNT_NAME"
  info $"Discovering the network. This action could take a while..."
  network_refresh "$ACCOUNT_PATH" | info_multi
  info $"Network updated"
  command_network_list
}

# help:fun: quit
# help:txt: Just quits timeline :.-(
command_quit ()
{
  exit 0
}

# help:fun: view {list|add|del} {args...}
# help:txt: Create and save views. A view is a filter which can be used to
# help:txt: show or hide posts from timeline. You can think a view like a
# help:txt: name for a filter.
command_view ()
{
  local cmd="$1"; shift
  if fun "command_view_$cmd"; then
    "command_view_$cmd" "$@"
  else
    E=1 error "$NOSUBCMD" "$cmd" "view"
  fi
}

# help:view:fun: view list
# help:view:txt: List all created views
command_view_list ()
{
  for view in $(config_iter views); do
    info "$view"
  done
}

# help:view:fun: view add <name> <filter>+
# help:view:txt: Create new view named as defined in arguments
command_view_add ()
{
  local name="$1"; shift
  config_set "views.$name" "$*"
  config_save "${CONFIG_FILE}"
}


# help:view:fun: view del <name>
# help:view:txt: Delete view named as defined in arguments
command_view_del ()
{
  local name="$1"; shift
  config_unset "views.$name"
  config_save "${CONFIG_FILE}"
}


# help:fun: daemon {start|stop|kill|status} 
# help:txt: Manage daemon mode of timeline.
command_daemon ()
{
  local cmd="$1"; shift
  if fun "command_daemon_$cmd"; then
    "command_daemon_$cmd" "$@"
  else
    E=1 error "$NOSUBCMD" "$cmd" "daemon"
  fi
}

# help:daemon:fun: daemon start
# help:daemon:txt: Start daemon in background
command_daemon_start ()
{
  daemon_start
}


# help:daemon:fun: daemon stop
# help:daemon:txt: Clean stop daemon running in background
command_daemon_stop ()
{
  daemon_stop TERM
}

# help:daemon:fun: daemon kill
# help:daemon:txt: Force kill daemon running in background
command_daemon_kill ()
{
  daemon_stop KILL
}

# help:daemon:fun: daemon status
# help:daemon:txt: Show if daemon is running or not
command_daemon_status ()
{
  daemon_list
}

# help:fun: version
# help:txt: Print version number
command_version ()
{
  echo "${TIMELINE_VERSION:-Unknown version}"
}

# help:fun: directory {refresh|add|del|list|search} {args...}
# help:txt: Manage public directories
command_directory ()
{
  local cmd="$1"; shift
  if fun "command_directory_$cmd"; then
    "command_directory_$cmd" "$@"
  else
    E=1 error "$NOSUBCMD" "$cmd" "directory"
  fi
}

# help:directory:fun: refresh [directory name]
# help:directory:txt: Refresh the directory data for a specific directory or for
# help:directory:txt: all directories in the config
command_directory_refresh ()
{
  directory_refresh "$@" | info_multi
}

# help:directory:fun: add [--force] <name> <url>
# help:directory:txt: Add a new directory to the config
command_directory_add ()
{
  directory_add "$@"
  config_save "${CONFIG_FILE}"
}

# help:directory:fun: del <name>
# help:directory:txt: Delete directory from the config
command_directory_del ()
{
  [[ -z "$1" ]] && E=2 error $"Directory name is required"
  directory_del "$@"
  config_save "${CONFIG_FILE}"
}

# help:directory:fun: list
# help:directory:txt: List all directories in config
command_directory_list ()
{
  directory_list | info_multi
}

# help:directory:fun: search <regexp>+
# help:directory:txt: Search for expressions in public directories.
command_directory_search ()
{
  local exp
  for exp in "$@"; do
    directory_search "$exp"
  done | info_multi
}

# hey! you do not want to use this, only for debug purposes
if ${DEBUG:-false}; then
  command_debug ()
  {
    eval "$@"
  }
fi

# help:fun: license
# help:txt: Show timeline license
command_license ()
{
  info_multi <<EOF
                    GNU GENERAL PUBLIC LICENSE
                       Version 3, 29 June 2007

 Copyright (C) 2007 Free Software Foundation, Inc. <https://fsf.org/>
 Everyone is permitted to copy and distribute verbatim copies
 of this license document, but changing it is not allowed.

                            Preamble

  The GNU General Public License is a free, copyleft license for
software and other kinds of works.

  The licenses for most software and other practical works are designed
to take away your freedom to share and change the works.  By contrast,
the GNU General Public License is intended to guarantee your freedom to
share and change all versions of a program--to make sure it remains free
software for all its users.  We, the Free Software Foundation, use the
GNU General Public License for most of our software; it applies also to
any other work released this way by its authors.  You can apply it to
your programs, too.

  When we speak of free software, we are referring to freedom, not
price.  Our General Public Licenses are designed to make sure that you
have the freedom to distribute copies of free software (and charge for
them if you wish), that you receive source code or can get it if you
want it, that you can change the software or use pieces of it in new
free programs, and that you know you can do these things.

  To protect your rights, we need to prevent others from denying you
these rights or asking you to surrender the rights.  Therefore, you have
certain responsibilities if you distribute copies of the software, or if
you modify it: responsibilities to respect the freedom of others.

  For example, if you distribute copies of such a program, whether
gratis or for a fee, you must pass on to the recipients the same
freedoms that you received.  You must make sure that they, too, receive
or can get the source code.  And you must show them these terms so they
know their rights.

  Developers that use the GNU GPL protect your rights with two steps:
(1) assert copyright on the software, and (2) offer you this License
giving you legal permission to copy, distribute and/or modify it.

  For the developers' and authors' protection, the GPL clearly explains
that there is no warranty for this free software.  For both users' and
authors' sake, the GPL requires that modified versions be marked as
changed, so that their problems will not be attributed erroneously to
authors of previous versions.

  Some devices are designed to deny users access to install or run
modified versions of the software inside them, although the manufacturer
can do so.  This is fundamentally incompatible with the aim of
protecting users' freedom to change the software.  The systematic
pattern of such abuse occurs in the area of products for individuals to
use, which is precisely where it is most unacceptable.  Therefore, we
have designed this version of the GPL to prohibit the practice for those
products.  If such problems arise substantially in other domains, we
stand ready to extend this provision to those domains in future versions
of the GPL, as needed to protect the freedom of users.

  Finally, every program is threatened constantly by software patents.
States should not allow patents to restrict development and use of
software on general-purpose computers, but in those that do, we wish to
avoid the special danger that patents applied to a free program could
make it effectively proprietary.  To prevent this, the GPL assures that
patents cannot be used to render the program non-free.

  The precise terms and conditions for copying, distribution and
modification follow.

                       TERMS AND CONDITIONS

  0. Definitions.

  "This License" refers to version 3 of the GNU General Public License.

  "Copyright" also means copyright-like laws that apply to other kinds of
works, such as semiconductor masks.

  "The Program" refers to any copyrightable work licensed under this
License.  Each licensee is addressed as "you".  "Licensees" and
"recipients" may be individuals or organizations.

  To "modify" a work means to copy from or adapt all or part of the work
in a fashion requiring copyright permission, other than the making of an
exact copy.  The resulting work is called a "modified version" of the
earlier work or a work "based on" the earlier work.

  A "covered work" means either the unmodified Program or a work based
on the Program.

  To "propagate" a work means to do anything with it that, without
permission, would make you directly or secondarily liable for
infringement under applicable copyright law, except executing it on a
computer or modifying a private copy.  Propagation includes copying,
distribution (with or without modification), making available to the
public, and in some countries other activities as well.

  To "convey" a work means any kind of propagation that enables other
parties to make or receive copies.  Mere interaction with a user through
a computer network, with no transfer of a copy, is not conveying.

  An interactive user interface displays "Appropriate Legal Notices"
to the extent that it includes a convenient and prominently visible
feature that (1) displays an appropriate copyright notice, and (2)
tells the user that there is no warranty for the work (except to the
extent that warranties are provided), that licensees may convey the
work under this License, and how to view a copy of this License.  If
the interface presents a list of user commands or options, such as a
menu, a prominent item in the list meets this criterion.

  1. Source Code.

  The "source code" for a work means the preferred form of the work
for making modifications to it.  "Object code" means any non-source
form of a work.

  A "Standard Interface" means an interface that either is an official
standard defined by a recognized standards body, or, in the case of
interfaces specified for a particular programming language, one that
is widely used among developers working in that language.

  The "System Libraries" of an executable work include anything, other
than the work as a whole, that (a) is included in the normal form of
packaging a Major Component, but which is not part of that Major
Component, and (b) serves only to enable use of the work with that
Major Component, or to implement a Standard Interface for which an
implementation is available to the public in source code form.  A
"Major Component", in this context, means a major essential component
(kernel, window system, and so on) of the specific operating system
(if any) on which the executable work runs, or a compiler used to
produce the work, or an object code interpreter used to run it.

  The "Corresponding Source" for a work in object code form means all
the source code needed to generate, install, and (for an executable
work) run the object code and to modify the work, including scripts to
control those activities.  However, it does not include the work's
System Libraries, or general-purpose tools or generally available free
programs which are used unmodified in performing those activities but
which are not part of the work.  For example, Corresponding Source
includes interface definition files associated with source files for
the work, and the source code for shared libraries and dynamically
linked subprograms that the work is specifically designed to require,
such as by intimate data communication or control flow between those
subprograms and other parts of the work.

  The Corresponding Source need not include anything that users
can regenerate automatically from other parts of the Corresponding
Source.

  The Corresponding Source for a work in source code form is that
same work.

  2. Basic Permissions.

  All rights granted under this License are granted for the term of
copyright on the Program, and are irrevocable provided the stated
conditions are met.  This License explicitly affirms your unlimited
permission to run the unmodified Program.  The output from running a
covered work is covered by this License only if the output, given its
content, constitutes a covered work.  This License acknowledges your
rights of fair use or other equivalent, as provided by copyright law.

  You may make, run and propagate covered works that you do not
convey, without conditions so long as your license otherwise remains
in force.  You may convey covered works to others for the sole purpose
of having them make modifications exclusively for you, or provide you
with facilities for running those works, provided that you comply with
the terms of this License in conveying all material for which you do
not control copyright.  Those thus making or running the covered works
for you must do so exclusively on your behalf, under your direction
and control, on terms that prohibit them from making any copies of
your copyrighted material outside their relationship with you.

  Conveying under any other circumstances is permitted solely under
the conditions stated below.  Sublicensing is not allowed; section 10
makes it unnecessary.

  3. Protecting Users' Legal Rights From Anti-Circumvention Law.

  No covered work shall be deemed part of an effective technological
measure under any applicable law fulfilling obligations under article
11 of the WIPO copyright treaty adopted on 20 December 1996, or
similar laws prohibiting or restricting circumvention of such
measures.

  When you convey a covered work, you waive any legal power to forbid
circumvention of technological measures to the extent such circumvention
is effected by exercising rights under this License with respect to
the covered work, and you disclaim any intention to limit operation or
modification of the work as a means of enforcing, against the work's
users, your or third parties' legal rights to forbid circumvention of
technological measures.

  4. Conveying Verbatim Copies.

  You may convey verbatim copies of the Program's source code as you
receive it, in any medium, provided that you conspicuously and
appropriately publish on each copy an appropriate copyright notice;
keep intact all notices stating that this License and any
non-permissive terms added in accord with section 7 apply to the code;
keep intact all notices of the absence of any warranty; and give all
recipients a copy of this License along with the Program.

  You may charge any price or no price for each copy that you convey,
and you may offer support or warranty protection for a fee.

  5. Conveying Modified Source Versions.

  You may convey a work based on the Program, or the modifications to
produce it from the Program, in the form of source code under the
terms of section 4, provided that you also meet all of these conditions:

    a) The work must carry prominent notices stating that you modified
    it, and giving a relevant date.

    b) The work must carry prominent notices stating that it is
    released under this License and any conditions added under section
    7.  This requirement modifies the requirement in section 4 to
    "keep intact all notices".

    c) You must license the entire work, as a whole, under this
    License to anyone who comes into possession of a copy.  This
    License will therefore apply, along with any applicable section 7
    additional terms, to the whole of the work, and all its parts,
    regardless of how they are packaged.  This License gives no
    permission to license the work in any other way, but it does not
    invalidate such permission if you have separately received it.

    d) If the work has interactive user interfaces, each must display
    Appropriate Legal Notices; however, if the Program has interactive
    interfaces that do not display Appropriate Legal Notices, your
    work need not make them do so.

  A compilation of a covered work with other separate and independent
works, which are not by their nature extensions of the covered work,
and which are not combined with it such as to form a larger program,
in or on a volume of a storage or distribution medium, is called an
"aggregate" if the compilation and its resulting copyright are not
used to limit the access or legal rights of the compilation's users
beyond what the individual works permit.  Inclusion of a covered work
in an aggregate does not cause this License to apply to the other
parts of the aggregate.

  6. Conveying Non-Source Forms.

  You may convey a covered work in object code form under the terms
of sections 4 and 5, provided that you also convey the
machine-readable Corresponding Source under the terms of this License,
in one of these ways:

    a) Convey the object code in, or embodied in, a physical product
    (including a physical distribution medium), accompanied by the
    Corresponding Source fixed on a durable physical medium
    customarily used for software interchange.

    b) Convey the object code in, or embodied in, a physical product
    (including a physical distribution medium), accompanied by a
    written offer, valid for at least three years and valid for as
    long as you offer spare parts or customer support for that product
    model, to give anyone who possesses the object code either (1) a
    copy of the Corresponding Source for all the software in the
    product that is covered by this License, on a durable physical
    medium customarily used for software interchange, for a price no
    more than your reasonable cost of physically performing this
    conveying of source, or (2) access to copy the
    Corresponding Source from a network server at no charge.

    c) Convey individual copies of the object code with a copy of the
    written offer to provide the Corresponding Source.  This
    alternative is allowed only occasionally and noncommercially, and
    only if you received the object code with such an offer, in accord
    with subsection 6b.

    d) Convey the object code by offering access from a designated
    place (gratis or for a charge), and offer equivalent access to the
    Corresponding Source in the same way through the same place at no
    further charge.  You need not require recipients to copy the
    Corresponding Source along with the object code.  If the place to
    copy the object code is a network server, the Corresponding Source
    may be on a different server (operated by you or a third party)
    that supports equivalent copying facilities, provided you maintain
    clear directions next to the object code saying where to find the
    Corresponding Source.  Regardless of what server hosts the
    Corresponding Source, you remain obligated to ensure that it is
    available for as long as needed to satisfy these requirements.

    e) Convey the object code using peer-to-peer transmission, provided
    you inform other peers where the object code and Corresponding
    Source of the work are being offered to the general public at no
    charge under subsection 6d.

  A separable portion of the object code, whose source code is excluded
from the Corresponding Source as a System Library, need not be
included in conveying the object code work.

  A "User Product" is either (1) a "consumer product", which means any
tangible personal property which is normally used for personal, family,
or household purposes, or (2) anything designed or sold for incorporation
into a dwelling.  In determining whether a product is a consumer product,
doubtful cases shall be resolved in favor of coverage.  For a particular
product received by a particular user, "normally used" refers to a
typical or common use of that class of product, regardless of the status
of the particular user or of the way in which the particular user
actually uses, or expects or is expected to use, the product.  A product
is a consumer product regardless of whether the product has substantial
commercial, industrial or non-consumer uses, unless such uses represent
the only significant mode of use of the product.

  "Installation Information" for a User Product means any methods,
procedures, authorization keys, or other information required to install
and execute modified versions of a covered work in that User Product from
a modified version of its Corresponding Source.  The information must
suffice to ensure that the continued functioning of the modified object
code is in no case prevented or interfered with solely because
modification has been made.

  If you convey an object code work under this section in, or with, or
specifically for use in, a User Product, and the conveying occurs as
part of a transaction in which the right of possession and use of the
User Product is transferred to the recipient in perpetuity or for a
fixed term (regardless of how the transaction is characterized), the
Corresponding Source conveyed under this section must be accompanied
by the Installation Information.  But this requirement does not apply
if neither you nor any third party retains the ability to install
modified object code on the User Product (for example, the work has
been installed in ROM).

  The requirement to provide Installation Information does not include a
requirement to continue to provide support service, warranty, or updates
for a work that has been modified or installed by the recipient, or for
the User Product in which it has been modified or installed.  Access to a
network may be denied when the modification itself materially and
adversely affects the operation of the network or violates the rules and
protocols for communication across the network.

  Corresponding Source conveyed, and Installation Information provided,
in accord with this section must be in a format that is publicly
documented (and with an implementation available to the public in
source code form), and must require no special password or key for
unpacking, reading or copying.

  7. Additional Terms.

  "Additional permissions" are terms that supplement the terms of this
License by making exceptions from one or more of its conditions.
Additional permissions that are applicable to the entire Program shall
be treated as though they were included in this License, to the extent
that they are valid under applicable law.  If additional permissions
apply only to part of the Program, that part may be used separately
under those permissions, but the entire Program remains governed by
this License without regard to the additional permissions.

  When you convey a copy of a covered work, you may at your option
remove any additional permissions from that copy, or from any part of
it.  (Additional permissions may be written to require their own
removal in certain cases when you modify the work.)  You may place
additional permissions on material, added by you to a covered work,
for which you have or can give appropriate copyright permission.

  Notwithstanding any other provision of this License, for material you
add to a covered work, you may (if authorized by the copyright holders of
that material) supplement the terms of this License with terms:

    a) Disclaiming warranty or limiting liability differently from the
    terms of sections 15 and 16 of this License; or

    b) Requiring preservation of specified reasonable legal notices or
    author attributions in that material or in the Appropriate Legal
    Notices displayed by works containing it; or

    c) Prohibiting misrepresentation of the origin of that material, or
    requiring that modified versions of such material be marked in
    reasonable ways as different from the original version; or

    d) Limiting the use for publicity purposes of names of licensors or
    authors of the material; or

    e) Declining to grant rights under trademark law for use of some
    trade names, trademarks, or service marks; or

    f) Requiring indemnification of licensors and authors of that
    material by anyone who conveys the material (or modified versions of
    it) with contractual assumptions of liability to the recipient, for
    any liability that these contractual assumptions directly impose on
    those licensors and authors.

  All other non-permissive additional terms are considered "further
restrictions" within the meaning of section 10.  If the Program as you
received it, or any part of it, contains a notice stating that it is
governed by this License along with a term that is a further
restriction, you may remove that term.  If a license document contains
a further restriction but permits relicensing or conveying under this
License, you may add to a covered work material governed by the terms
of that license document, provided that the further restriction does
not survive such relicensing or conveying.

  If you add terms to a covered work in accord with this section, you
must place, in the relevant source files, a statement of the
additional terms that apply to those files, or a notice indicating
where to find the applicable terms.

  Additional terms, permissive or non-permissive, may be stated in the
form of a separately written license, or stated as exceptions;
the above requirements apply either way.

  8. Termination.

  You may not propagate or modify a covered work except as expressly
provided under this License.  Any attempt otherwise to propagate or
modify it is void, and will automatically terminate your rights under
this License (including any patent licenses granted under the third
paragraph of section 11).

  However, if you cease all violation of this License, then your
license from a particular copyright holder is reinstated (a)
provisionally, unless and until the copyright holder explicitly and
finally terminates your license, and (b) permanently, if the copyright
holder fails to notify you of the violation by some reasonable means
prior to 60 days after the cessation.

  Moreover, your license from a particular copyright holder is
reinstated permanently if the copyright holder notifies you of the
violation by some reasonable means, this is the first time you have
received notice of violation of this License (for any work) from that
copyright holder, and you cure the violation prior to 30 days after
your receipt of the notice.

  Termination of your rights under this section does not terminate the
licenses of parties who have received copies or rights from you under
this License.  If your rights have been terminated and not permanently
reinstated, you do not qualify to receive new licenses for the same
material under section 10.

  9. Acceptance Not Required for Having Copies.

  You are not required to accept this License in order to receive or
run a copy of the Program.  Ancillary propagation of a covered work
occurring solely as a consequence of using peer-to-peer transmission
to receive a copy likewise does not require acceptance.  However,
nothing other than this License grants you permission to propagate or
modify any covered work.  These actions infringe copyright if you do
not accept this License.  Therefore, by modifying or propagating a
covered work, you indicate your acceptance of this License to do so.

  10. Automatic Licensing of Downstream Recipients.

  Each time you convey a covered work, the recipient automatically
receives a license from the original licensors, to run, modify and
propagate that work, subject to this License.  You are not responsible
for enforcing compliance by third parties with this License.

  An "entity transaction" is a transaction transferring control of an
organization, or substantially all assets of one, or subdividing an
organization, or merging organizations.  If propagation of a covered
work results from an entity transaction, each party to that
transaction who receives a copy of the work also receives whatever
licenses to the work the party's predecessor in interest had or could
give under the previous paragraph, plus a right to possession of the
Corresponding Source of the work from the predecessor in interest, if
the predecessor has it or can get it with reasonable efforts.

  You may not impose any further restrictions on the exercise of the
rights granted or affirmed under this License.  For example, you may
not impose a license fee, royalty, or other charge for exercise of
rights granted under this License, and you may not initiate litigation
(including a cross-claim or counterclaim in a lawsuit) alleging that
any patent claim is infringed by making, using, selling, offering for
sale, or importing the Program or any portion of it.

  11. Patents.

  A "contributor" is a copyright holder who authorizes use under this
License of the Program or a work on which the Program is based.  The
work thus licensed is called the contributor's "contributor version".

  A contributor's "essential patent claims" are all patent claims
owned or controlled by the contributor, whether already acquired or
hereafter acquired, that would be infringed by some manner, permitted
by this License, of making, using, or selling its contributor version,
but do not include claims that would be infringed only as a
consequence of further modification of the contributor version.  For
purposes of this definition, "control" includes the right to grant
patent sublicenses in a manner consistent with the requirements of
this License.

  Each contributor grants you a non-exclusive, worldwide, royalty-free
patent license under the contributor's essential patent claims, to
make, use, sell, offer for sale, import and otherwise run, modify and
propagate the contents of its contributor version.

  In the following three paragraphs, a "patent license" is any express
agreement or commitment, however denominated, not to enforce a patent
(such as an express permission to practice a patent or covenant not to
sue for patent infringement).  To "grant" such a patent license to a
party means to make such an agreement or commitment not to enforce a
patent against the party.

  If you convey a covered work, knowingly relying on a patent license,
and the Corresponding Source of the work is not available for anyone
to copy, free of charge and under the terms of this License, through a
publicly available network server or other readily accessible means,
then you must either (1) cause the Corresponding Source to be so
available, or (2) arrange to deprive yourself of the benefit of the
patent license for this particular work, or (3) arrange, in a manner
consistent with the requirements of this License, to extend the patent
license to downstream recipients.  "Knowingly relying" means you have
actual knowledge that, but for the patent license, your conveying the
covered work in a country, or your recipient's use of the covered work
in a country, would infringe one or more identifiable patents in that
country that you have reason to believe are valid.

  If, pursuant to or in connection with a single transaction or
arrangement, you convey, or propagate by procuring conveyance of, a
covered work, and grant a patent license to some of the parties
receiving the covered work authorizing them to use, propagate, modify
or convey a specific copy of the covered work, then the patent license
you grant is automatically extended to all recipients of the covered
work and works based on it.

  A patent license is "discriminatory" if it does not include within
the scope of its coverage, prohibits the exercise of, or is
conditioned on the non-exercise of one or more of the rights that are
specifically granted under this License.  You may not convey a covered
work if you are a party to an arrangement with a third party that is
in the business of distributing software, under which you make payment
to the third party based on the extent of your activity of conveying
the work, and under which the third party grants, to any of the
parties who would receive the covered work from you, a discriminatory
patent license (a) in connection with copies of the covered work
conveyed by you (or copies made from those copies), or (b) primarily
for and in connection with specific products or compilations that
contain the covered work, unless you entered into that arrangement,
or that patent license was granted, prior to 28 March 2007.

  Nothing in this License shall be construed as excluding or limiting
any implied license or other defenses to infringement that may
otherwise be available to you under applicable patent law.

  12. No Surrender of Others' Freedom.

  If conditions are imposed on you (whether by court order, agreement or
otherwise) that contradict the conditions of this License, they do not
excuse you from the conditions of this License.  If you cannot convey a
covered work so as to satisfy simultaneously your obligations under this
License and any other pertinent obligations, then as a consequence you may
not convey it at all.  For example, if you agree to terms that obligate you
to collect a royalty for further conveying from those to whom you convey
the Program, the only way you could satisfy both those terms and this
License would be to refrain entirely from conveying the Program.

  13. Use with the GNU Affero General Public License.

  Notwithstanding any other provision of this License, you have
permission to link or combine any covered work with a work licensed
under version 3 of the GNU Affero General Public License into a single
combined work, and to convey the resulting work.  The terms of this
License will continue to apply to the part which is the covered work,
but the special requirements of the GNU Affero General Public License,
section 13, concerning interaction through a network will apply to the
combination as such.

  14. Revised Versions of this License.

  The Free Software Foundation may publish revised and/or new versions of
the GNU General Public License from time to time.  Such new versions will
be similar in spirit to the present version, but may differ in detail to
address new problems or concerns.

  Each version is given a distinguishing version number.  If the
Program specifies that a certain numbered version of the GNU General
Public License "or any later version" applies to it, you have the
option of following the terms and conditions either of that numbered
version or of any later version published by the Free Software
Foundation.  If the Program does not specify a version number of the
GNU General Public License, you may choose any version ever published
by the Free Software Foundation.

  If the Program specifies that a proxy can decide which future
versions of the GNU General Public License can be used, that proxy's
public statement of acceptance of a version permanently authorizes you
to choose that version for the Program.

  Later license versions may give you additional or different
permissions.  However, no additional obligations are imposed on any
author or copyright holder as a result of your choosing to follow a
later version.

  15. Disclaimer of Warranty.

  THERE IS NO WARRANTY FOR THE PROGRAM, TO THE EXTENT PERMITTED BY
APPLICABLE LAW.  EXCEPT WHEN OTHERWISE STATED IN WRITING THE COPYRIGHT
HOLDERS AND/OR OTHER PARTIES PROVIDE THE PROGRAM "AS IS" WITHOUT WARRANTY
OF ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO,
THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
PURPOSE.  THE ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE PROGRAM
IS WITH YOU.  SHOULD THE PROGRAM PROVE DEFECTIVE, YOU ASSUME THE COST OF
ALL NECESSARY SERVICING, REPAIR OR CORRECTION.

  16. Limitation of Liability.

  IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MODIFIES AND/OR CONVEYS
THE PROGRAM AS PERMITTED ABOVE, BE LIABLE TO YOU FOR DAMAGES, INCLUDING ANY
GENERAL, SPECIAL, INCIDENTAL OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE
USE OR INABILITY TO USE THE PROGRAM (INCLUDING BUT NOT LIMITED TO LOSS OF
DATA OR DATA BEING RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD
PARTIES OR A FAILURE OF THE PROGRAM TO OPERATE WITH ANY OTHER PROGRAMS),
EVEN IF SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.

  17. Interpretation of Sections 15 and 16.

  If the disclaimer of warranty and limitation of liability provided
above cannot be given local legal effect according to their terms,
reviewing courts shall apply local law that most closely approximates
an absolute waiver of all civil liability in connection with the
Program, unless a warranty or assumption of liability accompanies a
copy of the Program in return for a fee.

                     END OF TERMS AND CONDITIONS

            How to Apply These Terms to Your New Programs

  If you develop a new program, and you want it to be of the greatest
possible use to the public, the best way to achieve this is to make it
free software which everyone can redistribute and change under these terms.

  To do so, attach the following notices to the program.  It is safest
to attach them to the start of each source file to most effectively
state the exclusion of warranty; and each file should have at least
the "copyright" line and a pointer to where the full notice is found.

    <one line to give the program's name and a brief idea of what it does.>
    Copyright (C) <year>  <name of author>

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>.

Also add information on how to contact you by electronic and paper mail.

  If the program does terminal interaction, make it output a short
notice like this when it starts in an interactive mode:

    <program>  Copyright (C) <year>  <name of author>
    This program comes with ABSOLUTELY NO WARRANTY; for details type \`show w'.
    This is free software, and you are welcome to redistribute it
    under certain conditions; type \`show c' for details.

The hypothetical commands \`show w' and \`show c' should show the appropriate
parts of the General Public License.  Of course, your program's commands
might be different; for a GUI interface, you would use an "about box".

  You should also get your employer (if you work as a programmer) or school,
if any, to sign a "copyright disclaimer" for the program, if necessary.
For more information on this, and how to apply and follow the GNU GPL, see
<https://www.gnu.org/licenses/>.

  The GNU General Public License does not permit incorporating your program
into proprietary programs.  If your program is a subroutine library, you
may consider it more useful to permit linking proprietary applications with
the library.  If this is what you want to do, use the GNU Lesser General
Public License instead of this License.  But first, please read
<https://www.gnu.org/licenses/why-not-lgpl.html>.
EOF
}
#! /usr/bin/env bash
# 
# Copyright (C) 2016  Andrés J. Díaz <ajdiaz@ajdiaz.me>
# 
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

# env: INTERACTIVE: if true, then interactive mode is enabled
export INTERACTIVE=

# env: CONFIG_FILE: should contain the path to the config file
export CONFIG_FILE=

# env: CACHE_DIR: should contain the path to the cache directory
export CACHE_DIR=

# fun: prompt
# txt: print prompt in interactive mode
prompt ()
{
  format_compose prompt account "${ACCOUNT_NAME:-<none>}"
  format_dumps prompt
}

# fun: main_interactive
# txt: evaluate commands in interactive mode
main_interactive ()
{
  local cmd
  local -a args

  history_load
  complete_load
  command_account_active "${ACCOUNT_NAME}"

  while true; do
    read -a args -e -r -p "$(T=true prompt)"
    [ $? -eq 1 ] && break
    cmd="${args[0]}"
    local -a args=( "${args[@]:1}" )

    [ "$cmd" ] || continue
    history_append "$cmd ${args[*]}"
    main_standalone "$cmd" "${args[@]}"
  done
  history_save
}

# fun: main_standalone <cmd> [args]...
# txt: evaluate command passed as argument
main_standalone ()
{
  local cmd="$1"; shift

  if fun "command_$cmd"; then
    "command_$cmd" "$@"
  else
    read -ra alias <<< "${CONFIG["alias.$cmd"]}"

    if [[ "${alias[*]}" ]]; then
      main_standalone "${alias[@]}" "$@"
    else
      E=2 fatal $"Invalid command '%s'." "$cmd"
    fi
  fi
}

# fun: main [args]...
# txt: entry point :D
main ()
{
  local config_path="$HOME/.config/tl/config:$HOME/.tl/config:$HOME/.tlrc"
  local major minor ver

  # check BASH
  if [[ "${BASH_VERSINFO[0]}" -lt 5 ]]; then
    E=1 error $"bash >= 5 is required"
  fi
  
  CONFIG_FILE="$(try_path "$config_path")"
  INTERACTIVE=false

  reqs_eval

  # check git version since it's a core requirement
  read -r _ _ ver < <(git --version)
  IFS=. read -r major minor _ <<<"$ver"

  if [[ "$major" -lt "2" ]] || [[ "$minor" -lt 30 ]]; then
    E=1 error $"git version >= 2.30 is required"
  fi

  # accept commands like tl-account as symlink to tl
  case "${0##*/}" in
    tl-*) set -- "${0##*/tl-}" "$@";;
  esac

  args_eval "$@" || shift $?

  [[ -r "${CONFIG_FILE}" ]] && config_load "${CONFIG_FILE}"
  [[ "$ACCOUNT_NAME" ]] && command_account_active "$ACCOUNT_NAME"


  CACHE_DIR="$(try_path "$(config_get cache.path)")"
  mkdir -p "${CACHE_DIR}"

  # local the OID cache if enabled
  oid_load

  if [ $# -eq 0 ]; then
    if [[ "${CONFIG[interactive.show-banner]}" = "true" ]]; then
      info "timeline  Copyright (C) %(%Y)T Andrés J. Díaz" "$(timestamp)"
      info "This program comes with ABSOLUTELY NO WARRANTY; for details"
      info "type 'license'. This is free software, and you are welcome to"
      info "redistribute it under certain conditions; type 'license' for"
      info "details."
    fi

    INTERACTIVE=true
    main_interactive "$@"
  else
    main_standalone "$@"
  fi

  oid_save
}
## vim:ft=sh

# env: EID: store the last EID created
export EID=

# env: EVENT: associative array which contains parts of an event line.
declare -A EVENTS_KIND=()
declare -A EVENTS_DATE=()
declare -A EVENTS_LINK=()
declare -A EVENTS_TAGS=()
declare -A EVENTS_MESG=()
declare -A EVENTS_SIGN=()
declare -A EVENTS_SCORE=()
declare -A EVENTS_COMMIT=()

declare -A EVENTS_CROSS_REPLY=()
declare -A EVENTS_CROSS_TAGS=()
declare -A EVENTS_CROSS_SCORE=()
declare -a EVENTS_SORTED=()

ERR_TIME_DUPLICATED=$"Duplicated timestamp for events %s and %s"

# fun: event_load <account_id> <filename>
# txt: given an content filename, parse it and store events in memory
event_load ()
{
  local max_user_posts fname="$2" account="$1" key val
  local commit line aname="${CONFIG["user.alias-$account"]:-$account}"
  local -A gitlog

  max_user_posts="${CONFIG["account.${aname}.max-posts"]:-${CONFIG[account.max-posts]:-20}}"

  while read -r key val; do
    gitlog["$key"]="$val"
  done < <(
    command git -C "${fname%/*}" log -s --pretty=format:"%H %G?" \
      --no-color "$fname"
  )

  _i() {
    case "${2}" in
      ''|\#*) return
    esac

    commit="${2%% *}";
    line="${2#$commit *) }";

    event_load_line "$account" "${fname%/*}" "$commit" \
      "${gitlog["$commit"]}" "${line}" "$1"
  }

  # shellcheck disable=SC2034
  mapfile -c 1 -n "${max_user_posts}" -C _i < <(
    command git -C "${fname%/*}" blame -s -l "$fname"
  )
}

# fun: event_load_line <account_id> <commit> <flags> <content>
# txt: parse a event line passed as argument and fill properly fields in
#      a associative array called EVENT. The account id is the OID
#      associated to the pull_url of the account.
#
#      The POST kind has the fields: timestamp,kind,message
#      The REPLY kind has the fields: timestamp,kind,ref,message
#      The TAG kind has the fields: timestamp,kind,ref,tags
#      The SCORE kind has the fields: timestamp,kind,ref,score
event_load_line ()
{
  local aid="$1" fname="$2" commit="$3" flags="$4" line="${5%$'\n'}"
  local datet="${line%% *}" idx
  local kind="${line#$datet }"; kind="${kind%% *}"
  local rest="${line#$datet $kind }"
  local link mesg tags score hmac='' eid show_untrusted

  idx="$(( ${datet}000 + $6 ))"

  show_untrusted="${CONFIG["timeline.show-untrusted-items"]}"

  case "$kind" in
    P|POST)
      mesg="$rest"
      kind='post'
      oid "$mesg"
      hmac="${OID_CACHE["$mesg"]}"
      ;;
    R|REPLY)
      link="${rest%% *}"
      mesg="${rest#$link }"
      kind='reply'
      oid "$mesg"
      hmac="${OID_CACHE["$mesg"]}"
      ;;
    T|TAG)
      link="${rest%% *}"
      tags="${rest#$link }"
      kind='tag'
      oid "$link $tags"
      hmac="${OID_CACHE["$link $tags"]}"
      ;;
    S|SCORE)
      kind='score'
      link="${rest%% *}"
      score="${rest#$link }"
      case "$score" in
        -1) score="-1";;
        *) score="1";;
      esac
      oid "$link $score"
      hmac="${OID_CACHE["$link $score"]}"
      ;;
    *)
      error $"Ignored malformed event: '$line'"
      return 0
      ;;
  esac

  if [[ "$show_untrusted" = "true" ]]; then
    eid="$aid:$datet"
    case "$link" in
      *:*:*) flags+="*"; link="${link%:*}";;
    esac
  else
    eid="$aid:$datet:$hmac"
  fi

  EVENTS_KIND["$eid"]="$kind"
  EVENTS_DATE["$eid"]="$datet"
  EVENTS_LINK["$eid"]="$link"
  EVENTS_TAGS["$eid"]="$tags"
  EVENTS_MESG["$eid"]="$mesg"
  EVENTS_SIGN["$eid"]="$flags"
  EVENTS_COMMIT["$eid"]="$fname $commit"

  # XXX some array abused. Because arrays allows any index number, and are
  # sorted by definition, we do not need to sort anything.
  EVENTS_SORTED["$idx"]="$eid"

  if [[ "$kind" = 'reply' ]]; then
    EVENTS_CROSS_REPLY[$link]+=" $eid "
  elif [[ "$kind" = 'tag' ]]; then
    EVENTS_CROSS_TAGS[$link]+=" $eid "
  elif [[ "$kind" = 'score' ]]; then
    if ! [[ "${EVENTS_CROSS_SCORE[$aid:$link]}" ]]; then
      EVENTS_CROSS_SCORE["$aid:$link"]=1
      (( EVENTS_SCORE["$link"]+=score ))
    fi
  fi

  [[ "$ACCOUNT_NAME" ]] && notify "$eid"
}

# fun: event_sign <eid>
# txt: return true if EID is signed
event_sign ()
{
  echo "${EVENTS_SIGN[$1]}"
}

# fun: event_replies <eid>
# txt: given an specific eid return the eids of the replies of that post
event_replies ()
{
  local -a sorted_replies=()
  local idx

  for reply in ${EVENTS_CROSS_REPLY["$1"]}; do
    idx="${reply#*:}"; idx="${idx%%:*}$(printf %03d "$((RANDOM % 100))")"
    [[ "$reply" = "$1" ]] && E=3 error "$ERR_TIME_DUPLICATED" "$label" "$1"
    sorted_replies[$idx]="$reply"
  done

  echo "${sorted_replies[@]}"
}

# fun: event_labels <eid>
# txt: given an specific eid return the eids of the tags of that post
event_labels ()
{
  local -a sorted_labels=()
  local idx

  for label in ${EVENTS_CROSS_TAGS["$1"]}; do
    idx="${label#*:}"; idx="${idx%%:*}$(printf %03d "$((RANDOM % 100))")"
    [[ "$label" = "$1" ]] && E=3 error "$ERR_TIME_DUPLICATED" "$label" "$1"
    sorted_labels[$idx]="$label"
  done

  echo "${sorted_labels[@]}"
}

# fun: event_score <eid>
# txt: return the score of the specified event
event_score ()
{
  echo "${EVENTS_SCORE[$1]:-0}"
}

# fun: event_iter
# txt: print a list of events saved in memory
event_iter ()
{
  echo "${EVENTS_SORTED[@]}"
}

# fun: event_kind <eid>
# txt: given an event id, get the kind of the event
event_kind ()
{
  echo "${EVENTS_KIND["$1"]}"
}

# fun: event_date <eid>
# txt: given an event id, get the date of the event
event_date ()
{
  echo "${EVENTS_DATE["$1"]}"
}

# fun: event_link <eid>
# txt: given an event id, get the link of the event (only for TAGS and
#      REPLIES)
event_link ()
{
  echo "${EVENTS_LINK["$1"]}"
}

# fun: event_tags <eid>
# txt: given an event id, get the tags of the event (only for TAGS)
event_tags ()
{
  echo "${EVENTS_TAGS["$1"]}"
}

# fun: event_mesg <eid>
# txt: given an event id, get the message of the event (only for REPLY and
#      POST)
event_mesg ()
{
  echo "${EVENTS_MESG["$1"]}"
}

# fun: event_create <args>
# txt: create new event. Args can vary depends of event type, the order of
#      the arguments should be:
#      For posts: date kind mesg
#      For reply: date kind link mesg
#      For tags:  date kind link tags
# env: EID: set this variable to the value of the EID to the created element.
event_create ()
{
  local auto_push content_markdown mesg line l
  local -a content

  auto_push="${CONFIG["account.${ACCOUNT_NAME}.auto-push"]}"

  if ! [[ "$auto_push" ]]; then
    auto_push="$(config_get account.auto-push)"
  fi

  EID="$ACCOUNT_OID:$1"

  case "$2" in
    P) mesg="$3"; line="$*";;
    R|T|S)
      mesg="$4"
      case "$3" in
        *:*:*) line="$*" ;;
        *:*)
          if [[ "${EVENTS_MESG["$3"]}" ]]; then
            oid "${EVENTS_MESG["$3"]}"
            line="$1 $2 $3:${OID_CACHE["${EVENTS_MESG["$3"]}"]} $4"
          else
            E=1 error $"Try to reference a non-existant EID: $3"
          fi;;
        *) E=1 error $"Invalid EID reference: $*";;
      esac;;
  esac
  oid "$mesg"
  EID+=":${OID_CACHE["$mesg"]}"

  mapfile -t content < "${ACCOUNT_PATH}/$TIMELINE_CONTENT"

  echo "$line" > "${ACCOUNT_PATH}/$TIMELINE_CONTENT"
  for l in "${content[@]}"; do
    echo "$l" >> "${ACCOUNT_PATH}/$TIMELINE_CONTENT"
  done

  content_markdown="${CONFIG["account.${ACCOUNT_NAME}.content-markdown"]}"

  if ! [[ "$content_markdown" ]]; then
    content_markdown="${CONFIG[account.content-markdown]}"
  fi

  if [[ "$content_markdown" = "true" ]]; then
    markdown_generate
  fi

  account_commit "event: $line"

  if [[ "$auto_push" = "true" ]]; then
    account_push
  fi
}

# fun: event_info <eid>
# txt: given an eid, print the infortmation related with this event
event_info ()
{
  local eid="$1" date kind mesg tags reply link tag

  date="${EVENTS_DATE["$1"]}"
  kind="${EVENTS_KIND["$1"]}"

  if [[ -z "$kind" ]]; then
    E=1 error $"Not found information for EID '$eid'"
    return 1
  fi

  mesg="${EVENTS_MESG["$eid"]}"
  tags="${EVENTS_TAGS["$eid"]}"
  link="${EVENTS_LINK["$eid"]}"
  
  printf $"%-10s %s\n" "EID:"   "$eid"
  printf $"%-10s %s (%s)\n" "UID:"   "${eid%%:*}" "$(username "$eid")"
  # shellcheck disable=SC2183
  printf $"%-10s %s (%(%Y-%m-%d %H:%M:%S)T)\n" "Date:"  "$date" "$date"
  printf $"%-10s %s\n" "Kind:"   "${kind^^}"
  printf $"%-10s %s\n" "Link:"   "${link}"
  printf $"%-10s %s\n" "Tags:"   "${tags}"
  printf $"%-10s %s\n" "Mesg:"   "${mesg}"
  printf $"Tagged by:\n"

  local -A taggedas=()
  for item in $(event_labels "$eid"); do
    printf "  -  %s\n" "$item"
    for tag in ${EVENTS_TAGS["$item"]}; do
      taggedas["$tag"]=1
    done
  done
  printf $"Tagged as:\n"
  for item in "${!taggedas[@]}"; do
    printf "  -  %s\n" "$item"
  done
  printf $"Replied by:\n"
  for item in $(event_replies "$eid"); do
    printf "  -  %s\n" "$item"
  done

  case "${EVENTS_SIGN["$eid"]}" in
    G|B|U|X|Y|R|E)
      printf "Signed: Yes\n"
      printf "Signature information:\n"

      command git -C "${EVENTS_COMMIT["$eid"]%% *}" \
        verify-commit "${EVENTS_COMMIT["$eid"]##* }" 2>&1
      ;;
    *)
      printf "Signed: No\n"
      ;;
  esac
}
## vim:ft=sh

# fun: notify <eid>
# txt: send notification for specified eid if match the notification filter.
notify ()
{
  local user uid="${1%%:*}" date="${1#*:}"
  local date="${date%%:*}" last_date=0
  local fexpr ncommand="${CONFIG[notify.command]}"

  [[ "$ncommand" ]] || return 0

  last_date_file="${CONFIG[notify.cache-file]:-${HOME}/.cache/tl/notify.cache}"
  [[ -r "${last_date_file}" ]] && 
    last_date="$(< "$last_date_file")"

  # discard old events
  [[ "$date" -le "${last_date}" ]] &&
    return

  # discard own events
  user="${ACCOUNT_OID}"
  [[ "$uid" = "$user" ]] &&
    return

  fexpr="${CONFIG[notify.filter]}"

  if [[ "$fexpr" ]] && filter_eval "$1" "$fexpr"; then
    # shellcheck disable=SC2059
    "$ncommand" "$(printf "${CONFIG[notify.format]:-%s %s}" \
      "$(username "$uid")")" \
      "${EVENTS_MESG[$eid]}"

    echo "$date" > "${last_date_file}"
  fi
}
## vim: ft=sh

# env: OID_CACHE
# txt: save a generated oids to avoid recalculation
declare -gA OID_CACHE

# fun: fun <function_name>
# txt: return true if function is defined
fun ()
{
  declare -f "$1" >/dev/null 2>&1
}

# fun: mute <command> [args]
# txt: run command quietly
mute ()
{
  "$@" >/dev/null 2>&1
}

# fun: timestamp
# txt: print current timestamp in UTC
timestamp ()
{
  # shellcheck disable=SC2183
  printf "%(%s)T"
}

# fun: join <delim> <array_items>
# txt: return a delim separated list of array_items
join ()
{
  local delim="$1"; shift
  for x in "$@"; do
    printf "%s%s" "$x" "$delim"
  done
}

# fun: oid <string>
# txt: create a unique object id for the string passed as argument
oid ()
{
  if [[ -z "${OID_CACHE["$1"]}" ]]; then
    OID_CACHE["$1"]="$(command git hash-object --stdin <<<"${1%.git}")"
  fi
}

# fun: oid_save
# txt: save the list of OIDs to a cache file
oid_save ()
{
  local i=0
  [[ "${CONFIG[oid.use-cache]}" != "true" ]] && return
  {
    echo "declare -Axg OID_CACHE=("
    for key in "${!OID_CACHE[@]}"; do
      echo "[\"$key\"]=\"${OID_CACHE[$key]}\""
      [[ $((++i)) -gt ${CONFIG[oid.max-cache-size]:-1000} ]] && break
    done
    echo ")"
  } > "${CACHE_DIR}/oid.cache"
}

# fun: oid_load
# txt: load precalculated OIDs from cache file
oid_load ()
{
  [[ "${CONFIG[oid.use-cache]}" != "true" ]] && return

  # shellcheck source=/dev/null
  [[ -r "${CACHE_DIR}/oid.cache" ]] &&
    source "${CACHE_DIR}/oid.cache"
}

# fun: try_path <path_list>
# txt: given a path list, return the first existant item in the list, or, if
#      none exists, the first one. NOTE: this function does not allow colons
#      in path items.
try_path ()
{
  local IFS=':'
  for path in $1; do
    if [ -d "$path" ]; then
      echo "$path"
      return
    fi
  done
  echo "${1%%:*}"
}

# fun: valid_url <url>
# txt: return true if url is valid, otherwise return false
valid_url ()
{
  case "$1" in
    ssh://*|http://*|https://*) return 0
  esac
  return 1
}

# fun: has_hmac <eid>
# txt: return true if the eid has an hmac
has_hmac ()
{
  local hmac; hmac="${1#*:}"
  [[ "${hmac}" != "${hmac#*:}" ]]
}

# fun: username <eid|account_id>
# txt: return username from a event_id or account_id using alias defined in
#      configuration and short form if 'timeline.use-short-ids' is true.
username ()
{
  local uname="$1"
  
  uname="${uname%%:*}" # remove timestamp if present
  uname="${uname#@}"  # remove trail @ if present

  alias_name="${CONFIG["user.alias-$uname"]}"
  short_ids="${CONFIG["timeline.use-short-ids"]}"

  if [[ "$alias_name" ]]; then
    uname="$alias_name"
  elif [[ "$short_ids" = "true" ]]; then
    uname="${uname:0:8}"
  fi

  echo "@${uname}"
}

# fun: is_decimal <num>
# txt: return true if num is a decimal based number.
is_decimal () {
  [[ "$1" = "0" ]] && return 0
  mute let i="10#${1#-}" 2>/dev/null
}

# fun: keyid <name>
# txt: get the keyid configured for account name passed as argument
keyid ()
{
  echo "${CONFIG[account.$1.keyid]:-${CONFIG[account.keyid]}}"
}

# fun: any <list> <list>
# txt: return true if any element of the first list is also in the second
#      list.
any ()
{
  case "$1" in
    '*'|"$2") return 0;;
    '') return 1;;
  esac

  local -A list

  for item in $1; do
    list["$item"]=1
  done

  for item in $2; do
    [[ "${list["$item"]}" ]] && return 0
  done
  return 1
}

# fun: on_exit <callback>
# txt: run callback on exit
declare -a _on_exit=()
trap _handler_on_exit EXIT
_handler_on_exit ()
{
  local fun
  for fun in "${_on_exit[@]}"; do
    "$fun";
  done
}
on_exit ()
{
  _on_exit+=( "$1" )
}

# fun: temp_file
# txt: outputs a temporary file which will ensure that will be eliminated
#      when exectution ends.
temp_file ()
{
  local name="${TMPDIR:-/tmp}/temp_$$.$RANDOM"
  : > "$name"
  echo "$name"
}
_temp_file_exit ()
{
  rm -f "${TMPDIR:-/tmp}/temp_$$".*
}
on_exit _temp_file_exit

# fun: temp_dir
# txt: outputs a temporary directory which will be removed when tl dies
temp_dir ()
{
  local name="${TMPDIR:-/tmp}/tempdir_$$.$RANDOM"
  mkdir -p "$name"
  echo "$name"
}
_temp_dir_exit ()
{
  rm -rf "${TMPDIR:-/tmp}/tempdir_$$".*
}
on_exit _temp_dir_exit
## vim:ft=sh

# env: TIMELINE_OLD: a $IFS separated line contains the last load
#      indexes.
TIMELINE_OLD=

# env: TIMELINE_CONTENT: The path relative to the account root, where
#      CONTENT file is stored.
TIMELINE_CONTENT="CONTENT"

# env: TIMELINE_FOLLOW The path relative to the account root, where
#      FOLLOW dir is located.
TIMELINE_FOLLOW="FOLLOW"

# env: TIMELINE_PRINTED: Internal associative array which contains the EID
#      of events alredy printed to avoid duplicates.
declare -A TIMELINE_PRINTED=()

# env: TIMELINE_INDEX: Internal array used to print an index in timeline to
#      easy refer to an event
declare -a TIMELINE_INDEX=()

# fun: timeline_load [path] [oid]
# txt: load the timeline from current active account into memory
timeline_load ()
{
  local oid="$2" content_path follow_path show_own path="$1"

  if [[ -z "$path" ]]; then
    path="${ACCOUNT_PATH}"
    oid="${ACCOUNT_OID}"
  fi

  content_path="$path/$TIMELINE_CONTENT"
  follow_path="$path/$TIMELINE_FOLLOW"
  show_own="${CONFIG["timeline.own-posts"]}"
  pattern=("⣾" "⣽" "⣻" "⢿" "⡿" "⣟" "⣯" "⣷")

  if ! [[ -r "$content_path" ]]; then
    error $"Content path does not exists."
    error $"Maybe you delete your account data?"
    E=1 error $"Try $0 account rebuild ${ACCOUNT_NAME} to recreate it automatically"
  fi

  # Load our account timeline
  [[ "$show_own" = "false" ]] ||
    event_load "$oid" "${content_path}"

  local dir i=0

  if [[ -d "${follow_path}" ]]; then
    for dir in "${follow_path}"/*; do
      [[ -d "$dir" ]] || continue  # ignore non-dir files
      [[ -r "$dir/$TIMELINE_CONTENT" ]] || continue # ignore non initialized

      dir="${dir%/}"
      echo -en "\r${pattern[$((i % ${#pattern[@]}))]}\r"
      event_load "${dir##*/}" "${dir}/$TIMELINE_CONTENT"
    done
  fi
}

# fun: timeline_hide_thread <eid>
# txt: hide the thread of the specific EID
timeline_hide_thread ()
{
  TIMELINE_PRINTED["$1"]=1
  for event in $(event_labels "$1"); do
    timeline_hide_thread "$event"
  done
  for event in $(event_replies "$1"); do
    timeline_hide_thread "$event"
  done
  return 0
}

# fun: timeline_show_thread <eid>
# txt: show the thread of the specific EID
timeline_show_thread ()
{
  unset TIMELINE_PRINTED["$1"]
  for event in $(event_labels "$1"); do
    timeline_show_thread "$event"
  done
  for event in $(event_replies "$1"); do
    timeline_show_thread "$event"
  done
  return 0
}

# fun: timeline_list_thread <eid>
# txt: print thread for specific eid passed as argument
timeline_list_thread ()
{
  local prefix indent date kind mesg tags link name eid="$1"
  local flag show_tags show_replies flags=''

  # item is already printed? then do nothing
  [[ "${TIMELINE_PRINTED["$eid"]}" ]] && return

  date="${EVENTS_DATE["$eid"]}"
  kind="${EVENTS_KIND["$eid"]}"
  name="$(username "$eid")"
  sign="${EVENTS_SIGN["$eid"]}"

  case "$kind" in
    post)
      mesg="${EVENTS_MESG["$eid"]}"
      ;;
    tag)
      tags="${EVENTS_TAGS["$eid"]// /, }"
      # shellcheck disable=SC2153
      link="${EVENTS_LINK["$eid"]}"
      ;;
    reply)
      mesg="${EVENTS_MESG["$eid"]}"
      link="${EVENTS_LINK["$eid"]}"
      ;;
  esac

  indent="${CONFIG["timeline.$kind.indent"]}"
  prefix="${CONFIG["timeline.$kind.prefix"]}"

  case "${sign}" in
    G*) flags+="${CONFIG["timeline.$kind.flag-signed-good"]}";;
    B*) flags+="${CONFIG["timeline.$kind.flag-signed-bad"]}";;
    U*) flags+="${CONFIG["timeline.$kind.flag-signed-unknown"]}";;
    X*|Y*) flags+="${CONFIG["timeline.$kind.flag-signed-expired"]}";;
    R*) flags+="${CONFIG["timeline.$kind.flag-signed-revoked"]}";;
    E*) flags+="${CONFIG["timeline.$kind.flag-signed-missing"]}";;
    *) flags+="${CONFIG["timeline.$kind.flag-signed-none"]}";;
  esac

  if [[ "${CONFIG["timeline.show-untrusted-items"]}" = "true" ]]; then
    [[ "${sign//\*/}" != "${sign}" ]] &&
      flags+="${CONFIG["timeline.$kind.flag-trusted"]}" ||
      flags+=' '
  fi

  if [[ "${TIMELINE_OLD//$eid/}" = "${TIMELINE_OLD}" ]]; then
    flags+="${CONFIG["timeline.$kind.flag-new"]}"
  else
    flags+=" "
  fi

  # composing the output
  format_compose "timeline.$kind" index "${#TIMELINE_INDEX[@]}"
  format_compose "timeline.$kind" name "$name"
  format_compose "timeline.$kind" date "$date"
  format_compose "timeline.$kind" tags "${2}${indent}${prefix}${tags}"
  format_compose "timeline.$kind" link "$link"
  format_compose "timeline.$kind" score "${EVENTS_SCORE["$eid"]}"
  format_compose "timeline.$kind" mesg "${2}${indent}${prefix}${mesg}"

  TIMELINE_PRINTED["$eid"]=1
  TIMELINE_INDEX+=( "$eid" )

  show_tags="${CONFIG["timeline.show-tags"]}"
  show_replies="${CONFIG["timeline.show-replies"]}"

  if [[ "$show_tags" != "true" ]]; then
    if [[ "$(event_labels "$eid")" ]]; then
      flags+="${CONFIG["timeline.$kind.flag-tagged"]}"
    else
      flags+=" "
    fi
  fi

  if [[ "$show_replies" != "true" ]]; then
    if [[ "$(event_replies "$eid")" ]]; then
      flags+="${CONFIG["timeline.$kind.flag-replied"]}"
    else
      flags+=" "
    fi
  fi

  if filter_eval "$eid"; then
    format_compose "timeline.$kind" flags "${flags}"
    format_dumps "timeline.$kind"
  fi

  if [[ "$show_tags" = "true" ]]; then
    for tags in $(event_labels "$eid"); do
      timeline_list_thread "$tags" "$2${indent}"
    done
  fi

  if [[ "$show_replies" = "true" ]]; then
    for reply in $(event_replies "$eid"); do
      timeline_list_thread "$reply" "$2${indent}"
    done
  fi
}

# fun: timeline_list [filter]
# txt: print the entire timelist
timeline_list ()
{
  local eid
  local -a filter_list

  TIMELINE_PRINTED=()
  TIMELINE_INDEX=()

  if [[ $# -eq 0 ]]; then
    read -ra filter_list <<< "${CONFIG[timeline.filter]}"
    filter_add "${filter_list[@]}"
  else
    filter_add "$@"
  fi

  for eid in "${EVENTS_SORTED[@]}"; do
    if [[ "${EVENTS_KIND["$eid"]}" = "post" ]]; then
      timeline_list_thread "$eid" ''
    fi
  done

  timeline_index_save
}

# fun: timeline_index_save
# txt: dumps TIMELINE_INDEX to a sourceable file to be loaded before any
#      input to identify an event easily.
timeline_index_save ()
{
  local var
  {
    echo "declare -ag TIMELINE_INDEX=("
    for var in "${TIMELINE_INDEX[@]}"; do
      echo "'$var'"
    done
    echo ")"
  } > "${CACHE_DIR}/index.${ACCOUNT_OID}.cache"
}

# fun: timeline_index_load
# txt: source index saved file with timeline_index_save
timeline_index_load ()
{
  # shellcheck source=/dev/null
  if [[ -r "${CACHE_DIR}/index.${ACCOUNT_OID}.cache" ]]; then
    source "${CACHE_DIR}/index.${ACCOUNT_OID}.cache" 
    TIMELINE_OLD="${TIMELINE_INDEX[*]}"
  fi
}

# fun: timeline_index_get <num>
# txt: return the EID of the event indexed by number passed as argument
timeline_index_get ()
{
  if [[ "$1" -ge ${#TIMELINE_INDEX[@]} ]]; then
    E=1 error $"Index out of bounds: %s in %s" "$1" "TIMELINE_INDEX"
  else
    echo "${TIMELINE_INDEX[$1]}"
  fi
}

# fun: timeline_edit
# txt: interactively edit your timeline
timeline_edit ()
{
  local content auto_push
  content="${ACCOUNT_PATH}/CONTENT"

  if [[ -w "$content" ]]; then

    auto_push="${CONFIG["account.${ACCOUNT_NAME}.auto-push"]}"

    if ! [[ "$auto_push" ]]; then
      auto_push="$(config_get account.auto-push)"
    fi

    ${EDITOR:-nano} "$content"

    account_commit "manual: timeline edit command" | info_multi

    if [[ "$auto_push" = "true" ]]; then
      account_push | info_multi
    fi

  else
    fatal $"Unable to edit CONTENT file"
  fi
}

# fun: timeline_orphans
# txt: show orphan events in the timeline
timeline_orphans ()
{
  for eids in "${EVENTS_CROSS_REPLY[@]}" "${EVENTS_CROSS_TAGS[@]}" \
    "${EVENTS_CROSS_SCORE[@]}"
  do
    for eid in $eids; do
      if [[ -z "${EVENTS_KIND["$eid"]}" ]]; then
        timeline_list_thread "$eid"
      fi
    done
  done
  timeline_index_save
}
## vim:ft=sh

FILTER_LIST=()

# fun: filter <tags_to_filter> <eid>
# txt: return true if EID need to be filtered
filter_tag ()
{
  local fpattern="$1" eid="$2"
  local event tag

  [[ "$fpattern" = "*" ]] && return 0

  for event in $(event_labels "$eid"); do
    for tag in $(event_tags "$event"); do
      if any "$fpattern" "$tag"; then
        return 0
      fi
    done
  done
  return 1
}

# fun: filter <view> <eid>
# txt: return true if EID need to be filtered
filter_view ()
{
  local fpattern="$1" eid="$2"
  read -ra view <<< "${CONFIG["views.$fpattern"]}"

  if [[ "${#view[@]}" -ne 0 ]]; then
    filter_eval "$eid" "${view[@]}"
  else
    E=1 fatal $"No view named: %s" "$fpattern"
  fi
}

# fun: filter {score-min|score-max} <value> <eid>
# txt: return true if EID need to be filtered according to score values
#      passsed as argument.
filter_score ()
{
  local kind="$1" value="$2" eid="$3"
  local score

  score="$(event_score "$eid")"

  case "$kind" in
    score-min)
      [[ "${score:-0}" -lt "${value}" ]] && return 0
    ;;
    score-max)
      [[ "${score:-0}" -gt "${value}" ]] && return 0
    ;;
    *)
      E=1 fatal $"Invalid score filter: %s" "$kind"
    ;;
  esac

  return 1
}

# fun: filter_text <pattern> <eid>
# txt: return true if especified eid contains text which match with pattern
#      passed as argument (glob pattern supported only).
filter_text ()
{
  local fpattern="$1" eid="$2"

  # shellcheck disable=SC2254
  case "${EVENTS_MESG["$eid"]}" in
    *$fpattern*) return 0;;
  esac
  return 1
}

# fun: filter_mention <eid>
# txt: return true if myself is mentioned in eid
filter_mention ()
{
  local eid="$1" uid pattern
  uid="${ACCOUNT_OID}"
  local -a reat=()

  # no acctive account
  [[ "$uid" ]] || return 1

  reat=( "@$uid" "@${uid:0:8}" "$(username "$uid")" )

  if [[ "${CONFIG[timeline.react-on-all]}" = "true" ]]; then
    reat+=( "@all" "@here" )
  fi

  for pattern in "${reat[@]}"; do
    filter_text "*${pattern}*" "$eid" && return 0
  done

  return 1
}

# fun: filter_engagement <eid>
# txt: return true if the event has engagement with your account
filter_engagement ()
{
  local eid="$1" uid="${ACCOUNT_OID}" link

  # no acctive account
  [[ "$uid" ]] || return 1

  case "${EVENTS_KIND["$eid"]}" in
    P) return 1;;
    R|T|S)
      link="${EVENTS_LINK["$eid"]}"
      link="${link#*:}"; link="${link%:*}"
      [[ "$link" = "$uid" ]] && return 0
      ;;
  esac
  return 1
}

# fun: filter_add <expr>
# txt: Add an expression filter
filter_add ()
{
  FILTER_LIST+=( "$@" )
}

# fun: filter_eval <eid> [<expr>...]
# txt: evaluate filtering of the eid for the specified mode. If this funcion
#      return 0, means that the item is filtered, otherwise is not filtered.
filter_eval ()
{
  local eid="$1" ret=0; shift

  [[ "$#" -eq 0 ]] && set -- "${FILTER_LIST[@]}"
  for exp in "$@"; do
    case "$exp" in
      -*) filter_eval_expr "$eid" "${exp#-}" && ret=1 || ret=0;;
      *) filter_eval_expr "$eid" "${exp#+}" && ret=0 || ret=1;;
    esac
  done
  return $ret
}

# fun: filter_eval_expr <eid> <expr>
# txt: eval an expression and return true if filtered or false if not
filter_eval_expr ()
{
  local eid="$1" expr="$2"

  case "$expr" in
    '') ;;
    tag:*)
      filter_tag "${expr#tag:}" "$eid" && return 0
      ;;
    score-min:*|score-max:*)
      filter_score "${expr%%:*}" "${expr#*:}" "$eid" && return 0
      ;;
    view:*)
      filter_view "${expr#view:}" "$eid" && return 0
      ;;
    mention)
      filter_mention "$eid" && return 0
      ;;
    engagement)
      filter_engagement "$eid" && return 0
      ;;
    *)
      filter_text "${expr#text:}" "$eid" && return 0
      ;;
  esac
  return 1
}
## vim:ft=sh

# env: CONFIG: associative array contains the configuration values. This
#      array should be loaded from file with `config_load` function, and
#      accessed by `config_get` and `config_set` to read and write,
#      res pectively.
declare -xA CONFIG=(
  [oid.use-cache]=true
  [oid.max-cache-size]=1000
  [interactive.show-banner]=true
  [account.auto-push]=true
  [account.content-markdown]=true
  [account.preview-depth]=100
  [account.default]=''
  [account.keyid]=''
  [account.max-posts]=20
  [account.path]="${XDG_DATA_HOME:-$HOME/.local/share}/tl/account:$HOME/.tl/account"
  [plugin.path]="${XDG_DATA_HOME:-$HOME/.local/share}/tl/plugin:$HOME/.tl/plugin"
  [cache.path]="${XDG_CACHE_HOME:-$HOME/.cache}/tl:$HOME/.tl/cache"
  [git.jobs]='4'
  [network.depth]=10
  [prompt.format]='%b%s:%b '
  [prompt.fields]='account'
  [prompt.color]='7,'
  [prompt.color-name]='7,'
  [history.enabled]=true
  [history.file]="${XDG_DATA_HOME:-$HOME/.local/share/}tl/history"
  [timeline.show-untrusted-items]=true
  [timeline.show-replies]=true
  [timeline.show-tags]=false
  [timeline.react-on-all]=true
  [timeline.filter]='-tag:spam -score-min:0'
  [timeline.own-posts]=true
  [timeline.use-short-ids]=true
  [timeline.post.format]='%b%-3d%b %b%(%Y%m%d %H%M%S)T%b %b%10s%b [%b%s%b] (%b%d%b) %b%s%b'
  [timeline.post.fields]='index,date,name,flags,score,mesg'
  [timeline.post.highlight-mesg]='[@#][^\ ,.:;=\!\?]+'
  [timeline.post.prefix]=''
  [timeline.post.color]='7,'
  [timeline.post.color-index]='7,'
  [timeline.post.color-date]='7,'
  [timeline.post.color-name]='7,'
  [timeline.post.color-flags]='7,'
  [timeline.post.color-mesg]='7,'
  [timeline.post.color-score]='7,'
  [timeline.post.style-index]='normal'
  [timeline.post.style-date]='normal'
  [timeline.post.style-name]='normal'
  [timeline.post.style-flags]='normal'
  [timeline.post.style-mesg]='normal'
  [timeline.post.style-score]='normal'
  [timeline.post.flag-signed-good]='S'
  [timeline.post.flag-signed-bad]='!'
  [timeline.post.flag-signed-unknown]='?'
  [timeline.post.flag-signed-expired]='X'
  [timeline.post.flag-signed-revoked]='R'
  [timeline.post.flag-signed-missing]='m'
  [timeline.post.flag-signed-none]=' '
  [timeline.post.flag-tagged]='T'
  [timeline.post.flag-replied]='R'
  [timeline.post.flag-new]='N'
  [timeline.tag.format]='%b%-3d%b %b%(%Y%m%d %H%M%S)T%b %b%10s%b [%b%s%b] (%b%d%b) %b%s%b'
  [timeline.tag.fields]='index,date,name,flags,score,tags'
  [timeline.tag.prefix]='# '
  [timeline.tag.indent]=' '
  [timeline.tag.color]='7,'
  [timeline.tag.color-index]='7,'
  [timeline.tag.color-date]='7,'
  [timeline.tag.color-name]='7,'
  [timeline.tag.color-mesg]='7,'
  [timeline.tag.color-score]='7,'
  [timeline.tag.color-flags]='7,'
  [timeline.tag.color-tags]='7,'
  [timeline.tag.style-index]='normal'
  [timeline.tag.style-date]='normal'
  [timeline.tag.style-name]='normal'
  [timeline.tag.style-score]='normal'
  [timeline.tag.style-flags]='normal'
  [timeline.tag.style-tags]='normal'
  [timeline.tag.flag-signed-good]='S'
  [timeline.tag.flag-signed-bad]='!'
  [timeline.tag.flag-signed-unknown]='?'
  [timeline.tag.flag-signed-expired]='X'
  [timeline.tag.flag-signed-revoked]='R'
  [timeline.tag.flag-signed-missing]='m'
  [timeline.tag.flag-signed-none]=' '
  [timeline.tag.flag-tagged]='T'
  [timeline.tag.flag-replied]='R'
  [timeline.tag.flag-new]='N'
  [timeline.tag.flag-trusted]='*'
  [timeline.reply.format]='%b%-3d%b %b%(%Y%m%d %H%M%S)T%b %b%10s%b [%b%s%b] (%b%d%b) %b%s%b'
  [timeline.reply.fields]='index,date,name,flags,score,mesg'
  [timeline.reply.highlight-mesg]='[@#][^\ ,.:;=\!\?]+'
  [timeline.reply.prefix]='> '
  [timeline.reply.indent]=' '
  [timeline.reply.color]='7,'
  [timeline.reply.color-index]='7,'
  [timeline.reply.color-date]='7,'
  [timeline.reply.color-name]='7,'
  [timeline.reply.color-flags]='7,'
  [timeline.reply.color-mesg]='7,'
  [timeline.reply.color-score]='7,'
  [timeline.reply.style-index]='normal'
  [timeline.reply.style-date]='normal'
  [timeline.reply.style-name]='normal'
  [timeline.reply.style-score]='normal'
  [timeline.reply.style-flags]='normal'
  [timeline.reply.style-mesg]='normal'
  [timeline.reply.flag-signed-good]='S'
  [timeline.reply.flag-signed-bad]='!'
  [timeline.reply.flag-signed-unknown]='?'
  [timeline.reply.flag-signed-expired]='X'
  [timeline.reply.flag-signed-revoked]='R'
  [timeline.reply.flag-signed-missing]='m'
  [timeline.reply.flag-signed-none]=' '
  [timeline.reply.flag-tagged]='T'
  [timeline.reply.flag-replied]='R'
  [timeline.reply.flag-new]='N'
  [timeline.reply.flag-trusted]='*'
  [timeline.fatal.format]='*** %b%(%Y%m%d %H%M%S)T%b %b%10s%b %b%s%b'
  [timeline.fatal.fields]='date,name,mesg'
  [timeline.fatal.name]='FATAL'
  [timeline.fatal.color]='7,'
  [timeline.fatal.color-date]='7,'
  [timeline.fatal.color-name]='7,'
  [timeline.fatal.color-mesg]='7,'
  [timeline.fatal.style-date]='normal'
  [timeline.fatal.style-name]='normal'
  [timeline.fatal.style-mesg]='normal'
  [timeline.error.format]='*** %b%(%Y%m%d %H%M%S)T%b %b%10s%b %b%s%b'
  [timeline.error.fields]='date,name,mesg'
  [timeline.error.name]='ERROR'
  [timeline.error.color]='7,'
  [timeline.error.color-date]='7,'
  [timeline.error.color-name]='7,'
  [timeline.error.color-mesg]='7,'
  [timeline.error.style-date]='normal'
  [timeline.error.style-name]='normal'
  [timeline.error.style-mesg]='normal'
  [timeline.info.format]='*** %b%(%Y%m%d %H%M%S)T%b %b%10s%b %b%s%b'
  [timeline.info.fields]='date,name,mesg'
  [timeline.info.name]='INFO'
  [timeline.info.color]='7,'
  [timeline.info.color-date]='7,'
  [timeline.info.color-name]='7,'
  [timeline.info.color-mesg]='7,'
  [timeline.info.style-date]='normal'
  [timeline.info.style-name]='normal'
  [timeline.info.style-mesg]='normal'
  [timeline.consistent-colors]=''
  [network.list.format]='*** %b%(%Y%m%d %H%M%S)T%b %b%10s%b  score: %b%-03d%b  %b%-10s%b %b%s%b'
  [network.list.fields]='date,name,score,user,url'
  [network.list.color-score]='7,'
  [network.list.color-date]='7,'
  [network.list.color-name]='7,'
  [network.list.color-user]='7,'
  [network.list.color-url]='7,'
  [network.list.color]='7,'
  [network.list.style-date]='normal'
  [network.list.style-name]='normal'
  [network.list.style-score]='normal'
  [network.list.style-user]='normal'
  [network.list.style-url]='normal'
  [network.show-followers]=true
  [network.follower.format]='*** %b%(%Y%m%d %H%M%S)T%b %b%10s%b                         FOLLOWED BY %b%-10s%b'
  [network.follower.fields]='date,name,user'
  [network.follower-color-date]='7,'
  [network.follower-color-name]='7,'
  [network.follower-color-user]='7,'
  [network.follower.color]='7,'
  [daemon.interval]='300'
  [daemon.commands]='timeline refresh'
  [daemon.pidfile]="${XDG_RUNTIME_DIR:-/run/$UID}/tl.pid"
  [daemon.log.file]="${XDG_DATA_HOME:-${HOME}/.local/share}/tl/daemon.log"
  [daemon.log.level]=info
  [notify.command]="notify-send"
  [notify.format]='Knock knock from %s:\n%s'
  [notify.filter]="mention engagement"
  [notify.cache-file]="${XDG_CACHE_HOME:-${HOME}/.cache}/tl/notify.cache"
  [directory.default]="https://tldir.ajdiaz.me/index.txt"
  [alias.tr]='timeline refresh'
  [alias.tl]='timeline list'
  [alias.edit]='timeline edit'
  [alias.e]='timeline edit'
  [alias.post]='event post'
  [alias.p]='event post'
  [alias.reply]='event reply'
  [alias.r]='event reply'
  [alias.tag]='event tag'
  [alias.info]='event info'
  [alias.show]='event info'
  [alias.score]='event score'
  [alias.net]='network'
  [alias.nl]='network list'
  [alias.nr]='network refresh'
  [alias.dir]='directory'
  [alias.ds]='directory search'
  [alias.pre]='account preview'
)

export NO_COLORS=0
export COLOR=false

if test -t 1; then
  case "$(tput colors)" in
     8)
       export COLOR=true
       CONFIG['timeline.post.color']=8,
       CONFIG['timeline.post.color-date']=8,
       CONFIG['timeline.post.color-mesg']=7,
       CONFIG['timeline.post.color-flags']=11,
       CONFIG['timeline.post.color-score']=3,
       CONFIG['timeline.post.color-name']=CONSISTENT,
       CONFIG['timeline.reply.color']=8,
       CONFIG['timeline.reply.color-date']=8,
       CONFIG['timeline.reply.color-mesg']=7,
       CONFIG['timeline.reply.color-flags']=11,
       CONFIG['timeline.reply.color-score']=3,
       CONFIG['timeline.reply.color-name']=CONSISTENT,
       CONFIG['timeline.tag.color']=8,
       CONFIG['timeline.tag.color-date']=8,
       CONFIG['timeline.tag.color-tags']=3,
       CONFIG['timeline.tag.color-name']=CONSISTENT,
       CONFIG['timeline.tag.color-flags']=11,
       CONFIG['timeline.tag.color-score']=3,
       CONFIG['timeline.info.color']=8,
       CONFIG['timeline.info.color-date']=8,
       CONFIG['timeline.info.color-name']=6,
       CONFIG['timeline.info.color-mesg']=7,
       CONFIG['timeline.error.color']=8,
       CONFIG['timeline.error.color-date']=8,
       CONFIG['timeline.error.color-name']=4,
       CONFIG['timeline.error.color-mesg']=7,
       CONFIG['timeline.fatal.color']=8,
       CONFIG['timeline.fatal.color-date']=8,
       CONFIG['timeline.fatal.color-name']=4,
       CONFIG['timeline.fatal.color-mesg']=7,
       CONFIG['timeline.consistent-colors']="3,5,6,9"
       CONFIG['network.list.color-date']=8,
       CONFIG['network.list.color-name']=6,
       CONFIG['network.list.color-score']=3,
       CONFIG['network.list.color-user']=CONSISTENT,
       CONFIG['network.list.color-url']=4,
       CONFIG['network.follower.color-user']=6,
       CONFIG['network.follower.color-name']=6,
       CONFIG['network.follower.color-date']=8,
       CONFIG['network.follower.color']=8,
       CONFIG['prompt.color']=4,
      ;;
   256)
       export COLOR=true
       CONFIG['timeline.post.color']=240,
       CONFIG['timeline.post.color-date']=240,
       CONFIG['timeline.post.color-mesg']=7,
       CONFIG['timeline.post.color-score']=3,
       CONFIG['timeline.post.color-name']=CONSISTENT,
       CONFIG['timeline.post.color-flags']=11,
       CONFIG['timeline.reply.color']=240,
       CONFIG['timeline.reply.color-date']=240,
       CONFIG['timeline.reply.color-mesg']=245,
       CONFIG['timeline.reply.color-score']=3,
       CONFIG['timeline.reply.color-name']=CONSISTENT,
       CONFIG['timeline.reply.color-flags']=11,
       CONFIG['timeline.reply.prefix']='⤷ ' # XXX 256colors -> unicode!!!
       CONFIG['timeline.tag.color']=240,
       CONFIG['timeline.tag.color-date']=240,
       CONFIG['timeline.tag.color-tags']=136,
       CONFIG['timeline.tag.color-score']=3,
       CONFIG['timeline.tag.color-name']=CONSISTENT,
       CONFIG['timeline.tag.style-tags']=italic
       CONFIG['timeline.tag.color-flags']=11,
       CONFIG['timeline.info.color']=240,
       CONFIG['timeline.info.color-date']=240,
       CONFIG['timeline.info.color-name']=69,
       CONFIG['timeline.info.color-mesg']=7,
       CONFIG['timeline.info.style-mesg']=italic
       CONFIG['timeline.error.color']=240,
       CONFIG['timeline.error.color-date']=240,
       CONFIG['timeline.error.color-name']=9,
       CONFIG['timeline.error.color-mesg']=7,
       CONFIG['timeline.fatal.color']=240,
       CONFIG['timeline.fatal.color-date']=240,
       CONFIG['timeline.fatal.color-name']=9,
       CONFIG['timeline.fatal.color-mesg']=7,
       CONFIG['timeline.consistent-colors']="34,139,149,199,209,173,153"
       CONFIG['network.list.color-date']=240,
       CONFIG['network.list.color-name']=165,
       CONFIG['network.list.color-score']=226,
       CONFIG['network.list.color-user']=CONSISTENT,
       CONFIG['network.list.color-url']=69,
       CONFIG['network.follower.color-user']=214,
       CONFIG['network.follower.color-name']=165,
       CONFIG['network.follower.color-date']=240,
       CONFIG['network.follower.style-user']='italic'
       CONFIG['network.follower.color']=240,
       CONFIG['prompt.color']=69,
       ;;
   esac
fi

declare -xa AVAIL_COLORS
IFS=',' read -ra AVAIL_COLORS <<<"${CONFIG[timeline.consistent-colors]}"

# fun: config_load <filename>
# txt: given a filename path as argument, read the content and save it in
#      `$CONFIG` environment variable properly.
config_load ()
{
  local IFS='='
  while read -r key val; do
    CONFIG["$key"]="$val"
  done < <(command git config -f "$1" -l)
}

# fun: config_get <key>
# txt: get the configuration value corresponding with the configuration
#      keyword passed as argument, or fails if not found.
config_get ()
{
  local val="${CONFIG["$1"]}"

  [[ "$val" ]] ||
    E=1 error $"Unknown configuration variable '%s'" "$1"

  echo "$val"
}

# fun: config_set <key> <val>
# txt: set the properly value of configuration key passed as argument using
#      value provided.
config_set ()
{
  CONFIG["$1"]="$2"
}

# fun: config_unset key
# txt: unset config key with named passed as parameter key.
config_unset ()
{
  CONFIG["$1"]=''
}

# fun: config_iter <prefix>
# txt: given a fixed prefix, return all keys matched with specified prefix.
config_iter ()
{
  for key in "${!CONFIG[@]}"; do
    case "$key" in
      "$1"*) echo "$key";;
    esac
  done
}

# fun: config_save <filename>
# txt: given a filename passed as argument, dump the content of `$CONFIG`
#      variable to that file
config_save ()
{
  local val

  if [[ ! -d "${1%/*}" ]]; then
    mkdir -p "${1%/*}"
  fi

  for var in "${!CONFIG[@]}"; do
    val="${CONFIG["$var"]}"

    if [[ "$val" ]]; then
      command git config -f "$1" "$var" "${CONFIG["$var"]}"
    else
      mute command git config -f "$1" --remove-section "${var}" ||
        command git config -f "$1" --unset "${var}"
    fi
  done
}

# fun: config_list
# txt: print all configuration values
config_list ()
{
  for var in "${!CONFIG[@]}"; do
    echo "${var}=${CONFIG[$var]}"
  done
}
## vim:ft=sh

# env: ACCOUNT_NAME: A variable contains the name of the acctive account.
export ACCOUNT_NAME=

# env: ACCOUNT_PATH: A variable contains the path of the acctive account.
export ACCOUNT_PATH=

# env: ACCOUNT_OID: A variable contains the OID of the acctive account.
export ACCOUNT_OID=

# fun: account_list
# txt: output a new-line separated list of defined accounts.
account_list ()
{
  local account

  for account in $(config_iter account.); do
    case "$account" in
      account.*.path)
        account="${account#account.}"
        account="${account%.path}"
        echo "$account"
      ;;
    esac
  done
}

# fun: account_load [name]
# txt: load the account named as argument, if argument is omit, then try to
#      load the account using the `account.default` configuration value or,
#      if missing and there is only one configured account this one.
#      Otherwise failed.
account_load ()
{
  local name="$1" pull_url changes

  name="${name:-${CONFIG[account.default]}}"

  if [[ -z "$name" ]]; then

    # try to infer the account name if none is provided
    
    read -ra all_accounts < <( account_list)

    case "${#all_accounts[@]}" in
      0) return 1;;
      1) name="${all_accounts[0]}";;
      *) E=1 fatal $"There are may accounts.";;
    esac

  fi

  ACCOUNT_NAME="$name"
  pull_url="$(config_get "account.$ACCOUNT_NAME.pull-url")"
  oid "$pull_url"
  ACCOUNT_OID="${OID_CACHE["$pull_url"]}"
  ACCOUNT_PATH="$(config_get "account.$ACCOUNT_NAME.path")"

  changes="$(command git -C "${ACCOUNT_PATH}" status --porcelain 2>&1)" ||
    E=3 error $"Unable to check account status"
  if [[ "$changes" ]]; then
    error $"Account is dirty. Maybe you edit your account manually and badly."
    error $"To repair just run: git reset --hard master in $ACCOUNT_PATH"
    exit 100
  fi
}

export NOACTIVE=$"There are no active accounts"

# fun: account_exists [name]
# txt: return true if the account name passed as argument is a initialized
#      account. If name is omit, then use active account path.
account_exists ()
{
  local path=
  
  [[ "$1" ]] && path="$(config_get "account.$1.path")"

  if [[ -z "$path" ]]; then
    path="${ACCOUNT_PATH}"
  fi
  [ -d "${path%.git}/.git" ]
}

# fun: account_create <name> <push_url> <pull_url> [keyid] [path]
# txt: create a new account named as name, with specific push and pull url,
#      if path is provided then set the account path to this one, otherwise,
#      use the default path for accounts as prefix
account_create ()
{
  local name="$1" push_url="$2" pull_url="$3" keyid="$4" path="$5"

  if [[ "${CONFIG["account.$name.path"]}" ]]; then
    E=1 fatal $"Another account already exists with that name"
  else
    path="${path:-$(try_path "$(config_get account.path)")/$name}"
    config_set "account.$name.push-url" "$push_url"
    config_set "account.$name.pull-url" "$pull_url"
    config_set "account.$name.path" "$path"
    config_set "account.$name.keyid" "$keyid"
    oid "$pull_url"
    config_set "user.alias-${OID_CACHE["$pull_url"]}" "$name"
    account_init "$name"
    config_save "${CONFIG_FILE}"
  fi
}

# fun: account_clone <name> <push_url> <pull_url> [keyid] [path]
# txt: clone new account named as name, from the specific push url,
#      if path is provided then set the account path to this one, otherwise,
#      use the default path for accounts as prefix
account_clone ()
{
  if [[ "$1" = "--force" ]]; then
    local force=true; shift
  else
    local force=false
  fi

  local name="$1" push_url="$2" pull_url="$3" keyid="$4" path="$5"

  if ! $force && [[ "${CONFIG["account.$name.path"]}" ]]; then
    E=1 fatal $"Another account already exists with that name"
  else
    path="${path:-$(try_path "$(config_get account.path)")/$name}"
    config_set "account.$name.push-url" "$push_url"
    config_set "account.$name.pull-url" "$pull_url"
    config_set "account.$name.keyid" "$keyid"
    config_set "account.$name.path" "$path"
    oid "$pull_url"
    config_set "user.alias-${OID_CACHE["$pull_url"]}" "$name"
    command git clone "$push_url" "$path"
    command git -C "$path" submodule init
    account_config "$path" "$pull_url" "$keyid"
    config_save "${CONFIG_FILE}"
  fi
}

# fun: account_init <name>
# txt: initialized the accoutn passed as argument
account_init ()
{
  if account_exists "$1"; then
    E=1 fatal $"Trying to initializating an already initialized account"
  else
    local path push_url pull_url keyid

    path="$(config_get "account.$1.path")"
    pull_url="$(config_get "account.$1.pull-url")"
    push_url="$(config_get "account.$1.push-url")"
    keyid="$(keyid "$1")"

    # create empty dir for init
    mkdir -p "$path" ||
      E=1 fatal $"Unable to create account directory: %s" "$path"

    command git -C "$path" init ${TIMELINE_EXPERIMENTAL_SHA256:+--object-format=sha256}
    account_config "$path" "$pull_url" "$keyid"
    command git -C "$path" add .
    if [[ "$keyid" ]]; then
      command git -C "$path" commit -S -m 'Initial commit'
    else
      command git -C "$path" commit -m 'Initial commit'
    fi
    command git -C "$path" remote add origin "$push_url"
  fi
}

# fun: account_config <path> <pull_url> [keyid]
# txt: configure user and other required things in the repo
account_config ()
{
  local path="$1" pull_url="$2" keyid="$3"
  oid "$pull_url"

  command git -C "$path" config user.name "${OID_CACHE["$pull_url"]}"
  command git -C "$path" config user.email "${OID_CACHE["$pull_url"]}@timeline"
  [[ "$keyid" ]] &&
    command git -C "$path" config user.signingkey "$keyid"
  command touch "${path:?}/CONTENT"
  command mkdir -p "${path:?}/FOLLOW"
}

# fun: account_commit [message]
# txt: set a commit point into current active account
account_commit ()
{
  [[ "$ACCOUNT_PATH" ]] || E=1 fatal $"No active account to commit"

  command git -C "$ACCOUNT_PATH" add .
  if [[ "$(keyid "${ACCOUNT_NAME}")" ]]; then
    command git -C "$ACCOUNT_PATH" commit -S -m "${1:-autosave}"
  else
    command git -C "$ACCOUNT_PATH" commit -m "${1:-autosave}"
  fi
}

# fun: account_push [remote]
# txt: push active account content to remote passed as argument or, if
#      missing, to `origin`.
account_push ()
{
  # TODO Add support for multiple branches
  command git -C "${ACCOUNT_PATH}" push "${1:-origin}" master
}

# fun: account_refresh <path> [remote]
# txt: rebase changes to current account from remote passed as argument or,
#     if missing, `origin`.
account_refresh ()
{
  local path="$1"; shift

  command git -C "$path" fetch --all
  # TODO Add support for multiple branches
  command git -C "$path" rebase "${1:-origin}/master"
  command git -C "$path" submodule update --remote \
    --jobs "${CONFIG[git.jobs]:-1}"
}

# fun: account_delete [name]
# txt: delete account by name passed as argument or active account if none
#      name is provided.
account_delete ()
{
  local name="${1:-$ACCOUNT_NAME}" path pull_url

  path="$(config_get "account.$name.path")"
  pull_url="$(config_get "account.$name.pull-url")"
  
  oid "$pull_url"

  if [[ -d "$path" ]]; then
    rm -rf "$path"
  fi

  config_unset "account.$name"
  config_unset "user.alias-${OID_CACHE["$pull_url"]}"

  config_save "${CONFIG_FILE}"
}

# fun: account_set_keyid <name> <keyid>
# txt: set keyid for an existant account
account_set_keyid ()
{
  command git -C "$(config_get "account.$1.path")" config user.signingkey "$2"
  config_set "account.$1.keyid" "$2"
}

# fun: account_preview <url> [filter]
# txt: preview the contents of the specified url repo filtered with the
#      specific if present.
account_preview ()
{
  local tmpdir depth
  tmpdir="$(temp_dir)"
  depth="${CONFIG[account.preview-depth]}"

  [[ "$depth" = "-1" ]] && depth=""

  command git clone ${depth:+--depth "${depth}"} "$1" "${tmpdir}" 2>&1 |
    info_multi ||
      E=1 error $"Unable to clone remote repo"

  oid "$1"
  timeline_load "${tmpdir}" "${OID_CACHE["$1"]}"
  shift
  timeline_list "$@"
}
main "$@"
