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
            -F | --force )
                forceCopyOrSymlink='TRUE'
                shift
                ;;
            --activateCommitFormatCheck )
                activateCommitFormatCheck='TRUE'
                shift
                ;;
            --subjectMaxLength )
                if [[ ! $2 =~ ^[1-9][0-9]*$ ]]; then
                    __static__AbortDueToInvalidOrMissingOptionValue "$1"
                else
                    commitHeadlineMaximumLength="$2"
                fi
                shift 2
                ;;
            --subjectMinLength )
                if [[ ! $2 =~ ^[1-9][0-9]*$ ]]; then
                    __static__AbortDueToInvalidOrMissingOptionValue "$1"
                else
                    commitHeadlineMinimumLength="$2"
                fi
                shift 2
                ;;
            --bodyLineMaxLength )
                if [[ ! $2 =~ ^[1-9][0-9]*$ ]]; then
                    __static__AbortDueToInvalidOrMissingOptionValue "$1"
                else
                    commitBodyLineMaximumLength="$2"
                fi
                shift 2
                ;;
            --activateCodeStyleCheck )
                activateCodeStyleCheck='TRUE'
                shift
                ;;
            -l | --language )
                repositoryLanguage="$2"
                shift 2
                ;;
            --clangFile )
                if [[ ! -f "$2" ]]; then
                    __static__AbortDueToInvalidOrMissingOptionValue "$1" "File not found!"
                else
                    clangFormatStyleFile="$2"
                fi
                shift 2
                ;;
            --activateLicenseNoticeCheck )
                activateLicenseNoticeCheck='TRUE'
                shift
                ;;
            --noticeFile )
                if [[ ! -f "$2" ]]; then
                    __static__AbortDueToInvalidOrMissingOptionValue "$1" "File not found!"
                else
                    licenseNoticeFile="$2"
                fi
                shift 2
                ;;
            --activateCopyrightCheck )
                activateCopyrightCheck='TRUE'
                shift
                ;;
            --activateSpacesFixAndCheck )
                activateWhitespaceFixAndCheck='TRUE'
                shift
                ;;
            --activateBranchRestrictions )
                activateBranchRestrictions='TRUE'
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
                '\e[38;5;33m  -g | --git                  \e[0m  ->  Git repository top-level for which hooks should be set up   \e[94m[MANDATORY]' \
                '\e[38;5;11m  -c | --copy                 \e[0m  ->  Copy files to given git repository \e[94m[recomended for multi-repository usage]' \
                '\e[38;5;11m  -s | --symlink              \e[0m  ->  Create symlinks to local files in given git repository' \
                '\e[38;5;14m  -F | --force                \e[0m  ->  Overwrite previous file(s) or symlink(s) in repository' \
                '' \
                '\e[38;5;10mOptions for the \e[1mcommit-msg\e[22m hook fine-tuning:' \
                '' \
                '\e[38;5;246m  --activateCommitFormatCheck \e[0m  ->  commit-msg hook will check message mail-like format' \
                "\e[38;5;14m       --subjectMaxLength    \e[0m   ->  Maximum length in characters of the first line of the commit message \e[94m[default: ${commitHeadlineMaximumLength}]" \
                "\e[38;5;14m       --subjectMinLength    \e[0m   ->  Minimum length in characters of the first line of the commit message \e[94m[default: ${commitHeadlineMinimumLength}]" \
                "\e[38;5;14m       --bodyLineMaxLength   \e[0m   ->  Maximum length in characters of the body lines of the commit message \e[94m[default: ${commitBodyLineMaximumLength}]" \
                '' \
                '\e[38;5;10mOptions for the \e[1mpre-commit\e[22m hook fine-tuning:' \
                '' \
                '\e[38;5;246m  --activateCodeStyleCheck    \e[0m  ->  At the moment only for "c" or "cpp" language' \
                '\e[38;5;14m  -l | --language             \e[0m  ->  Repository programming language' \
                '\e[38;5;14m       --clangFile            \e[0m  ->  Style file for clang-format, if not specified use local one' \
                '' \
                '\e[38;5;246m  --activateLicenseNoticeCheck\e[0m  ->  pre-commit hook will check license notice' \
                '\e[38;5;14m       --noticeFile           \e[0m  ->  License notice file for header check' \
                "\e[38;5;14m       --extensionsLicense    \e[0m  ->  Extensions of files to be checked about license notice      \e[94m[default: ${extensionsOfFilesWhoseLicenseNoticeShouldBeChecked}]" \
                '' \
                '\e[38;5;246m  --activateCopyrightCheck    \e[0m  ->  pre-commit hook will check copyright statement' \
                "\e[38;5;14m       --extensionsCopyright  \e[0m  ->  Extensions of files to be checked about copyright statement \e[94m[default: ${extensionsOfFilesWhoseCopyrightShouldBeChecked}]" \
                '' \
                '\e[38;5;246m  --activateSpacesFixAndCheck \e[0m  ->  pre-commit hook will fix and check whitespaces in fully staged files' \
                '' \
                '\e[38;5;246m  --activateBranchRestrictions\e[0m  ->  pre-commit hook will forbit commits on "master" and "develop" branches' \
                '\n     \e[34mNOTE: \e[38;5;246mGray options\e[34m should be used in combination with \e[38;5;14mfollowing cyan ones\e[34m!' \
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
    if [[ ${activateCodeStyleCheck} = 'TRUE' && "${repositoryLanguage}" = '' ]]; then
        PrintFatalAndExit "You asked to set up code style check but no language was specified."
    fi
    if [[ ${activateLicenseNoticeCheck} = 'TRUE' ]]; then
        if [[ "${licenseNoticeFile}" = '' ]]; then
            PrintFatalAndExit "You asked to set up license notice check but no notice file was specified."
        fi
    fi
    PrintTrace "Exiting ${FUNCNAME}"
}

function CreateFileWithVariablesToSupportHooksExecution()
{
    PrintTrace "Entering ${FUNCNAME}"
    CheckNumberOfArguments 0 $#
    CheckIfVariablesAreSet fileWithVariablesToSupportHooksExecution
    # fd 3 and 4 are used by BashLogger in its v0.1 -> use here fd 5
    exec 5>&1 1>"${fileWithVariablesToSupportHooksExecution}"
    printf '# commit-msg variables\n'
    printf "readonly doCommitMessageFormatCheck='${activateCommitFormatCheck}'\n"
    if [[ ${activateCommitFormatCheck} = 'TRUE' ]]; then
        printf "readonly commitHeadlineMinimumLength=${commitHeadlineMinimumLength}\n"
        printf "readonly commitHeadlineMaximumLength=${commitHeadlineMaximumLength}\n"
        printf "readonly commitBodyLineMaximumLength=${commitBodyLineMaximumLength}\n"
    fi
    printf '# pre-commit variables\n'
    printf "readonly doCodeStyleCheckWithClangFormat='${activateCodeStyleCheck}'\n"
    if [[ ${activateCodeStyleCheck} = 'TRUE' && "${repositoryLanguage}" =~ ^c(pp)?$ ]]; then
        printf "readonly extensionsOfFilesWhoseCodeStyleShouldBeCheckedWithClangFormat=( 'c' 'C' 'cpp' 'h' 'hpp' 'cl' )\n"
    fi
    printf "readonly doLicenseNoticeCheck='${activateLicenseNoticeCheck}'\n"
    if [[ ${activateLicenseNoticeCheck} = 'TRUE' ]]; then
        printf "readonly extensionsOfFilesWhoseLicenseNoticeShouldBeChecked=( '${extensionsOfFilesWhoseLicenseNoticeShouldBeChecked}' )\n"
    fi
    printf "readonly doCopyrightStatementCheck='${activateCopyrightCheck}'\n"
    if [[ ${activateCopyrightCheck} = 'TRUE' ]]; then
        printf "readonly extensionsOfFilesWhoseCopyrightShouldBeChecked=( '${extensionsOfFilesWhoseCopyrightShouldBeChecked}' )\n"
    fi
    printf "readonly doWhitespaceFixAndCheck='${activateWhitespaceFixAndCheck}'\n"
    printf "readonly restrictCommitsOnSomeBranches='${activateBranchRestrictions}'\n"
    exec 1>&5-
    PrintInfo "File \"${fileWithVariablesToSupportHooksExecution}\" successfully created!"
    PrintTrace "Exiting ${FUNCNAME}"
}

function CheckClangFormatAvailability()
{
    PrintTrace "Entering ${FUNCNAME}"
    CheckNumberOfArguments 0 $#
    if builtin type -P clang-format >/dev/null; then
        PrintInfo 'The program "clang-format" was successfully found.'
    else
        PrintWarning 'The program "clang-format" was not found but it is needed by the pre-commit hook.'
    fi
    PrintTrace "Exiting ${FUNCNAME}"
}

function SetupHooksForGivenRepository()
{
    PrintTrace "Entering ${FUNCNAME}"
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
            __static__SetupFileOrFolderCopyOrSymlink "${hookBash}" "${hookGit}"
            if [[ $? -ne 0 ]]; then
                (( errorOccurred++ ))
            fi
        fi
    done
    __static__SetupFileOrFolderCopyOrSymlink "${thisRepositoryTopLevelPath}/${hookImplementationFolderName}" "${hookGitFolder}/${hookImplementationFolderName}"
    if [[ $? -ne 0 ]]; then
        (( errorOccurred++ ))
    fi
    if [[ ${errorOccurred} -ne 0 ]]; then
        PrintFatalAndExit "${errorOccurred} errors occurred setting up git hooks! Setup aborted."
    fi
    PrintTrace "Exiting ${FUNCNAME}"
}

function SetupClangFormatStyleForGivenRepository()
{
    PrintTrace "Entering ${FUNCNAME}"
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
    __static__SetupFileOrFolderCopyOrSymlink "${clangFormatStyleFile}" "${clangFormatStyleFileDestination}"
    if [[ $? -ne 0 ]]; then
        PrintFatalAndExit "Error occurred setting up clang-format style check! Setup aborted."
    fi
    if [[ ! -f "${repositoryTopLevelPath}/.gitignore" || $(grep -c '_clang-format' "${repositoryTopLevelPath}/.gitignore") -eq 0 ]]; then
        PrintWarning \
            "File \"_clang-format\" is not excluded from tracking in repository \"${repositoryTopLevelPath}\"." \
            "Consider adding it to the respective \".gitignore\" file."
    fi
    PrintTrace "Exiting ${FUNCNAME}"
}


function SetupLicenceNoticeCheckForGivenRepository()
{
    PrintTrace "Entering ${FUNCNAME}"
    CheckNumberOfArguments 0 $#
    CheckIfVariablesAreSet repositoryTopLevelPath licenseNoticeFile
    local licenceNoticeFileDestination
    licenceNoticeFileDestination="${repositoryTopLevelPath}/.git/hooks/LicenseNotice.txt"
    __static__SetupFileOrFolderCopyOrSymlink "$(realpath ${licenseNoticeFile})" "${licenceNoticeFileDestination}"
    if [[ $? -ne 0 ]]; then
        PrintFatalAndExit "Error occurred setting up license notice check! Setup aborted."
    fi
    PrintTrace "Exiting ${FUNCNAME}"
}

function __static__SetupFileOrFolderCopyOrSymlink()
{
    PrintTrace "Entering ${FUNCNAME}"
    CheckNumberOfArguments 2 $#
    local sourceGlobalPath destinationGlobalPath objectType commandOptions
    sourceGlobalPath="$1"
    destinationGlobalPath="$2"
    if [[ -d "${sourceGlobalPath}" ]]; then
        objectType='Folder'
        commandOptions='-r'
    else
        objectType='File'
        commandOptions=''
    fi
    if [[ ${forceCopyOrSymlink} = 'TRUE' ]]; then
        PrintDebug "rm -f ${commandOptions} \"${destinationGlobalPath}\""
        rm -f ${commandOptions} "${destinationGlobalPath}"
    fi
    #Symlink clang-format options file to top directory so that it is found by clang-format
    if [[ -e "${destinationGlobalPath}" ]]; then
        if [[ -L "${destinationGlobalPath}" && "$(realpath ${destinationGlobalPath})" = "${sourceGlobalPath}" ]]; then
            if [[ ${copyFilesToRepository} = 'TRUE' ]]; then               
                PrintWarning \
                    "${objectType} \"${destinationGlobalPath}\" already correctly symlinked!" \
                    "Run the script again with the \"--force\" option if you want to overwrite the ${objectType,}."
            elif [[ ${symlinkFilesToRepository} = 'TRUE' ]]; then
                PrintInfo "${objectType} \"${destinationGlobalPath}\" already correctly symlinked!"
            fi
        else
            if [[ ${copyFilesToRepository} = 'TRUE' ]]; then
                PrintWarning \
                    "${objectType} \"${destinationGlobalPath}\" already existing, copy skipped!" \
                    "Run the script again with the \"--force\" option if you want to overwrite the ${objectType,}."
            elif [[ ${symlinkFilesToRepository} = 'TRUE' ]]; then
                PrintWarning \
                    "${objectType} \"${destinationGlobalPath}\" already existing, symlink not created!" \
                    "Run the script again with the \"--force\" option if you want to overwrite the link."
            fi
        fi
    else
        if [[ ${copyFilesToRepository} = 'TRUE' ]]; then
            cp ${commandOptions} "${sourceGlobalPath}" "${destinationGlobalPath}"
            if [[ ${objectType} = 'File' && -f "${destinationGlobalPath}" ]] || [[ ${objectType} = 'Folder' && -d "${destinationGlobalPath}" ]]; then
                PrintInfo "\"$(basename "${sourceGlobalPath}")\" ${objectType,} copied. ${objectType} \"${destinationGlobalPath}\" successfully created!"
            else
                PrintError "Copy of the \"$(basename "${sourceGlobalPath}")\" ${objectType,} failed. Unable to create \"${destinationGlobalPath}\" ${objectType,}!"
                return 1
            fi            
        elif [[ ${symlinkFilesToRepository} = 'TRUE' ]]; then
            PrintDebug "Symlinking ${objectType,} with clang-format options: \e[1mln -s -f \"${sourceGlobalPath}\" \"${destinationGlobalPath}\"\e[22m"
            ln -s -f "${sourceGlobalPath}" "${destinationGlobalPath}"
            if [[  -e "${destinationGlobalPath}" ]]; then
                PrintInfo "Symbolic link for ${objectType,} \"${destinationGlobalPath}\" successfully created!"
            else
                PrintError "Symbolic link for ${objectType,} \"${destinationGlobalPath}\" failed to be successfully created!"
                return 1
            fi
        fi
    fi
    PrintTrace "Exiting ${FUNCNAME}"
}
