#!/bin/bash
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
#
# Hook script to check the commit information and staged files.
#
# Check that the code follows a consistent code style and that
# some given rules are respected by what is about to be committed.
#
# LIST OF CHECKS:
#  1) Check if user name and email are set and reasonable
#  2) Prevent non-ASCII, spaces and endline characters in filenames
#  3) Optionally, go through staged files and
#      - check code style using clang-format
#      - check copyright statement
#      - check license notice
#  4) Optionally, go through fully staged files and
#      - remove trailing spaces at end of lines
#      - add end of line at the end of file
#      - remove empty lines at the end of the file
#  5) Optionally, make whitespace git check
#  6) Optionally, check branch on which the commit is being done
#
# Called by "git commit" with no arguments. The hook should exit
# with non-zero status after issuing an appropriate message if
# it wants to stop the commit.
#
#-----------------------------------------------------------------------
# NOTE: Some global variables defined here are used in function
#       and therefore do not be misled and tempted to remove them
#       if their name appears only on their definition line!
#

if git diff --cached --quiet ; then
    exit 0 # If the commit is a pure amend, skip hook. https://stackoverflow.com/a/41986190
fi

# Setup traps and allow exit on error also from subshells -> set -E
printf "\n"
readonly userFatalExitCode=113 # This is the error code variable name used by the Logger
set -E; trap '[[ $? -eq ${userFatalExitCode} ]] && exit ${userFatalExitCode}' ERR # https://unix.stackexchange.com/a/48550
trap '[[ $? -ne 0 ]] && printf "\n" || PrintInfo "Hook $(basename "${BASH_SOURCE[0]}") successfully finished!"' EXIT

# Source of bash functions
readonly repositoryTopLevelPath="$(git rev-parse --show-toplevel)"
readonly auxiliaryBashCodeTopLevelPath="${repositoryTopLevelPath}/$(dirname "${BASH_SOURCE[0]}")"
readonly hookImplementationFolderName='BashImplementation'
source "${auxiliaryBashCodeTopLevelPath}/${hookImplementationFolderName}/auxiliaryFunctions.bash"
# Global variable for this hook are sourced in the file just sourced!


#Check for committer identity as such and check if it exists in history
userName=''; userEmail=''; committerName=''; committerEmail=''
SetAuthorAndCommiterNamesAndEmailAdresses

if IsAuthorOrCommitterInformationEmpty; then
    AbortCommit "User information not configured!" GiveAdviceAboutUserNameAndEmail
fi
if IsAuthorNameNotAllowed; then
    AbortCommit "User name not allowed." GiveAdviceAboutUserNameFormat
fi
if IsAuthorEmailNotAllowed; then
    AbortCommit "User email not allowed." GiveAdviceAboutUserEmailFormat
fi
if IsCommitterNameNotAllowed; then
    AbortCommit "Committer name not allowed." GiveAdviceAboutCommitterNameFormat
fi
if IsCommitterEmailNotAllowed; then
    AbortCommit "Committer email not allowed." GiveAdviceAboutCommitterEmailFormat
fi
if IsAuthorOrCommitterInformationNew; then
    PrintWarning \
        'A new author and/or committer name(s) and/or email(s) has(have) been found.' \
        "              Author:   \e[1m${userName}  <${userEmail}>\e[22m" \
        "           Committer:   \e[1m${committerName}  <${committerEmail}>\e[22m"
    AskYesNoQuestionToUser PrintWarning "Would you like to continue the commit creating, then, a new author or committer?"
    if UserSaidNo; then
        AbortCommit "Author and/or committer name(s) and/or email(s) to be checked!"
    fi
fi

# Check added filenames
againstSHAToCompareWidth=''; SetRepositorySHA
if IsAnyNonAsciiFilenameBeingAddedToRepositoryAlthoughNotDesired; then
    AbortCommit 'Attempt to add a non-ASCII file name.' GiveAdviceAboutNonASCIICharacters
fi
if DoAddedFilenamesContainSpaces; then
    AbortCommit "Spaces are not allowed in filenames!"
fi
if DoAddedFilenamesContainEndlines; then
    AbortCommit "Endlines are not allowed in filenames!"
fi
# NOTE: From this point on assume no spaces and no newlines in filenames!

# Lists of files needed in different parts of following code
# NOTE: readonly must be done after the assignment to prevent it
#       from forbid the call of the trap ERR in case the command
#       in $() exits. If done together, bash would not execute the trap
#       on ERR because "the failed command is any command in a pipeline
#       but the last" (in this case readonly would not fail).
listOfStagedFiles=( $(GetListOfStagedFiles) ); readonly listOfStagedFiles
listOfFullyStagedFiles=( $(GetListOfFullyStagedFiles) ); readonly listOfFullyStagedFiles

if [[ ${doCodeStyleCheckWithClangFormat} = 'TRUE' ]]; then
    if [ ${#listOfStagedFiles[@]} -ne 0 ]; then
        readonly clangFormatParameters="-style=file"
        if IsClangFormatNotAvailable; then
            AbortCommit "The program \"clang-format\" was not found!" GiveAdviceAboutClangFormat
        fi
        if IsClangFormatStyleFileNotAvailable; then
            AbortCommit "The style file \"_clang-format\" was not found at the top-level of the repository!" GiveAdviceAboutClangFormatStyleFile
        fi
        filesWithCodeStyleErrors=(); fileExtensionsForCodeStyleCheck=( "${extensionsOfFilesWhoseCodeStyleShouldBeCheckedWithClangFormat[@]}" )
        if DoesCodeStyleCheckFailOnAnyStagedFileEndingWith "${fileExtensionsForCodeStyleCheck[@]}"; then
            AbortCommit "Code style error found!" PrintReportOnFilesWithStyleErrors "${filesWithCodeStyleErrors[@]}"
        fi
    fi
fi


if [[ ${doLicenseNoticeCheck} = 'TRUE' ]]; then
    if [ ${#listOfStagedFiles[@]} -ne 0 ]; then
        readonly licenseNoticeFile="${repositoryTopLevelPath}/.git/hooks/LicenseNotice.txt"
        if [[ ! -f "${licenseNoticeFile}" ]]; then
            PrintError "File \"${licenseNoticeFile}\" not found!"
            AbortCommit "Unable to locate the license notice file!"
        else
            fileExtensionsForLicenseAndCopyrightCheck=( "${extensionsOfFilesWhoseLicenseNoticeShouldBeChecked[@]}" )
            filesWithWrongOrMissingLicenseNotice=()
            PrintInfo -l -- '\n\e[2A' # https://unix.stackexchange.com/a/565602/370049
            PrintInfo 'Checking license notice of staged files... \e[s'
            if DoesLicenseNoticeCheckFailOfStagedFilesEndingWith "${fileExtensionsForLicenseAndCopyrightCheck[@]}"; then
                PrintReportOnFilesWithWrongOrMissingLicenseNotice "${filesWithWrongOrMissingLicenseNotice[@]}"
                AskYesNoQuestionToUser PrintWarning "Would you like to continue the commit without fixing the license notice of the file(s)?"
                if UserSaidNo; then
                    AbortCommit "Files with wrong or missing license notice found!" PrintSuggestionToFixHeader
                fi
            else
                PrintInfo -l -- "\e[udone!\n"
            fi
        fi
    fi
fi


if [[ ${doCopyrightStatementCheck} = 'TRUE' ]]; then
    if [ ${#listOfStagedFiles[@]} -ne 0 ]; then
        fileExtensionsForLicenseAndCopyrightCheck=( "${extensionsOfFilesWhoseCopyrightShouldBeChecked[@]}" )
        filesWithIncompleteCopyright=()
        PrintInfo -l -- '\n\e[2A' # https://unix.stackexchange.com/a/565602/370049
        PrintInfo 'Checking copyright statement of staged files... \e[s'
        if DoesCopyrightStatementCheckFailOfStagedFilesEndingWith "${fileExtensionsForLicenseAndCopyrightCheck[@]}"; then
            PrintReportOnFilesWithMissingCopyright "${filesWithIncompleteCopyright[@]}"
            AskYesNoQuestionToUser PrintWarning "Would you like to continue the commit without fixing the copyright statement of the file(s)?"
            if UserSaidNo; then
                AbortCommit "Files with wrong or missing copyright statement found!" PrintSuggestionToFixHeader
            fi
        else
            PrintInfo -l -- "\e[udone!\n"
        fi
    fi
fi

if [[ ${doWhitespaceFixAndCheck} = 'TRUE' ]]; then
    if [ ${#listOfFullyStagedFiles[@]} -ne 0 ]; then
        # Work on tab/spaces in files (only those fully stages, since after modification we have to
        # add them and if done on partially staged they would be then fully staged against user willing!
        FixWhitespaceOnFullyStagedFilesIfNeeded
        #If there are still whitespace errors, print the offending file names and fail
        if AreThereFilesWithWhitespaceErrors; then
            AbortCommit "Whitespace errors present in staged files!" GiveAdviceAboutWhitespaceError
        fi
    fi
fi

actualBranch=''; SetRepositoryLocalBranchName
if [[ $? -ne 0 ]]; then
    PrintWarning "Unable to retrieve local branch name, not checking if committing on it is allowed."
else
    listOfBranchNamesWhereDirectCommitsAreForbidden=( 'master' 'develop' )
    if IsActualBranchAnyOfTheFollowing "${listOfBranchNamesWhereDirectCommitsAreForbidden[@]}"; then
        if [[ ${restrictCommitsOnSomeBranches} = 'TRUE' ]]; then
            AbortCommit "To directly commit on \"${actualBranch}\" branch is forbidden!"
        else
            PrintWarning \
                "You just made a commit on the \"${actualBranch}\" branch." \
                "This is considered bad practice." \
                "Please undo it if it was not intended!\n"
        fi
    fi
fi
