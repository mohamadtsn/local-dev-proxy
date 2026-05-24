#!/usr/bin/env bash
# Bash completion for devproxy
# Install: source this file from ~/.bashrc, or copy to /etc/bash_completion.d/devproxy

_devproxy() {
    local cur prev
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    # Resolve the main command and subcommand from the word list
    local command="" subcommand=""
    local i
    for (( i=1; i<COMP_CWORD; i++ )); do
        local word="${COMP_WORDS[i]}"
        [[ "$word" == -* ]] && continue
        if [[ -z "$command" ]]; then
            command="$word"
        elif [[ -z "$subcommand" ]]; then
            subcommand="$word"
            break
        fi
    done

    # Option-argument pairs: complete their values, not more flags
    case "$prev" in
        --mode)
            COMPREPLY=($(compgen -W "docker local auto" -- "$cur"))
            return
            ;;
        --template)
            COMPREPLY=($(compgen -f -- "$cur"))
            return
            ;;
        --root)
            COMPREPLY=($(compgen -d -- "$cur"))
            return
            ;;
        -h|--host|-m|--main-domain|-p|--port|-i|--ip)
            return
            ;;
        bash|zsh|fish)
            # after `completion bash` etc. — nothing more to complete
            return
            ;;
    esac

    case "$command" in
        "")
            local top_cmds="create remove update cert hosts nginx mode config help completion"
            COMPREPLY=($(compgen -W "$top_cmds -v --version --help" -- "$cur"))
            ;;

        completion)
            COMPREPLY=($(compgen -W "bash zsh fish" -- "$cur"))
            ;;

        cert)
            if [[ -z "$subcommand" && "$cur" != -* ]]; then
                COMPREPLY=($(compgen -W "generate remove list" -- "$cur"))
            else
                COMPREPLY=($(compgen -W "-h --host --help" -- "$cur"))
            fi
            ;;

        hosts)
            if [[ -z "$subcommand" && "$cur" != -* ]]; then
                COMPREPLY=($(compgen -W "add remove list" -- "$cur"))
            else
                COMPREPLY=($(compgen -W "-h --host -i --ip --help" -- "$cur"))
            fi
            ;;

        nginx)
            if [[ -z "$subcommand" && "$cur" != -* ]]; then
                COMPREPLY=($(compgen -W "create-site create-static remove-site list test reload" -- "$cur"))
            else
                case "$subcommand" in
                    create-site)
                        COMPREPLY=($(compgen -W "-h --host -p --port --no-ssl --ssl --template --mode --help" -- "$cur"))
                        ;;
                    create-static)
                        COMPREPLY=($(compgen -W "-h --host --root --no-ssl --ssl --template --help" -- "$cur"))
                        ;;
                    remove-site)
                        COMPREPLY=($(compgen -W "-h --host --help" -- "$cur"))
                        ;;
                    *)
                        COMPREPLY=($(compgen -W "--help" -- "$cur"))
                        ;;
                esac
            fi
            ;;

        create)
            COMPREPLY=($(compgen -W "-h --host -p --port -i --ip -s --subdomain -m --main-domain --no-ssl --ssl --template --mode --static --root --help" -- "$cur"))
            ;;

        remove)
            COMPREPLY=($(compgen -W "-h --host --help" -- "$cur"))
            ;;

        mode)
            COMPREPLY=($(compgen -W "--mode --help" -- "$cur"))
            ;;

        update|config|help)
            COMPREPLY=($(compgen -W "--help" -- "$cur"))
            ;;

        *)
            COMPREPLY=($(compgen -W "--help" -- "$cur"))
            ;;
    esac
}

complete -F _devproxy devproxy