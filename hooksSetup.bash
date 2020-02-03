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

# Preliminary setup and source of bash functions
printf "\n"; trap 'printf "\n"' EXIT
readonly thisRepositoryTopLevelPath="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
readonly hookImplementationFolderName='BashImplementation'
readonly auxiliaryBashCodeTopLevelPath="${thisRepositoryTopLevelPath}"
source "${auxiliaryBashCodeTopLevelPath}/${hookImplementationFolderName}/auxiliaryFunctions.bash"
# Global variable for this hook are sourced in the file just sourced!

# Variables to tune setup
repositoryTopLevelPath=''
copyFilesToRepository='FALSE'
symlinkFilesToRepository='FALSE'
removeFilesFromRepository='FALSE'
forceCopyOrSymlink='FALSE'
activateCodeStyleCheck='FALSE'
repositoryLanguage=''
clangFormatStyleFile="${thisRepositoryTopLevelPath}/_clang-format"
activateLicenseNoticeCheck='FALSE'
licenceNoticeFile=''
extensionsOfFilesWhoseLicenseNoticeShouldBeChecked='.*'
activateCopyrightCheck='FALSE'
extensionsOfFilesWhoseCopyrightShouldBeChecked='.*'
activateWhitespaceFixAndCheck='FALSE'
activateBranchRestrictions='FALSE'
activateCommitFormatCheck='FALSE'
commitHeadlineMinimumLength=8
commitHeadlineMaximumLength=60
commitBodyLineMaximumLength=72

ParseCommandLineOptions "$@"
ValidateCommandLineOptions

# Actual set-up
readonly hookGitFolder="${repositoryTopLevelPath}/.git/hooks"
readonly hooksSourceFolderGlobalpath="${thisRepositoryTopLevelPath}"
readonly fileWithVariablesToSupportHooksExecution="${hookGitFolder}/hooksGlobalVariables.bash"
readonly clangFormatStyleFileDestination="${repositoryTopLevelPath}/$(basename "${clangFormatStyleFile}")"
readonly licenceNoticeFileDestination="${repositoryTopLevelPath}/.git/hooks/LicenseNotice.txt"

if [[ ${removeFilesFromRepository} = 'TRUE' ]]; then
   RemoveFilesOrSymlinksFromRepository
else
    CreateFileWithVariablesToSupportHooksExecution
    SetupHooksForGivenRepository

    if [[ ${activateCodeStyleCheck} = 'TRUE' && "${repositoryLanguage}" =~ ^c(pp)?$ ]]; then
        CheckClangFormatAvailability
        SetupClangFormatStyleForGivenRepository
    elif [[ "${repositoryLanguage}" != '' ]]; then
        PrintWarning "No code style setup available yet for the selected language."
    fi

    if [[ ${activateLicenseNoticeCheck} = 'TRUE' ]]; then
        SetupLicenceNoticeCheckForGivenRepository
    fi
fi
