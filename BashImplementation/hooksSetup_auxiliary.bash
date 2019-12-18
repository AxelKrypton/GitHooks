function ParseCommandLineOptions()
{
    PrintTrace "Entering ${FUNCNAME}"
    __static__PrintHelperAndExitIfNeeded "$@"
    local mutuallyExclusiveSpecifiedOptions mutuallyExclusiveOptions
    mutuallyExclusiveSpecifiedOptions=()
    mutuallyExclusiveOptions=( '-c | --copy'  '-s | --symlink' )

    PrintDebug "Parsing $# command line options: $*"
    while [[ $# -gt 0 ]]; do
        case $1 in
            -g | --git )
                if [[ -d "$2" ]]; then
                    repositoryTopLevelPath="$(realpath "$2")"
                else
                    __static__AbortDueToInvalidOrMissingOptionValue "$1" "Specified folder not found!"
                fi
                shift 2
                ;;
            -c | --copy )
                mutuallyExclusiveSpecifiedOptions+=( "$1" )
                copyFilesToRepository='TRUE'
                shift
                ;;
            -s | --symlink )
                mutuallyExclusiveSpecifiedOptions+=( "$1" )
                symlinkFilesToRepository='TRUE'
                shift
                ;;
            * )
                PrintFatalAndExit "Unrecognised option \"${1}\"."
                exit 1
                ;;
        esac
    done
    __static__CheckMutuallyExclusiveOptions
    PrintTrace "Exiting ${FUNCNAME}"
}

function __static__PrintHelperAndExitIfNeeded()
{
    PrintTrace "Entering ${FUNCNAME}"
    local option
    for option in "$@"; do
        if [[ ${option} =~ ^-(h|-help)$ ]]; then
            PrintInfo \
                'Available options to the script:\n' \
                '\e[38;5;14m  -g | --git       \e[0m  ->  Git repository top-level for which hooks should be set up   \e[94m[MANDATORY]' \
                '\e[38;5;11m  -c | --copy      \e[0m  ->  Copy files to given git repository' \
                '\e[38;5;11m  -s | --symlink   \e[0m  ->  Create symlinks to local files in given git repository' \
#                "\e[38;5;14m  -l | --lattice        \e[0m  ->  Lattice size (4 integers)           \e[94m[default: ${latticeSize[*]}]" \
#                '\e[38;5;14m  -p | --processors     \e[0m  ->  Processors grid (4 integers)        \e[94m[default: chosen from list]' \
#                '\e[38;5;14m       --doNotSubmitJob \e[0m  ->  Prepare all files but do not submit \e[94m[default: FALSE]' \
#                '\e[38;5;11m  -s | --status         \e[0m  ->  Report on benchmarks status' \
#                '\n     \e[34mNOTE: The value(s) of the \e[38;5;246mgray options\e[34m are not always used!' \
                'Options in \e[38;5;11myellow\e[34m are mutually exclusive but at least one must be given!\n'
            exit 0
        fi
    done
    PrintTrace "Exiting ${FUNCNAME}"
}

function __static__AbortDueToInvalidOrMissingOptionValue()
{
    PrintTrace "Entering ${FUNCNAME}"
    PrintFatalAndExit "The value of the option \"${1}\" was not correctly specified (either forgotten or invalid)!" "${@:2}"
    PrintTrace "Exiting ${FUNCNAME}"
}

function __static__CheckMutuallyExclusiveOptions()
{
    PrintTrace "Entering ${FUNCNAME}"
    CheckNumberOfArguments 0 $#
    if [[ ${#mutuallyExclusiveOptions[@]} -eq 0 ]]; then
        PrintTrace "Exiting ${FUNCNAME}"
        return 0;
    fi
    CheckIfVariablesAreSet mutuallyExclusiveOptions
    if [[ ${#mutuallyExclusiveSpecifiedOptions[@]} -eq 0 ]]; then
        PrintFatalAndExit \
            'One (and only one) of the options' \
            "${mutuallyExclusiveOptions[@]/#/  }" \
            'must be specified!'
    fi
    CheckIfVariablesAreSet mutuallyExclusiveSpecifiedOptions
    if [[ ${#mutuallyExclusiveSpecifiedOptions[@]} -gt 1 ]]; then
        PrintFatalAndExit \
            'The options' \
            "${mutuallyExclusiveOptions[@]/#/  }" \
            'are mutually exclusive and cannot be combined!'
    fi
    PrintTrace "Exiting ${FUNCNAME}"
}

function ValidateCommandLineOptions()
{
    PrintTrace "Entering ${FUNCNAME}"
    CheckNumberOfArguments 0 $#
    local dotGitDir
    if [[ ! -d "${repositoryTopLevelPath}" ]]; then
        PrintFatalAndExit "Mandatory option \e[1m-g | --git\e[22m has not been given!"
    else
        dotGitDir="$(git -C "${repositoryTopLevelPath}" rev-parse --git-dir 2>/dev/null)"
        if [[ $? -ne 0 ]]; then
            PrintFatalAndExit "Folder \"${repositoryTopLevelPath}\" seems not to be a git repository!"
        else
            if [[ "${dotGitDir}" != '.git' ]]; then
                PrintFatalAndExit "Folder \"${repositoryTopLevelPath}\" seems not to be the \e[1mTOP-LEVEL\e[22m of a git repository!"                
            fi
        fi
    fi    
    PrintTrace "Exiting ${FUNCNAME}"
}

function CheckClangFormatAvailability()
{
    CheckNumberOfArguments 0 $#
    if builtin type -P clang-format >/dev/null; then
        PrintInfo 'The program "clang-format" was successfully found.\n'
    else
        PrintWarning 'The program "clang-format" was not found but it is needed by the pre-commit hook.\n'
    fi
}

function SetupHooksForGivenRepository()
{
    CheckNumberOfArguments 0 $#
    CheckIfVariablesAreSet hookGitFolder thisRepositoryTopLevelPath hookImplementationFolderName
    local hookBash hookGit errorOccurred
    errorOccurred=0
    # Here we rely on the fact that in the "hooks" folder the executable files are only this
    # script together with all the hooks that will then be used. It sounds reasonable.
    for hookBash in "${thisRepositoryTopLevelPath}/"*.bash; do
        if [[ ! -f "${hookBash}" || ! -x "${hookBash}" ]]; then
            continue
        fi
        #We have to skip the main script file which is that sourcing this script => BASH_SOURCE[1]
        if [[ "$(basename ${hookBash})" != "$(basename "${BASH_SOURCE[1]}")" ]]; then
            hookGit="${hookGitFolder}/$(basename "${hookBash%.bash}")"
            if [[ -e "${hookGit}" ]]; then
                if [[ -L "${hookGit}" && "$(realpath ${hookGit})" = "${hookBash}" ]]; then
                    if [[ ${copyFilesToRepository} = 'TRUE' ]]; then
                        PrintWarning \
                            "Hook \"${hookGit}\" already correctly symlinked!" \
                            "Remove the symlink and run the script again if you want to copy the file!"
                    elif [[ ${symlinkFilesToRepository} = 'TRUE' ]]; then
                        PrintInfo "Hook \"${hookGit}\" already correctly symlinked!"
                    fi
                else
                    if [[ ${copyFilesToRepository} = 'TRUE' ]]; then
                        PrintWarning "Hook \"${hookGit}\" already existing, copy skipped!"
                    elif [[ ${symlinkFilesToRepository} = 'TRUE' ]]; then
                        PrintWarning "Hook \"${hookGit}\" already existing, symlink not created!"
                    fi
                fi
                continue
            else
                if [[ ${copyFilesToRepository} = 'TRUE' ]]; then
                    if [[ ! -d "${hookGitFolder}/${hookImplementationFolderName}" && ${copyFilesToRepository} = 'TRUE' ]]; then
                        PrintDebug "Copying implementation: \e[1mcp -r \"${thisRepositoryTopLevelPath}/${hookImplementationFolderName}\" \"${hookGitFolder}/.\"\e[22m"
                        cp -r "${thisRepositoryTopLevelPath}/${hookImplementationFolderName}" "${hookGitFolder}/."
                        if [[ $? -eq 0 ]]; then
                            PrintInfo "Implementation copy completed. Folder \"${hookGitFolder}/${hookImplementationFolderName}\" successfully created!"
                        else
                            PrintError "Unable to copy \"${thisRepositoryTopLevelPath}/${hookImplementationFolderName}\" folder to \"${hookGitFolder}/\""
                            (( errorOccurred++ ))
                        fi
                    fi
                    PrintDebug "Copying hook \"$(basename "${hookGit}")\": \e[1mcp \"${hookBash}\" \"${hookGit}\"\e[22m"
                    cp "${hookBash}" "${hookGit}"
                    if [[ -f "${hookGit}" ]]; then
                        PrintInfo "Hook \"$(basename "${hookGit}")\" copy completed. File \"${hookGit}\" successfully created!"
                    else
                        PrintError "Hook \"$(basename "${hookGit}")\" copy failed. Unable to create \"${hookGit}\" hook!"
                        (( errorOccurred++ ))
                    fi
                elif [[ ${symlinkFilesToRepository} = 'TRUE' ]]; then
                    PrintDebug "Symlinking hook \"$(basename "${hookGit}")\": \e[1mln -s -f \"${hookBash}\" \"${hookGit}\"\e[22m"
                    ln -s -f "${hookBash}" "${hookGit}"
                    if [[ -e "${hookGit}" ]]; then
                        PrintInfo "Symbolic link for \"${hookGit}\" hook successfully created!"
                    else
                        PrintError "Unable to create symbolic link for \"${hookGit}\" hook!"
                        (( errorOccurred++ ))
                    fi
                fi
            fi
        fi
    done
    if [[ ${errorOccurred} -eq 0 ]]; then
        PrintInfo -l -- ''
    else
        PrintFatalAndExit "${errorOccurred} errors occurred! Setup aborted."
    fi
}


function SetupClangFormatStyleForGivenRepository()
{
    CheckNumberOfArguments 0 $#
    CheckIfVariablesAreSet repositoryTopLevelPath clangFormatStyleFile
    local clangFormatStyleFileDestination
    clangFormatStyleFileDestination="${repositoryTopLevelPath}/_clang-format"
    if [[ ! -f "${clangFormatStyleFile}" ]]; then
        PrintError \
            "File \"${clangFormatStyleFile}\" has not been found." \
            "Setup for code style check done by hook skipped."
        return 0
    fi
    #Symlink clang-format options file to top directory so that it is found by clang-format
    if [[ -e "${clangFormatStyleFileDestination}" ]]; then
        if [[ -L "${clangFormatStyleFileDestination}" && "$(realpath ${clangFormatStyleFileDestination})" = "${clangFormatStyleFile}" ]]; then
            if [[ ${copyFilesToRepository} = 'TRUE' ]]; then               
                PrintWarning \
                    "File \"${clangFormatStyleFileDestination}\" already correctly symlinked!" \
                    "Remove the symlink and run the script again if you want to copy the file!"
            elif [[ ${symlinkFilesToRepository} = 'TRUE' ]]; then
                PrintInfo "File \"${clangFormatStyleFileDestination}\" already correctly symlinked!"
            fi
        else
            if [[ ${copyFilesToRepository} = 'TRUE' ]]; then
                PrintWarning "File \"${clangFormatStyleFileDestination}\" already existing, copy skipped!"
            elif [[ ${symlinkFilesToRepository} = 'TRUE' ]]; then
                PrintWarning "File \"${clangFormatStyleFileDestination}\" already existing, symlink not created!"
            fi
        fi
    else
        if [[ ${copyFilesToRepository} = 'TRUE' ]]; then
            cp "${clangFormatStyleFile}" "${clangFormatStyleFileDestination}"
            if [[  -f "${clangFormatStyleFileDestination}" ]]; then
                PrintInfo "Clang style file copied. File \"${clangFormatStyleFileDestination}\" successfully created!"
            else
                PrintFatalAndExit "Copy of the clang style file failed. Unable to create \"${clangFormatStyleFileDestination}\" file!"
            fi            
        elif [[ ${symlinkFilesToRepository} = 'TRUE' ]]; then
            PrintDebug "Symlinking file with clang-format options: \e[1mln -s -f \"${clangFormatStyleFile}\" \"${clangFormatStyleFileDestination}\"\e[22m"
            ln -s -f "${clangFormatStyleFile}" "${clangFormatStyleFileDestination}"
            if [[  -e "${clangFormatStyleFileDestination}" ]]; then
                PrintInfo "Symbolic link for file \"${clangFormatStyleFileDestination}\" successfully created!"
            else
                PrintFatalAndExit "Symbolic link for file \"${clangFormatStyleFileDestination}\" could not be created!"
            fi
        fi
    fi
    if [[ ! -f "${repositoryTopLevelPath}/.gitignore" || $(grep -c '_clang-format' "${repositoryTopLevelPath}/.gitignore") -eq 0 ]]; then
        PrintWarning \
            "File \"_clang-format\" is not excluded from tracking in repository \"${repositoryTopLevelPath}\"." \
            "Consider adding it to the respective \".gitignore\" file."
    fi
}
