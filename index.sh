#!/bin/sh

## Simplistic ReaPack index.xml generator
##  v0.1.1 (2018-08-07)
##
## Copyright (C) 2016-2018 Przemyslaw Pawelczyk <przemoc@gmail.com>
##
## This script is licensed under the terms of the MIT license.
## https://opensource.org/licenses/MIT


cd "${0%/*}"

if [ -r .reapack-index.conf ]; then
	while read -r LINE; do
		LINE=$(echo "$LINE" | sed 's,^[ \t]*,,;s,[ \t]*$,,')
		if    [ "$LINE" != "${LINE#-n}" ] \
		   || [ "$LINE" != "${LINE#--name}" ]
		then
			name=$(echo "$LINE" | sed 's,^[^ \t]*[ \t]*,,')
		fi
		if    [ "$LINE" != "${LINE#-U}" ] \
		   || [ "$LINE" != "${LINE#--url-template}" ]
		then
			url_template=$(echo "$LINE" | sed 's,^[^ \t]*[ \t]*,,')
		fi
	done <.reapack-index.conf
fi

if [ -r index.conf ]; then
	. ./index.conf
fi

STATUS=$(git status --porcelain | sed -r '/index\.(conf|sh|xml)$/d')

if [ -n "$STATUS" ]; then
	echo "$0: You have uncommited changes in working tree:" >&2
	echo "$STATUS" | sed 's,^,'"$0"': ,' >&2
fi

INDENT=0
beg()    { INDENT=$((INDENT+1)); }
end()    { INDENT=$((INDENT-1)); }
iprint() { FMT=$1; shift; printf "%*s$FMT\n" $((INDENT*2)) "" "$@"; }
catdirs(){ find . -mindepth 1 -type d \( -name '.*' -prune -o -print \) \
           | LC_ALL=C sort; }
files()  { find -maxdepth 1 -type f | LC_ALL=C sort; }

(

echo '<?xml version="1.0" encoding="utf-8"?>'

COCKOSFORUM="http://forum.cockos.com/"
REAPACK_IVER=1
HEADCOMMIT=$(git rev-parse HEAD)
iprint '<index version="%s" name="%s" commit="%s">' \
       "$REAPACK_IVER" "$name" "$HEADCOMMIT"
beg

iprint '<metadata>'
beg

if [ -n "$REPO_COCKOSFORUM_TID" ]; then
	iprint '<link rel="%s" href="%s">%s</link>' \
	       website \
	       "${COCKOSFORUM}showthread.php?t=$REPO_COCKOSFORUM_TID" \
	       "Cockos Forum thread"
fi

if [ -n "$REPO_AUTH_COCKOSFORUM_UID" ]; then
	iprint '<link rel="%s" href="%s">%s</link>' \
	       website \
	       "${COCKOSFORUM}member.php?u=$REPO_AUTH_COCKOSFORUM_UID" \
	       "Cockos Forum user"
fi

if [ -n "$REPO_URL" ]; then
	iprint '<link rel="%s" href="%s">%s</link>' \
	       website "$REPO_URL" Repository
fi

end
iprint '</metadata>'

catdirs | while read -r DIR; do
	DIR=${DIR#./}
	iprint '<category name="%s">' "$DIR"
	beg

	( cd "$DIR"; files | while read -r FILE; do
		FILEDESC=$(
		 sed '/^[ \t]*descfmt = "/!d;s,,,;s,".*,,;s, ([^)]*),,g;q' "$FILE" \
		)
		if [ -z "$FILEDESC" ]; then
			FILEDESC=$(
			 sed -r '/^.*(ReaScript|JSFX) Name: [ \t]*/!d;s,,,;q' "$FILE" \
			)
		fi
		FILEVERS=$(sed -r '/^.*[Vv]er(sion)?:?[ \t]*v?/!d;s,,,;s,[ \t].*,,;q' "$FILE")
		FILEVERS=${FILEVERS:-1.0}
		FILEAUTH=$(sed -r '/^.*[Aa]uthor:?[ \t]*/!d;s,,,;q' "$FILE")
		FILEAUTH=${FILEAUTH:-$REPO_AUTH}
		FILETIME=$(git log -1 --date=iso-strict --pretty=tformat:%ad "$FILE")
		FILECOMM=$(git log -1 --pretty=tformat:%H "$FILE")
		FILE=${FILE#./}
		FILETYPE=
		case "$FILE" in
			*.eel)   FILETYPE=script ;;
			*.jsfx)  FILETYPE=effect ;;
			*.lua)   FILETYPE=script ;;
			*.py)    FILETYPE=script ;;
			*.theme) FILETYPE=theme  ;;
			*) continue ;;
		esac
		# ReaPack-index half-compatibility
		commit=$FILECOMM
		path="$DIR/$FILE"
		version=$FILEVERS
		eval FILEURL="\"$url_template\""
		#
		FILEURL=$(echo "$FILEURL" | sed 's, ,%20,g')
		if [ -z "$FILEDESC" ]; then
			FILEDESC=$(
			 echo "$FILE" | sed -r 's,^([^ ]* - |[^_]*_),,;s,\.[^.]*$,,' \
			)
		fi
		iprint '<reapack name="%s" desc="%s" type="%s">' \
		       "$FILE" "$FILEDESC" "$FILETYPE"
		beg

		iprint '<version name="%s" author="%s" time="%s">' \
		       "$FILEVERS" "$FILEAUTH" "$FILETIME"
		beg

		iprint '<source main="true">%s</source>' \
		       "$FILEURL"

		end
		iprint '</version>'

		end
		iprint '</reapack>'
	done )

	end
	iprint '</category>'
done

end
iprint '</index>'

) >index.xml
