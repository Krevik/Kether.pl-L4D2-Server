#!/bin/bash
# Copyright (c) 2023 StarterX4 <starterx4@gmail.com>
# This software is licensed under the MIT license

# THIS SOFTWARE IS PROVIDED AS IS, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING
# BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
# DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
version="0.1 (kether edition)"
function gittools() {
    while getopts ac:h"-help"psu:U: flag
    do
        case "${flag}" in
            a) add="git add -Av" >&2 ;;
            c) commit+="git commit -m '${OPTARG}'" >&2 ;;
            p) push="git push" >&2 ;;
            s) sync="git pull origin; git fetch sir" >&2 ;;
            u) update="rm -r OUTDIR/*; rsync -R $(git diff --name-only HEAD~${OPTARG}) OUTDIR" >&2 ;;
            U) upbycomms="rm -r OUTDIR/*; rsync -R $(git diff --name-only '${OPTARG}') OUTDIR" >&2 ;;
            h|-help|*) manual >&2 ;;
        esac
    done

    # Check if any options were passed
    if [ $OPTIND -eq 1 ]
    then
        echo "No options were passed."
        manual;
        exit 1
    fi

    # Execute the commands
    eval "$sync"
    eval "$add"
    eval "$commit"
    eval "$push"
    eval "$update"
    eval "$upbycomms"
}

function manual() {
    echo    "______________________________________________________________"
    echo    "--------------------|| Simple Git Tools ||--------------------"
    echo    "¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯"
    echo    "Usage:              v${version}"
    echo    "  $(basename "$0") [option] [args]"
    echo    "Options:"
    echo    "  -a            Stage all changes"
    echo    "  -c MESSAGE    Commit changes with specified message"
    echo    "  -p            Push changes to remote repository"
    echo    "  -s            Sync local repository with remote repository"
    echo    "  -u NUM        Update OUTDIR with changes from last NUM commits"
    echo    "  -U COMMIT     Update OUTDIR with changes between specified"
    echo    "                COMMITS or HEAD (rsync required)"
    echo    "  -h, --help    Display this help message"
    exit 0
}
# Call the function with the command line arguments
gittools "$@"
