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
# Hook script to check the commit message.
#
# ENFORCED POLICY:
#  1) The first line of the commit must be at maximum 60 chars.
#     This is the hard limit for GitHub at which a commit message is hidden.
#     See https://chris.beams.io/posts/git-commit/ for more infortmation.
#  2) The first line of the commit must have at least 8 chars.
#  3) The first line must begin with a character
#  4) A small letter at the beginning of the first line is capitalised
#  5) Any character among ".?!" at the end of the first line is removed
#     in a repetitive way (e.g. "commit..!!!" -> "commit")
#  6) The second line must be empty
#  7) Any following line after the second must be 72 chars at maximum
#  8) Trailing spaces at begin and end of the first two lines are removed
#
# Called by "git commit" with one argument, the name of the file
# that has the commit message.  The hook should exit with non-zero
# status after issuing an appropriate message if it wants to stop the
# commit. The hook is allowed to edit the commit message file.

#Preliminary setup and source of bash functions
printf "\n"; trap 'printf "\n"' EXIT
readonly repositoryTopLevelPath="$(git rev-parse --show-toplevel)"
readonly hooksFolder="$(dirname "$(readlink -f "${BASH_SOURCE[0]")")"
for auxFile in "${hooksFolder}/BashImplementation/"*.bash; do
    source "${auxFile}" || exit 1
done

#Abort immediately on empty commit
if IsCommitMessageEmpty "$1"; then
    AbortCommit "Committed aborted due to empty message!"
fi

#Store commit message in a file to allow user to resume and edit commit
readonly commitMessageFile="${repositoryTopLevelPath}/.git/COMMIT_MSG"
RemoveTrailingSpacesAtBeginOfFirstThreeLines "$1"
RemoveTrailingSpacesAtEndOfEachLine "$1"
AddEndOfLineAtEndOfFileIfMissing "$1"
CapitalizeFirstLetterFirstLine "$1"
RemovePointAtTheEndFirstLine "$1"

# It is nicer to store a clean message in case the user has to resume editing after a
# hook failure due to a violation of the rules (storing just the file would lead to
# having the bunch of commented lines in the resumed commit more than once)
# NOTE: quit at "diff" in case of "git commit -v".
sed -n -e '/^#/d' -e '/^diff --git/q' -e 'p;d' "$1" > "${commitMessageFile}"

#Check format
if IsFirstLineNotStartingWithLetter "${commitMessageFile}"; then
    AbortCommit "The first line must start with a letter!" GiveAdviceToResumeCommit
elif IsFirstLineTooShort "${commitMessageFile}"; then
    AbortCommit "The first line of your commit must be at least 8 chars long!" GiveAdviceToResumeCommit
elif IsFirstLineTooLong "${commitMessageFile}"; then
    AbortCommit "The first line of your commit exceeds the 50-char limit!" GiveAdviceToResumeCommit
elif IsSecondLineNotEmpty "${commitMessageFile}"; then
    AbortCommit "The second line of your commit must be empty!" GiveAdviceToResumeCommit
elif IsAnyOfTheLinesAfterTheSecondTooLong "${commitMessageFile}"; then
    AbortCommit "All the lines of your commit after the second must be shorter than 72 chars!" GiveAdviceToResumeCommit
fi

#Remove commit file if not needed
rm -f "${commitMessageFile}" || exit 1
