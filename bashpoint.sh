#!/bin/bash
# shellcheck disable=1117

usage() {
    echo "Usage:
    ./bashpoint.sh [--debug] FILE ...
    ./bashpoint.sh [--debug] DIRECTORY ..."
}

declare -a SLIDES TITLES PAGES
declare -A STYLES COLORS
declare -i COLS
declare -i ROWS
declare -i PAGE=0
declare -i FG=0 BG=10
declare DEBUG=""
declare TALIGN HALIGN VALIGN TITLE=""
declare -i CUR=0

init_color() {
    local VALUE="$1"
    local KEY
    shift
    for KEY in "$@"; do
        COLORS["$KEY"]=$VALUE
    done
}

init_style() {
    local VALUE="$1"
    local KEY
    shift
    for KEY in "$@"; do
        STYLES["$KEY"]=$VALUE
    done
}

init() {
    set -e
    set -u
    set -o pipefail

    if [ -z "$(type -p tput)" ]; then
        echo "ERROR: tput not found!"
        exit 1
    fi

    COLS=$(tput cols)
    ROWS=$(tput lines)

    init_color 30 black
    init_color 31 red
    init_color 32 green
    init_color 33 yellow
    init_color 34 blue
    init_color 35 magenta
    init_color 36 cyan
    init_color 37 lightgr{a,e}y

    init_color 90 darkgr{a,e}y
    init_color 91 lightred
    init_color 92 lightgreen
    init_color 93 lightyellow
    init_color 94 lightblue
    init_color 95 lightmagenta
    init_color 96 lightcyan
    init_color 97 white

    init_color 39 default

    init_style 1 b bold
    init_style 2 d dim
    init_style 3 i italic slanted
    init_style 4 u underline underscore under
    init_style 5 bl blink
    init_style 6 o overline
    init_style 7 inv invert inverse
    init_style 8 h hidden invisible
    init_style 9 s strike strikethrough
}

log() {
    [ -z "$DEBUG" ] || echo "$*" >> debug.log
}

save_tokenized() {
    if [ "$DEBUG" ]; then
        tee debug.tokenized
    else
        cat
    fi
}

save_parsed() {
    if [ "$DEBUG" ]; then
        for ((i=0; i<${#SLIDES[@]}; i++)); do
            echo "=== $i ==========="
            echo "${SLIDES[$i]}"
        done > debug.slides
    fi
}

add_slide() {
    if [ "$OUT" ] && [ "$TITLE" ]; then
        local ALIGNED
        PAGE+=1
        ALIGNED="$(align "$OUT" "$PAGE" "$TITLE")"
        while [[ "$ALIGNED" =~ ===!!!pause!!!=== ]]; do
            SLIDES+=("${ALIGNED%%===!!!pause!!!===*}")
            TITLES+=("$TITLE")
            PAGES+=("$PAGE")
            ALIGNED="${ALIGNED/===!!!pause!!!===/}"
        done
        SLIDES+=("$ALIGNED")
        TITLES+=("$TITLE")
        PAGES+=("$PAGE")
    fi
}

parse_slide() {
    add_slide
    OUT=""
    IFS=' ' read -r TALIGN HALIGN VALIGN TITLE <<<"$1"
}

tokenizer() {
    #TODO: expand tabs and newlines in the loop?
    sed '
        s/\(<[^>]*>\)/\n\1ENDCMD\n/g
        :loop
            s/\(<[^>]*\)&lt;\([^>]*>\)/\1<\2/g
            s/\(<[^>]*\)&gt;\([^>]*>\)/\1>\2/g
        t loop
        s/>ENDCMD//g
        s/$/\n<br/
        s/&lt;/\n&\n/g
        s/&gt;/\n&\n/g
    ' | sed '
        /^$/d
    ' | save_tokenized
}

set_style() {
    local -i STYLE=${STYLES[$1]}
    if [ "$2" == "end" ]; then
        OUT+=$'\e[2'$((STYLE==1 ? 2 : STYLE))'m'
    else
        OUT+=$'\e['$STYLE'm'
    fi
}

set_color() {
    if [[ "$2" =~ \; ]]; then
        OUT+=$'\e['$((38 + $1))";2;${2}m"
    else
        OUT+=$'\e['$((${COLORS[$2]} + $1))'m'
    fi
}

run_cmd() {
    [ "$2" ] || OUT+="$1"
    # NOTE: we ignore errors from commands, they might be done on purpose
    set +ue
    eval "$1" &> /tmp/cmdout || true
    set -ue
    # NOTE: we have to ignore exit code, because read always hits EOF,
    # which means we always get exit code 1
    read -r -d '' -t 0.01 CMDOUT </tmp/cmdout || true
    : "$CMDOUT"
    rm /tmp/cmdout
}

align() {
    local LINE=""
    local -i LEN=0
    local -a LENGTHS=()
    local -i MAXLEN=0
    local -i LINECOUNT=0
    local BARE
    BARE="$(sed 's/===!!!pause!!!===//g;s/\x1b\[[^m]*m//g' <<<"$1")"
    while IFS='' read -r -d$'\n' LINE; do
        LINECOUNT+=1
        LEN=${#LINE}
        LENGTHS+=("$LEN")
        MAXLEN=$(( MAXLEN < LEN ? LEN : MAXLEN ))
    done <<<"$BARE"
    log "Slide $2 ($3) is $MAXLEN x $LINECOUNT"
    if [ "$MAXLEN" -ge "$COLS" ]; then
        echo >&2 "Slide $2 ($3) is too wide!"
        exit 1;
    fi
    if [ "$LINECOUNT" -ge $((ROWS - 1)) ]; then
        echo >&2 "Slide $2 ($3) is too high!"
        exit 1;
    fi
    log "linecount=$LINECOUNT"
    log "v=$VALIGN h=$HALIGN t=$TALIGN"
    case "$VALIGN" in
        top)
            # nothing to do
            ;;
        middle)
            eval "printf '\n%.0s' {1..$(((ROWS - LINECOUNT)/2))}"
            ;;
        bottom)
            eval "printf '\n%.0s' {1..$((ROWS - LINECOUNT))}"
            ;;
        *)
            echo >&2 "ERROR: unexpected vertical alignment value '$VALIGN'"
            exit 2
            ;;
    esac
    local -i CUR=0
    while IFS='' read -d $'\n' -r LINE; do
    log "line=$LINE"
        local -i PAD
        log "cur=$CUR len=${LENGTHS[$CUR]:-0}"
        LEN=${LENGTHS[$CUR]:-0}
        case "$HALIGN" in
            left)
                PAD=0
                ;;
            center)
                PAD=$(((COLS - MAXLEN)/2))
                ;;
            right)
                PAD=$((COLS - MAXLEN))
                ;;
            *)
                echo >&2 "ERROR: unexpected horizontal alignment value '$HALIGN'"
                exit 2
                ;;
        esac
        # TODO: talign per line
        case "$TALIGN" in
            left)
                # nothing to do
                ;;
            center)
                PAD+=$(((MAXLEN-LEN)/2))
                ;;
            right)
                PAD+=$((MAXLEN-LEN))
                ;;
            *)
                echo >&2 "ERROR: unexpected text alignment value '$TALIGN'"
                exit 2
                ;;
        esac
        log "cols=$COLS maxlen=$MAXLEN len=$LEN cols-maxlen=$((COLS-MAXLEN)) maxlen-len=$((MAXLEN-LEN)) pad=$PAD"
        printf "%${PAD}s%s\n" "" "$LINE"
        CUR+=1
    done <<<"$1"
}

parser() {
    OUT=""
    TOKEN=""
    while IFS='' read -r -d$'\n' TOKEN; do
        local VALUE="${TOKEN#* }"
        case "${TOKEN%% *}" in
            "<slide")   parse_slide "$VALUE";;
            "<pause")   OUT+="===!!!pause!!!===" ;;
            "<lfooter") LFOOTER="$VALUE" ;;
            "<rfooter") RFOOTER="$VALUE" ;;
            "<nop") ;;
            "<fg"|"<c"|"<color")
                        set_color $FG "$VALUE" ;;
            "</fg"|"</c"|"</color")
                        set_color $FG "default" ;;
            "<bg"|"<background")
                        set_color $BG "$VALUE" ;;
            "</bg"|"</background")
                        set_color $BG "default" ;;
            "<br")      OUT+=$'\n' ;;
            "<title")   OUT+="$TITLE" ;;
            "<env")     OUT+="${!VALUE}" ;;
            "<ans")     OUT+="$CMDOUT"; CMDOUT="" ;;
            "<run")     run_cmd "$VALUE" SILENT;;
            "<cmd")     run_cmd "$VALUE" "";;
            "</"*)      set_style "${TOKEN#</}" "end" ;;
            "<"*)       set_style "${TOKEN#<}" "start";;
            "&lt;")     OUT+="<" ;;
            "&gt;")     OUT+=">" ;;
            *)          OUT+="$TOKEN" ;;
        esac
    done
    OUT+=$'\e[0m'
    add_slide
}

display() {
    tput clear
    echo -e -n "\e]2;${TITLES[$CUR]}\007"
    echo -n "${SLIDES[$CUR]}"
    tput cup "$ROWS" 0
    local -i PROGRESS_BAR=$(( COLS*CUR/LAST ))
    local PROGRESS="${PAGES[$CUR]}/${PAGES[-1]}"
    local FOOTER
    printf -v FOOTER "%s%$((COLS/2-${#PROGRESS}/2-${#LFOOTER}))s%s" "$LFOOTER" " " "$PROGRESS"
    printf -v FOOTER "%s%$((COLS-${#FOOTER}-${#RFOOTER}))s%s" "$FOOTER" " " "$RFOOTER"
    echo -en "\e[48;5;242m${FOOTER:0:$PROGRESS_BAR}\e[49m${FOOTER:$PROGRESS_BAR}"
}

move() {
    for ((i=${#PAGES[@]}-1; i>=0; i--)); do
        if [ "${PAGES[$i]}" -eq "$1" ]; then
            CUR=$i
            return
        fi
    done
    log "ERROR: move to nonexistent page $1!"
    exit 1
}

run() {
    local -i CUR=0
    local -i LAST=$((${#SLIDES[@]}-1))
    local CHAR
    display
    while read -r -n1 CHAR; do
        case "$CHAR" in
            q|Q|x|X)                break ;;
            H)                      CUR=0 ;;
            F)                      CUR=$LAST ;;
            5)                      move $((${PAGES[$CUR]}>1 ? ${PAGES[$CUR]}-1 : 1)) ;;
            6)                      move $((${PAGES[$CUR]}<${PAGES[-1]} ? ${PAGES[$CUR]}+1 : ${PAGES[-1]})) ;;
            p|P|h|k|K|A|D|$'\x7F')  CUR+=-1 ;;
            n|N|l|j|J|B|C|" "|"")   CUR+=1 ;;
        esac
        CUR=$((CUR>LAST?LAST:(CUR<0?0:CUR)))
        display
    done
    # unfortunately, there is no reliable way to know the state of the title
    # before the presentation started, so we just set it to something reasonable
    echo -e -n "\e]2;$USER@$(hostname):$PWD\007"
    tput clear
}

load() {
    local FILES=()
    while [ $# -gt 0 ]; do
        if [ -d "$1" ]; then
            readarray -t FILES < <(find "$1" -type f | sort)
        elif [ -e "$1" ]; then
            FILES+=("$1")
        else
            echo "ERROR: '$1' is neither file nor directory!" > /dev/stderr
            exit 1
        fi
        shift
    done
    log "Input files: ${FILES[*]}"
    local TOKENS;
    TOKENS="$(cat "${FILES[@]}" | tokenizer)"
    parser <<<"$TOKENS"
    save_parsed
}

main() {
    if [ "$#" -eq 0 ]; then
        usage
        exit 1
    fi
    if [ "$1" = "--debug" ]; then
        DEBUG="true"
        shift
    fi
    init
    load "$@"
    run
}

if [ ${#BASH_SOURCE[@]} -eq 1 ]; then
    # we are executed directly, not sourced from other script
    main "$@"
fi
