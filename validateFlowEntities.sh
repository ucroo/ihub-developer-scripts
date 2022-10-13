#! /usr/bin/env bash
#
# Terminology:
#
# pip  - a package installer for python similar to Node.js' npm.
#
# venv - a Python module that creates a stand-alone Python sandbox to cut down on
#        package collisions. Once you create a sandbox, you can run the activate script
#        in the sandbox to set up your python environment.

quit() {
    >&2 echo "$*"
    exit 1
}

command -v $1 > /dev/null python3 || quit "python3 is required to run this script.  (try: brew install python@3.10)"

[ "$#" -eq "1" ] || quit "usage: validateRecipe.sh RECIPE_DIR"

script_dir=`dirname $0`
venv_dir="${script_dir}/.venv"

if [ ! -d "$venv_dir" ]; then
    >&2 echo "initializing python virtual environment.  This will only be run once."
    python3 -m venv "$venv_dir"
    source "${venv_dir}/bin/activate"
    pip -q install --upgrade pip
    pip -q install -e "${script_dir}/python/flint"
else
    source "${venv_dir}/bin/activate"
fi

python3 "${script_dir}/validateFlowEntities.py" --schema-dir=$HOME/json-schemas --directory="$1/src/main"
