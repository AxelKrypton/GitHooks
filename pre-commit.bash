#!/bin/bash
#
#  Copyright (c) 2019 Alessandro Sciarra <sciarra@itp.uni-frankfurt.de>
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
#  2) Check branch on which the commit is being done
#  3) Prevent non-ASCII characters in filenames
#  4) Make whitespace git check
#  5) Go through fully staged files and
#      - remove trailing spaces at end of lines
#      - add end of line at the end of file
#      - remove empty lines at the end of the file
#  6) Go through staged files and
#      - check copyright statement
#      - check license notice
#      - check code style using clang-format
#
# Called by "git commit" with no arguments. The hook should exit
# with non-zero status after issuing an appropriate message if
# it wants to stop the commit.

#Preliminary setup and source of bash functions
printf "\n"; trap 'printf "\n"' EXIT
readonly hooksFolder="$(dirname "$(readlink -f "${BASH_SOURCE[0]")")"
for auxFile in "${hooksFolder}/BashImplementation/"*.bash; do
    source "${auxFile}" || exit 1
done

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

# Get list of staged files which have to be checked with respect to CODE STYLE
readonly listOfStagedFiles=( $(GetListOfStagedFiles) )
readonly clangFormatParameters="-style=file"
if IsClangFormatNotAvailable; then
    AbortCommit "The program \"clang-format\" was not found!" GiveAdviceAboutClangFormat
fi
filesWithCodeStyleErrors=(); fileExtensionsForCodeStyleCheck=( 'c' 'cpp' 'h' 'hpp' 'cl' )
if DoesCodeStyleCheckFailOnAnyStagedFileEndingWith "${fileExtensionsForCodeStyleCheck[@]}"; then
    AbortCommit "Code style error found!" PrintReportOnFilesWithStyleErrors "${filesWithCodeStyleErrors[@]}"
fi

# Work on tab/spaces in files (only those fully stages, since after modification we have to
# add them and if done on partially staged they would be then fully staged against user willing!
readonly fullyStagedFiles=( $(GetListOfFullyStagedFiles) )
FixWhitespaceOnFullyStagedFilesIfNeeded

# Check header in staged files
readonly licenceNoticeFile="${hooksFolder}/LicenseNotice.txt"
if [[ ! -f "${licenceNoticeFile}" ]]; then
    PrintError "File \"${licenceNoticeFile}\" not found!"
    AbortCommit "Unable to locate the license notice file!"
else
    fileExtensionsForLicenseAndCopyrightCheck=( 'bash' 'c' 'C' 'cl' 'cmake' 'cpp' 'h' 'hpp' 'm' 'nb' 'py' 'sh' 'tex' 'txt' )
    if DoesLicenseAndCopyrightStatementCheckFailOfStagedFilesEndingWith "${fileExtensionsForLicenseAndCopyrightCheck[@]}"; then
        AskYesNoQuestionToUser PrintWarning "Would you like to continue the commit without fixing the header of the files?"
        if UserSaidNo; then
            AbortCommit "Files with wrong or missing header found!" PrintSuggestionToFixHeader
        fi
    fi
fi

#If there are still whitespace errors, print the offending file names and fail
if AreThereFilesWithWhitespaceErrors; then
    AbortCommit "Whitespace errors present in staged files!" GiveAdviceAboutWhitespaceError
fi

#Check branch: direct commit on 'develop' should not be done
readonly actualBranch="$(git rev-parse --abbrev-ref HEAD)"
listOfBranchNamesWhereDirectCommitsAreForbidden=( 'master' 'develop' )
if IsActualBranchAnyOfTheFollowing "${listOfBranchNamesWhereDirectCommitsAreForbidden[@]}"; then
    #PrintWarning \
    #    "You just made a commit on the \"${actualBranch}\" branch." \
    #    "This is considered bad practice." \
    #    "Please undo it if it was not intended!"
    AbortCommit "To directly commit on \"${actualBranch}\" branch is forbidden!" GiveAdviceToResumeCommit
fi
