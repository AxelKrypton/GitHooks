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

#Preliminary setup and source of bash functions
printf "\n"; trap '[[ $? -ne 0 ]] && printf "\n" || PrintInfo "Hook $(basename "${BASH_SOURCE[0]}") successfully finished!"' EXIT
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


if [[ ${doCodeStyleCheckWithClangFormat} = 'TRUE' ]]; then
    # Get list of staged files which have to be checked with respect to CODE STYLE
    readonly listOfStagedFiles=( $(GetListOfStagedFiles) )
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


if [[ ${doLicenseNoticeCheck} = 'TRUE' ]]; then
    readonly licenseNoticeFile="${repositoryTopLevelPath}/.git/hooks/LicenseNotice.txt"
    if [[ ! -f "${licenseNoticeFile}" ]]; then
        PrintError "File \"${licenseNoticeFile}\" not found!"
        AbortCommit "Unable to locate the license notice file!"
    else
        fileExtensionsForLicenseAndCopyrightCheck=( "${extensionsOfFilesWhoseLicenseNoticeShouldBeChecked[@]}" )
        filesWithWrongOrMissingLicenseNotice=()
        PrintInfo '\nChecking license notice of staged files... \e[s'
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


if [[ ${doCopyrightStatementCheck} = 'TRUE' ]]; then
    fileExtensionsForLicenseAndCopyrightCheck=( "${extensionsOfFilesWhoseCopyrightShouldBeChecked[@]}" )
    filesWithIncompleteCopyright=()
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


if [[ ${doWhitespaceFixAndCheck} = 'TRUE' ]]; then
    # Work on tab/spaces in files (only those fully stages, since after modification we have to
    # add them and if done on partially staged they would be then fully staged against user willing!
    readonly fullyStagedFiles=( $(GetListOfFullyStagedFiles) )
    FixWhitespaceOnFullyStagedFilesIfNeeded
    #If there are still whitespace errors, print the offending file names and fail
    if AreThereFilesWithWhitespaceErrors; then
        AbortCommit "Whitespace errors present in staged files!" GiveAdviceAboutWhitespaceError
    fi
fi


#Check branch (get branch from git status since it works also for first commit)
# NOTE: From git version 2.22 -> "git branch --show-current" might be used
readonly actualBranch="$(git status | sed -n '1 s/^On branch \(.*\)/\1/p')"
listOfBranchNamesWhereDirectCommitsAreForbidden=( 'master' 'develop' )
if IsActualBranchAnyOfTheFollowing "${listOfBranchNamesWhereDirectCommitsAreForbidden[@]}"; then
    if [[ ${restrictCommitsOnSomeBranches} = 'TRUE' ]]; then
        AbortCommit "To directly commit on \"${actualBranch}\" branch is forbidden!" GiveAdviceToResumeCommit
    else
        PrintWarning \
            "You just made a commit on the \"${actualBranch}\" branch." \
            "This is considered bad practice." \
            "Please undo it if it was not intended!"
    fi
fi
