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
        planing|1)
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

# Main dispatcher
main() {
    local cmd="${1:-help}"
    shift || true

    case "$cmd" in
        header)    cmd_header "$@" ;;
        phase)     cmd_phase "$@" ;;
        agent)     cmd_agent "$@" ;;
        status)    cmd_status "$@" ;;
        verdict)   cmd_verdict "$@" ;;
        banner)    cmd_banner "$@" ;;
        separator) cmd_separator "$@" ;;
        help|--help|-h)
            echo "STUDIO Output Utilities"
            echo ""
            echo "Usage: output.sh <command> [args...]"
            echo ""
            echo "Commands:"
            echo "  header <type>              Display header (task/init/planner/builder/verifier/complete/failed)"
            echo "  phase <phase>              Display phase banner (requirements/planing/building/verifying)"
            echo "  agent <agent> <message>    Display agent message (planner/builder/verifier/memory)"
            echo "  status <type> <message>    Display status (success/error/warning/info/pending/checkpoint)"
            echo "  verdict <verdict>          Display verdict (STRONG/SOUND/UNSTABLE/FAILED)"
            echo "  banner <type> [message]    Display completion banner"
            echo "  separator [color]          Display separator line"
            ;;
        *)
            echo "Unknown command: $cmd" >&2
            echo "Run 'output.sh help' for usage" >&2
            exit 1
            ;;
    esac
}

main "$@"
