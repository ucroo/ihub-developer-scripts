#! /usr/bin/env bash

# Provides a level of safety against accidental deployments of resources to
# customer environments by "deactivating" tokens you are not currently using.
#
# A token is inactive if its file name has a leading "_" character and active otherwise
#
# You can also use this script to create a new token for a custmer. The value of
# the token should be copied from that customer's flow server.

function usage() {
	>&2 echo "usage: $(basename "$0") COMMAND [TOKEN]"
	>&2 echo "Commands (and aliases):"
	>&2 echo "  list              - lists all tokens (ls)"
	>&2 echo "  list-active       - lists active tokens (la)"
	>&2 echo "  list-inactive     - lists inactive tokens (li)"
	>&2 echo "  activate TOKEN    - activates the specified token (a)"
	>&2 echo "  deactivate TOKEN  - deactivates the specified token (d)"
	>&2 echo "  update TOKEN      - updates the specified token (u)"
	>&2 echo "  create TOKEN      - creates a token with the the specified name (c)"
	>&2 echo "  validate TOKEN    - checks the validity of the token"
	exit 1
}

[ "$#" -ne "0" ] || usage

command=$1
creds_dir=$HOME/creds

case $command in

update | u)
	[ "$#" -eq "2" ] || usage
	token=$2
	if [ -e "$creds_dir/${token}.token" ] || [ -e "$creds_dir/_${token}.token" ]; then
		echo -n "Enter token value: "
		read token_value
		if [ -e "$creds_dir/${token}.token" ]; then
			echo $token_value >$creds_dir/$token.token
			echo "Updated active token: $token"
		elif [ -e "$creds_dir/_${token}.token" ]; then
			echo $token_value >$creds_dir/_$token.token
			echo "Updated inactive token: $token"
		fi
	else
		>&2 echo "Token does not exist.  Please create it."
	fi
	;;

activate | a)
	[ "$#" -eq "2" ] || usage
	token=$2
	if [ -e "$creds_dir/_${token}.token" ]; then
		mv $creds_dir/{_,}${token}.token
		echo "Activated token: $token"
	elif [ -e "$creds_dir/${token}.token" ]; then
		echo "Token is already active: $token"
	else
		>&2 echo "Could not find inactive token: $token"
	fi
	;;

create | c)
	[ "$#" -eq "2" ] || usage
	token=$2
	if [ -e "$creds_dir/${token}.token" ]; then
		>&2 echo "Token already exists and is active: $token"
	elif [ -e "$creds_dir/_${token}.token" ]; then
		>&2 echo "Token already exists and is inactive: $token"
	else
		echo -n "Enter token value: "
		read token_value
		echo $token_value >$creds_dir/$token.token
		echo "Created token: $token"
	fi
	;;

deactivate | d)
	[ "$#" -eq "2" ] || usage
	token=$2
	if [ -e "$creds_dir/${token}.token" ]; then
		mv $creds_dir/{,_}${token}.token
		echo "Deactivated token: $token"
	elif [ -e "$creds_dir/_${token}.token" ]; then
		echo "Token is already inactive: $token"
	else
		>&2 echo "Could not find active token: $token"
	fi
	;;

list | ls)
	[ "$#" -eq "1" ] || usage
	(
		cd $creds_dir
		ls -1 *.token | sed -r "s/^_(.*)\.token/\1 (inactive)/" | sed -r "s/^([^_].*)\.token/\1/"
	)
	;;

list-active | la)
	[ "$#" -eq "1" ] || usage
	(
		cd $creds_dir
		ls -1 *.token | grep -v "^_" | sed -r "s/(.*)\.token/\1/"
	)
	;;

list-inactive | li)
	[ "$#" -eq "1" ] || usage
	(
		cd $creds_dir
		ls -1 _*.token | sed -r "s/_(.*)\.token/\1/"
	)
	;;

validate)
	[ "$#" -eq "2" ] || usage
	token=$2
	tokenFile="$creds_dir/${token}.token"
	flowHostFile="$creds_dir/${token}.flow"
	if [ ! -r "${tokenFile}" ]; then
		>&2 echo "token ${token} does not exist at ${tokenFile}."
		exit 1
	fi
	flowToken="$(cat "${tokenFile}")"
	flowHost=
	if [ -r "${flowHostFile}" ]; then
		flowHost="$(cat "${flowHostFile}")"
	else
		flowHost="https://flow.${token}.pathify.com"
	fi

	echo -n "validating token with ${flowHost} ... "

	if ! curl -s --fail -X GET "${flowHost}/healthz" >/dev/null; then
		>&2 echo "server did not respond to health check"
		exit 1
	fi

	if ! curl -s --fail -X GET -H "flow-token: ${flowToken}" \
		"${flowHost}/about" >/dev/null; then
		echo "token is NOT valid"
		exit 1
	fi
  echo "OK"
	;;

*)
	>&2 echo "unknown command: $command"
	usage
	;;
esac
