#! /bin/bash -i
TIMELINE_VERSION='1.5-4-gd8e4061'
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
  DAEMON_LOG_FILE="$(config_get_empty daemon.log.file)"
  case "$DAEMON_LOG_FILE" in
    none) NOLOG=true;;
    stdout|STDOUT|stderr|STDERR) DAEMON_LOG_FILE="";;
    *) DAEMON_LOG_FILE=">> ${DAEMON_LOG_FILE}";;
  esac
  DAEMON_LOG_LEVEL="$(config_get_empty daemon.log.level)"
  case "${DAEMON_LOG_LEVEL}" in
    error) DAEMON_LOG_FILE+=" 2>&1 >/dev/null";;
    info) DAEMON_LOG_FILE+=" 2>&1";;
  esac
  DAEMON_INTERVAL="$(config_get_empty daemon.interval)"
  DAEMON_COMMANDS="$(config_get_empty daemon.commands)"
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
  done < <(workon "$path" command git config -f .gitmodules -l 2>/dev/null)
}


# fun: follow_add <pull_url> [name]
# txt: Add new following using pull_url passed as argument. Optional name
#      will add a config entry for user alias to this name.
follow_add ()
{
  local path pull_url="${1}" name="$2"
  
  path="$(account_active_path)"

  workon "$path" command git submodule add \
    "$pull_url" "${TIMELINE_FOLLOW}/$(oid "$pull_url")"
  workon "$path" command git submodule init
  workon "$path" command git submodule update --remote

  account_commit
  account_push

  if [[ "$name" ]]; then
    config_set "user.alias-$(oid "$pull_url")" "$name"
    config_save "${CONFIG_FILE}"
  fi

}

# fun: follow_del <uid>
# txt: remove following for user identified by specific UID
follow_del ()
{
  local path uid="$1"

  path="$(account_active_path)"
  mpath="${TIMELINE_FOLLOW}/$uid"

  # remove gitconfig sections
  workon "$path" mute command git config -f .git/config \
    --remove-section "submodule.$mpath"

  workon "$path" mute command git config -f .gitmodules \
    --remove-section "submodule.$mpath"

  account_commit

  workon "$path" command git rm --cached "$mpath"
  workon "$path" rm -rf ".git/modules/$mpath"
 
  if [[ -d "$path/$mpath" ]]; then
    rm -rf "${path:?}/${mpath:?}"
  fi

  account_push
}
## vim:ft=sh

# fun: history_load
# txt: if is defined prompt_history and prompt_history_file configuration
#      file, load from there the history of the commands.
history_load ()
{
  hist_enabled="$(config_get history.enabled)"
  hist_file="$(config_get_empty history.file)"

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
  hist_file="$(config_get_empty history.file)"

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

# fun: notify <eid>
# txt: send notification for specified eid if match the notification filter.
notify ()
{
  local user uid="${1%%:*}" date="${1##*:}" last_date=0
  local fexpr ncommand

  ncommand="$(config_get_empty notify.command)"

  [[ "$ncommand" ]] || return 0

  last_date_file="$(config_get notify.cache-file)"
  [[ -r "${last_date_file}" ]] && 
    last_date="$(< "$last_date_file")"

  # discard old events
  [[ "$date" -le "${last_date}" ]] &&
    return

  # discard own events
  user="$(account_active_oid)"
  [[ "$uid" = "$user" ]] &&
    return

  fexpr="$(config_get_empty notify.filter)"

  if [[ "$fexpr" ]] && filter_eval_expr "$1" "$fexpr"; then
    # shellcheck disable=SC2059
    "$ncommand" "$(printf "$(config_get notify.format)" "$(username "$uid")")"
    echo "$date" > "${last_date_file}"
  fi
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
        "?") E=1 error $"Binary '%s' is recommended, but not found" "$req";;
        *) E=1 fatal $"Unknown depedency kind '%s'" "$kind";;
      esac
  done
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
  active_oid="$(account_active_oid)"

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
  active_oid="$(account_active_oid)"

  while read -r  uid url; do
    [[ "$active_oid" = "$uid" ]] && continue

    if [[ -d "${cache}/$uid" ]]; then
      network_load_repo "$uid" "$url"
    else
      error $"Unable to load repository '%s'. Try network refresh first." \
        "$uid"
    fi
  done < <(follow_list "$(account_active_path)")
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
    if ! workon "${cache}/$uid" command git pull --rebase 2>&1; then
      error $"Unable to pull repository '%s' from '%s'" "$uid" "$url"
      return 1
    fi
  else
    # repo does not exists yet, cloning...
    if ! workon "${cache}" git clone --depth 1 "$url" "$uid" 2>&1; then
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

# env: ACCOUNT_NAME: A variable contains the name of the acctive account.
ACCOUNT_NAME=

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
  local name="$1"

  name="${name:-$(config_get_empty account.default)}"

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
}

NOACTIVE=$"There are no active accounts"

# fun: account_active_name
# txt: print the name of the current active account
account_active_name ()
{
  echo "${ACCOUNT_NAME}"
}

# fun: account_active_oid
# txt: print the OID of the current active account
account_active_oid ()
{
  [[ "$ACCOUNT_NAME" ]] ||
    E=1 fatal "$NOACTIVE"
  oid "$(config_get "account.$ACCOUNT_NAME.pull-url")"
}

# fun: account_active_path
# txt: print the path of the current active account
account_active_path ()
{
  [[ "$ACCOUNT_NAME" ]] ||
    E=1 fatal "$NOACTIVE"
  config_get "account.$ACCOUNT_NAME.path"
}

# fun: account_exists [name]
# txt: return true if the account name passed as argument is a initialized
#      account. If name is omit, then use active account path.
account_exists ()
{
  local path=
  
  [[ "$1" ]] && path="$(config_get "account.$1.path")"

  if [[ -z "$path" ]]; then
    path="$(account_active_path)"
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

  if [[ "$(config_get_empty "account.$name.path")" ]]; then
    E=1 fatal $"Another account already exists with that name"
  else
    path="${path:-$(try_path "$(config_get account.path)")/$name}"
    config_set "account.$name.push-url" "$push_url"
    config_set "account.$name.pull-url" "$pull_url"
    config_set "account.$name.path" "$path"
    config_set "account.$name.keyid" "$keyid"
    config_set "user.alias-$(oid "$pull_url")" "$name"
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
  local name="$1" push_url="$2" pull_url="$3" keyid="$4" path="$5"

  if [[ "$(config_get_empty "account.$name.path")" ]]; then
    E=1 fatal $"Another account already exists with that name"
  else
    path="${path:-$(try_path "$(config_get account.path)")/$name}"
    config_set "account.$name.push-url" "$push_url"
    config_set "account.$name.pull-url" "$pull_url"
    config_set "account.$name.keyid" "$keyid"
    config_set "account.$name.path" "$path"
    config_set "user.alias-$(oid "$pull_url")" "$name"
    command git clone "$push_url" "$path"
    workon "$path" command git submodule init
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

    workon "$path" command git init
    account_config "$path" "$pull_url" "$keyid"
    workon "$path" command git add .
    if [[ "$keyid" ]]; then
      workon "$path" command git commit -S -m 'Initial commit'
    else
      workon "$path" command git commit -m 'Initial commit'
    fi
    workon "$path" command git remote add origin "$push_url"
  fi
}

# fun: account_config <path> <pull_url> [keyid]
# txt: configure user and other required things in the repo
account_config ()
{
  local path="$1" pull_url="$2" keyid="$3"
  workon "$path" command git config user.name "$(oid "$pull_url")"
  workon "$path" command git config user.email "$(oid "$pull_url")@timeline"
  [[ "$keyid" ]] &&
    workon "$path" command git config user.signingkey "$keyid"
  workon "$path" command touch CONTENT
  workon "$path" command mkdir -p "FOLLOW"
}

# fun: account_commit
# txt: set a commit point into current active account
account_commit ()
{
  local path keyid

  path="$(account_active_path)"
  keyid="$(keyid "$(account_active_name)")"

  [[ "$path" ]] || E=1 fatal $"No active account to commit"

  workon "$path" command git add .
  if [[ "$keyid" ]]; then
    workon "$path" command git commit -S -m "Timeline Autosave: $(timestamp)"
  else
    workon "$path" command git commit -m "Timeline Autosave: $(timestamp)"
  fi
}

# fun: account_push [remote]
# txt: push active account content to remote passed as argument or, if
#      missing, to `origin`.
account_push ()
{
  # TODO Add support for multiple branches
  workon "$(account_active_path)" command git push "${1:-origin}" master
}

# fun: account_refresh [remote]
# txt: rebase changes to current account from remote passed as argument or,
#     if missing, `origin`.
account_refresh ()
{
  local path

  path="$(account_active_path)"

  account_commit

  workon "$path" command git fetch --all
  # TODO Add support for multiple branches
  workon "$path" command git rebase "${1:-origin}/master"
  workon "$path" command git submodule update --remote \
    --jobs "${CONFIG[git.jobs]}"

  account_push "${1:-origin}"
}

# fun: account_delete [name]
# txt: delete account by name passed as argument or active account if none
#      name is provided.
account_delete ()
{
  local name="${1:-$ACCOUNT_NAME}" path oid

  path="$(config_get "account.$name.path")"
  oid="$(oid "$(config_get "account.$name.pull-url")")"

  if [[ -d "$path" ]]; then
    rm -rf "$path"
  fi

  config_unset "account.$name"
  config_unset "user.alias-$oid"

  config_save "${CONFIG_FILE}"
}

# fun: account_set_keyid <name> <keyid>
# txt: set keyid for an existant account
account_set_keyid ()
{
  workon "$(config_get "account.$1.path")" \
    command git config user.signingkey "$2"
  config_set "account.$1.keyid" "$2"
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
        command_account_active "$OPTARG"
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

NOSUBCMD=$"No valid subcomand '%s' for command '%s'"
INVALIDURL=$"Invalid URL '%s'"

# help:fun: account {create|delete|clone|list|refresh|active} {args...}
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
    error $"Please create account:    %s account create <name> <push> <pull>"
    error $"Or clone an existent one:  %s account clone <name> <push> <pull>"
    E=1 error $"Account does not exist yet"
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
    command_account_active "$(account_active_name)"
    account_set_keyid "$(account_active_name)" "$1"
    config_save "${CONFIG_FILE}"
  fi
}

# help:account:fun: account refresh
# help:account:txt: Pull changes from the remote repository. This action
# help:account:txt: should be automatically and you should not use it
# help:account:txt: manually. But, if you need it, here it is.
command_account_refresh ()
{
  command_account_active "$(account_active_name)"
  { account_refresh 2>&1 | info_multi; } ||
      E=1 error $"Unable to refresh local account"
}

# help:fun: git <command>...
# help:txt: Execute raw git commands in the active account.
command_git ()
{
  command_account_refresh
  workon "$(account_active_path)" command git "$@"
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
  command_account_active "$(account_active_name)"
  timeline_load
  timeline_list "$@"
}

# help:timeline:fun: timeline refresh [filter]
# help:timeline:txt: Pull changes in the current enabled timeline and show
# help:timeline:txt: the results.
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
  command_account_active "$(account_active_name)"
  command_account_refresh
  timeline_edit
}

# help:fun: config {list|get|set|save} {args...}
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
    var="$(config_get_empty "$*")"
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

# help:fun: alias [name value]
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


# help:fun: user [uid nickname]
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
      local uid="$1"; shift
      command_config_set "user.alias-$uid" "$1"
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

# help:event:fun: event post <message>
# help:event:txt: Post a new message in our timeline
command_event_post ()
{
  if [[ $# -eq 0 ]]; then
    E=2 error $"Event post required an argument: message"
  else
    command_account_active "$(account_active_name)"
    command_account_refresh 
    event_create "$(timestamp)" P "$*" 2>&1 | info_multi
  fi
}

# help:event:fun: event reply [--eid] <num/eid> <message>
# help:event:txt: Post a reply to post indexed with num passed as argument,
# help:event:txt: or, if '--eid' flag is present, the EID passed as
# help:event:txt: argument.
command_event_reply ()
{
  local eid

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

  command_account_active "$(account_active_name)"

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

    command_account_refresh
    event_create "$(timestamp)" R "$eid" "$*" 2>&1 | info_multi
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

  command_account_active "$(account_active_name)"

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

  command_account_active "$(account_active_name)"

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

  command_account_active "$(account_active_name)"

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
  command_account_active "$(account_active_name)"
  follow_list "$(account_active_path)" | info_multi
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
    command_account_active "$(account_active_name)"
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

  command_account_active "$(account_active_name)"
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
  command_account_active "$(account_active_name)"
  network_load "$(account_active_path)"
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
  command_account_active "$(account_active_name)"
  info $"Discovering the network. This action could take a while..."
  network_refresh "$(account_active_path)" | info_multi
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

# hey! you do not want to use this, only for debug purposes
if ${DEBUG:-false}; then
  command_debug ()
  {
    eval "$@"
  }
fi
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

# fun: event_load <account_id> <filename>
# txt: given an content filename, parse it and store events in memory
event_load ()
{
  local i=0 max_posts max_user_posts fname="$2" account="$1" content

  max_posts="${CONFIG[timeline.max-posts]}"
  max_user_posts="${CONFIG[timeline.max-user-posts]}"

  mapfile content < "$fname"

  # reached timeline.max-posts
  [[ "${#EVENTS_SORTED[@]}" -gt "$max_posts" ]] && return


  _i() {
    [[ $((++i)) -gt "${max_user_posts}" ]] && return

    case "${content[i]}" in
      ''|\#) return
    esac

    commit="${2%% *}";
    flags="${2#$commit }"; flags="${flags%% *}"

    event_load_line "$account" "${fname%/*}" "$commit" "$flags" "${content[i]}"
  }

  mapfile -c 1 -C _i < <(
    git -C "${fname%/*}" log -s --pretty=format:"%H %G? %s" \
      --no-color "$fname"
  )

  ## shellcheck disable=SC2034
}

# fun: event_load_line <account_id> <commit> <flags> <content>
# txt: parse a event line passed as argument and fill properly fields in
#      a associative array called EVENT. The account id is the OID
#      associated to the pull_url of the account.
#
#      The POST kind has the fields: timestamp,kind,message
#      The REPLY kind has the fields: timestamp,kind,ref,message
#      The TAG kind has the fields: timestamp,kind,ref,tags
event_load_line ()
{
  local aid="$1" fname="$2" commit="$3" flags="$4" line="${5%$'\n'}"
  local datet="${line%% *}"
  local kind="${line#$datet }"; kind="${kind%% *}"
  local rest="${line#$datet $kind }"
  local link mesg tags score

  case "$kind" in
    P|POST)
      mesg="$rest"
      kind='post'
      ;;
    R|REPLY)
      link="${rest%% *}"
      mesg="${rest#$link }"
      kind='reply'
      ;;
    T|TAG)
      link="${rest%% *}"
      tags="${rest#$link }"
      kind='tag'
      ;;
    S|SCORE)
      kind='score'
      link="${rest%% *}"
      score="${rest#$link }"
      case "$score" in
        -1) score="-1";;
        *) score="1";;
      esac
      ;;
    *)
      error $"Ignored malformed event: '$line'"
      return 0
      ;;
  esac

  EVENTS_KIND["$aid:$datet"]="$kind"
  EVENTS_DATE["$aid:$datet"]="$datet"
  EVENTS_LINK["$aid:$datet"]="$link"
  EVENTS_TAGS["$aid:$datet"]="$tags"
  EVENTS_MESG["$aid:$datet"]="$mesg"
  EVENTS_SIGN["$aid:$datet"]="$flags"
  EVENTS_COMMIT["$aid:$datet"]="$fname $commit"

  # XXX some array abused. Because arrays allows any index number, and are
  # sorted by definition, we do not need to sort anything. To avoid
  # collision between accounts, add a RANDOM prefix.
  EVENTS_SORTED["$datet$(printf %03d "$((RANDOM % 100))")"]="$aid:$datet"

  if [[ "$kind" = 'reply' ]]; then
    EVENTS_CROSS_REPLY[$link]+=" $aid:$datet "
  elif [[ "$kind" = 'tag' ]]; then
    EVENTS_CROSS_TAGS[$link]+=" $aid:$datet "
  elif [[ "$kind" = 'score' ]]; then
    if ! [[ "${EVENTS_CROSS_SCORE[$aid:$link]}" ]]; then
      EVENTS_CROSS_SCORE["$aid:$link"]=1
      (( EVENTS_SCORE["$link"]+=score ))
    fi
  fi

  notify "$aid:$datet"
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

  for reply in ${EVENTS_CROSS_REPLY["$1"]}; do
    sorted_replies[${reply#*:}]="$reply"
  done

  echo "${sorted_replies[@]}"
}

# fun: event_labels <eid>
# txt: given an specific eid return the eids of the tags of that post
event_labels ()
{
  local -a sorted_labels=()

  for label in ${EVENTS_CROSS_TAGS["$1"]}; do
    sorted_labels[${label#*:}]="$label"
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
event_create ()
{
  local path auto_push
  local -a content

  auto_push="$(
    config_get_empty "account.$(account_active_name).auto-push"
  )"

  if ! [[ "$auto_push" ]]; then
    auto_push="$(config_get account.auto-push)"
  fi

  path="$(account_active_path)"
  mapfile -t content < "${path}/$TIMELINE_CONTENT"

  echo "$*" > "${path}/$TIMELINE_CONTENT"
  for line in "${content[@]}"; do
    echo "$line" >> "${path}/$TIMELINE_CONTENT"
  done

  account_commit

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
  printf $"%-10s %s (%s)\n" "UID:"   "${eid%:*}" "$(username "$eid")"
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

FILTER_HIDE=()
FILTER_SHOW=()

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
  read -ra view < <( config_get_empty "views.$fpattern" )

  if [[ "${#view[@]}" -ne 0 ]]; then
    filter_eval_expr "$eid" "${view[@]}"
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
  case "$(event_mesg "$eid")" in
    $fpattern) return 0;;
  esac
  return 1
}

# fun: filter_mention <eid>
# txt: return true if myself is mentioned in eid
filter_mention ()
{
  local eid="$1" uid pattern
  uid="$(account_active_oid)"
  local -a reat=()

  # no acctive account
  [[ "$uid" ]] || return 1

  reat=( "@$uid" "@${uid:0:8}" "$(username "$uid")" )

  if [[ "$(config_get_empty timeline.react-on-all)" = "true" ]]; then
    reat+=( "@all" "@here" )
  fi

  for pattern in "${reat[@]}"; do
    filter_text "*${pattern}*" "$eid" && return 0
  done

  return 1
}

# fun: filter_add {hide|show} <expr>
# txt: Add an expression filter
filter_add ()
{
  local mode="$1"; shift

  case "$mode" in
    hide) FILTER_HIDE+=( "$@" );;
    show) FILTER_SHOW+=( "$@" );;
  esac
}

# fun: filter_eval {hide|show} <eid>
# txt: evaluate filtering of the eid for the specified mode. If this funcion
#      return 0, means that the item is filtered, otherwise is not filtered.
filter_eval ()
{
  local mode="$1" eid="$2"
  local -a expr_array=()

  case "$mode" in
    hide) expr_array+=( "${FILTER_HIDE[@]}" );;
    show) expr_array+=( "${FILTER_SHOW[@]}" );;
  esac

  filter_eval_expr "$eid" "${expr_array[@]}"
}

# fun: filter_eval_expr <eid> <expr>...
# txt: eval an expression and return true if filtered or false if not
filter_eval_expr ()
{
  local eid="$1" expr=; shift

  for expr in "${@}"; do
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
      text:*)
        filter_text "${expr#text:}" "$eid" && return 0
        ;;
      mention)
        filter_mention "$eid" && return 0
        ;;
      *)
        E=3 error $"This kind of filtering is not implemented yet"
        ;;
    esac
  done
  return 1
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

  for field in $(split "$fields"); do
    mapfile -t -O "${#args[@]}" args <<< "${FORMAT["$field"]}"
  done

  # shellcheck disable=SC2059
  printf "${format}%b\n" "${args[@]}" "$sgr0"
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
  hide_help_banner="$(config_get_empty general.hide-help-banner)"

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
  local name
  name="$(account_active_name)"

  format_compose prompt account "${name:-<none>}"
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
  command_account_active "$(account_active_name)"

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
    read -ra alias < <( config_get_empty "alias.$cmd" )

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
  
  CONFIG_FILE="$(try_path "$config_path")"
  INTERACTIVE=false

  reqs_eval
  args_eval "$@" || shift $?

  [ -r "${CONFIG_FILE}" ] && config_load "${CONFIG_FILE}"

  CACHE_DIR="$(try_path "$(config_get cache.path)")"
  mkdir -p "${CACHE_DIR}"

  # load the timeline index to operate with previous listed timeline
  timeline_index_load

  if [ $# -eq 0 ]; then
    if [[ "$(config_get_empty interactive.show-banner)" = "true" ]]; then
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
}
## vim:ft=sh

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

# fun: timeline_load 
# txt: load the timeline from current active account into memory
timeline_load ()
{
  local oid content_path follow_path show_own

  oid="$(account_active_oid)"
  content_path="$(account_active_path)/$TIMELINE_CONTENT"
  follow_path="$(account_active_path)/$TIMELINE_FOLLOW"
  show_own="${CONFIG["timeline.own-posts"]}"

  # Load our account timeline
  [[ "$show_own" = "false" ]] ||
    event_load "$oid" "${content_path}"

  local dir
  for dir in "${follow_path}"/*; do
    [[ -d "$dir" ]] || continue  # ignore non-dir files
    [[ -r "$dir/$TIMELINE_CONTENT" ]] || continue # ignore non initialized

    dir="${dir%/}"
    event_load "${dir##*/}" "${dir}/$TIMELINE_CONTENT"
  done
}

# fun: timeline_filter <eid>
# txt: return true if the item should be filtered and false if not.
timeline_filter ()
{
  local eid="$1"
  local ret=1

  filter_eval hide "$eid" &&
    timeline_hide_thread "$eid" && ret=0

  filter_eval show "$eid" &&
    timeline_show_thread "$eid" && ret=1

  return "$ret"
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
      timeline_filter "$eid" && return
      ;;
    tag)
      tags="${EVENTS_TAGS["$eid"]// /, }"
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
    G) flags+="${CONFIG["timeline.$kind.flag-signed-good"]}";;
    B) flags+="${CONFIG["timeline.$kind.flag-signed-bad"]}";;
    U) flags+="${CONFIG["timeline.$kind.flag-signed-unknown"]}";;
    X|Y) flags+="${CONFIG["timeline.$kind.flag-signed-expired"]}";;
    R) flags+="${CONFIG["timeline.$kind.flag-signed-revoked"]}";;
    E) flags+="${CONFIG["timeline.$kind.flag-signed-missing"]}";;
    *) flags+="${CONFIG["timeline.$kind.flag-signed-none"]}";;
  esac

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

  format_compose "timeline.$kind" flags "${flags}"
  format_dumps "timeline.$kind"

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
  TIMELINE_PRINTED=()
  TIMELINE_INDEX=()

  local -a filter_show
  local -a filter_hide

  read -ra filter_show < <( config_get_empty timeline.filter.show )
  read -ra filter_hide < <( config_get_empty timeline.filter.hide )

  [[ "${#filter_show[@]}" -gt 0 ]] &&
    filter_add show "${filter_show[@]}"

  [[ "${#filter_hide[@]}" -gt 0 ]] &&
    filter_add hide "${filter_hide[@]}"

  if [[ "$1" ]]; then
    filter_add hide "tag:*"
    filter_add show "$@"
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
  {
    echo "declare -ag TIMELINE_INDEX=("
    for var in "${TIMELINE_INDEX[@]}"; do
      echo "'$var'"
    done
    echo ")"
  } > "${CACHE_DIR}/.timeline-index"
}

# fun: timeline_index_load
# txt: source index saved file with timeline_index_save
timeline_index_load ()
{
  # shellcheck source=/dev/null
  [[ -r "${CACHE_DIR}/.timeline-index" ]] &&
    source "${CACHE_DIR}/.timeline-index" 
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
  content="$(account_active_path)/CONTENT"

  if [[ -w "$content" ]]; then

    auto_push="${CONFIG["account.$(account_active_name).auto-push"]}"

    if ! [[ "$auto_push" ]]; then
      auto_push="$(config_get account.auto-push)"
    fi

    ${EDITOR:-nano} "$content"

    account_commit | info_multi

    if [[ "$auto_push" = "true" ]]; then
      account_push | info_multi
    fi

  else
    fatal $"Unable to edit CONTENT file"
  fi
}
## vim: ft=sh

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

# fun: split <str>
# txt: split a comma separated list
split ()
{
  echo "${1//,/ }"
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
  command git hash-object --stdin <<<"${1%.git}"
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

# fun: workon <path> <command>...
# txt: run command inside path passed as argument
workon ()
{
  local dir="$1"; shift
  ( cd "$dir" && "$@"; )
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

# fun: username <eid|account_id>
# txt: return username from a event_id or account_id using alias defined in
#      configuration and short form if 'timeline.use-short-ids' is true.
username ()
{
  local uname="$1"
  
  uname="${uname%:*}" # remove timestamp if present
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
  mute let i="10#$1" 2>/dev/null
}

# fun: keyid <name>
# txt: get the keyid configured for account name passed as argument
keyid ()
{
  local keyid

  keyid="$(config_get_empty "account.$1.keyid")"
  
  [[ "$keyid" ]] ||
    keyid="$(config_get_empty "account.keyid")"

  echo "$keyid"
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
## vim:ft=sh

# env: CONFIG: associative array contains the configuration values. This
#      array should be loaded from file with `config_load` function, and
#      accessed by `config_get` and `config_set` to read and write,
#      res pectively.
declare -xA CONFIG=(
  [interactive.show-banner]=true
  [account.auto-push]=true
  [account.default]=''
  [account.keyid]=''
  [account.path]="$HOME/.local/share/tl/account:$HOME/.tl/account"
  [plugin.path]="$HOME/.local/share/tl/plugin:$HOME/.tl/plugin"
  [cache.path]="$HOME/.cache/tl:$HOME/.tl/cache"
  [git.jobs]='4'
  [network.depth]=10
  [prompt.format]='%b%s:%b '
  [prompt.fields]='account'
  [prompt.color]='7,'
  [prompt.color-name]='7,'
  [history.enabled]=true
  [history.file]="$HOME/.local/share/tl/history"
  [timeline.show-replies]=true
  [timeline.show-tags]=false
  [timeline.react-on-all]=true
  [timeline.filter.show]=''
  [timeline.filter.hide]='tag:spam score-min:0'
  [timeline.own-posts]=true
  [timeline.max-posts]=100
  [timeline.max-user-posts]=20
  [timeline.use-short-ids]=true
  [timeline.post.format]='%b%-3d%b %b%(%Y%m%d %H%M%S)T%b %b%10s%b [%b%s%b] (%b%d%b) %b%s%b'
  [timeline.post.fields]='index,date,name,flags,score,mesg'
  [timeline.post.highlight-mesg]='@[^\ ,.:;=\!\?]+'
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
  [timeline.reply.format]='%b%-3d%b %b%(%Y%m%d %H%M%S)T%b %b%10s%b [%b%s%b] (%b%d%b) %b%s%b'
  [timeline.reply.fields]='index,date,name,flags,score,mesg'
  [timeline.reply.highlight-mesg]='@[^\ ,.:;=\!\?]+'
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
  [daemon.pidfile]="${HOME}/.local/share/tl/daemon.pid"
  [daemon.log.file]="${HOME}/.local/share/tl/daemon.log"
  [daemon.log.level]=info
  [notify.command]="notify-send"
  [notify.format]='Knock knock from %s'
  [notify.filter]="mention"
  [notify.cache-file]="${HOME}/.cache/tl/notify.cache"
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

# fun: config_get_empty <key>
# txt: similar to `config_get`, but if key is not defined an empty value is
#      returned instead of failing.
config_get_empty ()
{
  echo "${CONFIG["$1"]}"
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
main "$@"
