#
#  Copyright (c) 2019-2020 Alessandro Sciarra <sciarra@itp.uni-frankfurt.de>
#
#  This file is part of GitHooks.
#
#  GitHooks is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.
#
#  GitHooks is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with GitHooks. If not, see <https://www.gnu.org/licenses/>.
#
#-----------------------------------------------------------------------
# When this file is sourced, auxiliary files are also sourced,
# nothing is done if this file is for some reason executed.
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    # Here we cannot use functions in this file that rely on code in other files
    fileThatSourced="$(basename "${BASH_SOURCE[1]}")" # Assume this is true
    fileThatSourced="${fileThatSourced/%.bash}"
    filesToBeSourced=(
        "${auxiliaryBashCodeTopLevelPath}/${hookImplementationFolderName}/Logger.bash"
        "${auxiliaryBashCodeTopLevelPath}/${hookImplementationFolderName}/${fileThatSourced}_auxiliary.bash"
    )
    if [[ "${fileThatSourced}" != 'hooksSetup' ]]; then
        filesToBeSourced+=( "${auxiliaryBashCodeTopLevelPath}/hooksGlobalVariables.bash" )
    fi
    for auxFile in "${filesToBeSourced[@]}"; do
        source "${auxFile}"
        if [[ $? -ne 0 ]]; then
            printf "\e[1;91m FATAL:\e[22m Unable to source \"${auxFile}\".\e[0m\n"
            exit 1
        fi
    done
    unset -v 'fileThatSourced' 'filesToBeSourced' 'auxFile'
fi
#-----------------------------------------------------------------------

function AbortCommit() {
    PrintError "$1"; shift
    if [[ $# -gt 0 ]]; then
        "$@"
    fi
    PrintFatalAndExit "HOOK FAILURE ($(basename $0))"
}

function AskYesNoQuestionToUser()
{
    local printLevel
    printLevel="$1"; shift
    exec < /dev/tty #Allows us to read user input below, assigns stdin to keyboard
    case $# in
        0 )
            PrintInternalAndExit "Function \"${FUNCNAME}\" called without message!" ;;
        1 )
            ${printLevel} -n -l -- "$1  [Y/N]  " ;;
        * )
            ${printLevel} -n -l -- "${@:1:$#-1}" "${@: -1}  [Y/N]  " ;;
    esac
}

function UserSaidYes()
{
    local userAnswer
    while read userAnswer; do
        if [ "$userAnswer" = "Y" ]; then
            exec <&- #Closes stdin descriptor
            return 0
        elif [ "$userAnswer" = "N" ]; then
            exec <&- #Closes stdin descriptor
            return 1
        else
            PrintError -n -- "Please enter Y (yes) or N (no): "
        fi
    done
}

function UserSaidNo()
{
    if UserSaidYes; then
        return 1
    else
        return 0
    fi
}

function CheckIfVariablesAreSet() {
    local variableName
    for variableName in "$@"; do
        if [[ ! -v "${variableName}" ]]; then
            PrintInternalAndExit "Variable \"${variableName}\" not set but needed" "to be set in function \"${FUNCNAME[1]}\"."
        else
            if [[ ! "${!variableName}" ]]; then
                PrintInternalAndExit "Variable \"${variableName}\" set but empty" "in function \"${FUNCNAME[1]}\". A non-empty value should be set!"
            fi
        fi
    done
}

function CheckNumberOfArguments() {
    if [[ $1 -ne $2 ]]; then
        PrintInternalAndExit "Function \"${FUNCNAME[1]}\" called with $2 argument(s) but $1 needed!"
    fi
}
