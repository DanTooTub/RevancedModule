#!/usr/bin/env bash

set -e

pr() { echo -e "\033[0;32m[+] ${1}\033[0m"; }
ask() {
	local y
	for ((n = 0; n < 3; n++)); do
		pr "$1 [y/n]"
		if read -r y; then
			if [ "$y" = y ]; then
				return 0
			elif [ "$y" = n ]; then
				return 1
			fi
		fi
		pr "Asking again..."
	done
	return 1
}

pr "Ask for storage permission"
until
	yes | termux-setup-storage >/dev/null 2>&1
	ls /sdcard >/dev/null 2>&1
do sleep 1; done
if [ ! -f ~/.rvmm_"$(date '+%Y%m')" ]; then
	pr "Setting up environment..."
	yes "" | pkg update -y && pkg upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" && pkg install -y git curl jq openjdk-21 zip
	: >~/.rvmm_"$(date '+%Y%m')"
fi
mkdir -p /sdcard/Download/RevancedModule/

if [ -d RevancedModule ] || [ -f config.toml ]; then
	if [ -d RevancedModule ]; then cd RevancedModule; fi
	pr "Checking for RevancedModule updates"
	git fetch
	if git status | grep -q 'is behind\|fatal'; then
		pr "RevancedModule is not synced with upstream."
		pr "Cloning RevancedModule. config.toml will be preserved."
		cd ..
		cp -f RevancedModule/config.toml .
		rm -rf RevancedModule
		git clone https://github.com/DanTooTub/RevancedModule --recurse --depth 1
		mv -f config.toml RevancedModule/config.toml
		cd RevancedModule
	fi
else
	pr "Cloning RevancedModule."
	git clone https://github.com/DanTooTub/RevancedModule --depth 1
	cd RevancedModule
	sed -i '/^enabled.*/d; /^\[.*\]/a enabled = false' config.toml
	grep -q 'RevancedModule' ~/.gitconfig 2>/dev/null ||
		git config --global --add safe.directory ~/RevancedModule
fi

[ -f ~/storage/downloads/RevancedModule/config.toml ] ||
	cp config.toml ~/storage/downloads/RevancedModule/config.toml

if ask "Open rvmm-config-gen to generate a config?"; then
	am start -a android.intent.action.VIEW -d https://j-hc.github.io/rvmm-config-gen/
fi
printf "\n"
until
	if ask "Open 'config.toml' to configure builds?\nAll are disabled by default, you will need to enable at first time building"; then
		am start -a android.intent.action.VIEW -d file:///sdcard/Download/RevancedModule/config.toml -t text/plain
	fi
	ask "Setup is done. Do you want to start building?"
do :; done
cp -f ~/storage/downloads/RevancedModule/config.toml config.toml

./build.sh

cd build
PWD=$(pwd)
for op in *; do
	[ "$op" = "*" ] && {
		pr "glob fail"
		exit 1
	}
	mv -f "${PWD}/${op}" ~/storage/downloads/RevancedModule/"${op}"
done

pr "Outputs are available in /sdcard/Download/RevancedModule folder"
am start -a android.intent.action.VIEW -d file:///sdcard/Download/RevancedModule -t resource/folder
sleep 2
am start -a android.intent.action.VIEW -d file:///sdcard/Download/RevancedModule -t resource/folder
