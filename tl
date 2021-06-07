#! /bin/bash -i
TIMELINE_VERSION='1.8-24-gee7c30b'
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
## vim: ft=sh

# env: ABBR_TABLE
# txt: abbreviation table, using to replace input
declare -gxA ABBR_TABLE

# fun: abbr_replace <str>
# txt: given a text replace abbr occurencies and put the result in REPLY
abbr_replace ()
{
  local word

  REPLY=''
  abbr_emoji_load
  # shellcheck disable=SC2048
  for word in $*; do
    REPLY+="${ABBR_TABLE[$word]:-${CONFIG[abbr.$word]:-$word}} "
  done
  REPLY="${REPLY% }"
}

# fun: abbr_emoji_load
# txt: load a well known set of emoji abbreviations into ABBR_TABLE. Due the
#      size of this load, this function will be called on demand only if
#      `input.emojis` config setting is true
abbr_emoji_load ()
{
  [[ "${CONFIG["input.emojis"]}" != "true" ]] && return

  # not reload if already loaded
  [[ "${ABBR_TABLE[':+1:']}" ]] && return

  ABBR_TABLE[':+1:']='👍'
  ABBR_TABLE[':-1:']='👎'
  ABBR_TABLE[':100:']='💯'
  ABBR_TABLE[':1234:']='🔢'
  ABBR_TABLE[':1st_place_medal:']='🥇'
  ABBR_TABLE[':2nd_place_medal:']='🥈'
  ABBR_TABLE[':3rd_place_medal:']='🥉'
  ABBR_TABLE[':8ball:']='🎱'
  ABBR_TABLE[':a:']='🅰️'
  ABBR_TABLE[':ab:']='🆎'
  ABBR_TABLE[':abacus:']='🧮'
  ABBR_TABLE[':abc:']='🔤'
  ABBR_TABLE[':abcd:']='🔡'
  ABBR_TABLE[':accept:']='🉑'
  ABBR_TABLE[':accordion:']='🪗'
  ABBR_TABLE[':adhesive_bandage:']='🩹'
  ABBR_TABLE[':adult:']='🧑'
  ABBR_TABLE[':aerial_tramway:']='🚡'
  ABBR_TABLE[':afghanistan:']='🇦🇫'
  ABBR_TABLE[':airplane:']='✈️'
  ABBR_TABLE[':aland_islands:']='🇦🇽'
  ABBR_TABLE[':alarm_clock:']='⏰'
  ABBR_TABLE[':albania:']='🇦🇱'
  ABBR_TABLE[':alembic:']='⚗️'
  ABBR_TABLE[':algeria:']='🇩🇿'
  ABBR_TABLE[':alien:']='👽'
  ABBR_TABLE[':ambulance:']='🚑'
  ABBR_TABLE[':american_samoa:']='🇦🇸'
  ABBR_TABLE[':amphora:']='🏺'
  ABBR_TABLE[':anatomical_heart:']='🫀'
  ABBR_TABLE[':anchor:']='⚓'
  ABBR_TABLE[':andorra:']='🇦🇩'
  ABBR_TABLE[':angel:']='👼'
  ABBR_TABLE[':anger:']='💢'
  ABBR_TABLE[':angola:']='🇦🇴'
  ABBR_TABLE[':angry:']='😠'
  ABBR_TABLE[':anguilla:']='🇦🇮'
  ABBR_TABLE[':anguished:']='😧'
  ABBR_TABLE[':ant:']='🐜'
  ABBR_TABLE[':antarctica:']='🇦🇶'
  ABBR_TABLE[':antigua_barbuda:']='🇦🇬'
  ABBR_TABLE[':apple:']='🍎'
  ABBR_TABLE[':aquarius:']='♒'
  ABBR_TABLE[':argentina:']='🇦🇷'
  ABBR_TABLE[':aries:']='♈'
  ABBR_TABLE[':armenia:']='🇦🇲'
  ABBR_TABLE[':arrow_backward:']='◀️'
  ABBR_TABLE[':arrow_double_down:']='⏬'
  ABBR_TABLE[':arrow_double_up:']='⏫'
  ABBR_TABLE[':arrow_down:']='⬇️'
  ABBR_TABLE[':arrow_down_small:']='🔽'
  ABBR_TABLE[':arrow_forward:']='▶️'
  ABBR_TABLE[':arrow_heading_down:']='⤵️'
  ABBR_TABLE[':arrow_heading_up:']='⤴️'
  ABBR_TABLE[':arrow_left:']='⬅️'
  ABBR_TABLE[':arrow_lower_left:']='↙️'
  ABBR_TABLE[':arrow_lower_right:']='↘️'
  ABBR_TABLE[':arrow_right:']='➡️'
  ABBR_TABLE[':arrow_right_hook:']='↪️'
  ABBR_TABLE[':arrows_clockwise:']='🔃'
  ABBR_TABLE[':arrows_counterclockwise:']='🔄'
  ABBR_TABLE[':arrow_up:']='⬆️'
  ABBR_TABLE[':arrow_up_down:']='↕️'
  ABBR_TABLE[':arrow_upper_left:']='↖️'
  ABBR_TABLE[':arrow_upper_right:']='↗️'
  ABBR_TABLE[':arrow_up_small:']='🔼'
  ABBR_TABLE[':art:']='🎨'
  ABBR_TABLE[':articulated_lorry:']='🚛'
  ABBR_TABLE[':artificial_satellite:']='🛰️'
  ABBR_TABLE[':artist:']='🧑‍🎨'
  ABBR_TABLE[':aruba:']='🇦🇼'
  ABBR_TABLE[':ascension_island:']='🇦🇨'
  ABBR_TABLE[':asterisk:']='*️⃣'
  ABBR_TABLE[':astonished:']='😲'
  ABBR_TABLE[':astronaut:']='🧑‍🚀'
  ABBR_TABLE[':athletic_shoe:']='👟'
  ABBR_TABLE[':atm:']='🏧'
  ABBR_TABLE[':atom_symbol:']='⚛️'
  ABBR_TABLE[':australia:']='🇦🇺'
  ABBR_TABLE[':austria:']='🇦🇹'
  ABBR_TABLE[':auto_rickshaw:']='🛺'
  ABBR_TABLE[':avocado:']='🥑'
  ABBR_TABLE[':axe:']='🪓'
  ABBR_TABLE[':azerbaijan:']='🇦🇿'
  ABBR_TABLE[':baby:']='👶'
  ABBR_TABLE[':baby_bottle:']='🍼'
  ABBR_TABLE[':baby_chick:']='🐤'
  ABBR_TABLE[':baby_symbol:']='🚼'
  ABBR_TABLE[':back:']='🔙'
  ABBR_TABLE[':bacon:']='🥓'
  ABBR_TABLE[':badger:']='🦡'
  ABBR_TABLE[':badminton:']='🏸'
  ABBR_TABLE[':bagel:']='🥯'
  ABBR_TABLE[':baggage_claim:']='🛄'
  ABBR_TABLE[':baguette_bread:']='🥖'
  ABBR_TABLE[':bahamas:']='🇧🇸'
  ABBR_TABLE[':bahrain:']='🇧🇭'
  ABBR_TABLE[':balance_scale:']='⚖️'
  ABBR_TABLE[':bald_man:']='👨‍🦲'
  ABBR_TABLE[':bald_woman:']='👩‍🦲'
  ABBR_TABLE[':ballet_shoes:']='🩰'
  ABBR_TABLE[':balloon:']='🎈'
  ABBR_TABLE[':ballot_box:']='🗳️'
  ABBR_TABLE[':ballot_box_with_check:']='☑️'
  ABBR_TABLE[':bamboo:']='🎍'
  ABBR_TABLE[':banana:']='🍌'
  ABBR_TABLE[':bangbang:']='‼️'
  ABBR_TABLE[':bangladesh:']='🇧🇩'
  ABBR_TABLE[':banjo:']='🪕'
  ABBR_TABLE[':bank:']='🏦'
  ABBR_TABLE[':barbados:']='🇧🇧'
  ABBR_TABLE[':barber:']='💈'
  ABBR_TABLE[':bar_chart:']='📊'
  ABBR_TABLE[':baseball:']='⚾'
  ABBR_TABLE[':basket:']='🧺'
  ABBR_TABLE[':basketball:']='🏀'
  ABBR_TABLE[':basketball_man:']='⛹️‍♂️'
  ABBR_TABLE[':basketball_woman:']='⛹️‍♀️'
  ABBR_TABLE[':bat:']='🦇'
  ABBR_TABLE[':bath:']='🛀'
  ABBR_TABLE[':bathtub:']='🛁'
  ABBR_TABLE[':battery:']='🔋'
  ABBR_TABLE[':b:']='🅱️'
  ABBR_TABLE[':beach_umbrella:']='🏖️'
  ABBR_TABLE[':bear:']='🐻'
  ABBR_TABLE[':bearded_person:']='🧔'
  ABBR_TABLE[':beaver:']='🦫'
  ABBR_TABLE[':bed:']='🛏️'
  ABBR_TABLE[':bee:']='🐝'
  ABBR_TABLE[':beer:']='🍺'
  ABBR_TABLE[':beers:']='🍻'
  ABBR_TABLE[':beetle:']='🪲'
  ABBR_TABLE[':beginner:']='🔰'
  ABBR_TABLE[':belarus:']='🇧🇾'
  ABBR_TABLE[':belgium:']='🇧🇪'
  ABBR_TABLE[':belize:']='🇧🇿'
  ABBR_TABLE[':bell:']='🔔'
  ABBR_TABLE[':bellhop_bell:']='🛎️'
  ABBR_TABLE[':bell_pepper:']='🫑'
  ABBR_TABLE[':benin:']='🇧🇯'
  ABBR_TABLE[':bento:']='🍱'
  ABBR_TABLE[':bermuda:']='🇧🇲'
  ABBR_TABLE[':beverage_box:']='🧃'
  ABBR_TABLE[':bhutan:']='🇧🇹'
  ABBR_TABLE[':bicyclist:']='🚴'
  ABBR_TABLE[':bike:']='🚲'
  ABBR_TABLE[':biking_man:']='🚴‍♂️'
  ABBR_TABLE[':biking_woman:']='🚴‍♀️'
  ABBR_TABLE[':bikini:']='👙'
  ABBR_TABLE[':billed_cap:']='🧢'
  ABBR_TABLE[':biohazard:']='☣️'
  ABBR_TABLE[':bird:']='🐦'
  ABBR_TABLE[':birthday:']='🎂'
  ABBR_TABLE[':bison:']='🦬'
  ABBR_TABLE[':black_cat:']='🐈‍⬛'
  ABBR_TABLE[':black_circle:']='⚫'
  ABBR_TABLE[':black_flag:']='🏴'
  ABBR_TABLE[':black_heart:']='🖤'
  ABBR_TABLE[':black_joker:']='🃏'
  ABBR_TABLE[':black_large_square:']='⬛'
  ABBR_TABLE[':black_medium_small_square:']='◾'
  ABBR_TABLE[':black_medium_square:']='◼️'
  ABBR_TABLE[':black_nib:']='✒️'
  ABBR_TABLE[':black_small_square:']='▪️'
  ABBR_TABLE[':black_square_button:']='🔲'
  ABBR_TABLE[':blonde_woman:']='👱‍♀️'
  ABBR_TABLE[':blond_haired_man:']='👱‍♂️'
  ABBR_TABLE[':blond_haired_person:']='👱'
  ABBR_TABLE[':blond_haired_woman:']='👱‍♀️'
  ABBR_TABLE[':blossom:']='🌼'
  ABBR_TABLE[':blowfish:']='🐡'
  ABBR_TABLE[':blueberries:']='🫐'
  ABBR_TABLE[':blue_book:']='📘'
  ABBR_TABLE[':blue_car:']='🚙'
  ABBR_TABLE[':blue_heart:']='💙'
  ABBR_TABLE[':blue_square:']='🟦'
  ABBR_TABLE[':blush:']='😊'
  ABBR_TABLE[':boar:']='🐗'
  ABBR_TABLE[':boat:']='⛵'
  ABBR_TABLE[':bolivia:']='🇧🇴'
  ABBR_TABLE[':bomb:']='💣'
  ABBR_TABLE[':bone:']='🦴'
  ABBR_TABLE[':book:']='📖'
  ABBR_TABLE[':bookmark:']='🔖'
  ABBR_TABLE[':bookmark_tabs:']='📑'
  ABBR_TABLE[':books:']='📚'
  ABBR_TABLE[':boom:']='💥'
  ABBR_TABLE[':boomerang:']='🪃'
  ABBR_TABLE[':boot:']='👢'
  ABBR_TABLE[':bosnia_herzegovina:']='🇧🇦'
  ABBR_TABLE[':botswana:']='🇧🇼'
  ABBR_TABLE[':bouncing_ball_man:']='⛹️‍♂️'
  ABBR_TABLE[':bouncing_ball_person:']='⛹️'
  ABBR_TABLE[':bouncing_ball_woman:']='⛹️‍♀️'
  ABBR_TABLE[':bouquet:']='💐'
  ABBR_TABLE[':bouvet_island:']='🇧🇻'
  ABBR_TABLE[':bow:']='🙇'
  ABBR_TABLE[':bow_and_arrow:']='🏹'
  ABBR_TABLE[':bowing_man:']='🙇‍♂️'
  ABBR_TABLE[':bowing_woman:']='🙇‍♀️'
  ABBR_TABLE[':bowling:']='🎳'
  ABBR_TABLE[':bowl_with_spoon:']='🥣'
  ABBR_TABLE[':boxing_glove:']='🥊'
  ABBR_TABLE[':boy:']='👦'
  ABBR_TABLE[':brain:']='🧠'
  ABBR_TABLE[':brazil:']='🇧🇷'
  ABBR_TABLE[':bread:']='🍞'
  ABBR_TABLE[':breast_feeding:']='🤱'
  ABBR_TABLE[':bricks:']='🧱'
  ABBR_TABLE[':bride_with_veil:']='👰‍♀️'
  ABBR_TABLE[':bridge_at_night:']='🌉'
  ABBR_TABLE[':briefcase:']='💼'
  ABBR_TABLE[':british_indian_ocean_territory:']='🇮🇴'
  ABBR_TABLE[':british_virgin_islands:']='🇻🇬'
  ABBR_TABLE[':broccoli:']='🥦'
  ABBR_TABLE[':broken_heart:']='💔'
  ABBR_TABLE[':broom:']='🧹'
  ABBR_TABLE[':brown_circle:']='🟤'
  ABBR_TABLE[':brown_heart:']='🤎'
  ABBR_TABLE[':brown_square:']='🟫'
  ABBR_TABLE[':brunei:']='🇧🇳'
  ABBR_TABLE[':bubble_tea:']='🧋'
  ABBR_TABLE[':bucket:']='🪣'
  ABBR_TABLE[':bug:']='🐛'
  ABBR_TABLE[':building_construction:']='🏗️'
  ABBR_TABLE[':bulb:']='💡'
  ABBR_TABLE[':bulgaria:']='🇧🇬'
  ABBR_TABLE[':bullettrain_front:']='🚅'
  ABBR_TABLE[':bullettrain_side:']='🚄'
  ABBR_TABLE[':burkina_faso:']='🇧🇫'
  ABBR_TABLE[':burrito:']='🌯'
  ABBR_TABLE[':burundi:']='🇧🇮'
  ABBR_TABLE[':bus:']='🚌'
  ABBR_TABLE[':business_suit_levitating:']='🕴️'
  ABBR_TABLE[':busstop:']='🚏'
  ABBR_TABLE[':bust_in_silhouette:']='👤'
  ABBR_TABLE[':busts_in_silhouette:']='👥'
  ABBR_TABLE[':butter:']='🧈'
  ABBR_TABLE[':butterfly:']='🦋'
  ABBR_TABLE[':cactus:']='🌵'
  ABBR_TABLE[':cake:']='🍰'
  ABBR_TABLE[':calendar:']='📆'
  ABBR_TABLE[':calling:']='📲'
  ABBR_TABLE[':call_me_hand:']='🤙'
  ABBR_TABLE[':cambodia:']='🇰🇭'
  ABBR_TABLE[':camel:']='🐫'
  ABBR_TABLE[':camera:']='📷'
  ABBR_TABLE[':camera_flash:']='📸'
  ABBR_TABLE[':cameroon:']='🇨🇲'
  ABBR_TABLE[':camping:']='🏕️'
  ABBR_TABLE[':canada:']='🇨🇦'
  ABBR_TABLE[':canary_islands:']='🇮🇨'
  ABBR_TABLE[':cancer:']='♋'
  ABBR_TABLE[':candle:']='🕯️'
  ABBR_TABLE[':candy:']='🍬'
  ABBR_TABLE[':canned_food:']='🥫'
  ABBR_TABLE[':canoe:']='🛶'
  ABBR_TABLE[':cape_verde:']='🇨🇻'
  ABBR_TABLE[':capital_abcd:']='🔠'
  ABBR_TABLE[':capricorn:']='♑'
  ABBR_TABLE[':car:']='🚗'
  ABBR_TABLE[':card_file_box:']='🗃️'
  ABBR_TABLE[':card_index:']='📇'
  ABBR_TABLE[':card_index_dividers:']='🗂️'
  ABBR_TABLE[':caribbean_netherlands:']='🇧🇶'
  ABBR_TABLE[':carousel_horse:']='🎠'
  ABBR_TABLE[':carpentry_saw:']='🪚'
  ABBR_TABLE[':carrot:']='🥕'
  ABBR_TABLE[':cartwheeling:']='🤸'
  ABBR_TABLE[':cat:']='🐱'
  ABBR_TABLE[':cat2:']='🐈'
  ABBR_TABLE[':cayman_islands:']='🇰🇾'
  ABBR_TABLE[':cd:']='💿'
  ABBR_TABLE[':central_african_republic:']='🇨🇫'
  ABBR_TABLE[':ceuta_melilla:']='🇪🇦'
  ABBR_TABLE[':chad:']='🇹🇩'
  ABBR_TABLE[':chains:']='⛓️'
  ABBR_TABLE[':chair:']='🪑'
  ABBR_TABLE[':champagne:']='🍾'
  ABBR_TABLE[':chart:']='💹'
  ABBR_TABLE[':chart_with_downwards_trend:']='📉'
  ABBR_TABLE[':chart_with_upwards_trend:']='📈'
  ABBR_TABLE[':checkered_flag:']='🏁'
  ABBR_TABLE[':cheese:']='🧀'
  ABBR_TABLE[':cherries:']='🍒'
  ABBR_TABLE[':cherry_blossom:']='🌸'
  ABBR_TABLE[':chess_pawn:']='♟️'
  ABBR_TABLE[':chestnut:']='🌰'
  ABBR_TABLE[':chicken:']='🐔'
  ABBR_TABLE[':child:']='🧒'
  ABBR_TABLE[':children_crossing:']='🚸'
  ABBR_TABLE[':chile:']='🇨🇱'
  ABBR_TABLE[':chipmunk:']='🐿️'
  ABBR_TABLE[':chocolate_bar:']='🍫'
  ABBR_TABLE[':chopsticks:']='🥢'
  ABBR_TABLE[':christmas_island:']='🇨🇽'
  ABBR_TABLE[':christmas_tree:']='🎄'
  ABBR_TABLE[':church:']='⛪'
  ABBR_TABLE[':cinema:']='🎦'
  ABBR_TABLE[':circus_tent:']='🎪'
  ABBR_TABLE[':cityscape:']='🏙️'
  ABBR_TABLE[':city_sunrise:']='🌇'
  ABBR_TABLE[':city_sunset:']='🌆'
  ABBR_TABLE[':clamp:']='🗜️'
  ABBR_TABLE[':clap:']='👏'
  ABBR_TABLE[':clapper:']='🎬'
  ABBR_TABLE[':classical_building:']='🏛️'
  ABBR_TABLE[':cl:']='🆑'
  ABBR_TABLE[':climbing:']='🧗'
  ABBR_TABLE[':climbing_man:']='🧗‍♂️'
  ABBR_TABLE[':climbing_woman:']='🧗‍♀️'
  ABBR_TABLE[':clinking_glasses:']='🥂'
  ABBR_TABLE[':clipboard:']='📋'
  ABBR_TABLE[':clipperton_island:']='🇨🇵'
  ABBR_TABLE[':clock1:']='🕐'
  ABBR_TABLE[':clock10:']='🕙'
  ABBR_TABLE[':clock1030:']='🕥'
  ABBR_TABLE[':clock11:']='🕚'
  ABBR_TABLE[':clock1130:']='🕦'
  ABBR_TABLE[':clock12:']='🕛'
  ABBR_TABLE[':clock1230:']='🕧'
  ABBR_TABLE[':clock130:']='🕜'
  ABBR_TABLE[':clock2:']='🕑'
  ABBR_TABLE[':clock230:']='🕝'
  ABBR_TABLE[':clock3:']='🕒'
  ABBR_TABLE[':clock330:']='🕞'
  ABBR_TABLE[':clock4:']='🕓'
  ABBR_TABLE[':clock430:']='🕟'
  ABBR_TABLE[':clock5:']='🕔'
  ABBR_TABLE[':clock530:']='🕠'
  ABBR_TABLE[':clock6:']='🕕'
  ABBR_TABLE[':clock630:']='🕡'
  ABBR_TABLE[':clock7:']='🕖'
  ABBR_TABLE[':clock730:']='🕢'
  ABBR_TABLE[':clock8:']='🕗'
  ABBR_TABLE[':clock830:']='🕣'
  ABBR_TABLE[':clock9:']='🕘'
  ABBR_TABLE[':clock930:']='🕤'
  ABBR_TABLE[':closed_book:']='📕'
  ABBR_TABLE[':closed_lock_with_key:']='🔐'
  ABBR_TABLE[':closed_umbrella:']='🌂'
  ABBR_TABLE[':cloud:']='☁️'
  ABBR_TABLE[':cloud_with_lightning:']='🌩️'
  ABBR_TABLE[':cloud_with_lightning_and_rain:']='⛈️'
  ABBR_TABLE[':cloud_with_rain:']='🌧️'
  ABBR_TABLE[':cloud_with_snow:']='🌨️'
  ABBR_TABLE[':clown_face:']='🤡'
  ABBR_TABLE[':clubs:']='♣️'
  ABBR_TABLE[':cn:']='🇨🇳'
  ABBR_TABLE[':coat:']='🧥'
  ABBR_TABLE[':cockroach:']='🪳'
  ABBR_TABLE[':cocktail:']='🍸'
  ABBR_TABLE[':coconut:']='🥥'
  ABBR_TABLE[':cocos_islands:']='🇨🇨'
  ABBR_TABLE[':coffee:']='☕'
  ABBR_TABLE[':coffin:']='⚰️'
  ABBR_TABLE[':coin:']='🪙'
  ABBR_TABLE[':cold_face:']='🥶'
  ABBR_TABLE[':cold_sweat:']='😰'
  ABBR_TABLE[':collision:']='💥'
  ABBR_TABLE[':colombia:']='🇨🇴'
  ABBR_TABLE[':comet:']='☄️'
  ABBR_TABLE[':comoros:']='🇰🇲'
  ABBR_TABLE[':compass:']='🧭'
  ABBR_TABLE[':computer:']='💻'
  ABBR_TABLE[':computer_mouse:']='🖱️'
  ABBR_TABLE[':confetti_ball:']='🎊'
  ABBR_TABLE[':confounded:']='😖'
  ABBR_TABLE[':confused:']='😕'
  ABBR_TABLE[':congo_brazzaville:']='🇨🇬'
  ABBR_TABLE[':congo_kinshasa:']='🇨🇩'
  ABBR_TABLE[':congratulations:']='㊗️'
  ABBR_TABLE[':construction:']='🚧'
  ABBR_TABLE[':construction_worker:']='👷'
  ABBR_TABLE[':construction_worker_man:']='👷‍♂️'
  ABBR_TABLE[':construction_worker_woman:']='👷‍♀️'
  ABBR_TABLE[':control_knobs:']='🎛️'
  ABBR_TABLE[':convenience_store:']='🏪'
  ABBR_TABLE[':cook:']='🧑‍🍳'
  ABBR_TABLE[':cookie:']='🍪'
  ABBR_TABLE[':cook_islands:']='🇨🇰'
  ABBR_TABLE[':cool:']='🆒'
  ABBR_TABLE[':cop:']='👮'
  ABBR_TABLE[':copyright:']='©️'
  ABBR_TABLE[':corn:']='🌽'
  ABBR_TABLE[':costa_rica:']='🇨🇷'
  ABBR_TABLE[':cote_divoire:']='🇨🇮'
  ABBR_TABLE[':couch_and_lamp:']='🛋️'
  ABBR_TABLE[':couple:']='👫'
  ABBR_TABLE[':couplekiss:']='💏'
  ABBR_TABLE[':couplekiss_man_man:']='👨‍❤️‍💋‍👨'
  ABBR_TABLE[':couplekiss_man_woman:']='👩‍❤️‍💋‍👨'
  ABBR_TABLE[':couplekiss_woman_woman:']='👩‍❤️‍💋‍👩'
  ABBR_TABLE[':couple_with_heart:']='💑'
  ABBR_TABLE[':couple_with_heart_man_man:']='👨‍❤️‍👨'
  ABBR_TABLE[':couple_with_heart_woman_man:']='👩‍❤️‍👨'
  ABBR_TABLE[':couple_with_heart_woman_woman:']='👩‍❤️‍👩'
  ABBR_TABLE[':cow:']='🐮'
  ABBR_TABLE[':cow2:']='🐄'
  ABBR_TABLE[':cowboy_hat_face:']='🤠'
  ABBR_TABLE[':crab:']='🦀'
  ABBR_TABLE[':crayon:']='🖍️'
  ABBR_TABLE[':credit_card:']='💳'
  ABBR_TABLE[':crescent_moon:']='🌙'
  ABBR_TABLE[':cricket:']='🦗'
  ABBR_TABLE[':cricket_game:']='🏏'
  ABBR_TABLE[':croatia:']='🇭🇷'
  ABBR_TABLE[':crocodile:']='🐊'
  ABBR_TABLE[':croissant:']='🥐'
  ABBR_TABLE[':crossed_fingers:']='🤞'
  ABBR_TABLE[':crossed_flags:']='🎌'
  ABBR_TABLE[':crossed_swords:']='⚔️'
  ABBR_TABLE[':crown:']='👑'
  ABBR_TABLE[':cry:']='😢'
  ABBR_TABLE[':crying_cat_face:']='😿'
  ABBR_TABLE[':crystal_ball:']='🔮'
  ABBR_TABLE[':cuba:']='🇨🇺'
  ABBR_TABLE[':cucumber:']='🥒'
  ABBR_TABLE[':cupcake:']='🧁'
  ABBR_TABLE[':cupid:']='💘'
  ABBR_TABLE[':cup_with_straw:']='🥤'
  ABBR_TABLE[':curacao:']='🇨🇼'
  ABBR_TABLE[':curling_stone:']='🥌'
  ABBR_TABLE[':curly_haired_man:']='👨‍🦱'
  ABBR_TABLE[':curly_haired_woman:']='👩‍🦱'
  ABBR_TABLE[':curly_loop:']='➰'
  ABBR_TABLE[':currency_exchange:']='💱'
  ABBR_TABLE[':curry:']='🍛'
  ABBR_TABLE[':cursing_face:']='🤬'
  ABBR_TABLE[':custard:']='🍮'
  ABBR_TABLE[':customs:']='🛃'
  ABBR_TABLE[':cut_of_meat:']='🥩'
  ABBR_TABLE[':cyclone:']='🌀'
  ABBR_TABLE[':cyprus:']='🇨🇾'
  ABBR_TABLE[':czech_republic:']='🇨🇿'
  ABBR_TABLE[':dagger:']='🗡️'
  ABBR_TABLE[':dancer:']='💃'
  ABBR_TABLE[':dancers:']='👯'
  ABBR_TABLE[':dancing_men:']='👯‍♂️'
  ABBR_TABLE[':dancing_women:']='👯‍♀️'
  ABBR_TABLE[':dango:']='🍡'
  ABBR_TABLE[':dark_sunglasses:']='🕶️'
  ABBR_TABLE[':dart:']='🎯'
  ABBR_TABLE[':dash:']='💨'
  ABBR_TABLE[':date:']='📅'
  ABBR_TABLE[':de:']='🇩🇪'
  ABBR_TABLE[':deaf_man:']='🧏‍♂️'
  ABBR_TABLE[':deaf_person:']='🧏'
  ABBR_TABLE[':deaf_woman:']='🧏‍♀️'
  ABBR_TABLE[':deciduous_tree:']='🌳'
  ABBR_TABLE[':deer:']='🦌'
  ABBR_TABLE[':denmark:']='🇩🇰'
  ABBR_TABLE[':department_store:']='🏬'
  ABBR_TABLE[':derelict_house:']='🏚️'
  ABBR_TABLE[':desert:']='🏜️'
  ABBR_TABLE[':desert_island:']='🏝️'
  ABBR_TABLE[':desktop_computer:']='🖥️'
  ABBR_TABLE[':detective:']='🕵️'
  ABBR_TABLE[':diamonds:']='♦️'
  ABBR_TABLE[':diamond_shape_with_a_dot_inside:']='💠'
  ABBR_TABLE[':diego_garcia:']='🇩🇬'
  ABBR_TABLE[':disappointed:']='😞'
  ABBR_TABLE[':disappointed_relieved:']='😥'
  ABBR_TABLE[':disguised_face:']='🥸'
  ABBR_TABLE[':diving_mask:']='🤿'
  ABBR_TABLE[':diya_lamp:']='🪔'
  ABBR_TABLE[':dizzy:']='💫'
  ABBR_TABLE[':dizzy_face:']='😵'
  ABBR_TABLE[':djibouti:']='🇩🇯'
  ABBR_TABLE[':dna:']='🧬'
  ABBR_TABLE[':dodo:']='🦤'
  ABBR_TABLE[':dog:']='🐶'
  ABBR_TABLE[':dog2:']='🐕'
  ABBR_TABLE[':dollar:']='💵'
  ABBR_TABLE[':dolls:']='🎎'
  ABBR_TABLE[':dolphin:']='🐬'
  ABBR_TABLE[':dominica:']='🇩🇲'
  ABBR_TABLE[':dominican_republic:']='🇩🇴'
  ABBR_TABLE[':do_not_litter:']='🚯'
  ABBR_TABLE[':door:']='🚪'
  ABBR_TABLE[':doughnut:']='🍩'
  ABBR_TABLE[':dove:']='🕊️'
  ABBR_TABLE[':dragon:']='🐉'
  ABBR_TABLE[':dragon_face:']='🐲'
  ABBR_TABLE[':dress:']='👗'
  ABBR_TABLE[':dromedary_camel:']='🐪'
  ABBR_TABLE[':drooling_face:']='🤤'
  ABBR_TABLE[':droplet:']='💧'
  ABBR_TABLE[':drop_of_blood:']='🩸'
  ABBR_TABLE[':drum:']='🥁'
  ABBR_TABLE[':duck:']='🦆'
  ABBR_TABLE[':dumpling:']='🥟'
  ABBR_TABLE[':dvd:']='📀'
  ABBR_TABLE[':eagle:']='🦅'
  ABBR_TABLE[':ear:']='👂'
  ABBR_TABLE[':ear_of_rice:']='🌾'
  ABBR_TABLE[':earth_africa:']='🌍'
  ABBR_TABLE[':earth_americas:']='🌎'
  ABBR_TABLE[':earth_asia:']='🌏'
  ABBR_TABLE[':ear_with_hearing_aid:']='🦻'
  ABBR_TABLE[':ecuador:']='🇪🇨'
  ABBR_TABLE[':egg:']='🥚'
  ABBR_TABLE[':eggplant:']='🍆'
  ABBR_TABLE[':egypt:']='🇪🇬'
  ABBR_TABLE[':eight:']='8️⃣'
  ABBR_TABLE[':eight_pointed_black_star:']='✴️'
  ABBR_TABLE[':eight_spoked_asterisk:']='✳️'
  ABBR_TABLE[':eject_button:']='⏏️'
  ABBR_TABLE[':electric_plug:']='🔌'
  ABBR_TABLE[':elephant:']='🐘'
  ABBR_TABLE[':elevator:']='🛗'
  ABBR_TABLE[':elf:']='🧝'
  ABBR_TABLE[':elf_man:']='🧝‍♂️'
  ABBR_TABLE[':elf_woman:']='🧝‍♀️'
  ABBR_TABLE[':el_salvador:']='🇸🇻'
  ABBR_TABLE[':e-mail:']='📧'
  ABBR_TABLE[':email:']='📧'
  ABBR_TABLE[':end:']='🔚'
  ABBR_TABLE[':england:']='🏴󠁧󠁢󠁥󠁮󠁧󠁿'
  ABBR_TABLE[':envelope:']='✉️'
  ABBR_TABLE[':envelope_with_arrow:']='📩'
  ABBR_TABLE[':equatorial_guinea:']='🇬🇶'
  ABBR_TABLE[':eritrea:']='🇪🇷'
  ABBR_TABLE[':es:']='🇪🇸'
  ABBR_TABLE[':estonia:']='🇪🇪'
  ABBR_TABLE[':ethiopia:']='🇪🇹'
  ABBR_TABLE[':eu:']='🇪🇺'
  ABBR_TABLE[':euro:']='💶'
  ABBR_TABLE[':european_castle:']='🏰'
  ABBR_TABLE[':european_post_office:']='🏤'
  ABBR_TABLE[':european_union:']='🇪🇺'
  ABBR_TABLE[':evergreen_tree:']='🌲'
  ABBR_TABLE[':exclamation:']='❗'
  ABBR_TABLE[':exploding_head:']='🤯'
  ABBR_TABLE[':expressionless:']='😑'
  ABBR_TABLE[':eye:']='👁️'
  ABBR_TABLE[':eyeglasses:']='👓'
  ABBR_TABLE[':eyes:']='👀'
  ABBR_TABLE[':eye_speech_bubble:']='👁️‍🗨️'
  ABBR_TABLE[':facepalm:']='🤦'
  ABBR_TABLE[':facepunch:']='👊'
  ABBR_TABLE[':face_with_head_bandage:']='🤕'
  ABBR_TABLE[':face_with_thermometer:']='🤒'
  ABBR_TABLE[':factory:']='🏭'
  ABBR_TABLE[':factory_worker:']='🧑‍🏭'
  ABBR_TABLE[':fairy:']='🧚'
  ABBR_TABLE[':fairy_man:']='🧚‍♂️'
  ABBR_TABLE[':fairy_woman:']='🧚‍♀️'
  ABBR_TABLE[':falafel:']='🧆'
  ABBR_TABLE[':falkland_islands:']='🇫🇰'
  ABBR_TABLE[':fallen_leaf:']='🍂'
  ABBR_TABLE[':family:']='👪'
  ABBR_TABLE[':family_man_boy:']='👨‍👦'
  ABBR_TABLE[':family_man_boy_boy:']='👨‍👦‍👦'
  ABBR_TABLE[':family_man_girl:']='👨‍👧'
  ABBR_TABLE[':family_man_girl_boy:']='👨‍👧‍👦'
  ABBR_TABLE[':family_man_girl_girl:']='👨‍👧‍👧'
  ABBR_TABLE[':family_man_man_boy:']='👨‍👨‍👦'
  ABBR_TABLE[':family_man_man_boy_boy:']='👨‍👨‍👦‍👦'
  ABBR_TABLE[':family_man_man_girl:']='👨‍👨‍👧'
  ABBR_TABLE[':family_man_man_girl_boy:']='👨‍👨‍👧‍👦'
  ABBR_TABLE[':family_man_man_girl_girl:']='👨‍👨‍👧‍👧'
  ABBR_TABLE[':family_man_woman_boy:']='👨‍👩‍👦'
  ABBR_TABLE[':family_man_woman_boy_boy:']='👨‍👩‍👦‍👦'
  ABBR_TABLE[':family_man_woman_girl:']='👨‍👩‍👧'
  ABBR_TABLE[':family_man_woman_girl_boy:']='👨‍👩‍👧‍👦'
  ABBR_TABLE[':family_man_woman_girl_girl:']='👨‍👩‍👧‍👧'
  ABBR_TABLE[':family_woman_boy:']='👩‍👦'
  ABBR_TABLE[':family_woman_boy_boy:']='👩‍👦‍👦'
  ABBR_TABLE[':family_woman_girl:']='👩‍👧'
  ABBR_TABLE[':family_woman_girl_boy:']='👩‍👧‍👦'
  ABBR_TABLE[':family_woman_girl_girl:']='👩‍👧‍👧'
  ABBR_TABLE[':family_woman_woman_boy:']='👩‍👩‍👦'
  ABBR_TABLE[':family_woman_woman_boy_boy:']='👩‍👩‍👦‍👦'
  ABBR_TABLE[':family_woman_woman_girl:']='👩‍👩‍👧'
  ABBR_TABLE[':family_woman_woman_girl_boy:']='👩‍👩‍👧‍👦'
  ABBR_TABLE[':family_woman_woman_girl_girl:']='👩‍👩‍👧‍👧'
  ABBR_TABLE[':farmer:']='🧑‍🌾'
  ABBR_TABLE[':faroe_islands:']='🇫🇴'
  ABBR_TABLE[':fast_forward:']='⏩'
  ABBR_TABLE[':fax:']='📠'
  ABBR_TABLE[':fearful:']='😨'
  ABBR_TABLE[':feather:']='🪶'
  ABBR_TABLE[':feet:']='🐾'
  ABBR_TABLE[':female_detective:']='🕵️‍♀️'
  ABBR_TABLE[':female_sign:']='♀️'
  ABBR_TABLE[':ferris_wheel:']='🎡'
  ABBR_TABLE[':ferry:']='⛴️'
  ABBR_TABLE[':field_hockey:']='🏑'
  ABBR_TABLE[':fiji:']='🇫🇯'
  ABBR_TABLE[':file_cabinet:']='🗄️'
  ABBR_TABLE[':file_folder:']='📁'
  ABBR_TABLE[':film_projector:']='📽️'
  ABBR_TABLE[':film_strip:']='🎞️'
  ABBR_TABLE[':finland:']='🇫🇮'
  ABBR_TABLE[':fire:']='🔥'
  ABBR_TABLE[':firecracker:']='🧨'
  ABBR_TABLE[':fire_engine:']='🚒'
  ABBR_TABLE[':fire_extinguisher:']='🧯'
  ABBR_TABLE[':firefighter:']='🧑‍🚒'
  ABBR_TABLE[':fireworks:']='🎆'
  ABBR_TABLE[':first_quarter_moon:']='🌓'
  ABBR_TABLE[':first_quarter_moon_with_face:']='🌛'
  ABBR_TABLE[':fish:']='🐟'
  ABBR_TABLE[':fish_cake:']='🍥'
  ABBR_TABLE[':fishing_pole_and_fish:']='🎣'
  ABBR_TABLE[':fist:']='✊'
  ABBR_TABLE[':fist_left:']='🤛'
  ABBR_TABLE[':fist_oncoming:']='👊'
  ABBR_TABLE[':fist_raised:']='✊'
  ABBR_TABLE[':fist_right:']='🤜'
  ABBR_TABLE[':five:']='5️⃣'
  ABBR_TABLE[':flags:']='🎏'
  ABBR_TABLE[':flamingo:']='🦩'
  ABBR_TABLE[':flashlight:']='🔦'
  ABBR_TABLE[':flatbread:']='🫓'
  ABBR_TABLE[':flat_shoe:']='🥿'
  ABBR_TABLE[':fleur_de_lis:']='⚜️'
  ABBR_TABLE[':flight_arrival:']='🛬'
  ABBR_TABLE[':flight_departure:']='🛫'
  ABBR_TABLE[':flipper:']='🐬'
  ABBR_TABLE[':floppy_disk:']='💾'
  ABBR_TABLE[':flower_playing_cards:']='🎴'
  ABBR_TABLE[':flushed:']='😳'
  ABBR_TABLE[':fly:']='🪰'
  ABBR_TABLE[':flying_disc:']='🥏'
  ABBR_TABLE[':flying_saucer:']='🛸'
  ABBR_TABLE[':fog:']='🌫️'
  ABBR_TABLE[':foggy:']='🌁'
  ABBR_TABLE[':fondue:']='🫕'
  ABBR_TABLE[':foot:']='🦶'
  ABBR_TABLE[':football:']='🏈'
  ABBR_TABLE[':footprints:']='👣'
  ABBR_TABLE[':fork_and_knife:']='🍴'
  ABBR_TABLE[':fortune_cookie:']='🥠'
  ABBR_TABLE[':fountain:']='⛲'
  ABBR_TABLE[':fountain_pen:']='🖋️'
  ABBR_TABLE[':four:']='4️⃣'
  ABBR_TABLE[':four_leaf_clover:']='🍀'
  ABBR_TABLE[':fox_face:']='🦊'
  ABBR_TABLE[':fr:']='🇫🇷'
  ABBR_TABLE[':framed_picture:']='🖼️'
  ABBR_TABLE[':free:']='🆓'
  ABBR_TABLE[':french_guiana:']='🇬🇫'
  ABBR_TABLE[':french_polynesia:']='🇵🇫'
  ABBR_TABLE[':french_southern_territories:']='🇹🇫'
  ABBR_TABLE[':fried_egg:']='🍳'
  ABBR_TABLE[':fried_shrimp:']='🍤'
  ABBR_TABLE[':fries:']='🍟'
  ABBR_TABLE[':frog:']='🐸'
  ABBR_TABLE[':frowning:']='😦'
  ABBR_TABLE[':frowning_face:']='☹️'
  ABBR_TABLE[':frowning_man:']='🙍‍♂️'
  ABBR_TABLE[':frowning_person:']='🙍'
  ABBR_TABLE[':frowning_woman:']='🙍‍♀️'
  ABBR_TABLE[':fu:']='🖕'
  ABBR_TABLE[':fuelpump:']='⛽'
  ABBR_TABLE[':full_moon:']='🌕'
  ABBR_TABLE[':full_moon_with_face:']='🌝'
  ABBR_TABLE[':funeral_urn:']='⚱️'
  ABBR_TABLE[':gabon:']='🇬🇦'
  ABBR_TABLE[':gambia:']='🇬🇲'
  ABBR_TABLE[':game_die:']='🎲'
  ABBR_TABLE[':garlic:']='🧄'
  ABBR_TABLE[':gb:']='🇬🇧'
  ABBR_TABLE[':gear:']='⚙️'
  ABBR_TABLE[':gem:']='💎'
  ABBR_TABLE[':gemini:']='♊'
  ABBR_TABLE[':genie:']='🧞'
  ABBR_TABLE[':genie_man:']='🧞‍♂️'
  ABBR_TABLE[':genie_woman:']='🧞‍♀️'
  ABBR_TABLE[':georgia:']='🇬🇪'
  ABBR_TABLE[':ghana:']='🇬🇭'
  ABBR_TABLE[':ghost:']='👻'
  ABBR_TABLE[':gibraltar:']='🇬🇮'
  ABBR_TABLE[':gift:']='🎁'
  ABBR_TABLE[':gift_heart:']='💝'
  ABBR_TABLE[':giraffe:']='🦒'
  ABBR_TABLE[':girl:']='👧'
  ABBR_TABLE[':globe_with_meridians:']='🌐'
  ABBR_TABLE[':gloves:']='🧤'
  ABBR_TABLE[':goal_net:']='🥅'
  ABBR_TABLE[':goat:']='🐐'
  ABBR_TABLE[':goggles:']='🥽'
  ABBR_TABLE[':golf:']='⛳'
  ABBR_TABLE[':golfing:']='🏌️'
  ABBR_TABLE[':golfing_man:']='🏌️‍♂️'
  ABBR_TABLE[':golfing_woman:']='🏌️‍♀️'
  ABBR_TABLE[':gorilla:']='🦍'
  ABBR_TABLE[':grapes:']='🍇'
  ABBR_TABLE[':greece:']='🇬🇷'
  ABBR_TABLE[':green_apple:']='🍏'
  ABBR_TABLE[':green_book:']='📗'
  ABBR_TABLE[':green_circle:']='🟢'
  ABBR_TABLE[':green_heart:']='💚'
  ABBR_TABLE[':greenland:']='🇬🇱'
  ABBR_TABLE[':green_salad:']='🥗'
  ABBR_TABLE[':green_square:']='🟩'
  ABBR_TABLE[':grenada:']='🇬🇩'
  ABBR_TABLE[':grey_exclamation:']='❕'
  ABBR_TABLE[':grey_question:']='❔'
  ABBR_TABLE[':grimacing:']='😬'
  ABBR_TABLE[':grin:']='😁'
  ABBR_TABLE[':grinning:']='😀'
  ABBR_TABLE[':guadeloupe:']='🇬🇵'
  ABBR_TABLE[':guam:']='🇬🇺'
  ABBR_TABLE[':guard:']='💂'
  ABBR_TABLE[':guardsman:']='💂‍♂️'
  ABBR_TABLE[':guardswoman:']='💂‍♀️'
  ABBR_TABLE[':guatemala:']='🇬🇹'
  ABBR_TABLE[':guernsey:']='🇬🇬'
  ABBR_TABLE[':guide_dog:']='🦮'
  ABBR_TABLE[':guinea:']='🇬🇳'
  ABBR_TABLE[':guinea_bissau:']='🇬🇼'
  ABBR_TABLE[':guitar:']='🎸'
  ABBR_TABLE[':gun:']='🔫'
  ABBR_TABLE[':guyana:']='🇬🇾'
  ABBR_TABLE[':haircut:']='💇'
  ABBR_TABLE[':haircut_man:']='💇‍♂️'
  ABBR_TABLE[':haircut_woman:']='💇‍♀️'
  ABBR_TABLE[':haiti:']='🇭🇹'
  ABBR_TABLE[':hamburger:']='🍔'
  ABBR_TABLE[':hammer:']='🔨'
  ABBR_TABLE[':hammer_and_pick:']='⚒️'
  ABBR_TABLE[':hammer_and_wrench:']='🛠️'
  ABBR_TABLE[':hamster:']='🐹'
  ABBR_TABLE[':hand:']='✋'
  ABBR_TABLE[':handbag:']='👜'
  ABBR_TABLE[':handball_person:']='🤾'
  ABBR_TABLE[':hand_over_mouth:']='🤭'
  ABBR_TABLE[':handshake:']='🤝'
  ABBR_TABLE[':hankey:']='💩'
  ABBR_TABLE[':hash:']='#️⃣'
  ABBR_TABLE[':hatched_chick:']='🐥'
  ABBR_TABLE[':hatching_chick:']='🐣'
  ABBR_TABLE[':headphones:']='🎧'
  ABBR_TABLE[':headstone:']='🪦'
  ABBR_TABLE[':health_worker:']='🧑‍⚕️'
  ABBR_TABLE[':heard_mcdonald_islands:']='🇭🇲'
  ABBR_TABLE[':hear_no_evil:']='🙉'
  ABBR_TABLE[':heart:']='❤️'
  ABBR_TABLE[':heartbeat:']='💓'
  ABBR_TABLE[':heart_decoration:']='💟'
  ABBR_TABLE[':heart_eyes:']='😍'
  ABBR_TABLE[':heart_eyes_cat:']='😻'
  ABBR_TABLE[':heartpulse:']='💗'
  ABBR_TABLE[':hearts:']='♥️'
  ABBR_TABLE[':heavy_check_mark:']='✔️'
  ABBR_TABLE[':heavy_division_sign:']='➗'
  ABBR_TABLE[':heavy_dollar_sign:']='💲'
  ABBR_TABLE[':heavy_exclamation_mark:']='❗'
  ABBR_TABLE[':heavy_heart_exclamation:']='❣️'
  ABBR_TABLE[':heavy_minus_sign:']='➖'
  ABBR_TABLE[':heavy_multiplication_x:']='✖️'
  ABBR_TABLE[':heavy_plus_sign:']='➕'
  ABBR_TABLE[':hedgehog:']='🦔'
  ABBR_TABLE[':helicopter:']='🚁'
  ABBR_TABLE[':herb:']='🌿'
  ABBR_TABLE[':hibiscus:']='🌺'
  ABBR_TABLE[':high_brightness:']='🔆'
  ABBR_TABLE[':high_heel:']='👠'
  ABBR_TABLE[':hiking_boot:']='🥾'
  ABBR_TABLE[':hindu_temple:']='🛕'
  ABBR_TABLE[':hippopotamus:']='🦛'
  ABBR_TABLE[':hocho:']='🔪'
  ABBR_TABLE[':hole:']='🕳️'
  ABBR_TABLE[':honduras:']='🇭🇳'
  ABBR_TABLE[':honeybee:']='🐝'
  ABBR_TABLE[':honey_pot:']='🍯'
  ABBR_TABLE[':hong_kong:']='🇭🇰'
  ABBR_TABLE[':hook:']='🪝'
  ABBR_TABLE[':horse:']='🐴'
  ABBR_TABLE[':horse_racing:']='🏇'
  ABBR_TABLE[':hospital:']='🏥'
  ABBR_TABLE[':hotdog:']='🌭'
  ABBR_TABLE[':hotel:']='🏨'
  ABBR_TABLE[':hot_face:']='🥵'
  ABBR_TABLE[':hot_pepper:']='🌶️'
  ABBR_TABLE[':hotsprings:']='♨️'
  ABBR_TABLE[':hourglass:']='⌛'
  ABBR_TABLE[':hourglass_flowing_sand:']='⏳'
  ABBR_TABLE[':house:']='🏠'
  ABBR_TABLE[':houses:']='🏘️'
  ABBR_TABLE[':house_with_garden:']='🏡'
  ABBR_TABLE[':hugs:']='🤗'
  ABBR_TABLE[':hungary:']='🇭🇺'
  ABBR_TABLE[':hushed:']='😯'
  ABBR_TABLE[':hut:']='🛖'
  ABBR_TABLE[':ice_cream:']='🍨'
  ABBR_TABLE[':icecream:']='🍦'
  ABBR_TABLE[':ice_cube:']='🧊'
  ABBR_TABLE[':ice_hockey:']='🏒'
  ABBR_TABLE[':iceland:']='🇮🇸'
  ABBR_TABLE[':ice_skate:']='⛸️'
  ABBR_TABLE[':ideograph_advantage:']='🉐'
  ABBR_TABLE[':id:']='🆔'
  ABBR_TABLE[':imp:']='👿'
  ABBR_TABLE[':inbox_tray:']='📥'
  ABBR_TABLE[':incoming_envelope:']='📨'
  ABBR_TABLE[':india:']='🇮🇳'
  ABBR_TABLE[':indonesia:']='🇮🇩'
  ABBR_TABLE[':infinity:']='♾️'
  ABBR_TABLE[':information_desk_person:']='💁'
  ABBR_TABLE[':information_source:']='ℹ️'
  ABBR_TABLE[':innocent:']='😇'
  ABBR_TABLE[':interrobang:']='⁉️'
  ABBR_TABLE[':iphone:']='📱'
  ABBR_TABLE[':iran:']='🇮🇷'
  ABBR_TABLE[':iraq:']='🇮🇶'
  ABBR_TABLE[':ireland:']='🇮🇪'
  ABBR_TABLE[':isle_of_man:']='🇮🇲'
  ABBR_TABLE[':israel:']='🇮🇱'
  ABBR_TABLE[':it:']='🇮🇹'
  ABBR_TABLE[':izakaya_lantern:']='🏮'
  ABBR_TABLE[':jack_o_lantern:']='🎃'
  ABBR_TABLE[':jamaica:']='🇯🇲'
  ABBR_TABLE[':japan:']='🗾'
  ABBR_TABLE[':japanese_castle:']='🏯'
  ABBR_TABLE[':japanese_goblin:']='👺'
  ABBR_TABLE[':japanese_ogre:']='👹'
  ABBR_TABLE[':jeans:']='👖'
  ABBR_TABLE[':jersey:']='🇯🇪'
  ABBR_TABLE[':jigsaw:']='🧩'
  ABBR_TABLE[':jordan:']='🇯🇴'
  ABBR_TABLE[':joy:']='😂'
  ABBR_TABLE[':joy_cat:']='😹'
  ABBR_TABLE[':joystick:']='🕹️'
  ABBR_TABLE[':jp:']='🇯🇵'
  ABBR_TABLE[':judge:']='🧑‍⚖️'
  ABBR_TABLE[':juggling_person:']='🤹'
  ABBR_TABLE[':kaaba:']='🕋'
  ABBR_TABLE[':kangaroo:']='🦘'
  ABBR_TABLE[':kazakhstan:']='🇰🇿'
  ABBR_TABLE[':kenya:']='🇰🇪'
  ABBR_TABLE[':key:']='🔑'
  ABBR_TABLE[':keyboard:']='⌨️'
  ABBR_TABLE[':keycap_ten:']='🔟'
  ABBR_TABLE[':kick_scooter:']='🛴'
  ABBR_TABLE[':kimono:']='👘'
  ABBR_TABLE[':kiribati:']='🇰🇮'
  ABBR_TABLE[':kiss:']='💋'
  ABBR_TABLE[':kissing:']='😗'
  ABBR_TABLE[':kissing_cat:']='😽'
  ABBR_TABLE[':kissing_closed_eyes:']='😚'
  ABBR_TABLE[':kissing_heart:']='😘'
  ABBR_TABLE[':kissing_smiling_eyes:']='😙'
  ABBR_TABLE[':kite:']='🪁'
  ABBR_TABLE[':kiwi_fruit:']='🥝'
  ABBR_TABLE[':kneeling_man:']='🧎‍♂️'
  ABBR_TABLE[':kneeling_person:']='🧎'
  ABBR_TABLE[':kneeling_woman:']='🧎‍♀️'
  ABBR_TABLE[':knife:']='🔪'
  ABBR_TABLE[':knot:']='🪢'
  ABBR_TABLE[':koala:']='🐨'
  ABBR_TABLE[':koko:']='🈁'
  ABBR_TABLE[':kosovo:']='🇽🇰'
  ABBR_TABLE[':kr:']='🇰🇷'
  ABBR_TABLE[':kuwait:']='🇰🇼'
  ABBR_TABLE[':kyrgyzstan:']='🇰🇬'
  ABBR_TABLE[':lab_coat:']='🥼'
  ABBR_TABLE[':label:']='🏷️'
  ABBR_TABLE[':lacrosse:']='🥍'
  ABBR_TABLE[':ladder:']='🪜'
  ABBR_TABLE[':lady_beetle:']='🐞'
  ABBR_TABLE[':lantern:']='🏮'
  ABBR_TABLE[':laos:']='🇱🇦'
  ABBR_TABLE[':large_blue_circle:']='🔵'
  ABBR_TABLE[':large_blue_diamond:']='🔷'
  ABBR_TABLE[':large_orange_diamond:']='🔶'
  ABBR_TABLE[':last_quarter_moon:']='🌗'
  ABBR_TABLE[':last_quarter_moon_with_face:']='🌜'
  ABBR_TABLE[':latin_cross:']='✝️'
  ABBR_TABLE[':latvia:']='🇱🇻'
  ABBR_TABLE[':laughing:']='😆'
  ABBR_TABLE[':leafy_green:']='🥬'
  ABBR_TABLE[':leaves:']='🍃'
  ABBR_TABLE[':lebanon:']='🇱🇧'
  ABBR_TABLE[':ledger:']='📒'
  ABBR_TABLE[':left_luggage:']='🛅'
  ABBR_TABLE[':left_right_arrow:']='↔️'
  ABBR_TABLE[':left_speech_bubble:']='🗨️'
  ABBR_TABLE[':leftwards_arrow_with_hook:']='↩️'
  ABBR_TABLE[':leg:']='🦵'
  ABBR_TABLE[':lemon:']='🍋'
  ABBR_TABLE[':leo:']='♌'
  ABBR_TABLE[':leopard:']='🐆'
  ABBR_TABLE[':lesotho:']='🇱🇸'
  ABBR_TABLE[':level_slider:']='🎚️'
  ABBR_TABLE[':liberia:']='🇱🇷'
  ABBR_TABLE[':libra:']='♎'
  ABBR_TABLE[':libya:']='🇱🇾'
  ABBR_TABLE[':liechtenstein:']='🇱🇮'
  ABBR_TABLE[':light_rail:']='🚈'
  ABBR_TABLE[':link:']='🔗'
  ABBR_TABLE[':lion:']='🦁'
  ABBR_TABLE[':lips:']='👄'
  ABBR_TABLE[':lipstick:']='💄'
  ABBR_TABLE[':lithuania:']='🇱🇹'
  ABBR_TABLE[':lizard:']='🦎'
  ABBR_TABLE[':llama:']='🦙'
  ABBR_TABLE[':lobster:']='🦞'
  ABBR_TABLE[':lock:']='🔒'
  ABBR_TABLE[':lock_with_ink_pen:']='🔏'
  ABBR_TABLE[':lollipop:']='🍭'
  ABBR_TABLE[':long_drum:']='🪘'
  ABBR_TABLE[':loop:']='➿'
  ABBR_TABLE[':lotion_bottle:']='🧴'
  ABBR_TABLE[':lotus_position:']='🧘'
  ABBR_TABLE[':lotus_position_man:']='🧘‍♂️'
  ABBR_TABLE[':lotus_position_woman:']='🧘‍♀️'
  ABBR_TABLE[':loud_sound:']='🔊'
  ABBR_TABLE[':loudspeaker:']='📢'
  ABBR_TABLE[':love:']='❤️'
  ABBR_TABLE[':love_hotel:']='🏩'
  ABBR_TABLE[':love_letter:']='💌'
  ABBR_TABLE[':love_you_gesture:']='🤟'
  ABBR_TABLE[':low_brightness:']='🔅'
  ABBR_TABLE[':luggage:']='🧳'
  ABBR_TABLE[':lungs:']='🫁'
  ABBR_TABLE[':luxembourg:']='🇱🇺'
  ABBR_TABLE[':lying_face:']='🤥'
  ABBR_TABLE[':macau:']='🇲🇴'
  ABBR_TABLE[':macedonia:']='🇲🇰'
  ABBR_TABLE[':madagascar:']='🇲🇬'
  ABBR_TABLE[':mag:']='🔍'
  ABBR_TABLE[':mage:']='🧙'
  ABBR_TABLE[':mage_man:']='🧙‍♂️'
  ABBR_TABLE[':mage_woman:']='🧙‍♀️'
  ABBR_TABLE[':magic_wand:']='🪄'
  ABBR_TABLE[':magnet:']='🧲'
  ABBR_TABLE[':mag_right:']='🔎'
  ABBR_TABLE[':mahjong:']='🀄'
  ABBR_TABLE[':mailbox:']='📫'
  ABBR_TABLE[':mailbox_closed:']='📪'
  ABBR_TABLE[':mailbox_with_mail:']='📬'
  ABBR_TABLE[':mailbox_with_no_mail:']='📭'
  ABBR_TABLE[':malawi:']='🇲🇼'
  ABBR_TABLE[':malaysia:']='🇲🇾'
  ABBR_TABLE[':maldives:']='🇲🇻'
  ABBR_TABLE[':male_detective:']='🕵️‍♂️'
  ABBR_TABLE[':male_sign:']='♂️'
  ABBR_TABLE[':mali:']='🇲🇱'
  ABBR_TABLE[':malta:']='🇲🇹'
  ABBR_TABLE[':mammoth:']='🦣'
  ABBR_TABLE[':man:']='👨'
  ABBR_TABLE[':man_artist:']='👨‍🎨'
  ABBR_TABLE[':man_astronaut:']='👨‍🚀'
  ABBR_TABLE[':man_cartwheeling:']='🤸‍♂️'
  ABBR_TABLE[':man_cook:']='👨‍🍳'
  ABBR_TABLE[':man_dancing:']='🕺'
  ABBR_TABLE[':mandarin:']='🍊'
  ABBR_TABLE[':man_facepalming:']='🤦‍♂️'
  ABBR_TABLE[':man_factory_worker:']='👨‍🏭'
  ABBR_TABLE[':man_farmer:']='👨‍🌾'
  ABBR_TABLE[':man_feeding_baby:']='👨‍🍼'
  ABBR_TABLE[':man_firefighter:']='👨‍🚒'
  ABBR_TABLE[':mango:']='🥭'
  ABBR_TABLE[':man_health_worker:']='👨‍⚕️'
  ABBR_TABLE[':man_in_manual_wheelchair:']='👨‍🦽'
  ABBR_TABLE[':man_in_motorized_wheelchair:']='👨‍🦼'
  ABBR_TABLE[':man_in_tuxedo:']='🤵‍♂️'
  ABBR_TABLE[':man_judge:']='👨‍⚖️'
  ABBR_TABLE[':man_juggling:']='🤹‍♂️'
  ABBR_TABLE[':man_mechanic:']='👨‍🔧'
  ABBR_TABLE[':man_office_worker:']='👨‍💼'
  ABBR_TABLE[':man_pilot:']='👨‍✈️'
  ABBR_TABLE[':man_playing_handball:']='🤾‍♂️'
  ABBR_TABLE[':man_playing_water_polo:']='🤽‍♂️'
  ABBR_TABLE[':man_scientist:']='👨‍🔬'
  ABBR_TABLE[':man_shrugging:']='🤷‍♂️'
  ABBR_TABLE[':man_singer:']='👨‍🎤'
  ABBR_TABLE[':mans_shoe:']='👞'
  ABBR_TABLE[':man_student:']='👨‍🎓'
  ABBR_TABLE[':man_teacher:']='👨‍🏫'
  ABBR_TABLE[':man_technologist:']='👨‍💻'
  ABBR_TABLE[':mantelpiece_clock:']='🕰️'
  ABBR_TABLE[':manual_wheelchair:']='🦽'
  ABBR_TABLE[':man_with_gua_pi_mao:']='👲'
  ABBR_TABLE[':man_with_probing_cane:']='👨‍🦯'
  ABBR_TABLE[':man_with_turban:']='👳‍♂️'
  ABBR_TABLE[':man_with_veil:']='👰‍♂️'
  ABBR_TABLE[':maple_leaf:']='🍁'
  ABBR_TABLE[':marshall_islands:']='🇲🇭'
  ABBR_TABLE[':martial_arts_uniform:']='🥋'
  ABBR_TABLE[':martinique:']='🇲🇶'
  ABBR_TABLE[':mask:']='😷'
  ABBR_TABLE[':massage:']='💆'
  ABBR_TABLE[':massage_man:']='💆‍♂️'
  ABBR_TABLE[':massage_woman:']='💆‍♀️'
  ABBR_TABLE[':mate:']='🧉'
  ABBR_TABLE[':mauritania:']='🇲🇷'
  ABBR_TABLE[':mauritius:']='🇲🇺'
  ABBR_TABLE[':mayotte:']='🇾🇹'
  ABBR_TABLE[':meat_on_bone:']='🍖'
  ABBR_TABLE[':mechanic:']='🧑‍🔧'
  ABBR_TABLE[':mechanical_arm:']='🦾'
  ABBR_TABLE[':mechanical_leg:']='🦿'
  ABBR_TABLE[':medal_military:']='🎖️'
  ABBR_TABLE[':medal_sports:']='🏅'
  ABBR_TABLE[':medical_symbol:']='⚕️'
  ABBR_TABLE[':mega:']='📣'
  ABBR_TABLE[':melon:']='🍈'
  ABBR_TABLE[':memo:']='📝'
  ABBR_TABLE[':menorah:']='🕎'
  ABBR_TABLE[':mens:']='🚹'
  ABBR_TABLE[':men_wrestling:']='🤼‍♂️'
  ABBR_TABLE[':mermaid:']='🧜‍♀️'
  ABBR_TABLE[':merman:']='🧜‍♂️'
  ABBR_TABLE[':merperson:']='🧜'
  ABBR_TABLE[':metal:']='🤘'
  ABBR_TABLE[':metro:']='🚇'
  ABBR_TABLE[':mexico:']='🇲🇽'
  ABBR_TABLE[':microbe:']='🦠'
  ABBR_TABLE[':micronesia:']='🇫🇲'
  ABBR_TABLE[':microphone:']='🎤'
  ABBR_TABLE[':microscope:']='🔬'
  ABBR_TABLE[':middle_finger:']='🖕'
  ABBR_TABLE[':military_helmet:']='🪖'
  ABBR_TABLE[':milk_glass:']='🥛'
  ABBR_TABLE[':milky_way:']='🌌'
  ABBR_TABLE[':minibus:']='🚐'
  ABBR_TABLE[':minidisc:']='💽'
  ABBR_TABLE[':mirror:']='🪞'
  ABBR_TABLE[':m:']='Ⓜ️'
  ABBR_TABLE[':mobile_phone_off:']='📴'
  ABBR_TABLE[':moldova:']='🇲🇩'
  ABBR_TABLE[':monaco:']='🇲🇨'
  ABBR_TABLE[':moneybag:']='💰'
  ABBR_TABLE[':money_mouth_face:']='🤑'
  ABBR_TABLE[':money_with_wings:']='💸'
  ABBR_TABLE[':mongolia:']='🇲🇳'
  ABBR_TABLE[':monkey:']='🐒'
  ABBR_TABLE[':monkey_face:']='🐵'
  ABBR_TABLE[':monocle_face:']='🧐'
  ABBR_TABLE[':monorail:']='🚝'
  ABBR_TABLE[':montenegro:']='🇲🇪'
  ABBR_TABLE[':montserrat:']='🇲🇸'
  ABBR_TABLE[':moon:']='🌔'
  ABBR_TABLE[':moon_cake:']='🥮'
  ABBR_TABLE[':morocco:']='🇲🇦'
  ABBR_TABLE[':mortar_board:']='🎓'
  ABBR_TABLE[':mosque:']='🕌'
  ABBR_TABLE[':mosquito:']='🦟'
  ABBR_TABLE[':motor_boat:']='🛥️'
  ABBR_TABLE[':motorcycle:']='🏍️'
  ABBR_TABLE[':motorized_wheelchair:']='🦼'
  ABBR_TABLE[':motor_scooter:']='🛵'
  ABBR_TABLE[':motorway:']='🛣️'
  ABBR_TABLE[':mountain:']='⛰️'
  ABBR_TABLE[':mountain_bicyclist:']='🚵'
  ABBR_TABLE[':mountain_biking_man:']='🚵‍♂️'
  ABBR_TABLE[':mountain_biking_woman:']='🚵‍♀️'
  ABBR_TABLE[':mountain_cableway:']='🚠'
  ABBR_TABLE[':mountain_railway:']='🚞'
  ABBR_TABLE[':mountain_snow:']='🏔️'
  ABBR_TABLE[':mount_fuji:']='🗻'
  ABBR_TABLE[':mouse:']='🐭'
  ABBR_TABLE[':mouse2:']='🐁'
  ABBR_TABLE[':mouse_trap:']='🪤'
  ABBR_TABLE[':movie_camera:']='🎥'
  ABBR_TABLE[':moyai:']='🗿'
  ABBR_TABLE[':mozambique:']='🇲🇿'
  ABBR_TABLE[':mrs_claus:']='🤶'
  ABBR_TABLE[':muscle:']='💪'
  ABBR_TABLE[':mushroom:']='🍄'
  ABBR_TABLE[':musical_keyboard:']='🎹'
  ABBR_TABLE[':musical_note:']='🎵'
  ABBR_TABLE[':musical_score:']='🎼'
  ABBR_TABLE[':mute:']='🔇'
  ABBR_TABLE[':mx_claus:']='🧑‍🎄'
  ABBR_TABLE[':myanmar:']='🇲🇲'
  ABBR_TABLE[':nail_care:']='💅'
  ABBR_TABLE[':name_badge:']='📛'
  ABBR_TABLE[':namibia:']='🇳🇦'
  ABBR_TABLE[':national_park:']='🏞️'
  ABBR_TABLE[':nauru:']='🇳🇷'
  ABBR_TABLE[':nauseated_face:']='🤢'
  ABBR_TABLE[':nazar_amulet:']='🧿'
  ABBR_TABLE[':necktie:']='👔'
  ABBR_TABLE[':negative_squared_cross_mark:']='❎'
  ABBR_TABLE[':nepal:']='🇳🇵'
  ABBR_TABLE[':nerd_face:']='🤓'
  ABBR_TABLE[':nesting_dolls:']='🪆'
  ABBR_TABLE[':netherlands:']='🇳🇱'
  ABBR_TABLE[':neutral_face:']='😐'
  ABBR_TABLE[':new_caledonia:']='🇳🇨'
  ABBR_TABLE[':new_moon:']='🌑'
  ABBR_TABLE[':new_moon_with_face:']='🌚'
  ABBR_TABLE[':new:']='🆕'
  ABBR_TABLE[':newspaper:']='📰'
  ABBR_TABLE[':newspaper_roll:']='🗞️'
  ABBR_TABLE[':new_zealand:']='🇳🇿'
  ABBR_TABLE[':next_track_button:']='⏭️'
  ABBR_TABLE[':ng_man:']='🙅‍♂️'
  ABBR_TABLE[':ng:']='🆖'
  ABBR_TABLE[':ng_woman:']='🙅‍♀️'
  ABBR_TABLE[':nicaragua:']='🇳🇮'
  ABBR_TABLE[':niger:']='🇳🇪'
  ABBR_TABLE[':nigeria:']='🇳🇬'
  ABBR_TABLE[':night_with_stars:']='🌃'
  ABBR_TABLE[':nine:']='9️⃣'
  ABBR_TABLE[':ninja:']='🥷'
  ABBR_TABLE[':niue:']='🇳🇺'
  ABBR_TABLE[':no_bell:']='🔕'
  ABBR_TABLE[':no_bicycles:']='🚳'
  ABBR_TABLE[':no_entry:']='⛔'
  ABBR_TABLE[':no_entry_sign:']='🚫'
  ABBR_TABLE[':no_good:']='🙅'
  ABBR_TABLE[':no_good_man:']='🙅‍♂️'
  ABBR_TABLE[':no_good_woman:']='🙅‍♀️'
  ABBR_TABLE[':no_mobile_phones:']='📵'
  ABBR_TABLE[':no_mouth:']='😶'
  ABBR_TABLE[':non-potable_water:']='🚱'
  ABBR_TABLE[':no_pedestrians:']='🚷'
  ABBR_TABLE[':norfolk_island:']='🇳🇫'
  ABBR_TABLE[':northern_mariana_islands:']='🇲🇵'
  ABBR_TABLE[':north_korea:']='🇰🇵'
  ABBR_TABLE[':norway:']='🇳🇴'
  ABBR_TABLE[':nose:']='👃'
  ABBR_TABLE[':no_smoking:']='🚭'
  ABBR_TABLE[':notebook:']='📓'
  ABBR_TABLE[':notebook_with_decorative_cover:']='📔'
  ABBR_TABLE[':notes:']='🎶'
  ABBR_TABLE[':nut_and_bolt:']='🔩'
  ABBR_TABLE[':o:']='⭕'
  ABBR_TABLE[':o2:']='🅾️'
  ABBR_TABLE[':ocean:']='🌊'
  ABBR_TABLE[':octopus:']='🐙'
  ABBR_TABLE[':oden:']='🍢'
  ABBR_TABLE[':office:']='🏢'
  ABBR_TABLE[':office_worker:']='🧑‍💼'
  ABBR_TABLE[':oil_drum:']='🛢️'
  ABBR_TABLE[':ok_hand:']='👌'
  ABBR_TABLE[':ok_man:']='🙆‍♂️'
  ABBR_TABLE[':ok:']='🆗'
  ABBR_TABLE[':ok_person:']='🙆'
  ABBR_TABLE[':ok_woman:']='🙆‍♀️'
  ABBR_TABLE[':older_adult:']='🧓'
  ABBR_TABLE[':older_man:']='👴'
  ABBR_TABLE[':older_woman:']='👵'
  ABBR_TABLE[':old_key:']='🗝️'
  ABBR_TABLE[':olive:']='🫒'
  ABBR_TABLE[':om:']='🕉️'
  ABBR_TABLE[':oman:']='🇴🇲'
  ABBR_TABLE[':on:']='🔛'
  ABBR_TABLE[':oncoming_automobile:']='🚘'
  ABBR_TABLE[':oncoming_bus:']='🚍'
  ABBR_TABLE[':oncoming_police_car:']='🚔'
  ABBR_TABLE[':oncoming_taxi:']='🚖'
  ABBR_TABLE[':one:']='1️⃣'
  ABBR_TABLE[':one_piece_swimsuit:']='🩱'
  ABBR_TABLE[':onion:']='🧅'
  ABBR_TABLE[':open_book:']='📖'
  ABBR_TABLE[':open_file_folder:']='📂'
  ABBR_TABLE[':open_hands:']='👐'
  ABBR_TABLE[':open_mouth:']='😮'
  ABBR_TABLE[':open_umbrella:']='☂️'
  ABBR_TABLE[':ophiuchus:']='⛎'
  ABBR_TABLE[':orange:']='🍊'
  ABBR_TABLE[':orange_book:']='📙'
  ABBR_TABLE[':orange_circle:']='🟠'
  ABBR_TABLE[':orange_heart:']='🧡'
  ABBR_TABLE[':orange_square:']='🟧'
  ABBR_TABLE[':orangutan:']='🦧'
  ABBR_TABLE[':orthodox_cross:']='☦️'
  ABBR_TABLE[':otter:']='🦦'
  ABBR_TABLE[':outbox_tray:']='📤'
  ABBR_TABLE[':owl:']='🦉'
  ABBR_TABLE[':ox:']='🐂'
  ABBR_TABLE[':oyster:']='🦪'
  ABBR_TABLE[':package:']='📦'
  ABBR_TABLE[':page_facing_up:']='📄'
  ABBR_TABLE[':pager:']='📟'
  ABBR_TABLE[':page_with_curl:']='📃'
  ABBR_TABLE[':paintbrush:']='🖌️'
  ABBR_TABLE[':pakistan:']='🇵🇰'
  ABBR_TABLE[':palau:']='🇵🇼'
  ABBR_TABLE[':palestinian_territories:']='🇵🇸'
  ABBR_TABLE[':palms_up_together:']='🤲'
  ABBR_TABLE[':palm_tree:']='🌴'
  ABBR_TABLE[':panama:']='🇵🇦'
  ABBR_TABLE[':pancakes:']='🥞'
  ABBR_TABLE[':panda_face:']='🐼'
  ABBR_TABLE[':paperclip:']='📎'
  ABBR_TABLE[':paperclips:']='🖇️'
  ABBR_TABLE[':papua_new_guinea:']='🇵🇬'
  ABBR_TABLE[':parachute:']='🪂'
  ABBR_TABLE[':paraguay:']='🇵🇾'
  ABBR_TABLE[':parasol_on_ground:']='⛱️'
  ABBR_TABLE[':parking:']='🅿️'
  ABBR_TABLE[':parrot:']='🦜'
  ABBR_TABLE[':part_alternation_mark:']='〽️'
  ABBR_TABLE[':partly_sunny:']='⛅'
  ABBR_TABLE[':partying_face:']='🥳'
  ABBR_TABLE[':passenger_ship:']='🛳️'
  ABBR_TABLE[':passport_control:']='🛂'
  ABBR_TABLE[':pause_button:']='⏸️'
  ABBR_TABLE[':paw_prints:']='🐾'
  ABBR_TABLE[':peace_symbol:']='☮️'
  ABBR_TABLE[':peach:']='🍑'
  ABBR_TABLE[':peacock:']='🦚'
  ABBR_TABLE[':peanuts:']='🥜'
  ABBR_TABLE[':pear:']='🍐'
  ABBR_TABLE[':pen:']='🖊️'
  ABBR_TABLE[':pencil:']='📝'
  ABBR_TABLE[':pencil2:']='✏️'
  ABBR_TABLE[':penguin:']='🐧'
  ABBR_TABLE[':pensive:']='😔'
  ABBR_TABLE[':people_holding_hands:']='🧑‍🤝‍🧑'
  ABBR_TABLE[':people_hugging:']='🫂'
  ABBR_TABLE[':performing_arts:']='🎭'
  ABBR_TABLE[':persevere:']='😣'
  ABBR_TABLE[':person_bald:']='🧑‍🦲'
  ABBR_TABLE[':person_curly_hair:']='🧑‍🦱'
  ABBR_TABLE[':person_feeding_baby:']='🧑‍🍼'
  ABBR_TABLE[':person_fencing:']='🤺'
  ABBR_TABLE[':person_in_manual_wheelchair:']='🧑‍🦽'
  ABBR_TABLE[':person_in_motorized_wheelchair:']='🧑‍🦼'
  ABBR_TABLE[':person_in_tuxedo:']='🤵'
  ABBR_TABLE[':person_red_hair:']='🧑‍🦰'
  ABBR_TABLE[':person_white_hair:']='🧑‍🦳'
  ABBR_TABLE[':person_with_probing_cane:']='🧑‍🦯'
  ABBR_TABLE[':person_with_turban:']='👳'
  ABBR_TABLE[':person_with_veil:']='👰'
  ABBR_TABLE[':peru:']='🇵🇪'
  ABBR_TABLE[':petri_dish:']='🧫'
  ABBR_TABLE[':philippines:']='🇵🇭'
  ABBR_TABLE[':phone:']='☎️'
  ABBR_TABLE[':pick:']='⛏️'
  ABBR_TABLE[':pickup_truck:']='🛻'
  ABBR_TABLE[':pie:']='🥧'
  ABBR_TABLE[':pig:']='🐷'
  ABBR_TABLE[':pig2:']='🐖'
  ABBR_TABLE[':pig_nose:']='🐽'
  ABBR_TABLE[':pill:']='💊'
  ABBR_TABLE[':pilot:']='🧑‍✈️'
  ABBR_TABLE[':pinata:']='🪅'
  ABBR_TABLE[':pinched_fingers:']='🤌'
  ABBR_TABLE[':pinching_hand:']='🤏'
  ABBR_TABLE[':pineapple:']='🍍'
  ABBR_TABLE[':ping_pong:']='🏓'
  ABBR_TABLE[':pirate_flag:']='🏴‍☠️'
  ABBR_TABLE[':pisces:']='♓'
  ABBR_TABLE[':pitcairn_islands:']='🇵🇳'
  ABBR_TABLE[':pizza:']='🍕'
  ABBR_TABLE[':placard:']='🪧'
  ABBR_TABLE[':place_of_worship:']='🛐'
  ABBR_TABLE[':plate_with_cutlery:']='🍽️'
  ABBR_TABLE[':play_or_pause_button:']='⏯️'
  ABBR_TABLE[':pleading_face:']='🥺'
  ABBR_TABLE[':plunger:']='🪠'
  ABBR_TABLE[':point_down:']='👇'
  ABBR_TABLE[':point_left:']='👈'
  ABBR_TABLE[':point_right:']='👉'
  ABBR_TABLE[':point_up:']='☝️'
  ABBR_TABLE[':point_up_2:']='👆'
  ABBR_TABLE[':poland:']='🇵🇱'
  ABBR_TABLE[':polar_bear:']='🐻‍❄️'
  ABBR_TABLE[':police_car:']='🚓'
  ABBR_TABLE[':policeman:']='👮‍♂️'
  ABBR_TABLE[':police_officer:']='👮'
  ABBR_TABLE[':policewoman:']='👮‍♀️'
  ABBR_TABLE[':poodle:']='🐩'
  ABBR_TABLE[':poop:']='💩'
  ABBR_TABLE[':popcorn:']='🍿'
  ABBR_TABLE[':portugal:']='🇵🇹'
  ABBR_TABLE[':postal_horn:']='📯'
  ABBR_TABLE[':postbox:']='📮'
  ABBR_TABLE[':post_office:']='🏣'
  ABBR_TABLE[':potable_water:']='🚰'
  ABBR_TABLE[':potato:']='🥔'
  ABBR_TABLE[':potted_plant:']='🪴'
  ABBR_TABLE[':pouch:']='👝'
  ABBR_TABLE[':poultry_leg:']='🍗'
  ABBR_TABLE[':pound:']='💷'
  ABBR_TABLE[':pout:']='😡'
  ABBR_TABLE[':pouting_cat:']='😾'
  ABBR_TABLE[':pouting_face:']='🙎'
  ABBR_TABLE[':pouting_man:']='🙎‍♂️'
  ABBR_TABLE[':pouting_woman:']='🙎‍♀️'
  ABBR_TABLE[':pray:']='🙏'
  ABBR_TABLE[':prayer_beads:']='📿'
  ABBR_TABLE[':pregnant_woman:']='🤰'
  ABBR_TABLE[':pretzel:']='🥨'
  ABBR_TABLE[':previous_track_button:']='⏮️'
  ABBR_TABLE[':prince:']='🤴'
  ABBR_TABLE[':princess:']='👸'
  ABBR_TABLE[':printer:']='🖨️'
  ABBR_TABLE[':probing_cane:']='🦯'
  ABBR_TABLE[':puerto_rico:']='🇵🇷'
  ABBR_TABLE[':punch:']='👊'
  ABBR_TABLE[':purple_circle:']='🟣'
  ABBR_TABLE[':purple_heart:']='💜'
  ABBR_TABLE[':purple_square:']='🟪'
  ABBR_TABLE[':purse:']='👛'
  ABBR_TABLE[':pushpin:']='📌'
  ABBR_TABLE[':put_litter_in_its_place:']='🚮'
  ABBR_TABLE[':qatar:']='🇶🇦'
  ABBR_TABLE[':question:']='❓'
  ABBR_TABLE[':rabbit:']='🐰'
  ABBR_TABLE[':rabbit2:']='🐇'
  ABBR_TABLE[':raccoon:']='🦝'
  ABBR_TABLE[':racehorse:']='🐎'
  ABBR_TABLE[':racing_car:']='🏎️'
  ABBR_TABLE[':radio:']='📻'
  ABBR_TABLE[':radioactive:']='☢️'
  ABBR_TABLE[':radio_button:']='🔘'
  ABBR_TABLE[':rage:']='😡'
  ABBR_TABLE[':railway_car:']='🚃'
  ABBR_TABLE[':railway_track:']='🛤️'
  ABBR_TABLE[':rainbow:']='🌈'
  ABBR_TABLE[':rainbow_flag:']='🏳️‍🌈'
  ABBR_TABLE[':raised_back_of_hand:']='🤚'
  ABBR_TABLE[':raised_eyebrow:']='🤨'
  ABBR_TABLE[':raised_hand:']='✋'
  ABBR_TABLE[':raised_hands:']='🙌'
  ABBR_TABLE[':raised_hand_with_fingers_splayed:']='🖐️'
  ABBR_TABLE[':raising_hand:']='🙋'
  ABBR_TABLE[':raising_hand_man:']='🙋‍♂️'
  ABBR_TABLE[':raising_hand_woman:']='🙋‍♀️'
  ABBR_TABLE[':ram:']='🐏'
  ABBR_TABLE[':ramen:']='🍜'
  ABBR_TABLE[':rat:']='🐀'
  ABBR_TABLE[':razor:']='🪒'
  ABBR_TABLE[':receipt:']='🧾'
  ABBR_TABLE[':record_button:']='⏺️'
  ABBR_TABLE[':recycle:']='♻️'
  ABBR_TABLE[':red_car:']='🚗'
  ABBR_TABLE[':red_circle:']='🔴'
  ABBR_TABLE[':red_envelope:']='🧧'
  ABBR_TABLE[':red_haired_man:']='👨‍🦰'
  ABBR_TABLE[':red_haired_woman:']='👩‍🦰'
  ABBR_TABLE[':red_square:']='🟥'
  ABBR_TABLE[':registered:']='®️'
  ABBR_TABLE[':relaxed:']='☺️'
  ABBR_TABLE[':relieved:']='😌'
  ABBR_TABLE[':reminder_ribbon:']='🎗️'
  ABBR_TABLE[':repeat:']='🔁'
  ABBR_TABLE[':repeat_one:']='🔂'
  ABBR_TABLE[':rescue_worker_helmet:']='⛑️'
  ABBR_TABLE[':restroom:']='🚻'
  ABBR_TABLE[':reunion:']='🇷🇪'
  ABBR_TABLE[':revolving_hearts:']='💞'
  ABBR_TABLE[':rewind:']='⏪'
  ABBR_TABLE[':rhinoceros:']='🦏'
  ABBR_TABLE[':ribbon:']='🎀'
  ABBR_TABLE[':rice:']='🍚'
  ABBR_TABLE[':rice_ball:']='🍙'
  ABBR_TABLE[':rice_cracker:']='🍘'
  ABBR_TABLE[':rice_scene:']='🎑'
  ABBR_TABLE[':right_anger_bubble:']='🗯️'
  ABBR_TABLE[':ring:']='💍'
  ABBR_TABLE[':ringed_planet:']='🪐'
  ABBR_TABLE[':robot:']='🤖'
  ABBR_TABLE[':rock:']='🪨'
  ABBR_TABLE[':rocket:']='🚀'
  ABBR_TABLE[':rofl:']='🤣'
  ABBR_TABLE[':roller_coaster:']='🎢'
  ABBR_TABLE[':roller_skate:']='🛼'
  ABBR_TABLE[':roll_eyes:']='🙄'
  ABBR_TABLE[':roll_of_paper:']='🧻'
  ABBR_TABLE[':romania:']='🇷🇴'
  ABBR_TABLE[':rooster:']='🐓'
  ABBR_TABLE[':rose:']='🌹'
  ABBR_TABLE[':rosette:']='🏵️'
  ABBR_TABLE[':rotating_light:']='🚨'
  ABBR_TABLE[':round_pushpin:']='📍'
  ABBR_TABLE[':rowboat:']='🚣'
  ABBR_TABLE[':rowing_man:']='🚣‍♂️'
  ABBR_TABLE[':rowing_woman:']='🚣‍♀️'
  ABBR_TABLE[':ru:']='🇷🇺'
  ABBR_TABLE[':rugby_football:']='🏉'
  ABBR_TABLE[':runner:']='🏃'
  ABBR_TABLE[':running:']='🏃'
  ABBR_TABLE[':running_man:']='🏃‍♂️'
  ABBR_TABLE[':running_shirt_with_sash:']='🎽'
  ABBR_TABLE[':running_woman:']='🏃‍♀️'
  ABBR_TABLE[':rwanda:']='🇷🇼'
  ABBR_TABLE[':safety_pin:']='🧷'
  ABBR_TABLE[':safety_vest:']='🦺'
  ABBR_TABLE[':sagittarius:']='♐'
  ABBR_TABLE[':sailboat:']='⛵'
  ABBR_TABLE[':sake:']='🍶'
  ABBR_TABLE[':salt:']='🧂'
  ABBR_TABLE[':samoa:']='🇼🇸'
  ABBR_TABLE[':sandal:']='👡'
  ABBR_TABLE[':sandwich:']='🥪'
  ABBR_TABLE[':san_marino:']='🇸🇲'
  ABBR_TABLE[':santa:']='🎅'
  ABBR_TABLE[':sao_tome_principe:']='🇸🇹'
  ABBR_TABLE[':sari:']='🥻'
  ABBR_TABLE[':sassy_man:']='💁‍♂️'
  ABBR_TABLE[':sassy_woman:']='💁‍♀️'
  ABBR_TABLE[':satellite:']='📡'
  ABBR_TABLE[':satisfied:']='😆'
  ABBR_TABLE[':saudi_arabia:']='🇸🇦'
  ABBR_TABLE[':sauna_man:']='🧖‍♂️'
  ABBR_TABLE[':sauna_person:']='🧖'
  ABBR_TABLE[':sauna_woman:']='🧖‍♀️'
  ABBR_TABLE[':sauropod:']='🦕'
  ABBR_TABLE[':saxophone:']='🎷'
  ABBR_TABLE[':sa:']='🈂️'
  ABBR_TABLE[':scarf:']='🧣'
  ABBR_TABLE[':school:']='🏫'
  ABBR_TABLE[':school_satchel:']='🎒'
  ABBR_TABLE[':scientist:']='🧑‍🔬'
  ABBR_TABLE[':scissors:']='✂️'
  ABBR_TABLE[':scorpion:']='🦂'
  ABBR_TABLE[':scorpius:']='♏'
  ABBR_TABLE[':scotland:']='🏴󠁧󠁢󠁳󠁣󠁴󠁿'
  ABBR_TABLE[':scream:']='😱'
  ABBR_TABLE[':scream_cat:']='🙀'
  ABBR_TABLE[':screwdriver:']='🪛'
  ABBR_TABLE[':scroll:']='📜'
  ABBR_TABLE[':seal:']='🦭'
  ABBR_TABLE[':seat:']='💺'
  ABBR_TABLE[':secret:']='㊙️'
  ABBR_TABLE[':seedling:']='🌱'
  ABBR_TABLE[':see_no_evil:']='🙈'
  ABBR_TABLE[':selfie:']='🤳'
  ABBR_TABLE[':senegal:']='🇸🇳'
  ABBR_TABLE[':serbia:']='🇷🇸'
  ABBR_TABLE[':service_dog:']='🐕‍🦺'
  ABBR_TABLE[':seven:']='7️⃣'
  ABBR_TABLE[':sewing_needle:']='🪡'
  ABBR_TABLE[':seychelles:']='🇸🇨'
  ABBR_TABLE[':shallow_pan_of_food:']='🥘'
  ABBR_TABLE[':shamrock:']='☘️'
  ABBR_TABLE[':shark:']='🦈'
  ABBR_TABLE[':shaved_ice:']='🍧'
  ABBR_TABLE[':sheep:']='🐑'
  ABBR_TABLE[':shell:']='🐚'
  ABBR_TABLE[':shield:']='🛡️'
  ABBR_TABLE[':shinto_shrine:']='⛩️'
  ABBR_TABLE[':ship:']='🚢'
  ABBR_TABLE[':shirt:']='👕'
  ABBR_TABLE[':shit:']='💩'
  ABBR_TABLE[':shoe:']='👞'
  ABBR_TABLE[':shopping:']='🛍️'
  ABBR_TABLE[':shopping_cart:']='🛒'
  ABBR_TABLE[':shorts:']='🩳'
  ABBR_TABLE[':shower:']='🚿'
  ABBR_TABLE[':shrimp:']='🦐'
  ABBR_TABLE[':shrug:']='🤷'
  ABBR_TABLE[':shushing_face:']='🤫'
  ABBR_TABLE[':sierra_leone:']='🇸🇱'
  ABBR_TABLE[':signal_strength:']='📶'
  ABBR_TABLE[':singapore:']='🇸🇬'
  ABBR_TABLE[':singer:']='🧑‍🎤'
  ABBR_TABLE[':sint_maarten:']='🇸🇽'
  ABBR_TABLE[':six:']='6️⃣'
  ABBR_TABLE[':six_pointed_star:']='🔯'
  ABBR_TABLE[':skateboard:']='🛹'
  ABBR_TABLE[':ski:']='🎿'
  ABBR_TABLE[':skier:']='⛷️'
  ABBR_TABLE[':skull:']='💀'
  ABBR_TABLE[':skull_and_crossbones:']='☠️'
  ABBR_TABLE[':skunk:']='🦨'
  ABBR_TABLE[':sled:']='🛷'
  ABBR_TABLE[':sleeping:']='😴'
  ABBR_TABLE[':sleeping_bed:']='🛌'
  ABBR_TABLE[':sleepy:']='😪'
  ABBR_TABLE[':slightly_frowning_face:']='🙁'
  ABBR_TABLE[':slightly_smiling_face:']='🙂'
  ABBR_TABLE[':sloth:']='🦥'
  ABBR_TABLE[':slot_machine:']='🎰'
  ABBR_TABLE[':slovakia:']='🇸🇰'
  ABBR_TABLE[':slovenia:']='🇸🇮'
  ABBR_TABLE[':small_airplane:']='🛩️'
  ABBR_TABLE[':small_blue_diamond:']='🔹'
  ABBR_TABLE[':small_orange_diamond:']='🔸'
  ABBR_TABLE[':small_red_triangle:']='🔺'
  ABBR_TABLE[':small_red_triangle_down:']='🔻'
  ABBR_TABLE[':smile:']='😄'
  ABBR_TABLE[':smile_cat:']='😸'
  ABBR_TABLE[':smiley:']='😃'
  ABBR_TABLE[':smiley_cat:']='😺'
  ABBR_TABLE[':smiling_face_with_tear:']='🥲'
  ABBR_TABLE[':smiling_face_with_three_hearts:']='🥰'
  ABBR_TABLE[':smiling_imp:']='😈'
  ABBR_TABLE[':smirk:']='😏'
  ABBR_TABLE[':smirk_cat:']='😼'
  ABBR_TABLE[':smoking:']='🚬'
  ABBR_TABLE[':snail:']='🐌'
  ABBR_TABLE[':snake:']='🐍'
  ABBR_TABLE[':sneezing_face:']='🤧'
  ABBR_TABLE[':snowboarder:']='🏂'
  ABBR_TABLE[':snowflake:']='❄️'
  ABBR_TABLE[':snowman:']='⛄'
  ABBR_TABLE[':snowman_with_snow:']='☃️'
  ABBR_TABLE[':soap:']='🧼'
  ABBR_TABLE[':sob:']='😭'
  ABBR_TABLE[':soccer:']='⚽'
  ABBR_TABLE[':socks:']='🧦'
  ABBR_TABLE[':softball:']='🥎'
  ABBR_TABLE[':solomon_islands:']='🇸🇧'
  ABBR_TABLE[':somalia:']='🇸🇴'
  ABBR_TABLE[':soon:']='🔜'
  ABBR_TABLE[':sos:']='🆘'
  ABBR_TABLE[':sound:']='🔉'
  ABBR_TABLE[':south_africa:']='🇿🇦'
  ABBR_TABLE[':south_georgia_south_sandwich_islands:']='🇬🇸'
  ABBR_TABLE[':south_sudan:']='🇸🇸'
  ABBR_TABLE[':space_invader:']='👾'
  ABBR_TABLE[':spades:']='♠️'
  ABBR_TABLE[':spaghetti:']='🍝'
  ABBR_TABLE[':sparkle:']='❇️'
  ABBR_TABLE[':sparkler:']='🎇'
  ABBR_TABLE[':sparkles:']='✨'
  ABBR_TABLE[':sparkling_heart:']='💖'
  ABBR_TABLE[':speaker:']='🔈'
  ABBR_TABLE[':speaking_head:']='🗣️'
  ABBR_TABLE[':speak_no_evil:']='🙊'
  ABBR_TABLE[':speech_balloon:']='💬'
  ABBR_TABLE[':speedboat:']='🚤'
  ABBR_TABLE[':spider:']='🕷️'
  ABBR_TABLE[':spider_web:']='🕸️'
  ABBR_TABLE[':spiral_calendar:']='🗓️'
  ABBR_TABLE[':spiral_notepad:']='🗒️'
  ABBR_TABLE[':sponge:']='🧽'
  ABBR_TABLE[':spoon:']='🥄'
  ABBR_TABLE[':squid:']='🦑'
  ABBR_TABLE[':sri_lanka:']='🇱🇰'
  ABBR_TABLE[':stadium:']='🏟️'
  ABBR_TABLE[':standing_man:']='🧍‍♂️'
  ABBR_TABLE[':standing_person:']='🧍'
  ABBR_TABLE[':standing_woman:']='🧍‍♀️'
  ABBR_TABLE[':star:']='⭐'
  ABBR_TABLE[':star2:']='🌟'
  ABBR_TABLE[':star_and_crescent:']='☪️'
  ABBR_TABLE[':star_of_david:']='✡️'
  ABBR_TABLE[':stars:']='🌠'
  ABBR_TABLE[':star_struck:']='🤩'
  ABBR_TABLE[':station:']='🚉'
  ABBR_TABLE[':statue_of_liberty:']='🗽'
  ABBR_TABLE[':st_barthelemy:']='🇧🇱'
  ABBR_TABLE[':steam_locomotive:']='🚂'
  ABBR_TABLE[':stethoscope:']='🩺'
  ABBR_TABLE[':stew:']='🍲'
  ABBR_TABLE[':st_helena:']='🇸🇭'
  ABBR_TABLE[':st_kitts_nevis:']='🇰🇳'
  ABBR_TABLE[':st_lucia:']='🇱🇨'
  ABBR_TABLE[':st_martin:']='🇲🇫'
  ABBR_TABLE[':stop_button:']='⏹️'
  ABBR_TABLE[':stop_sign:']='🛑'
  ABBR_TABLE[':stopwatch:']='⏱️'
  ABBR_TABLE[':st_pierre_miquelon:']='🇵🇲'
  ABBR_TABLE[':straight_ruler:']='📏'
  ABBR_TABLE[':strawberry:']='🍓'
  ABBR_TABLE[':stuck_out_tongue:']='😛'
  ABBR_TABLE[':stuck_out_tongue_closed_eyes:']='😝'
  ABBR_TABLE[':stuck_out_tongue_winking_eye:']='😜'
  ABBR_TABLE[':student:']='🧑‍🎓'
  ABBR_TABLE[':studio_microphone:']='🎙️'
  ABBR_TABLE[':stuffed_flatbread:']='🥙'
  ABBR_TABLE[':st_vincent_grenadines:']='🇻🇨'
  ABBR_TABLE[':sudan:']='🇸🇩'
  ABBR_TABLE[':sun_behind_large_cloud:']='🌥️'
  ABBR_TABLE[':sun_behind_rain_cloud:']='🌦️'
  ABBR_TABLE[':sun_behind_small_cloud:']='🌤️'
  ABBR_TABLE[':sunflower:']='🌻'
  ABBR_TABLE[':sunglasses:']='😎'
  ABBR_TABLE[':sunny:']='☀️'
  ABBR_TABLE[':sunrise:']='🌅'
  ABBR_TABLE[':sunrise_over_mountains:']='🌄'
  ABBR_TABLE[':sun_with_face:']='🌞'
  ABBR_TABLE[':superhero:']='🦸'
  ABBR_TABLE[':superhero_man:']='🦸‍♂️'
  ABBR_TABLE[':superhero_woman:']='🦸‍♀️'
  ABBR_TABLE[':supervillain:']='🦹'
  ABBR_TABLE[':supervillain_man:']='🦹‍♂️'
  ABBR_TABLE[':supervillain_woman:']='🦹‍♀️'
  ABBR_TABLE[':surfer:']='🏄'
  ABBR_TABLE[':surfing_man:']='🏄‍♂️'
  ABBR_TABLE[':surfing_woman:']='🏄‍♀️'
  ABBR_TABLE[':suriname:']='🇸🇷'
  ABBR_TABLE[':sushi:']='🍣'
  ABBR_TABLE[':suspension_railway:']='🚟'
  ABBR_TABLE[':svalbard_jan_mayen:']='🇸🇯'
  ABBR_TABLE[':swan:']='🦢'
  ABBR_TABLE[':swaziland:']='🇸🇿'
  ABBR_TABLE[':sweat:']='😓'
  ABBR_TABLE[':sweat_drops:']='💦'
  ABBR_TABLE[':sweat_smile:']='😅'
  ABBR_TABLE[':sweden:']='🇸🇪'
  ABBR_TABLE[':sweet_potato:']='🍠'
  ABBR_TABLE[':swim_brief:']='🩲'
  ABBR_TABLE[':swimmer:']='🏊'
  ABBR_TABLE[':swimming_man:']='🏊‍♂️'
  ABBR_TABLE[':swimming_woman:']='🏊‍♀️'
  ABBR_TABLE[':switzerland:']='🇨🇭'
  ABBR_TABLE[':symbols:']='🔣'
  ABBR_TABLE[':synagogue:']='🕍'
  ABBR_TABLE[':syria:']='🇸🇾'
  ABBR_TABLE[':syringe:']='💉'
  ABBR_TABLE[':taco:']='🌮'
  ABBR_TABLE[':tada:']='🎉'
  ABBR_TABLE[':taiwan:']='🇹🇼'
  ABBR_TABLE[':tajikistan:']='🇹🇯'
  ABBR_TABLE[':takeout_box:']='🥡'
  ABBR_TABLE[':tamale:']='🫔'
  ABBR_TABLE[':tanabata_tree:']='🎋'
  ABBR_TABLE[':tangerine:']='🍊'
  ABBR_TABLE[':tanzania:']='🇹🇿'
  ABBR_TABLE[':taurus:']='♉'
  ABBR_TABLE[':taxi:']='🚕'
  ABBR_TABLE[':tea:']='🍵'
  ABBR_TABLE[':teacher:']='🧑‍🏫'
  ABBR_TABLE[':teapot:']='🫖'
  ABBR_TABLE[':technologist:']='🧑‍💻'
  ABBR_TABLE[':teddy_bear:']='🧸'
  ABBR_TABLE[':telephone:']='☎️'
  ABBR_TABLE[':telephone_receiver:']='📞'
  ABBR_TABLE[':telescope:']='🔭'
  ABBR_TABLE[':tennis:']='🎾'
  ABBR_TABLE[':tent:']='⛺'
  ABBR_TABLE[':test_tube:']='🧪'
  ABBR_TABLE[':thailand:']='🇹🇭'
  ABBR_TABLE[':thermometer:']='🌡️'
  ABBR_TABLE[':thinking:']='🤔'
  ABBR_TABLE[':thong_sandal:']='🩴'
  ABBR_TABLE[':thought_balloon:']='💭'
  ABBR_TABLE[':thread:']='🧵'
  ABBR_TABLE[':three:']='3️⃣'
  ABBR_TABLE[':thumbsdown:']='👎'
  ABBR_TABLE[':thumbsup:']='👍'
  ABBR_TABLE[':ticket:']='🎫'
  ABBR_TABLE[':tickets:']='🎟️'
  ABBR_TABLE[':tiger:']='🐯'
  ABBR_TABLE[':tiger2:']='🐅'
  ABBR_TABLE[':timer_clock:']='⏲️'
  ABBR_TABLE[':timor_leste:']='🇹🇱'
  ABBR_TABLE[':tipping_hand_man:']='💁‍♂️'
  ABBR_TABLE[':tipping_hand_person:']='💁'
  ABBR_TABLE[':tipping_hand_woman:']='💁‍♀️'
  ABBR_TABLE[':tired_face:']='😫'
  ABBR_TABLE[':tm:']='™️'
  ABBR_TABLE[':togo:']='🇹🇬'
  ABBR_TABLE[':toilet:']='🚽'
  ABBR_TABLE[':tokelau:']='🇹🇰'
  ABBR_TABLE[':tokyo_tower:']='🗼'
  ABBR_TABLE[':tomato:']='🍅'
  ABBR_TABLE[':tonga:']='🇹🇴'
  ABBR_TABLE[':tongue:']='👅'
  ABBR_TABLE[':toolbox:']='🧰'
  ABBR_TABLE[':tooth:']='🦷'
  ABBR_TABLE[':toothbrush:']='🪥'
  ABBR_TABLE[':top:']='🔝'
  ABBR_TABLE[':tophat:']='🎩'
  ABBR_TABLE[':tornado:']='🌪️'
  ABBR_TABLE[':tr:']='🇹🇷'
  ABBR_TABLE[':trackball:']='🖲️'
  ABBR_TABLE[':tractor:']='🚜'
  ABBR_TABLE[':traffic_light:']='🚥'
  ABBR_TABLE[':train:']='🚋'
  ABBR_TABLE[':train2:']='🚆'
  ABBR_TABLE[':tram:']='🚊'
  ABBR_TABLE[':transgender_flag:']='🏳️‍⚧️'
  ABBR_TABLE[':transgender_symbol:']='⚧️'
  ABBR_TABLE[':t-rex:']='🦖'
  ABBR_TABLE[':triangular_flag_on_post:']='🚩'
  ABBR_TABLE[':triangular_ruler:']='📐'
  ABBR_TABLE[':trident:']='🔱'
  ABBR_TABLE[':trinidad_tobago:']='🇹🇹'
  ABBR_TABLE[':tristan_da_cunha:']='🇹🇦'
  ABBR_TABLE[':triumph:']='😤'
  ABBR_TABLE[':trolleybus:']='🚎'
  ABBR_TABLE[':trophy:']='🏆'
  ABBR_TABLE[':tropical_drink:']='🍹'
  ABBR_TABLE[':tropical_fish:']='🐠'
  ABBR_TABLE[':truck:']='🚚'
  ABBR_TABLE[':trumpet:']='🎺'
  ABBR_TABLE[':tshirt:']='👕'
  ABBR_TABLE[':tulip:']='🌷'
  ABBR_TABLE[':tumbler_glass:']='🥃'
  ABBR_TABLE[':tunisia:']='🇹🇳'
  ABBR_TABLE[':turkey:']='🦃'
  ABBR_TABLE[':turkmenistan:']='🇹🇲'
  ABBR_TABLE[':turks_caicos_islands:']='🇹🇨'
  ABBR_TABLE[':turtle:']='🐢'
  ABBR_TABLE[':tuvalu:']='🇹🇻'
  ABBR_TABLE[':tv:']='📺'
  ABBR_TABLE[':twisted_rightwards_arrows:']='🔀'
  ABBR_TABLE[':two:']='2️⃣'
  ABBR_TABLE[':two_hearts:']='💕'
  ABBR_TABLE[':two_men_holding_hands:']='👬'
  ABBR_TABLE[':two_women_holding_hands:']='👭'
  ABBR_TABLE[':u5272:']='🈹'
  ABBR_TABLE[':u5408:']='🈴'
  ABBR_TABLE[':u55b6:']='🈺'
  ABBR_TABLE[':u6307:']='🈯'
  ABBR_TABLE[':u6708:']='🈷️'
  ABBR_TABLE[':u6709:']='🈶'
  ABBR_TABLE[':u6e80:']='🈵'
  ABBR_TABLE[':u7121:']='🈚'
  ABBR_TABLE[':u7533:']='🈸'
  ABBR_TABLE[':u7981:']='🈲'
  ABBR_TABLE[':u7a7a:']='🈳'
  ABBR_TABLE[':uganda:']='🇺🇬'
  ABBR_TABLE[':uk:']='🇬🇧'
  ABBR_TABLE[':ukraine:']='🇺🇦'
  ABBR_TABLE[':umbrella:']='☔'
  ABBR_TABLE[':unamused:']='😒'
  ABBR_TABLE[':underage:']='🔞'
  ABBR_TABLE[':unicorn:']='🦄'
  ABBR_TABLE[':united_arab_emirates:']='🇦🇪'
  ABBR_TABLE[':united_nations:']='🇺🇳'
  ABBR_TABLE[':unlock:']='🔓'
  ABBR_TABLE[':upside_down_face:']='🙃'
  ABBR_TABLE[':up:']='🆙'
  ABBR_TABLE[':uruguay:']='🇺🇾'
  ABBR_TABLE[':us:']='🇺🇸'
  ABBR_TABLE[':us_outlying_islands:']='🇺🇲'
  ABBR_TABLE[':us_virgin_islands:']='🇻🇮'
  ABBR_TABLE[':uzbekistan:']='🇺🇿'
  ABBR_TABLE[':v:']='✌️'
  ABBR_TABLE[':vampire:']='🧛'
  ABBR_TABLE[':vampire_man:']='🧛‍♂️'
  ABBR_TABLE[':vampire_woman:']='🧛‍♀️'
  ABBR_TABLE[':vanuatu:']='🇻🇺'
  ABBR_TABLE[':vatican_city:']='🇻🇦'
  ABBR_TABLE[':venezuela:']='🇻🇪'
  ABBR_TABLE[':vertical_traffic_light:']='🚦'
  ABBR_TABLE[':vhs:']='📼'
  ABBR_TABLE[':vibration_mode:']='📳'
  ABBR_TABLE[':video_camera:']='📹'
  ABBR_TABLE[':video_game:']='🎮'
  ABBR_TABLE[':vietnam:']='🇻🇳'
  ABBR_TABLE[':violin:']='🎻'
  ABBR_TABLE[':virgo:']='♍'
  ABBR_TABLE[':volcano:']='🌋'
  ABBR_TABLE[':volleyball:']='🏐'
  ABBR_TABLE[':vomiting_face:']='🤮'
  ABBR_TABLE[':vs:']='🆚'
  ABBR_TABLE[':vulcan_salute:']='🖖'
  ABBR_TABLE[':waffle:']='🧇'
  ABBR_TABLE[':wales:']='🏴󠁧󠁢󠁷󠁬󠁳󠁿'
  ABBR_TABLE[':walking:']='🚶'
  ABBR_TABLE[':walking_man:']='🚶‍♂️'
  ABBR_TABLE[':walking_woman:']='🚶‍♀️'
  ABBR_TABLE[':wallis_futuna:']='🇼🇫'
  ABBR_TABLE[':waning_crescent_moon:']='🌘'
  ABBR_TABLE[':waning_gibbous_moon:']='🌖'
  ABBR_TABLE[':warning:']='⚠️'
  ABBR_TABLE[':wastebasket:']='🗑️'
  ABBR_TABLE[':watch:']='⌚'
  ABBR_TABLE[':water_buffalo:']='🐃'
  ABBR_TABLE[':watermelon:']='🍉'
  ABBR_TABLE[':water_polo:']='🤽'
  ABBR_TABLE[':wave:']='👋'
  ABBR_TABLE[':wavy_dash:']='〰️'
  ABBR_TABLE[':waxing_crescent_moon:']='🌒'
  ABBR_TABLE[':waxing_gibbous_moon:']='🌔'
  ABBR_TABLE[':wc:']='🚾'
  ABBR_TABLE[':weary:']='😩'
  ABBR_TABLE[':wedding:']='💒'
  ABBR_TABLE[':weight_lifting:']='🏋️'
  ABBR_TABLE[':weight_lifting_man:']='🏋️‍♂️'
  ABBR_TABLE[':weight_lifting_woman:']='🏋️‍♀️'
  ABBR_TABLE[':western_sahara:']='🇪🇭'
  ABBR_TABLE[':whale:']='🐳'
  ABBR_TABLE[':whale2:']='🐋'
  ABBR_TABLE[':wheelchair:']='♿'
  ABBR_TABLE[':wheel_of_dharma:']='☸️'
  ABBR_TABLE[':white_check_mark:']='✅'
  ABBR_TABLE[':white_circle:']='⚪'
  ABBR_TABLE[':white_flag:']='🏳️'
  ABBR_TABLE[':white_flower:']='💮'
  ABBR_TABLE[':white_haired_man:']='👨‍🦳'
  ABBR_TABLE[':white_haired_woman:']='👩‍🦳'
  ABBR_TABLE[':white_heart:']='🤍'
  ABBR_TABLE[':white_large_square:']='⬜'
  ABBR_TABLE[':white_medium_small_square:']='◽'
  ABBR_TABLE[':white_medium_square:']='◻️'
  ABBR_TABLE[':white_small_square:']='▫️'
  ABBR_TABLE[':white_square_button:']='🔳'
  ABBR_TABLE[':wilted_flower:']='🥀'
  ABBR_TABLE[':wind_chime:']='🎐'
  ABBR_TABLE[':wind_face:']='🌬️'
  ABBR_TABLE[':window:']='🪟'
  ABBR_TABLE[':wine_glass:']='🍷'
  ABBR_TABLE[':wink:']='😉'
  ABBR_TABLE[':wolf:']='🐺'
  ABBR_TABLE[':woman:']='👩'
  ABBR_TABLE[':woman_artist:']='👩‍🎨'
  ABBR_TABLE[':woman_astronaut:']='👩‍🚀'
  ABBR_TABLE[':woman_cartwheeling:']='🤸‍♀️'
  ABBR_TABLE[':woman_cook:']='👩‍🍳'
  ABBR_TABLE[':woman_dancing:']='💃'
  ABBR_TABLE[':woman_facepalming:']='🤦‍♀️'
  ABBR_TABLE[':woman_factory_worker:']='👩‍🏭'
  ABBR_TABLE[':woman_farmer:']='👩‍🌾'
  ABBR_TABLE[':woman_feeding_baby:']='👩‍🍼'
  ABBR_TABLE[':woman_firefighter:']='👩‍🚒'
  ABBR_TABLE[':woman_health_worker:']='👩‍⚕️'
  ABBR_TABLE[':woman_in_manual_wheelchair:']='👩‍🦽'
  ABBR_TABLE[':woman_in_motorized_wheelchair:']='👩‍🦼'
  ABBR_TABLE[':woman_in_tuxedo:']='🤵‍♀️'
  ABBR_TABLE[':woman_judge:']='👩‍⚖️'
  ABBR_TABLE[':woman_juggling:']='🤹‍♀️'
  ABBR_TABLE[':woman_mechanic:']='👩‍🔧'
  ABBR_TABLE[':woman_office_worker:']='👩‍💼'
  ABBR_TABLE[':woman_pilot:']='👩‍✈️'
  ABBR_TABLE[':woman_playing_handball:']='🤾‍♀️'
  ABBR_TABLE[':woman_playing_water_polo:']='🤽‍♀️'
  ABBR_TABLE[':woman_scientist:']='👩‍🔬'
  ABBR_TABLE[':womans_clothes:']='👚'
  ABBR_TABLE[':womans_hat:']='👒'
  ABBR_TABLE[':woman_shrugging:']='🤷‍♀️'
  ABBR_TABLE[':woman_singer:']='👩‍🎤'
  ABBR_TABLE[':woman_student:']='👩‍🎓'
  ABBR_TABLE[':woman_teacher:']='👩‍🏫'
  ABBR_TABLE[':woman_technologist:']='👩‍💻'
  ABBR_TABLE[':woman_with_headscarf:']='🧕'
  ABBR_TABLE[':woman_with_probing_cane:']='👩‍🦯'
  ABBR_TABLE[':woman_with_turban:']='👳‍♀️'
  ABBR_TABLE[':woman_with_veil:']='👰‍♀️'
  ABBR_TABLE[':womens:']='🚺'
  ABBR_TABLE[':women_wrestling:']='🤼‍♀️'
  ABBR_TABLE[':wood:']='🪵'
  ABBR_TABLE[':woozy_face:']='🥴'
  ABBR_TABLE[':world_map:']='🗺️'
  ABBR_TABLE[':worm:']='🪱'
  ABBR_TABLE[':worried:']='😟'
  ABBR_TABLE[':wrench:']='🔧'
  ABBR_TABLE[':wrestling:']='🤼'
  ABBR_TABLE[':writing_hand:']='✍️'
  ABBR_TABLE[':x:']='❌'
  ABBR_TABLE[':yarn:']='🧶'
  ABBR_TABLE[':yawning_face:']='🥱'
  ABBR_TABLE[':yellow_circle:']='🟡'
  ABBR_TABLE[':yellow_heart:']='💛'
  ABBR_TABLE[':yellow_square:']='🟨'
  ABBR_TABLE[':yemen:']='🇾🇪'
  ABBR_TABLE[':yen:']='💴'
  ABBR_TABLE[':yin_yang:']='☯️'
  ABBR_TABLE[':yo_yo:']='🪀'
  ABBR_TABLE[':yum:']='😋'
  ABBR_TABLE[':zambia:']='🇿🇲'
  ABBR_TABLE[':zany_face:']='🤪'
  ABBR_TABLE[':zap:']='⚡'
  ABBR_TABLE[':zebra:']='🦓'
  ABBR_TABLE[':zero:']='0️⃣'
  ABBR_TABLE[':zimbabwe:']='🇿🇼'
  ABBR_TABLE[':zipper_mouth_face:']='🤐'
  ABBR_TABLE[':zombie:']='🧟'
  ABBR_TABLE[':zombie_man:']='🧟‍♂️'
  ABBR_TABLE[':zombie_woman:']='🧟‍♀️'
  ABBR_TABLE[':zzz:']='💤'
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
            echo "> ${line//$'\e'[\[(]*([0-9;])[@-n]/}"
          done
          printf "\n\n"
        } >> "${ACCOUNT_PATH}/CONTENT.md"
      fi
    done < "${ACCOUNT_PATH}/CONTENT"
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

# fun: daemon_run
# txt: Run the commands configured for the daemon every interval.
daemon_run ()
{
  daemon_reload_config

  trap daemon_reload_config HUP

  # while sleep ...
  while sleep "${DAEMON_INTERVAL:-300}"
  do
    if ! ${NOLOG:-false}; then
      eval "main_standalone ${DAEMON_COMMANDS} ${DAEMON_LOG_FILE}"
    fi
  done
}

# fun: daemon_start [--foreground]
# txt: Start daemon in background or in foreground in --foreground flag
#      is present.
daemon_start ()
{
  local pid
  daemon_reload_config

  [[ -r "${PIDFILE}" ]] && pid="$(<"${PIDFILE}")"

  if [[ "$pid" ]]; then
    fatal $"There are another daemon running. Force quit with daemon kill"
  else
    daemon_run &
    echo "$!" > "${PIDFILE}"

    info $"Starting daemon at pid %d" "$!"
    if [[ "$1" = "--foreground" ]]; then
      on_exit "daemon_stop"
      wait
    else
      disown
    fi
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
    pkill "-${1:-INT}" -P "$pid" && rm "${PIDFILE}"
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
    local out;

    case "${CONFIG["${1}.style-${2}"]}" in
      italic) out="$sitm$3$ritm";;
      underline) out="$smul$3$rmul";;
      *) out="$3";;
    esac

    rep="$out"

    if [[ "${CONFIG["${1}.highlight-${2}"]}" ]]; then
      while [[ "$out" =~ ${CONFIG["${1}.highlight-${2}"]} ]]; do
          rep="${rep//${BASH_REMATCH[0]}/$smso${BASH_REMATCH[0]}$rmso}"
          out="${out#*"${BASH_REMATCH[0]}"}"
      done
    fi

    FORMAT["$2"]="$(color_eval "${1}.color-${2}" "${1}.color" "$rep")"
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
  local field IFS=','
  local -a args=()

  for field in ${CONFIG["${1}.fields"]}; do
    mapfile -t -O "${#args[@]}" args <<< "${FORMAT["$field"]}"
  done

  # shellcheck disable=SC2059
  printf "${CONFIG["${1}.format"]}%b\n" "${args[@]}" "$sgr0"
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
declare -A EVENTS_ENCROUT=()
declare -A EVENTS_CFLAGS=()

declare -A EVENTS_CROSS_REPLY=()
declare -A EVENTS_CROSS_TAGS=()
declare -A EVENTS_CROSS_SCORE=()
declare -a EVENTS_SORTED=()

ERR_TIME_DUPLICATED=$"Duplicated timestamp for events %s and %s"

# fun: event_load_line <account_id> <fname> <commit> <flags> <content> <index> <encrout> <cflag>
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
  local encrout="$7" cflag="$8" show_untrusted t_output t_status
  local idx link mesg tags score hmac='' eid

  local datet="${line%% *}"
  local kind="${line#$datet }"; kind="${kind%% *}"
  local rest="${line#$datet $kind }"

  local -a status

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
    E|ENCRYPTED)
      local ignore_anon rcpt="${rest%% *}"; mesg="${rest#$rcpt }"

      ignore_anon="$(config_eval \
        "account.$ACCOUNT_NAME.crypto-ignore-anon" \
        "account.crypto-ignore-anon"
      )"

      if [[ "$rcpt" = "${ACCOUNT_OID}" ]] ||
        [[ ("$rcpt" = "@all") && ($ignore_anon != "false") ]]; then
        t_output="$(temp_file)"; t_status="$(temp_file)"

        crypto_decrypt "${ACCOUNT_OID}" "$mesg" \
          "${CONFIG[account.$ACCOUNT_NAME.passphrase-file]:-/dev/null}" \
          "$t_status" > "$t_output" 2>&1

        mesg="$REPLY"

        while read -ra status; do
          case "${status[1]}" in
            DECRYPTION_KEY)
              crypto_keyflags "${status[2]}"
              cflag="${REPLY}" && break;;
          esac
        done < "$t_status"

        if  [[ "$mesg" ]]; then
          event_load_line "$1" "$2" "$3" "$4" "$mesg" "$6" "$(< "$t_output")" "$cflag"
        elif [[ "${CONFIG[timeline.show-anon-failed]}" = "true" ]]; then
          error $"Unable to decrypt anonymous message from %s." "$(username "$aid")"
        fi

      elif [[ "${CONFIG[timeline.show-all-encrypted]}" = "true" ]]; then
        info $"Encrypted message from %s to %s." "$(username "$aid")" "$(username "$rcpt")"
      fi
      return 0;;
    *)
      error $"Ignored malformed event: '$line'"
      return 0
      ;;
  esac

  [[ "$encrout" ]] && unset OID_CACHE["$mesg"]

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
  EVENTS_ENCROUT["$eid"]="$encrout"
  EVENTS_CFLAGS["$eid"]="$cflag"

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
#      For dms: date kind recipient mesg-base64
# env: EID: set this variable to the value of the EID to the created element.
event_create ()
{
  local auto_push content_markdown mesg line l
  local -a content

  auto_push="$(config_eval "account.${ACCOUNT_NAME}.auto-push" account.auto-push)"

  EID="$ACCOUNT_OID:$1"

  case "$2" in
    P) mesg="$3"; line="$*";;
    E) mesg="$4"; line="$*";;
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
  
  printf "%-10s %s\n" $"EID:"   "$eid"
  printf "%-10s %s (%s)\n" $"UID:"   "${eid%%:*}" "$(username "$eid")"
  # shellcheck disable=SC2183
  printf "%-10s %s (%(%Y-%m-%d %H:%M:%S)T)\n" $"Date:"  "$date" "$date"
  printf "%-10s %s\n" $"Kind:"   "${kind^^}"
  printf "%-10s %s\n" $"Link:"   "${link}"
  printf "%-10s %s\n" $"Tags:"   "${tags}"
  printf "%-10s %s\n" $"Mesg:"   "${mesg}"
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

  case "${EVENTS_SIGN["$eid"]//\*/}" in
    G|B|U|X|Y|R|E)
      printf "%-10s %s\n" $"Signed:" $"Yes"
      printf $"Signature information:\n"

      git_helper -C "${EVENTS_COMMIT["$eid"]%% *}" \
        verify-commit "${EVENTS_COMMIT["$eid"]##* }" 2>&1 | prefix "     "
      ;;
    *)
      printf "%-10s %s\n" $"Signed:" $"No"
      ;;
  esac

  if [[ "${EVENTS_ENCROUT["$eid"]}" ]]; then
    printf "%-10s %s\n" $"Encrypted:" $"Yes"
    printf "%-10s %s\n" $"Encrypted Flags": "${EVENTS_CFLAGS["$eid"]}"
    printf "%-10s %s\n" $"Keyring:" "${CONFIG["account.$ACCOUNT_NAME.keyring"]}"
    printf $"Decryption Process Information:\n"

    echo "${EVENTS_ENCROUT["$eid"]}" | prefix "     "
  else
    printf "%-10s %s\n" $"Encrypted:" $"No"
  fi
}

# fun: event_load <account_id> <filename>
# txt: given an content filename, parse it and store events in memory
event_load ()
{
  local max_user_posts fname="$2" account="$1"
  local commit line aname="${CONFIG["user.alias-$account"]:-$account}"
  local -A gitlog

  max_user_posts="${CONFIG["account.${aname}.max-posts"]:-${CONFIG[account.max-posts]:-20}}"

  # shellcheck disable=SC1090
  source <(
    git_helper -C "${fname%/*}" log -s --pretty=format:"gitlog[%H]='%G?'" \
      --no-color "$fname"
  )

  _i() {
    case "${2}" in
      ''|\#*) return
    esac

    commit="${2%% *}";
    line="${2#$commit *) }";

    event_load_line "$account" "${fname%/*}" "$commit" \
      "${gitlog["$commit"]}" "${line//$'\e'[\[(]*([0-9;])[@-n]/}" "$1"
  }

  # shellcheck disable=SC2034
  mapfile -c 1 -n "${max_user_posts}" -C _i < <(
    git_helper -C "${fname%/*}" blame -s -l "$fname"
  )
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
    if ! git_helper -C "${cache}/$uid" pull --rebase 2>&1; then
      error $"Unable to pull repository '%s' from '%s'" "$uid" "$url"
      return 1
    fi
  else
    # repo does not exists yet, cloning...
    if ! git_helper clone --depth 1 "$url" "$cache/$uid" 2>&1; then
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

# env: TIMELINE_CONTENT: The path relative to the account root, where
#      CONTENT file is stored.
TIMELINE_CONTENT="CONTENT"

# env: TIMELINE_FOLLOW The path relative to the account root, where
#      FOLLOW dir is located.
TIMELINE_FOLLOW="FOLLOW"

# env: TIMELINE_PRINTED: Internal associative array which contains the EID
#      of events alredy printed to avoid duplicates in the current execution.
declare -A TIMELINE_PRINTED=()

# env: TIMELINE_WAS_PRINTED: Internal associative array which contains the EID
#      of events printed in some previous execution.
declare -A TIMELINE_WAS_PRINTED=()

# env: TIMELINE_INDEX: Internal array used to print an index in timeline to
#      easy refer to an event
declare -a TIMELINE_INDEX=()

# fun: timeline_load [path] [oid]
# txt: load the timeline from current active account into memory
timeline_load ()
{
  local oid="$2" content_path follow_path show_own path="$1"
  local -a pattern

  if [[ -z "$path" ]]; then
    path="${ACCOUNT_PATH}"
    oid="${ACCOUNT_OID}"
  fi

  content_path="$path/$TIMELINE_CONTENT"
  follow_path="$path/$TIMELINE_FOLLOW"
  show_own="${CONFIG["timeline.own-posts"]}"
  read -ra pattern  <<< "${CONFIG["timeline.loading-pattern"]}"

  if ! [[ -r "$content_path" ]]; then
    error $"Content path does not exists."
    error $"Maybe you delete your account data?"
    E=1 error $"Try $0 account rebuild ${ACCOUNT_NAME} to recreate it automatically"
  fi

  echo -en $"> Loading ${pattern[$((i++ % ${#pattern[@]}))]}\r" >&2
  # Load our account timeline
  [[ "$show_own" = "false" ]] ||
    event_load "$oid" "${content_path}"

  local dir i=0

  if [[ -d "${follow_path}" ]]; then
    for dir in "${follow_path}"/*; do
      [[ -d "$dir" ]] || continue  # ignore non-dir files
      [[ -r "$dir/$TIMELINE_CONTENT" ]] || continue # ignore non initialized

      dir="${dir%/}"
      echo -en $"> Loading ${pattern[$((i++ % ${#pattern[@]}))]}\r" >&2
      event_load "${dir##*/}" "${dir}/$TIMELINE_CONTENT"
    done
  fi
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
  indent="${CONFIG["timeline.$kind.indent"]}"
  prefix="${CONFIG["timeline.$kind.prefix"]}"

  case "$kind" in
    post)
      mesg="${EVENTS_MESG["$eid"]}"
      ;;
    tag)
      tags="${EVENTS_TAGS["$eid"]// /, }"
      # shellcheck disable=SC2153
      link="${EVENTS_LINK["$eid"]}"
      format_compose "timeline.$kind" tags "${2}${indent}${prefix}${tags}"
      ;;
    reply)
      mesg="${EVENTS_MESG["$eid"]}"
      link="${EVENTS_LINK["$eid"]}"
      ;;
  esac

  if [[ "${EVENTS_CFLAGS["$eid"]}" ]]; then
    case "${EVENTS_CFLAGS["$eid"]}" in
      'u') flags+="${CONFIG["timeline.$kind.flag-encrypted-good"]}";;
      '-') flags+="${CONFIG["timeline.$kind.flag-encrypted-unknown"]}";;
      'r') flags+="${CONFIG["timeline.$kind.flag-encrypted-revoked"]}";;
      'e') flags+="${CONFIG["timeline.$kind.flag-encrypted-expired"]}";;
      *) flags+="${CONFIG["timeline.$kind.flag-encrypted-bad"]}";;
    esac
  else
    flags+="${CONFIG["timeline.$kind.flag-encrypted-none"]}"
  fi

  case "${sign}" in
    G*) flags+="${CONFIG["timeline.$kind.flag-signed-good"]}";;
    B*) flags+="${CONFIG["timeline.$kind.flag-signed-bad"]}";;
    U*) flags+="${CONFIG["timeline.$kind.flag-signed-unknown"]}";;
    X*|Y*) flags+="${CONFIG["timeline.$kind.flag-signed-expired"]}";;
    R*) flags+="${CONFIG["timeline.$kind.flag-signed-revoked"]}";;
    E*) flags+="${CONFIG["timeline.$kind.flag-signed-missing"]}";;
    N*) flags+="${CONFIG["timeline.$kind.flag-signed-none"]}";;
    *) flags+="${sign}";;
  esac

  if [[ "${CONFIG["timeline.show-untrusted-items"]}" = "true" ]]; then
    [[ "${sign//\*/}" != "${sign}" ]] &&
      flags+="${CONFIG["timeline.$kind.flag-trusted"]}" ||
      flags+=' '
  fi

  if [[ "${TIMELINE_WAS_PRINTED[$eid]}" ]]; then
    flags+=" "
  else
    flags+="${CONFIG["timeline.$kind.flag-new"]}"
  fi

  # composing the output
  format_compose "timeline.$kind" index "${#TIMELINE_INDEX[@]}"
  format_compose "timeline.$kind" name "$name"
  format_compose "timeline.$kind" date "$date"
  format_compose "timeline.$kind" link "$link"
  format_compose "timeline.$kind" score "${EVENTS_SCORE["$eid"]}"
  format_compose "timeline.$kind" mesg "${2}${indent}${prefix}${mesg}"

  TIMELINE_PRINTED["$eid"]=1
  TIMELINE_INDEX+=( "$eid" )

  show_tags="${CONFIG["timeline.show-tags"]}"
  show_replies="${CONFIG["timeline.show-replies"]}"

  if [[ "$(event_labels "$eid")" ]]; then
    flags+="${CONFIG["timeline.$kind.flag-tagged"]}"
  else
    flags+=" "
  fi

  if [[ "$(event_replies "$eid")" ]]; then
    flags+="${CONFIG["timeline.$kind.flag-replied"]}"
  else
    flags+=" "
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

    echo "declare -Ag TIMELINE_WAS_PRINTED=("
    for var in "${!TIMELINE_WAS_PRINTED[@]}"; do
      echo "[$var]=1"
    done
    for var in "${!TIMELINE_PRINTED[@]}"; do
      [[ "${TIMELINE_WAS_PRINTED[$var]}" ]] || echo "[$var]=1"
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
## vim: ft=sh

# env: OID_CACHE
# txt: save a generated oids to avoid recalculation
declare -gA OID_CACHE

# fun: fun <function_name>
# txt: return true if function is defined
fun () { declare -f "$1" >/dev/null 2>&1; }

# fun: input <pass_text>
# txt: return true if the text typed by the user match with the pass_text
input ()
{
  local reply i
  read -r reply
  for i in "$@"; do
    [[ "$i" = "$reply" ]] && return 0
  done

  return 1
}

# fun: prefix <item>
# txt: prefix each line in stdin with a item and output to stdout
prefix () { local line; while read -r line; do echo "$1$line"; done; }

# fun: mute <command> [args]
# txt: run command quietly
mute () { "$@" >/dev/null 2>&1; }

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
    OID_CACHE["$1"]="$(git_helper hash-object --stdin <<<"${1%.git}")"
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
    ssh://*|http://*|https://*|file://*) return 0
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

# fun: uid <name>
# txt: reverse search for name in list of account alias
uid ()
{
  local key
  for key in "${!CONFIG[@]}"; do
    case "$key" in
      user.alias-*)
        [[ "${CONFIG[$key]}" = "$1" ]] && echo "${key#*-}" && return 0;;
    esac
  done
}

# fun: expand_user <userlist>
# txt: expand a user list to a list of valids uids
expand_user ()
{
  local u
  for u in ${1//,/ }; do
    case "$u" in
      =*) echo "${CONFIG["group.${u%=}"]}";;
      *) uid "${u%@}";;
    esac
  done
}

# fun: is_decimal <num>
# txt: return true if num is a decimal based number.
is_decimal () {
  [[ "$1" = "0" ]] && return 0
  mute let i="10#${1#-}" 2>/dev/null
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

# fun: git_helper <cmds>+
# txt: send commands to git assuming some things
git_helper ()
{
  HOME=/dev/null command git "$@"
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
  local name="${TMPDIR:-/tmp}/temp_$$.$RANDOM$RANDOM"
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

# env: CONFIG: associative array contains the configuration values. This
#      array should be loaded from file with `config_load` function, and
#      accessed by `config_get` and `config_set` to read and write,
#      res pectively.
declare -xA CONFIG=(
  [oid.use-cache]=true
  [oid.max-cache-size]=1000
  [interactive.show-banner]=true
  [account.auto-push]=true
  [account.auto-keygen]=true
  [account.content-markdown]=true
  [account.preview-depth]=100
  [account.default]=''
  [account.signkey]=''
  [account.encrkey]=''
  [account.encrypt-to-me]=true
  [account.max-posts]=20
  [account.path]="${XDG_DATA_HOME:-$HOME/.local/share}/tl/account:$HOME/.tl/account"
  [plugin.path]="${XDG_DATA_HOME:-$HOME/.local/share}/tl/plugin:$HOME/.tl/plugin"
  [cache.path]="${XDG_CACHE_HOME:-$HOME/.cache}/tl:$HOME/.tl/cache"
  [git.jobs]='4'
  [crypto.gnupg-binary]="gpg"
  [crypto.auto-import]=true
  [crypto.ignore-anon]=false
  [crypto.always-anon]=false
  [crypto.keyring-path]="${XDG_DATA_HOME:-$HOME/.local/share}/tl/keyring:$HOME/.tl/keyring"
  [network.depth]=10
  [prompt.format]='%b%s:%b '
  [prompt.fields]='account'
  [prompt.color]='7,'
  [prompt.color-name]='7,'
  [history.enabled]=true
  [history.file]="${XDG_DATA_HOME:-$HOME/.local/share/}tl/history"
  [timeline.show-untrusted-items]=true
  [timeline.show-all-encrypted]=false
  [timeline.show-anon-failed]=false
  [timeline.show-replies]=true
  [timeline.show-tags]=true
  [timeline.react-on-all]=true
  [timeline.filter]='-tag:spam -score-min:0'
  [timeline.own-posts]=true
  [timeline.use-short-ids]=true
  [timeline.post.format]='%b%-3d%b %b%(%Y%m%d %H%M%S)T%b %b%10s%b [%b%s%b] (%b%d%b) %b%s%b'
  [timeline.post.fields]='index,date,name,flags,score,mesg'
  [timeline.post.highlight-mesg]='[@][^\ ,.:;=\!\?]+'
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
  [timeline.post.flag-encrypted-good]='K'
  [timeline.post.flag-encrypted-bad]='!'
  [timeline.post.flag-encrypted-revoked]='R'
  [timeline.post.flag-encrypted-unknown]='m'
  [timeline.post.flag-encrypted-expired]='X'
  [timeline.post.flag-encrypted-none]=' '
  [timeline.post.flag-signed-good]='S'
  [timeline.post.flag-signed-bad]='!'
  [timeline.post.flag-signed-unknown]='s'
  [timeline.post.flag-signed-expired]='X'
  [timeline.post.flag-signed-revoked]='R'
  [timeline.post.flag-signed-missing]='m'
  [timeline.post.flag-signed-none]=' '
  [timeline.post.flag-tagged]='T'
  [timeline.post.flag-replied]='r'
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
  [timeline.tag.flag-encrypted-good]='K'
  [timeline.tag.flag-encrypted-bad]='!'
  [timeline.tag.flag-encrypted-revoked]='R'
  [timeline.tag.flag-encrypted-unknown]='m'
  [timeline.tag.flag-encrypted-expired]='X'
  [timeline.tag.flag-encrypted-none]=' '
  [timeline.tag.flag-signed-good]='S'
  [timeline.tag.flag-signed-bad]='!'
  [timeline.tag.flag-signed-unknown]='s'
  [timeline.tag.flag-signed-expired]='X'
  [timeline.tag.flag-signed-revoked]='R'
  [timeline.tag.flag-signed-missing]='m'
  [timeline.tag.flag-signed-none]=' '
  [timeline.tag.flag-tagged]='T'
  [timeline.tag.flag-replied]='r'
  [timeline.tag.flag-new]='N'
  [timeline.tag.flag-trusted]='*'
  [timeline.reply.format]='%b%-3d%b %b%(%Y%m%d %H%M%S)T%b %b%10s%b [%b%s%b] (%b%d%b) %b%s%b'
  [timeline.reply.fields]='index,date,name,flags,score,mesg'
  [timeline.reply.highlight-mesg]='[@][^\ ,.:;=\!\?]+'
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
  [timeline.reply.flag-encrypted-good]='K'
  [timeline.reply.flag-encrypted-bad]='!'
  [timeline.reply.flag-encrypted-revoked]='R'
  [timeline.reply.flag-encrypted-unknown]='m'
  [timeline.reply.flag-encrypted-expired]='X'
  [timeline.reply.flag-encrypted-none]=' '
  [timeline.reply.flag-signed-good]='S'
  [timeline.reply.flag-signed-bad]='!'
  [timeline.reply.flag-signed-unknown]='s'
  [timeline.reply.flag-signed-expired]='X'
  [timeline.reply.flag-signed-revoked]='R'
  [timeline.reply.flag-signed-missing]='m'
  [timeline.reply.flag-signed-none]=' '
  [timeline.reply.flag-tagged]='T'
  [timeline.reply.flag-replied]='r'
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
  [timeline.loading-pattern]='. o O o'
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
  [alias.trn]='timeline refresh flag:new'
  [alias.tl]='timeline list'
  [alias.dr]='timeline refresh flag:new'
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
  [alias.keys]='account keys'
  [alias.keygen]='account keygen'
  [alias.revoke]='account keyrevoke'
  [input.emojis]=false
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

if [[ "${LC_MESSAGES//UTF-8/}" != "${LC_MESSAGES}" ]]; then
  # if utf-8 is available in locale
  CONFIG['input.emojis']=true
  CONFIG['timeline.reply.prefix']='⤷ '
  CONFIG['timeline.loading-pattern']="⣾ ⣽ ⣻ ⢿ ⡿ ⣟ ⣯ ⣷"
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
  done < <(git_helper config -f "$1" -l)
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

# fun: config_eval <key>+
# txt: return the first occurence of a key in the config or empty string if
#      keys are not found.
config_eval ()
{
  local key
  for key in "$@"; do
    [[ "${CONFIG["$key"]}" ]] && echo "${CONFIG["$key"]}" && return 0
  done
  return 1
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

  [[ "$1" ]] || E=2 fatal $"No config file path provided for config_save"

  if [[ ! -d "${1%/*}" ]]; then
    mkdir -p "${1%/*}"
  fi

  for var in "${!CONFIG[@]}"; do
    val="${CONFIG["$var"]}"

    if [[ "$val" ]]; then
      git_helper config -f "$1" "$var" "${CONFIG["$var"]}"
    else
      mute git_helper config -f "$1" --remove-section "${var}" ||
        git_helper config -f "$1" --unset "${var}"
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

FILTER_LIST=()

# fun: filter_tag <tags_to_filter> <eid>
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

# fun: filter_flag <flag_to_filter> <eid>
# txt: return true if EID need to be filtered
filter_flag ()
{
  local flag="$1" eid="$2"

  [[ "${flag}" ]] || return 0

  case "$flag" in
    new) [[ "${TIMELINE_WAS_PRINTED[$eid]}" ]] || return 0;;
    trust)
      [[ "${EVENTS_SIGN["$eid"]//\*/}" != "${EVENTS_SIGN["$eid"]}" ]] &&
        return 0;;
    signed-good)
      [[ "${EVENTS_SIGN["$eid"]//G/}" != "${EVENTS_SIGN["$eid"]}" ]] &&
        return 0;;
    signed-bad)
      [[ "${EVENTS_SIGN["$eid"]//B/}" != "${EVENTS_SIGN["$eid"]}" ]] &&
        return 0;;
    signed-unknown)
      [[ "${EVENTS_SIGN["$eid"]//U/}" != "${EVENTS_SIGN["$eid"]}" ]] &&
        return 0;;
    signed-expired)
      [[ "${EVENTS_SIGN["$eid"]//X/}" != "${EVENTS_SIGN["$eid"]}" ]] &&
        return 0
      [[ "${EVENTS_SIGN["$eid"]//Y/}" != "${EVENTS_SIGN["$eid"]}" ]] &&
        return 0;;
    signed-revoked)
      [[ "${EVENTS_SIGN["$eid"]//R/}" != "${EVENTS_SIGN["$eid"]}" ]] &&
        return 0;;
    signed-missing)
      [[ "${EVENTS_SIGN["$eid"]//E/}" != "${EVENTS_SIGN["$eid"]}" ]] &&
        return 0;;
    signed)
      case "${EVENTS_SIGN["$eid"]}" in
        G*|B*|U*|X*|Y*|R*|E*) return 0;;
      esac;;
  esac
  return 1
}

# fun: filter_view <view> <eid>
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

# fun: filter_score {score-min|score-max} <value> <eid>
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
    flag:*)
      filter_flag "${expr#flag:}" "$eid" && return 0
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

# fun: error_multi
# txt: get messages from stdin and print informational messages to stderr
error_multi ()
{
  format_compose timeline.error name "${CONFIG[timeline.error.name]:-ERROR}"
  format_compose timeline.error date "$(printf "%(%s)T")"
  _i() {
    format_compose timeline.error mesg "${2%$'\n'}"
    format_dumps timeline.error >&2
  }
  # shellcheck disable=SC2034
  mapfile -c 1 -C _i
}
## vim:ft=sh

# env: ACCOUNT_NAME: A variable contains the name of the active account.
export ACCOUNT_NAME=

# env: ACCOUNT_PATH: A variable contains the path of the active account.
export ACCOUNT_PATH=

# env: ACCOUNT_OID: A variable contains the OID of the active account.
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
  pull_url="${CONFIG["account.$ACCOUNT_NAME.pull-url"]}"

  [[ "$pull_url" ]] ||
    E=2 fatal $"Unknown account $ACCOUNT_NAME"

  oid "$pull_url"
  ACCOUNT_OID="${OID_CACHE["$pull_url"]}"
  ACCOUNT_PATH="$(config_get "account.$ACCOUNT_NAME.path")"

  export GNUPGHOME="${CONFIG[account.$ACCOUNT_NAME.keyring]}"

  changes="$(git_helper -C "${ACCOUNT_PATH}" status --porcelain 2>&1)" ||
    E=3 error $"Unable to check account status"
  if [[ "$changes" ]]; then
    error $"Account is dirty. Maybe you edit your account manually and badly."
    error $"To repair just run: git -C '%s' reset --hard master" "$ACCOUNT_PATH"
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
  
  [[ "$1" ]] && path="${CONFIG["account.$1.path"]}"

  if [[ -z "$path" ]]; then
    path="${ACCOUNT_PATH}"
  fi
  [[ -d "${path%.git}/.git" ]]
}

# fun: account_keygen <oid> <tstamp> <name>
# txt: generate a new keypair for the account named name and the oid oid and
#      specific tstamp
account_keygen ()
{
  local name="$3" tstamp="$2" oid="$1"

  config_set "account.$name.keyring" "$(try_path "${CONFIG[crypto.keyring-path]}")/$name"

  mkdir -p "${CONFIG["account.$name.keyring"]}" &&
    chmod 700 "${CONFIG["account.$name.keyring"]}"

  export GNUPGHOME="${CONFIG["account.$name.keyring"]}"

  crypto_keygen "$oid" "$tstamp" \
    "${CONFIG[account.$name.passphrase-file]:-/dev/null}" 2>&1
}

# fun: account_create <name> <push_url> <pull_url> [path]
# txt: create a new account named as name, with specific push and pull url,
#      if path is provided then set the account path to this one, otherwise,
#      use the default path for accounts as prefix
account_create ()
{
  local name="$1" push_url="$2" pull_url="$3" path="$4" tstamp

  tstamp="$(timestamp)"

  [[ "${CONFIG["account.$name.path"]}" ]] &&
    E=1 fatal $"Another account already exists with that name"

  account_exists "$name" &&
    E=1 fatal $"Trying to initializating an already initialized account"
  
  path="${path:-$(try_path "$(config_get account.path)")/$name}"
  config_set "account.$name.push-url" "$push_url"
  config_set "account.$name.pull-url" "$pull_url"
  config_set "account.$name.path" "$path"

  oid "$pull_url"

  config_set "user.alias-${OID_CACHE["$pull_url"]}" "$name"

  [[ "${CONFIG[account.auto-keygen]}" = "true" ]] &&
    account_keygen "${OID_CACHE[$pull_url]}" "$tstamp" "$name"

  # create empty dir for init
  mkdir -p "$path" ||
    E=1 fatal $"Unable to create account directory: %s" "$path"

  git_helper -C "$path" init ${TIMELINE_EXPERIMENTAL_SHA256:+--object-format=sha256}
  account_config "$path" "$pull_url" "$1" "$tstamp"

  config_save "${CONFIG_FILE}"

  git_helper -C "$path" add .

  git_helper -C "$path" commit -m 'init' 2>&1
  git_helper -C "$path" remote add origin "$push_url" 2>&1
  git_helper -C "$path" push -u origin master 2>&1 ||
    E=2 fatal $"Unable to push initial commit"
}

# fun: account_clone <name> <push_url> <pull_url> [path]
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

  local name="$1" push_url="$2" pull_url="$3" path="$4"

  if ! $force && [[ "${CONFIG["account.$name.path"]}" ]]; then
    E=1 fatal $"Another account already exists with that name"
  else
    path="${path:-$(try_path "$(config_get account.path)")/$name}"
    config_set "account.$name.push-url" "$push_url"
    config_set "account.$name.pull-url" "$pull_url"
    config_set "account.$name.path" "$path"

    oid "$pull_url"

    [[ -z "${CONFIG[account.$name.keyring]}" ]] &&
      [[ "${CONFIG[account.auto-keygen]}" = "true" ]] &&
        account_keygen "${OID_CACHE[$pull_url]}" "$tstamp" "$name"

    config_set "user.alias-${OID_CACHE["$pull_url"]}" "$name"
    git_helper clone "$push_url" "$path" 2>&1
    git_helper -C "$path" submodule init 2>&1

    account_config "$path" "$pull_url" "$name" "timeline"

    config_save "${CONFIG_FILE}"
  fi
}

# fun: account_config <path> <pull_url> <name> <tstamp>
# txt: configure user and other required things in the repo
account_config ()
{
  local path="$1" pull_url="$2" name="$3" tstamp="$4" keyid
  oid "$pull_url"

  git_helper -C "$path" config user.name "${OID_CACHE["$pull_url"]}"
  git_helper -C "$path" config user.email "${OID_CACHE["$pull_url"]}@timeline"
  git_helper -C "$path" config core.preloadindex true
  git_helper -C "$path" config core.fscache true
  git_helper -C "$path" config gc.auto 256

  command touch "${path:?}/CONTENT"
  command mkdir -p "${path:?}/FOLLOW"

  if [[ "$tstamp" ]]; then
    keyid="$(crypto_keyid "${OID_CACHE["$pull_url"]}" "$tstamp")"

    if [[ "$keyid" ]]; then
      account_set_signkey "$name" "$keyid"
      crypto_export "${OID_CACHE["$pull_url"]}" "${path:?}/SIGNKEY"
      account_set_encrkey "$name" "$keyid"
      crypto_export "${OID_CACHE["$pull_url"]}" "${path:?}/ENCRKEY"

      export GNUPGHOME="${CONFIG[account.$name.keyring]}"
    fi
  fi

}

# fun: account_commit [message]
# txt: set a commit point into current active account
account_commit ()
{
  [[ "$ACCOUNT_PATH" ]] || E=1 fatal $"No active account to commit"

  git_helper -C "$ACCOUNT_PATH" add .

  if config_eval "account.$ACCOUNT_NAME.signkey" "account.signkey" >/dev/null
  then
    git_helper -C "$ACCOUNT_PATH" commit -S -m "${1:-autosave}"
  else
    git_helper -C "$ACCOUNT_PATH" commit -m "${1:-autosave}"
  fi
}

# fun: account_push [remote]
# txt: push active account content to remote passed as argument or, if
#      missing, to `origin`.
account_push ()
{
  # TODO Add support for multiple branches
  git_helper -C "${ACCOUNT_PATH}" push "${1:-origin}" master
}

# fun: account_refresh <path> [remote]
# txt: rebase changes to current account from remote passed as argument or,
#     if missing, `origin`.
account_refresh ()
{
  local line path="$1" commit=false; shift

  git_helper -C "$path" fetch --all --jobs "${CONFIG[git.jobs]:-4}" 2>&1
  # TODO Add support for multiple branches
  git_helper -C "$path" rebase "${1:-origin}/master" 2>&1
  git_helper -C "$path" submodule update --remote \
    --jobs "${CONFIG[git.jobs]:-4}" 2>&1

  while read -r _ line; do
    commit=true
    case "$line" in
      FOLLOW/*) account_import "${line#FOLLOW/}" "$path/$line";;
    esac
  done < <(git_helper -C "$path" status -s)

  ${commit} &&
    account_commit "chore: update submodules"

  git_helper -C "$path" repack -a -d --depth=250 --window=250 2>&1
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

# fun: account_set_signkey <name> <keyid>
# txt: set signing keyid for an existant account
account_set_signkey ()
{
  if [[ "$2" ]]; then
    git_helper -C "$(config_get "account.$1.path")" config user.signingkey "$2"
  else
    git_helper -C "$(config_get "account.$1.path")" config --unset user.signingkey
  fi

  config_set "account.$1.signkey" "$2"
}

# fun: account_set_encrkey <name> <keyid>
# txt: set encryption keyid for an existant account
account_set_encrkey ()
{
  config_set "account.$1.encrkey" "$2"
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

  git_helper clone ${depth:+--depth "${depth}"} "$1" "${tmpdir}" 2>&1 |
    info_multi ||
      E=1 error $"Unable to clone remote repo"

  oid "$1"
  timeline_load "${tmpdir}" "${OID_CACHE["$1"]}"
  shift
  timeline_list "$@"
}

# fun: account_keys
# txt: print the associated keys for the current account
account_keys ()
{
  local fpr flags

  while read -r fpr flags; do
    [[ "$fpr" = "${CONFIG[account.$ACCOUNT_NAME.signkey]}" ]] &&
      flags+='S'

    [[ "$fpr" = "${CONFIG[account.$ACCOUNT_NAME.encrkey]}" ]] &&
      flags+='E'

    echo "$fpr $flags"
  done < <(crypto_list "=${ACCOUNT_OID}@timeline")
}

# fun: account_import  <account> <path>
# txt: get public keys references in path
account_import ()
{
  local line account="$1" path="$2";

  # shellcheck disable=SC2016
  while read -r line; do
    case "$line" in
      ENCRKEY|SIGNKEY) crypto_import "$account" "$path/$line"
    esac
  done < <(git_helper -C "$path" show --pretty="" --name-only)
}
## vim:ft=sh

# fun: crypto_requirements
# txt: ensure that specific requirements for crypto management are
#      present in the system
crypto_requirements ()
{
  REQUIREMENTS+=( "+gpg" )
  reqs_eval
}

# fun: crypto_keygen <account_id> <tstamp> <passphrase-file>
# txt: generate key pair for the specific account and echoes the key_id of the
#      generated one. The crver is v1 by default. Read tl-crypto(7) man page
#      for details.
crypto_keygen ()
{
  crypto_requirements

  local keyid

  gpg_helper \
    --passphrase-file "$3" \
    --quick-gen-key "$1@$2" "ed25519" cert,sign never ||
    E=3 error $"Unable to create master key for account $1 (v1)."

  keyid="$(crypto_keyid "$1@$2")"

  [[ "$keyid" ]] || E=3 fatal $"Unable to retrieve recent generate keyID"

  gpg_helper \
    --passphrase-file "$3" \
    --quick-add-key "$keyid" "cv25519" encr never ||
    E=3 error $"Unable to create encryption key for account $1 (v1)"

  gpg_helper \
    --passphrase-file "$3" \
    --quick-add-uid "$keyid" "$1@timeline" ||
    E=3 error $"Unable to create user-id for account $1 (v1)"

  echo -e "5\ny\nsave\n" | 
    gpg_helper --no-batch --command-fd 0 \
      --expert --edit-key "$keyid" trust >/dev/null 2>/dev/null ||
      E=3 error $"Unable to trust keyID $keyid"
}

# fun: crypto_keyid <account_id>
# txt: get the fingerprint for the key associated to specific account id.
crypto_keyid ()
{
  local -a out
  mapfile -d $'\n' out < <(
    gpg_helper --keyid-format long -k "$1${2:+@$2}" 2>/dev/null
  )
  [[ "${out[1]// /}" ]] &&
    echo "${out[1]// /}"
}

# fun: crypto_import <account_id> <keyfile>
# txt: import a key from the account_id into the timeline keyring
crypto_import ()
{
  local status account="$1" keyfile="$2" kind keyid uid

  crypto_requirements
  status="$(temp_file)"

  gpg_helper --status-file "$status" --import "$keyfile" ||
    E=3 error $"Unable to import key file %s" "$keyfile"

  while read -r _ kind keyid uid _; do
    case "$kind" in
      IMPORTED) 
        if [[ "${uid%@*}" != "$account" ]]; then
          if gpg_helper --yes --delete-keys "$keyid"; then
            error $"Ignoring key %s: account does not match %s != %s" \
              "$keyid" "${uid%@*}" "$account"
          else
            error $"\!\!\! SECURITY RISK \!\!\!"
            error $"You've been imported an invalid key."
            error $"Key %s does not belong to account owner %s" "$keyid" "$account."
            error $"Timeline was try to remove it from the keyring, but something weird happened."
            error $"Read manual tl-crypto(1) to know more about how to handle this."
            E=3 fatal $"Unable to remove an invalid key."
          fi
        fi
    esac
  done < "$status"
}

# fun: crypto_export <account_id> <file>
# txt: export public key of the specific account id to file
crypto_export ()
{
  crypto_requirements
  gpg_helper --no-comments --no-emit-version \
    --armor --export "$1@timeline" > "$2" ||
    E=3 error $"Unable to export keys for account $1"
}

# fun: crypto_revoke <account_name> <key_id>
# txt: revoke a specific key_id
crypto_revoke ()
{
  local rcert
  local homedir="${CONFIG[account.$1.keyring]}"
  crypto_requirements

  [[ -r "${homedir}/openpgp-revocs.d/$2.rev" ]] ||
    E=4 fatal $"KeyID $1 does not have revocation certificate."

  rcert="$(< "${homedir}/openpgp-revocs.d/$2.rev")"
  gpg_helper --import <<< "${rcert//:---/---}" || # remove : guard 
    E=4 fatal $"Unable to revoke key"
}

# fun: crypto_uid <key_id> [match]
# txt: echoes the uid of the key_id or, if match provided, return true if
#      the uid match the pattern.
crypto_uid ()
{
  local line
  while read -r line; do
    case "$line" in
      uid:*)
        IFS=: read -r -a line <<< "$line"
        if [[ "$2" ]]; then
          [[ "${line[9]}" = "$2" ]] && return 0
        else
          echo "${line[9]}"
        fi
        ;;
    esac
  done < <(gpg_helper --with-colons -k "$1")
  ! [[ "$2" ]]
}

# fun: crypto_validate <key_id> <crver>
# txt: validate that specific key_id is conforminr crver specification
crypto_validate ()
{
  local kind val data
  crypto_requirements

  data="$(gpg_helper --keyid-format long -k "$1@timeline" 2>&1)" ||
    E=3 error $"Unable to validate key $1 ($2). Error was: '$data'."

  case "$2" in
    v1)
      while read -r kind val _; do
        case "$kind" in
          pub)
            [[ "${val#ed25519/}" = "${val}" ]] &&
              E=3 error $"Key $1 does not conform $2: Pub part is no ED25519"
            ;;
          sub)
            [[ "${val#cv25519/}" = "${val}" ]] &&
              E=3 error $"Key $1 does not conform $2: Sub part is no CV25519"
            ;;
        esac
      done <<< "$data"
      ;;
  esac
}

# fun: crypto_list
# txt: echoes a list of keys present in keyring
crypto_list ()
{
  local line flags pub=false
  while IFS=: read -r -a line; do
    case "${line[0]}" in
      pub)
        case "${line[1]}" in
          *r*) flags="R";;
          *) flags="";;
        esac
        pub=true;;
      fpr) "$pub" && echo "${line[9]} $flags";;
      *) pub=false;;
    esac
  done < <(gpg_helper --with-colons -k "$@")
}

# fun: crypto_encrypt [--anon] <recipient> <message> <passfile>
# txt: return a encrypted message for the specific recipient in REPLY var
crypto_encrypt ()
{
  local mesg arg='-r'
  local -a payload
  crypto_requirements

  [[ "$1" = "--anon" ]] && arg="-R" && shift

  mapfile -t -s 2 payload < <(
    gpg_helper -vv \
      --armor --passphrase-file "$3" \
      --sign --encrypt --no-comments --no-emit-version \
      "$arg" "$1@timeline" <<< "$2"
  ) 2>&1

  [[ ${#payload[@]} -eq 0 ]] && exit 4

  payload[-1]=''
  REPLY="${payload[*]}"
  REPLY="${REPLY// /}"
}

# fun: crypto_decrypt <account_id> <message> <passfile> [statusfile]
# txt: decrypt a previously encrypted message
crypto_decrypt ()
{
  local -a args
  local -a mesg=(
    "-----BEGIN PGP MESSAGE-----"
    ""
    "$2"
    "-----END PGP MESSAGE-----"
  )
  crypto_requirements

  [[ "$4" ]] && args+=( "--status-file=$4" )

  read -r < <(
    gpg_helper "${args[@]}" --passphrase-file "$3" -v --armor --decrypt \
      --try-secret-key "$1@timeline" <<< "$(join $'\n' "${mesg[@]}")"
  ) 2>&1 || REPLY=''
}

# fun: crypto_keyflags <keyid>
# txt: put in $REPLY a list of flags for the keyid passed as argument
crypto_keyflags ()
{
  local -a line
  local aux
  REPLY=''

  while IFS=: read -ra line ; do
    case "${line[0]}" in
      pub|sub) aux="${line[1]}";;
      fpr|fp2) [[ "${line[9]}" = "$1" ]] && REPLY="$aux" || true;;
    esac
  done < <(gpg_helper --with-colons -k "$1") ||
    E=3 fatal $"Unable to retrieve keyflags for key %s" "$1"
}

# fun: gpg_helper [args]
# txt: run gpg command with some well known parameters
gpg_helper ()
{
  local homedir

  [[ "$GNUPGHOME" ]] ||
    E=3 fatal $"GNUPGHOME not set executing $*"

  command "${CONFIG[crypto.gnupg-binary]:-exit}" --batch --no-tty \
    --no-auto-key-retrieve --auto-key-locate "local" \
    --trust-model always \
    --personal-cipher-preferences AES256 \
    --personal-digest-preferences SHA256 \
    "$@"
}
## vim:ft=sh

NOSUBCMD=$"No valid subcomand '%s' for command '%s'"
INVALIDURL=$"Invalid URL '%s'"



# help:fun: account {create|delete|rebuild|clone|list|refresh|active|preview|keys|keygen|keyrevoke|encrkey|signkey} {args...}
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

# help:account:fun: account create <name> <push_url> <pull_url> [path]
# help:account:txt: Create a new account (aka git repository) which will
# help:account:txt: push data to specified push_url and publish public url
# help:account:txt: as specified pull_url. Optionally, you can set the path
# help:account:txt: where repository lives, if omit, uses default path for
# help:account:txt: accounts.
command_account_create ()
{
  local name="$1" push_url="$2" pull_url="$3" path="$4"

  if [[ -z "$1" ]]; then
    E=1 error $"Account command create requires 'name'."
  else
    if ! valid_url "$push_url"; then
      E=1 error "$INVALIDURL" "$push_url"
    elif ! valid_url "$pull_url"; then
      E=1 error "$INVALIDURL" "$pull_url"
    else
      account_create "$name" "$push_url" "$pull_url" "$path" |
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
  local name="$1" push_url pull_url path

  if [[ -z "$1" ]]; then
    E=1 error $"Account command rebuild requires 'name'."
  else
    push_url="${CONFIG["account.$name.push-url"]}"
    pull_url="${CONFIG["account.$name.pull-url"]}"
    path="${CONFIG["account.$name.path"]}"

    if [[ -z "$path" ]] || [[ -z "$push_url" ]] || [[ -z "$pull_url" ]]; then
      E=1 error $"Unable to rebuild. Account '$name' was not configured yet."
    fi

    if ! config_eval "account.$name.signkey" "account.signkey" >/dev/null; then
      error $"The account $name has not associated signkey."
      error $"Use 'account genkey' to generate new keypair or 'account signkey' to set previous generated one."
    fi

    if ! config_eval "account.$name.encrkey" "account.encrkey" >/dev/null; then
      error $"The account $name has not associated encrkey."
      error $"Use 'account genkey' to generate new keypair or 'account encrkey' to set previous generated one."
    fi

    account_clone --force "$name" "$push_url" "$pull_url" "$path" |
        info_multi
      config_load "${CONFIG_FILE}"
      command_account_active "$name"
    # shellcheck disable=SC2119
    command_timeline_refresh
  fi
}

# help:account:fun: account keygen [--no-default-sign] [--no-default-encr]
# help:account:txt: Generate new keypair for the current account. If the
# help:account:txt: --no-default flag is present, then do not switch default
# help:account:txt: keys to encrypt or sign and keep the old ones by default.
command_account_keygen ()
{
  local tstamp keyid commit=false

  command_account_active "${ACCOUNT_NAME}"

  tstamp="$(timestamp)"

  account_keygen "${ACCOUNT_OID}" "$tstamp" "${ACCOUNT_NAME}" 2>&1 | info_multi

  keyid="$(crypto_keyid "${ACCOUNT_OID}" "$tstamp")"

  gpg_helper --quick-set-expire "$keyid" seconds=10 '*'

  [[ "$keyid" ]] ||
    E=4 fatal $"Unable to retrieve KeyID for generated one"

  if [[ "$1" != "--no-default-sign" ]] && [[ "$2" != "--no-default-sign" ]]; then
    account_set_signkey "${ACCOUNT_NAME}" "$keyid"
    crypto_export "${ACCOUNT_OID}" "${ACCOUNT_PATH}/SIGNKEY"
    commit=true
  fi

  if [[ "$1" != "--no-default-encr" ]] && [[ "$2" != "--no-default-encr" ]]; then
    account_set_encrkey "${ACCOUNT_NAME}" "$keyid"
    crypto_export "${ACCOUNT_OID}" "${ACCOUNT_PATH}/ENCRKEY"
    commit=true
  fi

  config_save "${CONFIG_FILE}"

  if ${commit}; then
    account_commit $"bump: new public key" | info_multi
    if [[ "$(config_eval "account.${ACCOUNT_NAME}.auto-push" account.auto-push)" = "true" ]];
    then
      account_push 2>&1 | info_multi
    fi
  fi
}

# help:account:fun: account keyrevoke <key_id>
# help:account:txt: Revoke a key associated with the current account
command_account_keyrevoke ()
{
  local force=false

  [[ "$1" == "--force" ]] && shift && force=true

  command_account_active "${ACCOUNT_NAME}"

  if ! ${force}; then
    if [[ "$(config_eval "account.$ACCOUNT_NAME.signkey" account.signkey)" = "$1" ]]
    then
      error $"You are going to revoke the signing key for this account."
      E=3 fatal $"Use --force if you are sure of what are you doing."
    fi
    if [[ "$(config_eval "account.$ACCOUNT_NAME.encrkey" account.encrkey)" = "$1" ]]
    then
      error $"You are going to revoke the encryption key for this account."
      E=3 fatal $"Use --force if you are sure of what are you doing."
    fi
  fi

  crypto_uid "$1" "${ACCOUNT_OID}@timeline" ||
    E=2 fatal $"The provided KeyID was not generated for this account"

  crypto_revoke "${ACCOUNT_NAME}" "$1" ||
    E=2 fatal $"Unable to revoke key $1"
  crypto_export "${ACCOUNT_OID}" "${ACCOUNT_PATH}/SIGNKEY"
  crypto_export "${ACCOUNT_OID}" "${ACCOUNT_PATH}/ENCRKEY"

  [[ "${CONFIG[account.$ACCOUNT_NAME.signkey]}" = "$1" ]] &&
    account_set_signkey "$ACCOUNT_NAME" ""

  if [[ "${CONFIG[account.signkey]}" = "$1" ]]; then
    account_set_signkey "$ACCOUNT_NAME" ""
    config_set account.signkey ""
  fi

  [[ "${CONFIG[account.$ACCOUNT_NAME.encrkey]}" = "$1" ]] &&
    account_set_encrkey "$ACCOUNT_NAME" ""

  if [[ "${CONFIG[account.encrkey]}" = "$1" ]]; then
    account_set_encrkey "$ACCOUNT_NAME" ""
    config_set "account.encrkey" ""
  fi

  config_save "${CONFIG_FILE}"

  account_commit $"clean: revoke key $1"
  if [[ "$(config_eval "account.${ACCOUNT_NAME}.auto-push" account.auto-push)" = "true" ]]; then
    account_push
  fi
}

# help:account:fun: account clone <name> <push_url> <pull_url> [path]
# help:account:txt: Clone an account (aka git repository) from specified
# help:account:txt: push_url passed as argument, and also configure the
# help:account:txt: provided pull_url, like 'account create' does.
command_account_clone ()
{
  local name="$1" push_url="$2" pull_url="$3" path="$4"

  if [[ -z "$1" ]]; then
    E=1 error $"Account command clone requires 'name'."
  else
    if ! valid_url "$push_url"; then
      E=1 error "$INVALIDURL" "$push_url"
    elif ! valid_url "$pull_url"; then
      E=1 error "$INVALIDURL" "$pull_url"
    else
      account_clone "$name" "$push_url" "$pull_url" "$path" |
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

# help:account:fun: account signkey <keyid>
# help:account:txt: Set keyid for signing commits in the current enabled
# help:account:txt: account.
command_account_signkey ()
{
  if [[ $# -ne 1 ]]; then
    E=2 error "Account sign key requires one argument: keyid"
  else
    command_account_active "${ACCOUNT_NAME}"
    account_set_signkey "$ACCOUNT_NAME" "$1"
    config_save "${CONFIG_FILE}"
  fi
}

# help:account:fun: account encrkey <keyid>
# help:account:txt: Set keyid for encrypt messags in the current enabled
# help:account:txt: account.
command_account_encrkey ()
{
  if [[ $# -ne 1 ]]; then
    E=2 error "Account encryption key requires one argument: keyid"
  else
    command_account_active "${ACCOUNT_NAME}"
    account_set_encrkey "$ACCOUNT_NAME" "$1"
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

# help:account:fun: account keys
# help:account:txt: print available keys for current account. The flags S and
# help:account:txt: E will be printed for keys current enable for signing and
# help:account:txt: encryption respectively
command_account_keys ()
{
  command_account_active "${ACCOUNT_NAME}"
  account_keys | info_multi
}

# help:fun: git <command>...
# help:txt: Execute raw git commands in the active account.
command_git ()
{
  command_account_active "${ACCOUNT_NAME}"
  git_helper -C "${ACCOUNT_PATH}" "$@"
}

# help:fun: gpg <command>...
# help:txt: Execute raw gpg commands in the active account.
command_gpg ()
{
  command_account_active "${ACCOUNT_NAME}"
  gpg_helper "$@"
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

# help:fun: abbr [<name> <value>]
# help:txt: Show abbreviatures (if no argument provided) or created a new one
# help:txt  identified by name, and replaced by value.
command_abbr ()
{
  case $# in
    0)
      for key in $(config_iter abbr.); do
        info "%s=%s" "${key}" "$(config_get "${key}")"
      done
      ;;
    2)
      local name="$1"; shift
      command_config_set "abbr.$name" "$*"
      ;;
    *)
      E=2 error $"Abbr command requires zero or two arguments"
      ;;
  esac
}

# help:fun: user alias [<name> <uid>]
# help:txt: Show user aliases registered in configuration if not arguments
# help:txt: provided. If two arguments passed create a new user aliases,
# help:txt: replacing UID by nickname in timeline.
command_user_alias ()
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

# help:fun: event {post|reply|tag|message} {args...}
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

# help:event:fun: event post [--encrypt <rcpt> | --encrypt-anon <rcpt>] <message> [<tags>+]
# help:event:txt: Post a new message in our timeline. The --encrypt flag will result in
# help:event:txt: an encrypted post. The --encrypt-anon do the same that --encrypt but
# help:event:txt: without exfiltrate recipient.
command_event_post ()
{
  local u rcpt='' anon pfile="${CONFIG[account.$ACCOUNT_NAME.passphrase-file]:-/dev/null}"

  anon="$(config_eval \
    "account.$ACCOUNT_NAME.crypto-always-anon"  \
    "account.crypto-always-anon"
  )"


  case "$1" in
    --encrypt|--encrypt-anon)
      [[ "$2" ]] ||
        E=2 fatal $"Options --encrypt and --encrypt-anon require a recipient"

      [[ "$(config_eval "account.$ACCOUNT_NAME.encrypt-to-me" account.encrypt-to-me)" = "true" ]] &&
        rcpt="$2,$ACCOUNT_NAME" ||
        rcpt="$2"

      [[ "$1" = "--encrypt-anon" ]] && anon=--anon
      shift 2 ;;
  esac

  if [[ $# -eq 0 ]]; then
    E=2 error $"Event post required an argument: message"
  else
    local eid tag msg="$1" ts oid; shift
    ts="$(timestamp)"
    command_account_active "${ACCOUNT_NAME}"
    command_account_refresh
    {
      abbr_replace "$msg"; msg="$REPLY"
      oid="$(oid "$REPLY")"
      if [[ "$rcpt" ]]; then
        for u in $(expand_user "$rcpt"); do
          crypto_encrypt $anon "$u" "$ts P $msg" "$pfile" 2>&1
          u="${anon:-$u}"; u="${u//--anon/@all}"
          event_create "$ts" E "$u" "$REPLY" 2>&1
        done
      else
        event_create "$ts" P "$REPLY" 2>&1
      fi
      eid="$EID"
      for tag in "$@"; do
        sleep 1  # Because we can only post one event per second.
        if [[ "$rcpt" ]]; then
          for u in $(expand_user "$rcpt"); do
            crypto_encrypt $anon "$u" "$(timestamp) T $ACCOUNT_OID:$ts:$oid $tag" "$pfile" 2>&1
            u="${anon:-$u}"; u="${u//--anon/@all}"
            event_create "$ts" E "$u" "$REPLY" 2>&1
          done
        else
          event_create "$ts" T "$eid" "$tag" 2>&1
        fi
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
    abbr_replace "$1"
    local tag mesg="$REPLY" ts; ts="$(timestamp)"; shift
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

# help:fun: follow {list|add|del|keys} {args...}
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

# help:follow:fun: follow keys [account_name] 
# help:follow:txt: Print keys for the specific account in present, or for all
# help:follow:txt: none is specified
command_follow_keys ()
{
  command_account_active "${ACCOUNT_NAME}"
  follow_keys "$1" 2>&1 | info_multi
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
  command_account_active "${ACCOUNT_NAME}"
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

# help:daemon:fun: daemon start [--foreground]
# help:daemon:txt: Start daemon in background or in foreground if the specific
# help:daemon:txt: flag is set.
command_daemon_start ()
{
  daemon_start "$@"
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
  [[ "$1" ]] || E=2 error $"Name is required for del a directory"
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
  directory_requirements
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
  done < <(git_helper -C "$path" config -f .gitmodules -l 2>/dev/null)
}


# fun: follow_add <pull_url> [name]
# txt: Add new following using pull_url passed as argument. Optional name
#      will add a config entry for user alias to this name.
follow_add ()
{
  local pull_url="${1}" name="$2"
  oid "$pull_url"
  
  git_helper -C "${ACCOUNT_PATH}" submodule add \
    "$pull_url" "${TIMELINE_FOLLOW}/${OID_CACHE["$pull_url"]}"
  git_helper -C "${ACCOUNT_PATH}" submodule init
  git_helper -C "${ACCOUNT_PATH}" submodule update --remote

  account_commit "follow: add ${OID_CACHE["${pull_url}"]}"
  account_push

  if [[ "${CONFIG[crypto.auto-import]}" = "true" ]]
  then
    [[ -r "${ACCOUNT_PATH}/${TIMELINE_FOLLOW}/${OID_CACHE["$pull_url"]}/ENCRKEY" ]] &&
      crypto_import "${OID_CACHE["$pull_url"]}" "${ACCOUNT_PATH}/${TIMELINE_FOLLOW}/${OID_CACHE["$pull_url"]}/ENCRKEY"

    [[ -r "${ACCOUNT_PATH}/${TIMELINE_FOLLOW}/${OID_CACHE["$pull_url"]}/SIGNKEY" ]] &&
      crypto_import "${OID_CACHE["$pull_url"]}" "${ACCOUNT_PATH}/${TIMELINE_FOLLOW}/${OID_CACHE["$pull_url"]}/SIGNKEY"
  fi

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
  mute git_helper -C "$ACCOUNT_PATH" config -f .git/config \
    --remove-section "submodule.$mpath"

  mute git_helper -C "$ACCOUNT_PATH" config -f .gitmodules \
    --remove-section "submodule.$mpath"

  account_commit "follow: del ${uid}"

  git_helper -C "$ACCOUNT_PATH" rm --cached "$mpath"
  rm -rf "${ACCOUNT_PATH:?}/.git/modules/$mpath"
 
  if [[ -d "$ACCOUNT_PATH/$mpath" ]]; then
    rm -rf "${ACCOUNT_PATH:?}/${mpath:?}"
  fi

  account_push
}

# fun: follow_keys [user]
# txt: print the keys available for the specific following user if present, or
#      for all following people if none is specified.
follow_keys ()
{
  local -a line out

  [[ "$1" ]] &&
    set -- "$(uid "$1")"

  _state () {
    case "$1" in
      e) echo "expired";;
      r) echo "revoked";;
      n) echo "invalid";;
      *) echo "valid($1)";;
    esac
  }

  _print () {
    local i
    echo "${out[1]} ${out[0]}"
    for((i=2;i<${#out[@]};i++)); do
      echo "    ${out[i]}"
    done
  }

  while IFS=: read -ra line; do
    case "${line[0]}" in
      pub) out=( "$(_state "${line[1]}")" );;
      fpr) out+=( "${line[9]}" );;
      uid) out+=( "${line[9]} $(_state "${line[1]}")" );;
      sub) out[0]+="/$(_state "${line[1]}")"; _print;;
    esac
  done < <(gpg_helper -k --with-colons ${1:+"$1@timeline"})
}
main "$@"
