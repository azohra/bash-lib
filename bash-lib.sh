#!/usr/bin/env bash
#SC2059 is disabled to have POSIX compliant colour text.
#shellcheck disable=SC2059

export C_GREEN="\\033[32m"
export C_PINK="\\033[35m"
export C_BLUE="\\033[94m"
export C_GOLD="\\033[33m"
export C_CYAN="\\033[36m"
export C_REG="\\033[0;39m"
export C_BLACK="\\e[30m"
export B_WHITE="\\e[107m"
export B_GREY="\\e[47m"
export B_BLUE_LIGHT="\\e[104m"

run_task () { 
    local __command=${1}
    eval "${__command}" 2>/dev/null &
    pid=$!
    spin[0]=".    "
    spin[1]="..   "
    spin[2]="...  "
    spin[3]=".... "
    i=0
    while kill -0 $pid 2>/dev/null || [ $i -ne 3 ]
    do
        i=$(( (i+1) %4 ))
        announce "${spin[$i]}"
        sleep .1
    done
    printf "${C_GREEN}Done!${C_REG}\n"
}

ask_permission () {  
    announce "${1}" 0
    printf " ${C_REG}(y/n): "
    while true
    do
        if [ "${auto_approve}" ]; then ans="y" && echo "y (auto)"; else read -r ans; fi
        case ${ans} in
        [yY]* ) break;;
        [nN]* ) announce "${3}" 4; exit;;
        * ) announce "Please enter y or n (y/n):" 3;;
        esac
    done
}

announce () {
    local __message=${1}
    local __kind=${2}
    if [[ "$__kind" -eq "0" ]]; then 
        printf "\r${C_GREEN}[INFO]${C_REG} ${__message}${C_REG}\n"
    elif [[ "$__kind" -eq "1" ]]; then
        printf "\r${C_PINK}[INFO]${C_REG} ${__message}${C_REG}\n"
    elif [[ "$__kind" -eq "2" ]]; then
        printf "\r${C_GOLD}[WARN]${C_REG} ${__message}${C_REG}\n"
    elif [[ "$__kind" -eq "3" ]]; then 
        printf "\r${C_CYAN}[USER]${C_REG} ${__message}${C_REG}\n"
    elif [[ "$__kind" -eq "4" ]]; then 
        printf "\r${C_PINK}[ERRO]${C_REG} ${__message}${C_REG}\n"
    fi
}

check_deps () { #this command expects an associative array of binary_name: brew package
# Example:
# $ declare -A deps=( ["gcloud"]="google-cloud-sdk" )
# $ check_deps "$(declare -p deps)"
	eval "declare -A __deps=${1#*=}"
	local __resp
	for dep in "${!__deps[@]}"; do
		command -v "${dep}" &> /dev/null
		local __resp=$?
		if [[ $__resp -ne 0 ]]; then
            ask_permission "${dep} not found. Should we install it?" "We cannot proceed without ${dep}"
            install_dep "${__deps[$dep]}" 
		fi
	done
  announce "Dependency check complete!\n" 0
}

install_dep() {
    local __target=${1}
    if [[ "$OSTYPE" == "darwin"* ]]; then
        brew install "${__target}"
    elif [[ "$OSTYPE" == "linux-gnu" ]]; then
        announce "Linux currently not supported. Exiting..." 1
        exit 1
    else 
        echo "${C_PINK}[ERRO]${C_REG} "  
        announce "Unsupported OS. Exiting..." 1
        exit 1
    fi
}
