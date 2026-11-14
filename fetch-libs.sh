#!/usr/bin/env bash
# Downloads the libraries listed in .pkgmeta into Libs/, so the addon works when you copy this
# folder straight into your AddOns folder. Release builds don't need this: the packager fetches
# its own copies. Run it again any time to update them.
set -euo pipefail
cd "$(dirname "$0")"

WOWACE=https://repos.wowace.com/wow
fetch() { # fetch <url> <destination file>
	mkdir -p "$(dirname "$2")"
	curl -sfL "$1" -o "$2" || { echo "Couldn't download $1" >&2; exit 1; }
	echo "  $2"
}

echo "Downloading libraries into Libs/:"
fetch "$WOWACE/libstub/trunk/LibStub.lua" Libs/LibStub/LibStub.lua
fetch "$WOWACE/callbackhandler/trunk/CallbackHandler-1.0/CallbackHandler-1.0.lua" Libs/CallbackHandler-1.0/CallbackHandler-1.0.lua
fetch "https://raw.githubusercontent.com/tekkub/libdatabroker-1-1/master/LibDataBroker-1.1.lua" Libs/LibDataBroker-1.1/LibDataBroker-1.1.lua
fetch "$WOWACE/libdbicon-1-0/trunk/LibDBIcon-1.0/LibDBIcon-1.0.lua" Libs/LibDBIcon-1.0/LibDBIcon-1.0.lua
echo "Done."
