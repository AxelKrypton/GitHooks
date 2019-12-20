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
forceCopyOrSymlink='FALSE'
setupCodeStyleCheck='FALSE'
repositoryLanguage=''
clangFormatStyleFile="${thisRepositoryTopLevelPath}/_clang-format"
setupLicenseNoticeCheck='FALSE'
licenceNoticeFile=''
extensionsOfFilesWhoseLicenseNoticeShouldBeChecked='.*'
activateCopyrightCheck='FALSE'
extensionsOfFilesWhoseCopyrightShouldBeChecked='.*'
activateWhitespaceFixAndCheck='FALSE'
activateCommitRestrictions='FALSE'

ParseCommandLineOptions "$@"
ValidateCommandLineOptions

# Actual set-up
readonly hookGitFolder="${repositoryTopLevelPath}/.git/hooks"
readonly hooksSourceFolderGlobalpath="${thisRepositoryTopLevelPath}"
readonly fileWithVariablesToSupportHooksExecution="${hookGitFolder}/hooksGlobalVariables.bash"
CreateFileWithVariablesToSupportHooksExecution
SetupHooksForGivenRepository

if [[ ${setupCodeStyleCheck} = 'TRUE' && "${repositoryLanguage}" =~ ^c(pp)?$ ]]; then
    CheckClangFormatAvailability
    SetupClangFormatStyleForGivenRepository
elif [[ "${repositoryLanguage}" != '' ]]; then
    PrintWarning "No code style setup available yet for the selected language."
fi

if [[ ${setupLicenseNoticeCheck} = 'TRUE' ]]; then
    SetupLicenceNoticeCheckForGivenRepository
fi
