#!/usr/bin/env bash
#
# STUDIO Output Utilities - Terminal Formatting
# =============================================
#
# This script handles all STUDIO terminal output formatting.
# Use this script instead of embedding ANSI codes in markdown instructions.
#
# Usage:
#   ./output.sh header <type>              Display phase/task headers
#   ./output.sh phase <phase>              Display phase transition banner
#   ./output.sh agent <agent> <message>    Display agent-prefixed message
#   ./output.sh status <type> <message>    Display status message (success/error/warning/info)
#   ./output.sh verdict <verdict>          Display verdict banner
#   ./output.sh banner <type> [message]    Display completion/failure banner
#   ./output.sh separator [color]          Display separator line
#
# Environment:
#   NO_COLOR=1    Disable colors
#   STUDIO_PHASE   Current phase (planing/building/verifying)
#

set -euo pipefail

# Colors (disabled if NO_COLOR is set or not a terminal)
setup_colors() {
    if [[ -n "${NO_COLOR:-}" ]] || [[ ! -t 1 ]]; then
        RESET="" BOLD="" DIM=""
        BLACK="" RED="" GREEN="" YELLOW="" BLUE="" MAGENTA="" CYAN="" WHITE=""
        BRIGHT_BLACK="" BRIGHT_RED="" BRIGHT_GREEN="" BRIGHT_YELLOW=""
        BRIGHT_BLUE="" BRIGHT_MAGENTA="" BRIGHT_CYAN="" BRIGHT_WHITE=""
    else
        RESET='\033[0m'
        BOLD='\033[1m'
        DIM='\033[2m'

        BLACK='\033[30m'
        RED='\033[31m'
        GREEN='\033[32m'
        YELLOW='\033[33m'
        BLUE='\033[34m'
        MAGENTA='\033[35m'
        CYAN='\033[36m'
        WHITE='\033[37m'

        BRIGHT_BLACK='\033[90m'
        BRIGHT_RED='\033[91m'
        BRIGHT_GREEN='\033[92m'
        BRIGHT_YELLOW='\033[93m'
        BRIGHT_BLUE='\033[94m'
        BRIGHT_MAGENTA='\033[95m'
        BRIGHT_CYAN='\033[96m'
        BRIGHT_WHITE='\033[97m'
    fi
}

setup_colors

# Separator line (80 chars)
SEP="════════════════════════════════════════════════════════════════════════════════"
LINE="────────────────────────────────────────────────────────────────────────────────"

# Header command - display major section headers
cmd_header() {
    local type="${1:-task}"
    local color title

    case "$type" in
        task)
            color="$BRIGHT_WHITE"
            title="STUDIO TASK"
            ;;
        init)
            color="$BRIGHT_WHITE"
            title="STUDIO INIT"
            ;;
        planner|planing)
            color="$BRIGHT_BLUE"
            title="THE PLANNER"
            ;;
        builder|building)
            color="$BRIGHT_YELLOW"
            title="THE BUILDER"
            ;;
        verifier|verifying)
            color="$BRIGHT_CYAN"
            title="THE VERIFIER"
            ;;
        complete)
            color="$BRIGHT_GREEN"
            title="TASK COMPLETE"
            ;;
        failed)
            color="$BRIGHT_RED"
            title="TASK FAILED"
            ;;
        *)
            color="$BRIGHT_WHITE"
            title="$type"
            ;;
    esac

    echo -e "${BOLD}${color}${SEP}${RESET}"
    printf "${BOLD}${color}%*s${RESET}\n" $(( (${#title} + 80) / 2 )) "$title"
    echo -e "${BOLD}${color}${SEP}${RESET}"
}

# Phase command - display phase transition
cmd_phase() {
    local phase="${1:-}"
    local color icon num

    case "$phase" in
        planning|planing|1)
            color="$BRIGHT_BLUE"
            icon="🔷"
            num="1"
            phase="PLANNING"
            ;;
        building|2)
            color="$BRIGHT_YELLOW"
            icon="🔶"
            num="2"
            phase="BUILDING"
            ;;
        verifying|3)
            color="$BRIGHT_CYAN"
            icon="🔷"
            num="3"
            phase="VERIFYING"
            ;;
        requirements|0)
            color="$BRIGHT_BLUE"
            icon="📋"
            num="0"
            phase="REQUIREMENTS GATHERING"
            ;;
        *)
            echo "Unknown phase: $phase" >&2
            exit 1
            ;;
    esac

    echo ""
    echo -e "${BOLD}${color}${icon} PHASE ${num}: ${phase}${RESET}"
    echo -e "${color}${LINE}${RESET}"
    echo ""
}

# Agent command - display agent-prefixed message
cmd_agent() {
    local agent="${1:-}"
    local message="${2:-}"
    local color

    case "$agent" in
        planner|Planner)
            color="$BRIGHT_BLUE"
            agent="Planner"
            ;;
        builder|Builder)
            color="$BRIGHT_YELLOW"
            agent="Builder"
            ;;
        verifier|Verifier)
            color="$BRIGHT_CYAN"
            agent="Verifier"
            ;;
        memory|Memory)
            color="$BRIGHT_MAGENTA"
            agent="Memory"
            ;;
        init|Init)
            color="$BRIGHT_MAGENTA"
            agent="Init"
            ;;
        *)
            color="$BRIGHT_WHITE"
            ;;
    esac

    echo -e "${color}[${agent}]${RESET} ${message}"
}

# Status command - display status message
cmd_status() {
    local type="${1:-info}"
    local message="${2:-}"
    local icon color

    case "$type" in
        success|ok|done)
            icon="✓"
            color="$BRIGHT_GREEN"
            ;;
        error|fail|failed)
            icon="✗"
            color="$BRIGHT_RED"
            ;;
        warning|warn)
            icon="⚠"
            color="$BRIGHT_YELLOW"
            ;;
        info)
            icon="→"
            color="$BRIGHT_BLUE"
            ;;
        pending)
            icon="○"
            color="$BRIGHT_BLACK"
            ;;
        checkpoint)
            icon="◆"
            color="$BRIGHT_MAGENTA"
            ;;
        *)
            icon="•"
            color="$RESET"
            ;;
    esac

    echo -e "${color}${icon}${RESET} ${message}"
}

# Verdict command - display verdict banner
cmd_verdict() {
    local verdict="${1:-}"
    local color

    case "$verdict" in
        STRONG|strong)
            color="$BRIGHT_GREEN"
            verdict="STRONG"
            ;;
        SOUND|sound)
            color="$BRIGHT_GREEN"
            verdict="SOUND"
            ;;
        UNSTABLE|unstable)
            color="$BRIGHT_YELLOW"
            verdict="UNSTABLE"
            ;;
        FAILED|failed)
            color="$BRIGHT_RED"
            verdict="FAILED"
            ;;
        *)
            color="$BRIGHT_WHITE"
            ;;
    esac

    echo -e "${BOLD}${color}Verdict: ${verdict}${RESET}"
}

# Banner command - display completion/failure banner
cmd_banner() {
    local type="${1:-complete}"
    local message="${2:-}"

    case "$type" in
        complete|success)
            cmd_header "complete"
            ;;
        failed|failure|error)
            cmd_header "failed"
            ;;
        *)
            cmd_header "$type"
            ;;
    esac

    if [[ -n "$message" ]]; then
        echo ""
        echo "$message"
    fi
}

# Separator command - display separator line
cmd_separator() {
    local color="${1:-}"

    case "$color" in
        blue) echo -e "${BRIGHT_BLUE}${LINE}${RESET}" ;;
        yellow) echo -e "${BRIGHT_YELLOW}${LINE}${RESET}" ;;
        cyan) echo -e "${BRIGHT_CYAN}${LINE}${RESET}" ;;
        green) echo -e "${BRIGHT_GREEN}${LINE}${RESET}" ;;
        red) echo -e "${BRIGHT_RED}${LINE}${RESET}" ;;
        *) echo -e "${LINE}" ;;
    esac
}

# ============================================================================
# PHASE 1: Progress Visualization Functions
# ============================================================================

# Spinner characters for animated progress
SPINNERS=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
SPINNER_IDX=0

# Progress bar command - display a progress bar
# Usage: progress_bar <current> <total> [label]
cmd_progress_bar() {
    local current="${1:-0}"
    local total="${2:-100}"
    local label="${3:-Progress}"
    local width=40

    # Avoid division by zero
    [[ "$total" -eq 0 ]] && total=1

    local pct=$((current * 100 / total))
    local filled=$((current * width / total))
    local empty=$((width - filled))

    # Build the bar
    local bar=""
    for ((i=0; i<filled; i++)); do bar+="█"; done
    for ((i=0; i<empty; i++)); do bar+="░"; done

    printf "${BOLD}%s${RESET}: [${BRIGHT_GREEN}%s${DIM}%s${RESET}] %d%% (%d/%d)\n" \
        "$label" "${bar:0:$filled}" "${bar:$filled}" "$pct" "$current" "$total"
}

# Step header command - display step header with status
# Usage: step_header <step_num> <total> <step_name> [status]
cmd_step_header() {
    local step_num="${1:-1}"
    local total="${2:-1}"
    local step_name="${3:-Step}"
    local status="${4:-running}"

    local status_icon status_color
    case "$status" in
        running|in_progress)
            status_icon="⟳"
            status_color="$BRIGHT_YELLOW"
            ;;
        success|complete|completed)
            status_icon="✓"
            status_color="$BRIGHT_GREEN"
            ;;
        failed|error)
            status_icon="✗"
            status_color="$BRIGHT_RED"
            ;;
        retry|retrying)
            status_icon="↻"
            status_color="$BRIGHT_YELLOW"
            ;;
        skipped)
            status_icon="⊘"
            status_color="$BRIGHT_BLACK"
            ;;
        pending)
            status_icon="○"
            status_color="$BRIGHT_BLACK"
            ;;
        *)
            status_icon="•"
            status_color="$RESET"
            ;;
    esac

    echo ""
    echo -e "${BOLD}╭─ STEP ${step_num}/${total}: ${step_name}${RESET}"
    echo -e "│ Status: ${status_color}${status_icon} ${status}${RESET}"
}

# Build status box command - display current build status
# Usage: build_status <task_id> <phase> <step> <total> <current_action>
cmd_build_status() {
    local task_id="${1:-unknown}"
    local phase="${2:-building}"
    local step="${3:-0}"
    local total="${4:-1}"
    local current_action="${5:-Working...}"

    [[ "$total" -eq 0 ]] && total=1
    local pct=$((step * 100 / total))

    # Build progress bar
    local width=40
    local filled=$((step * width / total))
    local bar=""
    for ((i=0; i<filled; i++)); do bar+="█"; done
    for ((i=filled; i<width; i++)); do bar+="░"; done

    echo ""
    echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${BOLD}║${RESET}  BUILDING: ${BRIGHT_CYAN}${task_id}${RESET}"
    echo -e "${BOLD}╠══════════════════════════════════════════════════════════════╣${RESET}"
    echo -e "${BOLD}║${RESET}  Progress: [${BRIGHT_GREEN}${bar:0:$filled}${DIM}${bar:$filled}${RESET}] ${pct}%"
    echo -e "${BOLD}║${RESET}  Phase:    ${phase} (step ${step}/${total})"
    echo -e "${BOLD}║${RESET}  Current:  ${current_action}"
    echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${RESET}"
}

# Error box command - display contextual error with fix suggestions
# Usage: error_box <error_type> <why> <fix> [auto_fix_cmd]
cmd_error_box() {
    local error_type="${1:-Error}"
    local why="${2:-An error occurred}"
    local fix="${3:-Check the logs for details}"
    local auto_fix="${4:-}"

    echo ""
    echo -e "${BOLD}${BRIGHT_RED}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${BOLD}${BRIGHT_RED}║${RESET}  ❌ ERROR: ${BOLD}${error_type}${RESET}"
    echo -e "${BOLD}${BRIGHT_RED}╠══════════════════════════════════════════════════════════════╣${RESET}"
    echo -e "${BOLD}${BRIGHT_RED}║${RESET}"
    echo -e "${BOLD}${BRIGHT_RED}║${RESET}  ${BOLD}Why this happened:${RESET}"
    echo -e "${BOLD}${BRIGHT_RED}║${RESET}  ${why}"
    echo -e "${BOLD}${BRIGHT_RED}║${RESET}"
    echo -e "${BOLD}${BRIGHT_RED}║${RESET}  ${BOLD}How to fix:${RESET}"

    # Handle multi-line fix instructions
    while IFS= read -r line; do
        echo -e "${BOLD}${BRIGHT_RED}║${RESET}    ${line}"
    done <<< "$fix"

    if [[ -n "$auto_fix" ]]; then
        echo -e "${BOLD}${BRIGHT_RED}║${RESET}"
        echo -e "${BOLD}${BRIGHT_RED}║${RESET}  ${BOLD}Auto-fix available:${RESET}"
        echo -e "${BOLD}${BRIGHT_RED}║${RESET}  ${BRIGHT_GREEN}[y]${RESET} Run: ${BRIGHT_CYAN}${auto_fix}${RESET}"
        echo -e "${BOLD}${BRIGHT_RED}║${RESET}  ${BRIGHT_BLACK}[n]${RESET} Fix manually"
    fi

    echo -e "${BOLD}${BRIGHT_RED}║${RESET}"
    echo -e "${BOLD}${BRIGHT_RED}╚══════════════════════════════════════════════════════════════╝${RESET}"
}

# Spinner command - display/advance spinner
# Usage: spinner <message>
cmd_spinner() {
    local message="${1:-Working...}"
    SPINNER_IDX=$(( (SPINNER_IDX + 1) % ${#SPINNERS[@]} ))
    printf "\r${BRIGHT_CYAN}${SPINNERS[$SPINNER_IDX]}${RESET} %s" "$message"
}

# Panel command - display content in a styled panel
# Usage: panel <title> <content> [color]
cmd_panel() {
    local title="${1:-Panel}"
    local content="${2:-}"
    local color="${3:-BRIGHT_CYAN}"

    # Get the color variable
    local panel_color
    case "$color" in
        red|RED)       panel_color="$BRIGHT_RED" ;;
        green|GREEN)   panel_color="$BRIGHT_GREEN" ;;
        yellow|YELLOW) panel_color="$BRIGHT_YELLOW" ;;
        blue|BLUE)     panel_color="$BRIGHT_BLUE" ;;
        cyan|CYAN)     panel_color="$BRIGHT_CYAN" ;;
        magenta|MAGENTA) panel_color="$BRIGHT_MAGENTA" ;;
        *)             panel_color="$BRIGHT_CYAN" ;;
    esac

    local width=60
    local title_len=${#title}
    local title_pad=$(( (width - title_len - 2) / 2 ))

    # Top border
    echo -e "${panel_color}╭$(printf '─%.0s' $(seq 1 $width))╮${RESET}"

    # Title line
    printf "${panel_color}│${RESET}"
    printf "%*s" $title_pad ""
    printf "${BOLD}%s${RESET}" "$title"
    printf "%*s" $((width - title_pad - title_len)) ""
    printf "${panel_color}│${RESET}\n"

    # Title separator
    echo -e "${panel_color}├$(printf '─%.0s' $(seq 1 $width))┤${RESET}"

    # Content lines
    while IFS= read -r line; do
        local line_len=${#line}
        local pad=$((width - line_len - 1))
        [[ $pad -lt 0 ]] && pad=0
        printf "${panel_color}│${RESET} %s%*s${panel_color}│${RESET}\n" "$line" $pad ""
    done <<< "$content"

    # Bottom border
    echo -e "${panel_color}╰$(printf '─%.0s' $(seq 1 $width))╯${RESET}"
}

# Resume prompt command - display task resume prompt
# Usage: resume_prompt <task_id> <goal> <status> <step> <total> <last_activity>
cmd_resume_prompt() {
    local task_id="${1:-unknown}"
    local goal="${2:-Unknown goal}"
    local status="${3:-PAUSED}"
    local step="${4:-?}"
    local total="${5:-?}"
    local last_activity="${6:-unknown}"

    echo ""
    echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${BOLD}║${RESET}  ${BRIGHT_YELLOW}INCOMPLETE BUILD FOUND${RESET}"
    echo -e "${BOLD}╠══════════════════════════════════════════════════════════════╣${RESET}"
    echo -e "${BOLD}║${RESET}"
    echo -e "${BOLD}║${RESET}  ID:     ${BRIGHT_CYAN}${task_id}${RESET}"
    echo -e "${BOLD}║${RESET}  Goal:   ${goal:0:50}"
    echo -e "${BOLD}║${RESET}  Status: ${BRIGHT_YELLOW}${status}${RESET} at step ${step}/${total}"
    echo -e "${BOLD}║${RESET}  Last:   ${last_activity}"
    echo -e "${BOLD}║${RESET}"
    echo -e "${BOLD}║${RESET}  Options:"
    echo -e "${BOLD}║${RESET}  ${BRIGHT_GREEN}[r]${RESET} Resume this build: ${DIM}/build resume${RESET}"
    echo -e "${BOLD}║${RESET}  ${BRIGHT_RED}[a]${RESET} Abort this build:  ${DIM}/build abort${RESET}"
    echo -e "${BOLD}║${RESET}  ${BRIGHT_BLUE}[n]${RESET} Start a new build: ${DIM}/build <goal>${RESET}"
    echo -e "${BOLD}║${RESET}"
    echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${RESET}"
}

# Table command - display data as a table
# Usage: table <headers> <rows...>
# Headers and rows are pipe-separated: "Col1|Col2|Col3"
cmd_table() {
    local headers="$1"
    shift
    local rows=("$@")

    # Parse headers
    IFS='|' read -ra cols <<< "$headers"
    local num_cols=${#cols[@]}

    # Calculate column widths (minimum 10)
    local widths=()
    for col in "${cols[@]}"; do
        local w=${#col}
        [[ $w -lt 10 ]] && w=10
        widths+=("$w")
    done

    # Update widths based on row content
    for row in "${rows[@]}"; do
        IFS='|' read -ra cells <<< "$row"
        for i in "${!cells[@]}"; do
            local cell_len=${#cells[$i]}
            [[ $cell_len -gt ${widths[$i]:-10} ]] && widths[$i]=$cell_len
        done
    done

    # Print header
    echo -ne "${BOLD}"
    for i in "${!cols[@]}"; do
        printf "│ %-${widths[$i]}s " "${cols[$i]}"
    done
    echo -e "│${RESET}"

    # Print separator
    for i in "${!widths[@]}"; do
        printf "├─"
        printf '─%.0s' $(seq 1 ${widths[$i]})
        printf "─"
    done
    echo "┤"

    # Print rows
    for row in "${rows[@]}"; do
        IFS='|' read -ra cells <<< "$row"
        for i in "${!cells[@]}"; do
            printf "│ %-${widths[$i]:-10}s " "${cells[$i]:-}"
        done
        echo "│"
    done
}

# Main dispatcher
main() {
    local cmd="${1:-help}"
    shift || true

    case "$cmd" in
        header)        cmd_header "$@" ;;
        phase)         cmd_phase "$@" ;;
        agent)         cmd_agent "$@" ;;
        status)        cmd_status "$@" ;;
        verdict)       cmd_verdict "$@" ;;
        banner)        cmd_banner "$@" ;;
        separator)     cmd_separator "$@" ;;
        progress_bar)  cmd_progress_bar "$@" ;;
        step_header)   cmd_step_header "$@" ;;
        build_status)  cmd_build_status "$@" ;;
        error_box)     cmd_error_box "$@" ;;
        spinner)       cmd_spinner "$@" ;;
        panel)         cmd_panel "$@" ;;
        resume_prompt) cmd_resume_prompt "$@" ;;
        table)         cmd_table "$@" ;;
        help|--help|-h)
            echo "STUDIO Output Utilities"
            echo ""
            echo "Usage: output.sh <command> [args...]"
            echo ""
            echo "Basic Commands:"
            echo "  header <type>              Display header (task/init/planner/builder/verifier/complete/failed)"
            echo "  phase <phase>              Display phase banner (requirements/planing/building/verifying)"
            echo "  agent <agent> <message>    Display agent message (planner/builder/verifier/memory)"
            echo "  status <type> <message>    Display status (success/error/warning/info/pending/checkpoint)"
            echo "  verdict <verdict>          Display verdict (STRONG/SOUND/UNSTABLE/FAILED)"
            echo "  banner <type> [message]    Display completion banner"
            echo "  separator [color]          Display separator line"
            echo ""
            echo "Progress Commands:"
            echo "  progress_bar <cur> <total> [label]     Display progress bar"
            echo "  step_header <n> <total> <name> [status] Display step header"
            echo "  build_status <id> <phase> <step> <total> <action> Display build status box"
            echo "  spinner <message>                       Display/advance spinner"
            echo ""
            echo "Rich UI Commands:"
            echo "  error_box <type> <why> <fix> [auto_fix] Display contextual error box"
            echo "  panel <title> <content> [color]         Display content panel"
            echo "  resume_prompt <id> <goal> <status> <step> <total> <time> Display resume prompt"
            echo "  table <headers> <row1> [row2...]        Display table (pipe-separated)"
            ;;
        *)
            echo "Unknown command: $cmd" >&2
            echo "Run 'output.sh help' for usage" >&2
            exit 1
            ;;
    esac
}

main "$@"
