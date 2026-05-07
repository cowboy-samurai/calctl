#!/bin/bash
################################################################################
# Bash completion script for calctl
# 
# Installation:
#   1. Source this file in your shell:
#      source calctl-completion.bash
#   
#   2. Or copy to completion directory:
#      sudo cp calctl-completion.bash /etc/bash_completion.d/calctl
#      (or ~/.local/share/bash-completion/completions/calctl)
#
# Usage:
#   After installation, type 'calctl ' and press TAB to see completions
################################################################################

_calctl_completion() {
    local cur prev opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    
    # Get the actual calctl command (could be ./calctl, /path/to/calctl, or just calctl)
    local calctl_cmd="${COMP_WORDS[0]}"
    
    # Global flags
    local global_flags="--help --version --verbose --quiet --no-color --dry-run --format"
    
    # Top-level commands
    local commands="agent operation lab inventory config"
    
    # Agent subcommands
    local agent_cmds="list check wait get help"
    
    # Operation subcommands
    local operation_cmds="create list status resume pause monitor summary failures export delete help"
    
    # Lab subcommands
    local lab_cmds="run manual list help"
    
    # Inventory subcommands
    local inventory_cmds="courses labs show add help"
    
    # Config subcommands
    local config_cmds="init show check set help"
    
    # Format options
    local format_opts="table json summary"
    
    # Get the command (first non-flag word after calctl)
    local command=""
    local i=1
    while [ $i -lt $COMP_CWORD ]; do
        case "${COMP_WORDS[$i]}" in
            --*|-*)
                # Skip flags
                if [ "${COMP_WORDS[$i]}" = "--format" ]; then
                    ((i++))  # Skip format value too
                fi
                ;;
            *)
                if [ -z "$command" ]; then
                    command="${COMP_WORDS[$i]}"
                fi
                ;;
        esac
        ((i++))
    done
    
    # Complete --format values
    if [ "$prev" = "--format" ]; then
        COMPREPLY=( $(compgen -W "$format_opts" -- "$cur") )
        return 0
    fi
    
    # If no command yet, complete commands and global flags
    if [ -z "$command" ]; then
        COMPREPLY=( $(compgen -W "$commands $global_flags" -- "$cur") )
        return 0
    fi
    
    # Complete based on command
    case "$command" in
        agent)
            # Get subcommand if exists
            local subcommand=""
            for ((i=1; i<COMP_CWORD; i++)); do
                if [ "${COMP_WORDS[$i]}" = "agent" ]; then
                    if [ $((i+1)) -lt $COMP_CWORD ] && [[ ! "${COMP_WORDS[$((i+1))]}" =~ ^- ]]; then
                        subcommand="${COMP_WORDS[$((i+1))]}"
                    fi
                    break
                fi
            done
            
            if [ -z "$subcommand" ] || [ "$prev" = "agent" ]; then
                COMPREPLY=( $(compgen -W "$agent_cmds $global_flags" -- "$cur") )
            fi
            ;;
            
        operation)
            local subcommand=""
            for ((i=1; i<COMP_CWORD; i++)); do
                if [ "${COMP_WORDS[$i]}" = "operation" ]; then
                    if [ $((i+1)) -lt $COMP_CWORD ] && [[ ! "${COMP_WORDS[$((i+1))]}" =~ ^- ]]; then
                        subcommand="${COMP_WORDS[$((i+1))]}"
                    fi
                    break
                fi
            done
            
            if [ -z "$subcommand" ] || [ "$prev" = "operation" ]; then
                COMPREPLY=( $(compgen -W "$operation_cmds $global_flags" -- "$cur") )
            fi
            ;;
            
        lab)
            local subcommand=""
            for ((i=1; i<COMP_CWORD; i++)); do
                if [ "${COMP_WORDS[$i]}" = "lab" ]; then
                    if [ $((i+1)) -lt $COMP_CWORD ] && [[ ! "${COMP_WORDS[$((i+1))]}" =~ ^- ]]; then
                        subcommand="${COMP_WORDS[$((i+1))]}"
                    fi
                    break
                fi
            done
            
            if [ -z "$subcommand" ] || [ "$prev" = "lab" ]; then
                COMPREPLY=( $(compgen -W "$lab_cmds $global_flags" -- "$cur") )
            elif [ "$subcommand" = "run" ] || [ "$subcommand" = "manual" ] || [ "$subcommand" = "list" ]; then
                # Try to complete course names
                local courses=""
                if [ -x "$calctl_cmd" ] || command -v "$calctl_cmd" &>/dev/null; then
                    # Get courses from calctl
                    courses=$("$calctl_cmd" --format json inventory courses 2>/dev/null | jq -r 'keys[]' 2>/dev/null || echo "esend")
                fi
                
                # Check if we're completing the course or lab-id
                local lab_pos=0
                for ((i=1; i<COMP_CWORD; i++)); do
                    if [ "${COMP_WORDS[$i]}" = "$subcommand" ]; then
                        lab_pos=$((i+1))
                        break
                    fi
                done
                
                if [ $COMP_CWORD -eq $((lab_pos+1)) ]; then
                    # Complete course name
                    COMPREPLY=( $(compgen -W "$courses" -- "$cur") )
                elif [ $COMP_CWORD -eq $((lab_pos+2)) ]; then
                    # Complete lab ID for the given course
                    local course="${COMP_WORDS[$((lab_pos+1))]}"
                    if [ -n "$course" ] && ([ -x "$calctl_cmd" ] || command -v "$calctl_cmd" &>/dev/null); then
                        local lab_ids=$("$calctl_cmd" --format json inventory labs "$course" 2>/dev/null | jq -r '.[].id' 2>/dev/null)
                        COMPREPLY=( $(compgen -W "$lab_ids" -- "$cur") )
                    fi
                fi
            fi
            ;;
            
        inventory)
            local subcommand=""
            for ((i=1; i<COMP_CWORD; i++)); do
                if [ "${COMP_WORDS[$i]}" = "inventory" ]; then
                    if [ $((i+1)) -lt $COMP_CWORD ] && [[ ! "${COMP_WORDS[$((i+1))]}" =~ ^- ]]; then
                        subcommand="${COMP_WORDS[$((i+1))]}"
                    fi
                    break
                fi
            done
            
            if [ -z "$subcommand" ] || [ "$prev" = "inventory" ]; then
                COMPREPLY=( $(compgen -W "$inventory_cmds $global_flags" -- "$cur") )
            elif [ "$subcommand" = "labs" ] || [ "$subcommand" = "show" ] || [ "$subcommand" = "add" ]; then
                # Complete course names
                local courses=""
                if [ -x "$calctl_cmd" ] || command -v "$calctl_cmd" &>/dev/null; then
                    courses=$("$calctl_cmd" --format json inventory courses 2>/dev/null | jq -r 'keys[]' 2>/dev/null || echo "esend")
                fi
                
                # Check position for labs/show commands
                local inv_pos=0
                for ((i=1; i<COMP_CWORD; i++)); do
                    if [ "${COMP_WORDS[$i]}" = "$subcommand" ]; then
                        inv_pos=$((i+1))
                        break
                    fi
                done
                
                if [ $COMP_CWORD -eq $((inv_pos+1)) ]; then
                    # Complete course name
                    COMPREPLY=( $(compgen -W "$courses" -- "$cur") )
                elif [ $COMP_CWORD -eq $((inv_pos+2)) ] && [ "$subcommand" = "show" ]; then
                    # Complete lab ID for show command
                    local course="${COMP_WORDS[$((inv_pos+1))]}"
                    if [ -n "$course" ] && ([ -x "$calctl_cmd" ] || command -v "$calctl_cmd" &>/dev/null); then
                        local lab_ids=$("$calctl_cmd" --format json inventory labs "$course" 2>/dev/null | jq -r '.[].id' 2>/dev/null)
                        COMPREPLY=( $(compgen -W "$lab_ids" -- "$cur") )
                    fi
                fi
            fi
            ;;
            
        config)
            local subcommand=""
            for ((i=1; i<COMP_CWORD; i++)); do
                if [ "${COMP_WORDS[$i]}" = "config" ]; then
                    if [ $((i+1)) -lt $COMP_CWORD ] && [[ ! "${COMP_WORDS[$((i+1))]}" =~ ^- ]]; then
                        subcommand="${COMP_WORDS[$((i+1))]}"
                    fi
                    break
                fi
            done
            
            if [ -z "$subcommand" ] || [ "$prev" = "config" ]; then
                COMPREPLY=( $(compgen -W "$config_cmds $global_flags" -- "$cur") )
            elif [ "$subcommand" = "set" ]; then
                # Complete config keys
                local config_pos=0
                for ((i=1; i<COMP_CWORD; i++)); do
                    if [ "${COMP_WORDS[$i]}" = "set" ]; then
                        config_pos=$((i+1))
                        break
                    fi
                done
                
                if [ $COMP_CWORD -eq $((config_pos+1)) ]; then
                    local config_keys="CALDERA_API ADVERSARY_INVENTORY NO_COLOR VERBOSE QUIET"
                    COMPREPLY=( $(compgen -W "$config_keys" -- "$cur") )
                fi
            fi
            ;;
    esac
    
    return 0
}

# Register the completion function
complete -F _calctl_completion calctl
