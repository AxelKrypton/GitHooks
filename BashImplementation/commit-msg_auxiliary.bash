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
function GiveAdviceToResumeCommit()
{
    CheckNumberOfArguments 0 $#
    CheckIfVariablesAreSet commitMessageFile
    PrintWarning -l -- \
        'To resume editing your commit message, run the command:' \
        "   git commit -e -F ${commitMessageFile}\n" #Variable commitMessageFile from invoking script
}

function IsCommitMessageEmpty()
{
    CheckNumberOfArguments 1 $#
    if [[ -s "$1" ]]; then
        return 1
    else
        return 0
    fi
}

function RemoveTrailingSpacesAtBeginOfFirstThreeLines()
{
    CheckNumberOfArguments 1 $#
    sed -i '1,3{s/^[[:blank:]]*//}' "$1"
}

function RemoveTrailingSpacesAtEndOfEachLine()
{
    CheckNumberOfArguments 1 $#
    sed -i 's/[[:blank:]]*$//g' "$1"
}

function AddEndOfLineAtEndOfFileIfMissing()
{
    CheckNumberOfArguments 1 $#
    sed -i '$a\' "$1"
}

function CapitalizeFirstLetterFirstLine()
{
    CheckNumberOfArguments 1 $#
    sed -i '1s/^\(.\)/\U\1/' "$1"
}

function RemovePointAtTheEndFirstLine()
{
    CheckNumberOfArguments 1 $#
    sed -i '1s/[:;,.!?]\+$//g' "$1"
}

function IsFirstLineNotStartingWithLetter()
{
    #Assume no trailing spaces, since removed
    CheckNumberOfArguments 1 $#
    if [[ $(head -n 1 "$1" | grep -c '^[[:alpha:]]') -gt 0 ]]; then
        return 1
    else
        return 0
    fi
}

function IsFirstLineShorterThan()
{
    CheckNumberOfArguments 2 $#
    if [[ $(head -n 1 "$2" | grep -c "^.\{$1\}") -gt 0 ]]; then
        return 1
    else
        return 0
    fi
}

function IsFirstLineLongerThan()
{
    CheckNumberOfArguments 2 $#
    if [[ $(head -n 1 "$2" | grep -c "^..\{$1\}") -gt 0 ]]; then
        return 0
    else
        return 1
    fi
}

function IsSecondLineNotEmpty()
{
    CheckNumberOfArguments 1 $#
    if [[ $(wc -l < "$1") -lt 2 ]]; then
        return 1 #Needed otherwise head and tail below match first line
    fi
    if [[ $(head -n 2 "$1" | tail -1 | grep -c '^[[:blank:]]*$') -gt 0 ]]; then
        return 1
    else
        return 0
    fi
}

function IsAnyOfTheLinesAfterTheSecondLongerThan()
{
    CheckNumberOfArguments 2 $#
    if [[ $(tail -n +2 "$2" | grep -c "^..\{$1\}") -gt 0 ]]; then
        return 0
    else
        return 1
    fi
}
