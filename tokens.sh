#! /usr/bin/env bash

# Provides a level of safety against accidental deployments of resources to
# customer environments by "deactivating" tokens you are not currently using.
#
# A token is inactive if its file name has a leading "_" character and active otherwise
#
# You can also use this script to create a new token for a custmer. The value of
# the token should be copied from that customer's flow server.

function usage() {
    >&2 echo "usage: $(basename $0) COMMAND [TOKEN]"
    >&2 echo "Commands:"
    >&2 echo "  list             - lists all tokens"
    >&2 echo "  list-active      - lists active tokens"
    >&2 echo "  list-inactive    - lists inactive tokens"
    >&2 echo "  activate TOKEN   - activates the specified token"
    >&2 echo "  deactivate TOKEN - deactivates the specified token"
    >&2 echo "  create TOKEN     - creates a token with the the specified name"
    exit 1
}

[ "$#" -ne "0" ] || usage

command=$1
creds_dir=$HOME/creds

case $command in

    activate)
        [ "$#" -eq "2" ] || usage
        token=$2
        if [ -e "$creds_dir/_${token}.token" ]; then
            mv $creds_dir/{_,}${token}.token 
            echo "Activated token: $token"
        else
            >&2 echo "Could not find inactive token: $token"
        fi
        ;;

    create)
        [ "$#" -eq "2" ] || usage
        token=$2
        if [ -e "$creds_dir/${token}.token" ] || [ -e "$creds_dir/_${token}.token" ]; then
            >&2 echo "Token already exists: $token"
        else
            echo -n "Enter token value: "
            read token_value
            echo $token_value > $creds_dir/$token.token
            echo "Created token: $token"
        fi
        ;;

    deactivate)
        [ "$#" -eq "2" ] || usage
        token=$2
        if [ -e "$creds_dir/${token}.token" ]; then
            mv $creds_dir/{,_}${token}.token 
            echo "Deactivated token: $token"
        else
            >&2 echo "Could not find active token: $token"
        fi
        ;;

     list)
         [ "$#" -eq "1" ] || usage
         (cd $creds_dir ; ls -1 *.token | sed -r "s/^_(.*)\.token/\1 (inactive)/" | sed -r "s/^([^_].*)\.token/\1/" )
          ;;

     list-active)
         [ "$#" -eq "1" ] || usage
         (cd $creds_dir ; ls -1 *.token | grep -v "^_" | sed -r "s/(.*)\.token/\1/" )
          ;;

     list-inactive)
         [ "$#" -eq "1" ] || usage
         (cd $creds_dir ; ls -1 _*.token | sed -r "s/_(.*)\.token/\1/" )
          ;;

     *)
         >&2 echo "unknown command: $command"
         usage
         ;;
esac
