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
function SetAuthorAndCommiterNamesAndEmailAdresses()
{
    CheckNumberOfArguments 0 $#
    if [ "$GIT_AUTHOR_NAME" != '' ]; then
        readonly userName="$GIT_AUTHOR_NAME"
    else
        readonly userName="$(git config --get user.name)"
    fi
    if [ "$GIT_AUTHOR_EMAIL" != '' ]; then
        readonly userEmail="$GIT_AUTHOR_EMAIL"
    else
        readonly userEmail="$(git config --get user.email)"
    fi
    if [ "$GIT_COMMITTER_NAME" != '' ]; then
        readonly committerName="$GIT_COMMITTER_NAME"
    else
        readonly committerName="$(git config --get user.name)"
    fi
    if [ "$GIT_COMMITTER_EMAIL" != '' ]; then
        readonly committerEmail="$GIT_COMMITTER_EMAIL"
    else
        readonly committerEmail="$(git config --get user.email)"
    fi
}

function IsAuthorOrCommitterInformationEmpty()
{
    CheckNumberOfArguments 0 $#
    if [[ "${userName}" = '' || "${userEmail}" = '' || "${committerName}" = '' || "${committerEmail}" = '' ]]; then
        return 0
    else
        return 1
    fi
}

function IsAuthorNameNotAllowed()
{
    CheckNumberOfArguments 0 $#
    CheckIfVariablesAreSet userName
    if [[ ${userName} =~ ^[A-Z][a-z]+(\ [A-Z][a-z]+)+$ ]]; then
        return 1
    else
        return 0
    fi
}

function IsAuthorEmailNotAllowed()
{
    CheckNumberOfArguments 0 $#
    CheckIfVariablesAreSet userEmail
    if [[ ${userEmail} =~ ^[^@]+@[^@]+$ ]]; then
        return 1
    else
        return 0
    fi
}

function IsCommitterNameNotAllowed()
{
    CheckNumberOfArguments 0 $#
    CheckIfVariablesAreSet userName
    if [[ ${committerName} =~ ^[A-Z][a-z]+(\ [A-Z][a-z]+)+$ ]]; then
        return 1
    else
        return 0
    fi
}

function IsCommitterEmailNotAllowed()
{
    CheckNumberOfArguments 0 $#
    CheckIfVariablesAreSet committerEmail
    if [[ ${committerEmail} =~ ^[^@]+@[^@]+$ ]]; then
        return 1
    else
        return 0
    fi
}

function IsAuthorOrCommitterInformationNew()
{
    CheckNumberOfArguments 0 $#
    CheckIfVariablesAreSet userName userEmail committerName committerEmail
    local existingUserOrCommitterNamesAndEmails userOrCommitterNameAndEmail
    readarray -t existingUserOrCommitterNamesAndEmails <<< "$(cat <(git log --all --format='%an %ae') <(git log --all --format='%cn %ce') | sort -u)"
    for userOrCommitterNameAndEmail in "${existingUserOrCommitterNamesAndEmails[@]}"; do
        if [[ "${userOrCommitterNameAndEmail}" = "${userName} ${userEmail}" || "${userOrCommitterNameAndEmail}" = "${committerName} ${committerEmail}" ]]; then
            return 1
        fi
    done
    return 0
}

function SetRepositorySHA()
{
    if [ "$(git rev-parse --verify HEAD 2>/dev/null)" != '' ]; then
        readonly againstSHAToCompareWidth=HEAD
    else
        # Initial commit: diff against an empty tree object
        readonly againstSHAToCompareWidth=$(git hash-object -t tree /dev/null) # it gives 4b825dc642cb6eb9a060e54bf8d69288fbee4904
    fi
}

function IsAnyNonAsciiFilenameBeingAddedToRepositoryAlthoughNotDesired()
{
    CheckNumberOfArguments 0 $#
    CheckIfVariablesAreSet againstSHAToCompareWidth
    local allowNonAscii
    allowNonAscii=$(git config --bool hooks.allowNnAscii) # If you want to allow non-ASCII filenames set this variable to true.
    # Cross platform projects tend to avoid non-ASCII filenames; prevent
    # them from being added to the repository. We exploit the fact that the
    # printable range starts at the space character and ends with tilde.
    #
    # NOTE: the use of brackets around a tr range is ok here, (it's
    #       even required, for portability to Solaris 10's /usr/bin/tr), since
    #       the square bracket bytes happen to fall in the designated range.
    if [[ "${allowNonAscii}" != 'true' && $(git diff --cached --name-only --diff-filter=A -z ${againstSHAToCompareWidth} | LC_ALL=C tr -d '[ -~]\0' | wc -c) -ne 0 ]]; then
        return 0
    else
        return 1
    fi
}

function DoAddedFilenamesContainSpaces()
{
    CheckNumberOfArguments 0 $#
    CheckIfVariablesAreSet againstSHAToCompareWidth
    if [[ $(git diff --cached --name-only --diff-filter=A -z ${againstSHAToCompareWidth} | grep -c '[ ]') -ne 0 ]]; then
        return 0
    else
        return 1
    fi
}

function DoAddedFilenamesContainEndlines()
{
    CheckNumberOfArguments 0 $#
    CheckIfVariablesAreSet againstSHAToCompareWidth
    local listOfFilesToBeChecked file
    #Fill array using null separator since endlines might be part of file
    IFS='' readarray -d '' listOfFilesToBeChecked < <(git diff --cached --name-only --diff-filter=A -z ${againstSHAToCompareWidth})
    for file in "${listOfFilesToBeChecked[@]}"; do
        if [[ "${file}" =~ $'\n' ]]; then
            return 0
        fi
    done
    return 1
}

function GetListOfStagedFilesEndingWith()
{
    CheckIfVariablesAreSet againstSHAToCompareWidth
    local extensionRegex
    extensionRegex="$(printf "%s|" "$@")"
    extensionRegex="[.](${extensionRegex%?})\$"
    #The following line assumes no endline in filenames
    printf '%s\n' "$(git diff-index --cached --name-only ${againstSHAToCompareWidth} --diff-filter=ACMR | grep -E "${extensionRegex}")"
}

function IsClangFormatNotAvailable()
{
    if ! builtin type -P clang-format >>/dev/null; then
        return 0
    else
        return 1
    fi
}

function IsClangFormatStyleFileNotAvailable()
{
    CheckNumberOfArguments 0 $#
    CheckIfVariablesAreSet repositoryTopLevelPath
    if [[ -f "${repositoryTopLevelPath}/_clang-format" ]]; then
        return 1
    else
        return 0
    fi
}

function DoesCodeStyleCheckFailOnAnyStagedFileEndingWith()
{
    CheckIfVariablesAreSet listOfStagedFiles
    local extensionRegex file newFile
    extensionRegex="$(printf "%s|" "$@")"
    extensionRegex="[.](${extensionRegex%?})\$"
    PrintInfo "\nChecking style of code... \e[s"
    for file in "${listOfStagedFiles[@]}"; do
        if [[ ! ${file} =~ ${extensionRegex} ]]; then
            continue
        fi
        # The file in the staging area could differ from the ${file} in case
        # it was only partially staged. It would be possible, in principle, to
        # obtain the file from the index using
        #     indexFile=$(git checkout-index --temp ${file} | cut -f 1)
        #
        # Actually, if we use a copy of ${file} with a different name
        # in order to check if the code style rules are respected,
        # clang-format could reorder differently the #include, since
        # it might not identify that the ${file} is a .cpp associated
        # with a .hpp (in this case the .hpp should be included as first).
        # Therefore, we always check the ${file} as if it was fully staged
        # and if there are style violation in the not staged modifications
        # we do not care and we abort the commit any way (just give some
        # advice to the user).
        newFile="$(mktemp /tmp/$(basename ${file}).XXXXXX)" || exit 1
        clang-format "${clangFormatParameters}" "${file}" > "${newFile}" 2>> /dev/null
        if ! cmp -s "${file}" "${newFile}"; then # <- if they differ
            filesWithCodeStyleErrors+=( "${file}" )
        fi
        rm "${newFile}"
    done
    if [ ${#filesWithCodeStyleErrors[@]} -eq 0 ]; then
        PrintInfo -l -- "\e[udone!\n"
        return 1
    else
        return 0
    fi
}

function GetListOfStagedFiles()
{
    CheckNumberOfArguments 0 $#
    CheckIfVariablesAreSet againstSHAToCompareWidth
    #The following line assumes no endline in filenames
    printf '%s\n' "$(git diff-index --name-only --cached --diff-filter=AM ${againstSHAToCompareWidth} | sort | uniq)"
}

function GetListOfFullyStagedFiles()
{
    CheckNumberOfArguments 0 $#
    CheckIfVariablesAreSet stagedFiles
    local partiallyStagedFiles stagedAndPartiallyStagedFiles fullyStagedFiles
    # Adapted from https://gist.github.com/larsxschneider/3957621
    partiallyStagedFiles=( $(git status --porcelain --untracked-files=no | # Find all staged files
                                 egrep -i '^(A|M)M '                     | # Filter only partially staged files
                                 sed -e 's/^[AM]M[[:space:]]*//'         | # Remove leading git info
                                 sort | uniq) )                            # Remove duplicates
    stagedAndPartiallyStagedFiles=( "${stagedFiles[@]}" "${partiallyStagedFiles[@]}" )
    # Remove all files that are staged AND partially staged -> we get only the fully staged files
    fullyStagedFiles=( $(tr ' ' '\n' <<< "${stagedAndPartiallyStagedFiles[@]}" | sort | uniq -u) )
    #The following line assumes no endline in filenames
    printf '%s\n' "${fullyStagedFiles[@]}"
}

function FixWhitespaceOnFullyStagedFilesIfNeeded()
{
    CheckNumberOfArguments 0 $#
    if [ ${#fullyStagedFiles[@]} -ne 0 ]; then
        local file
        PrintInfo '\nFixing trailing whitespaces and newline at EOF in fully staged files:'
        for file in "${fullyStagedFiles[@]}"; do
            PrintWarning -l -- "   - ${file}"
            # Strip trailing whitespace
            sed -i 's/[[:space:]]*$//' "$file"
            # Add newline to the end of the file
            sed -i '$a\' "$file" # 'a\' appends the following text, which is nothing, in this case!
            # The code "$a\" just says "match the last line of the file, and add nothing to it."
            # But, implicitly, sed adds the newline to every line it processes if it is not already there.
            # Remove empty (w/o spaces) lines at the end of the file (http://sed.sourceforge.net/sed1line.txt)
            sed -i -e :a -e '/^\n*$/{$d;N;};/\n$/ba' "$file"
            # Alternative in awk, but it needs a temporary file
            # awk '/^$/{emptyLines=emptyLines"\n"; next} {printf "%s", emptyLines; emptyLines=""; print}'
            # Stage all changes
            git add "${file}"
        done
    fi
}

function DoesLicenseNoticeCheckFailOfStagedFilesEndingWith()
{
    CheckIfVariablesAreSet listOfStagedFiles userName licenseNoticeFile
    local extensionRegex numberOfExpectedTextLines file returnCode
    extensionRegex="$(printf "%s|" "$@")"
    extensionRegex="[.](${extensionRegex%?})\$"
    numberOfExpectedTextLines=$(sed '/^$/d' "${licenseNoticeFile}" | wc -l)
    returnCode=0
    for file in "${stagedFiles[@]}"; do
        if [[ ! ${file} =~ ${extensionRegex} ]]; then
            continue
        fi
        # Note that here the "| sort | uniq" avoids counting multiple times lines of the
        # licenseNoticeFile which could be by accident repeated in third party code
        numberOfMatchingLines=$(grep -o -f "${licenseNoticeFile}" "${file}" | sort | uniq | wc -l)
        if [[ ${numberOfMatchingLines} -ne ${numberOfExpectedTextLines} ]]; then
            filesWithWrongOrMissingLicenseNotice+=( "${file}" )
            returnCode=1
        fi
    done
    return ${returnCode}
}

function DoesCopyrightStatementCheckFailOfStagedFilesEndingWith()
{
    CheckIfVariablesAreSet listOfStagedFiles userName licenseNoticeFile
    local extensionRegex expectedCopyright file returnCode
    extensionRegex="$(printf "%s|" "$@")"
    extensionRegex="[.](${extensionRegex%?})\$"
    expectedCopyright='Copyright \(c\) ([2][0-9]{3}[,-]?[ ]?)*'"$(date +%Y) ${userName}"
    returnCode=0
    PrintInfo '\nChecking copyright statement of staged files... \e[s'
    for file in "${stagedFiles[@]}"; do
        if [[ ! ${file} =~ ${extensionRegex} ]]; then
            continue
        fi
        if [[ $(grep -cE "${expectedCopyright}" "${file}") -eq 0 ]]; then
            filesWithIncompleteCopyright+=( "${file}" )
            returnCode=1
        fi
    done
    return ${returnCode}
}

function AreThereFilesWithWhitespaceErrors()
{
    CheckNumberOfArguments 0 $#
    CheckIfVariablesAreSet againstSHAToCompareWidth
    if ! git diff-index --check --cached ${againstSHAToCompareWidth} >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

function IsActualBranchAnyOfTheFollowing()
{
    CheckIfVariablesAreSet actualBranch
    local branchRegex
    branchRegex="$(printf "%s|" "$@")"
    branchRegex="^(${extensionRegex%?})\$"
    if [[ ${actualBranch} =~ ${branchRegex} ]]; then
        return 0
    else
        return 1
    fi
}



#------------------------------------------------------------------------------------------------------------------

function GiveAdviceAboutUserNameAndEmail()
{
    CheckNumberOfArguments 0 $#
    PrintWarning -l -- \
        'Use the commands' \
        '   \e[1mgit config --global user.name "Your Name"' \
        '   git config --global user.email "you@yourdomain.com"\e[22m' \
        'to introduce yourself to Git before committing.\n' \
        'Omit the "--global" option to set your infortmation only in the local repository.' 
}

function GiveAdviceAboutUserNameFormat()
{
    CheckNumberOfArguments 0 $#
    PrintWarning -l -- \
        'Please, configure your user.name using the command' \
        '   \e[1mgit config --global user.name "Your Name"\e[22m' \
        'where your name has to be formed by at least two words starting' \
        'with capital letter and separated by one space.\n' \
        'Omit the "--global" option to set your infortmation only in the local repository.\n'
}

function GiveAdviceAboutUserEmailFormat()
{
    CheckNumberOfArguments 0 $#
    PrintWarning -l -- \
        'Please, configure your user.email using the command' \
        '   \e[1mgit config --global user.email "you@yourdomain.com"\e[22m' \
        'where your email has to be in a valid format as shown here above.\n' \
        'Omit the "--global" option to set your infortmation only in the local repository.\n'
}

function GiveAdviceAboutCommitterNameFormat()
{
    CheckNumberOfArguments 0 $#
    PrintWarning -l -- \
        'The committer name must be composed by at least two words starting' \
        'with capital letter and separated by one space.\n'
}

function GiveAdviceAboutCommitterEmailFormat()
{
    CheckNumberOfArguments 0 $#
    PrintWarning -l -- \
        'The committer email must be a valid email address, for example "xxx@yourdomain.com".\n'
}

function GiveAdviceAboutNonAsciiCharacters()
{
    CheckNumberOfArguments 0 $#
    PrintWarning -l -- \
        'This can cause problems if you want to work with people on other platforms.' \
        'To be portable it is advisable to rename the file.' \
        'If you know what you are doing you can disable this check using:' \
        '   \e[1mgit config hooks.allownonascii true\e[22m\n'
}

function GiveAdviceAboutWhitespaceError()
{
    CheckNumberOfArguments 0 $#
    CheckIfVariablesAreSet againstSHAToCompareWidth
    PrintWarning -l -- \
        'Use the command' \
        "   \e[1mgit diff-index --check --cached ${againstSHAToCompareWidth}\e[22m\n" \
        'to have a look to the whitespace violation on staged files.\n'
}

function GiveAdviceAboutClangFormat()
{
    CheckNumberOfArguments 0 $#
    PrintWarning -l -- \
        'Please install it before continuing' \
        '  http://releases.llvm.org/\n' \
        'Download the entire pre-built LLVM toolchain and extract the' \
        'clang-format binary. Put it where you wish but make sure its' \
        'location can be automatically found (e.g. setting the PATH variable).\n'
}

function GiveAdviceAboutClangFormatStyleFile()
{
    CheckNumberOfArguments 0 $#
    PrintWarning -l -- \
        'The style file for clang-format should be automatically set up' \
        'together with the hooks, if needed. Apparently something went' \
        'wrong or you might have by accident moved/renamed/deleted it.' \
        'Try to run the hooks setup again and, if this error persists,' \
        'feel free to contact the GitHooks developers.\n'
}

function GiveAdviceAboutMissingLicenseNotice()
{
    CheckNumberOfArguments 0 $#
    CheckIfVariablesAreSet licenseNoticeFile
    PrintWarning -l -- \
        'A file with the expected license notice should be available as' \
        "   ${licenseNoticeFile}" \
        'Please, add one in order to use the automatic hook check.\n'
}

function PrintReportOnFilesWithWrongOrMissingLicenseNotice()
{
    PrintError '\nHere a list of files with wrong or missing license notice:'
    local file
    for file in "$@"; do
        PrintError -l -- "     - ${file}"
    done
    PrintError -l -- ''
}

function PrintReportOnFilesWithMissingCopyright()
{
    PrintError '\nHere a list of modified files with present year and author missing in the copyright statement in the header:'
    local file
    for file in "$@"; do
        PrintError -l -- "     - ${file}"
    done
    PrintError -l -- ''
}

function PrintSuggestionToFixHeader()
{
    CheckNumberOfArguments 0 $#
    CheckIfVariablesAreSet licenseNoticeFile
    PrintWarning -l -- \
        'The correct license header can be found in the' \
        "   \e[1m${licenseNoticeFile}\e[22m" \
        'file. If only the copyright statement is missing add' \
        "   \e[1mCopyright (c) [past-years]$(date +%Y) ${userName}\e[22m" \
        'in the header before the license part. The [past-years] part may contain other years and' \
        'you should use a comma separated list, using a \"-\" to concatenate consecutive years.\n' \
        'Have a look to the \e[1mCONTRIBUTING\e[22m file, if available, for more information.\n'
}

function PrintReportOnFilesWithStyleErrors()
{
    CheckNumberOfArguments 0 $#
    CheckIfVariablesAreSet clangFormatParameters
    PrintError 'Here a list of the affected files:'
    local file
    for file in "$@"; do
        PrintError -l -- "     - ${file}"
    done
    PrintWarning -l -- \
        "\nPlease fix before committing. Don't forget to run \"git add\" before trying to commit again." \
        ' If the whole file is to be committed, this should work:\n' \
        '' \
        "   \e[1mclang-format -i ${clangFormatParameters} filename; git add filename; git commit\e[22m" \
        '' \
        'If some of the files above was only partially staged, it could be that the code-style' \
        'violation is not in the staged part. This does not prevent the commit from failing and you' \
        'should any way correctly format your code. Consider moving them back from the staging area' \
        '' \
        '   \e[1mgit reset HEAD filename\e[22m' \
        '' \
        'and running clang-format on them, before partially stage them again.' \
        'If you are sure that the code-style violation is in not in the staged part and you' \
        'do NOT want to fix the style in the whole file, another possibility is to' \
        '' \
        '   \e[1mgit stash; git commit; git stash pop\e[22m' \
        '' \
        '(we cannot forsee all possible scenario => think carefully about what you do  before acting!)'
}
