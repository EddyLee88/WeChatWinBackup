#!/usr/bin/env bash

set -eo pipefail

temp_path="WeChatWin/temp"
download_link="$1"
if [ -z "$1" ]; then
    >&2 echo -e "Missing argument. Using default download link"
    download_link="https://dldir1v6.qq.com/weixin/Universal/Windows/WeChatWin.exe"
fi

function install_depends() {
    printf "#%.0s" {1..60}
    echo -e "## \033[1;33mInstalling p7zip-full, p7zip-rar, libdigest-sha-perl, wget, curl, git...\033[0m"
    printf "#%.0s" {1..60}

    apt install -y p7zip-full p7zip-rar libdigest-sha-perl wget curl git
}

function login_gh() {
    printf "#%.0s" {1..60}
    echo -e "## \033[1;33mLogin to github to use github-cli...\033[0m"
    printf "#%.0s" {1..60}

    if [ -z $GH_TOKEN ]; then
        >&2 echo -e "\033[1;31mMissing Github Token! Please get a Github Token and set it in Secret\033[0m"
        exit 1
    fi
    echo $GH_TOKEN > WeChatWin/temp/GH_TOKEN
    gh auth login --with-token < WeChatWin/temp/GH_TOKEN
    if [ "$?" -ne 0 ]; then
        >&2 echo -e "\033[1;31mLogin Failed, please check your network or token!\033[0m"
        clean_data 1
    fi
    rm -rfv WeChatWin/temp/GH_TOKEN
}

function download_wechat() {
    printf "#%.0s" {1..60}
    echo -e "## \033[1;33mDownloading the newest WeChatWin...\033[0m"
    printf "#%.0s" {1..60}

    wget "$download_link" -O ${temp_path}/WeChatWin.exe
    if [ "$?" -ne 0 ]; then
        >&2 echo -e "\033[1;31mDownload Failed, please check your network!\033[0m"
        clean_data 1
    fi
}

function extract_version() {
    printf "#%.0s" {1..60}
    echo -e "## \033[1;33mExtract WeChatWin, get the dest version of WeChat\033[0m"
    printf "#%.0s" {1..60}

    7z x ${temp_path}/WeChatWin.exe -o${temp_path}/temp
    current_version=`ls -l ${temp_path}/temp | awk '{print $9}' | grep '^[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*$'`
}

function prepare_commit() {
    printf "#%.0s" {1..60}
    echo -e "## \033[1;33mPrepare to commit new version\033[0m"
    printf "#%.0s" {1..60}

    mkdir -p WeChatWin/$current_version
    cp $temp_path/WeChatWin.exe WeChatWin/$current_version/WeChatWin-$current_version.exe
    echo "Version: $current_version" > WeChatWin/$current_version/WeChatWin-$current_version.exe.sha256
    echo "Sha256: $now_sum256" >> WeChatWin/$current_version/WeChatWin-$current_version.exe.sha256
    echo "UpdateTime: $(date -u '+%Y-%m-%d %H:%M:%S') (UTC)" >> WeChatWin/$current_version/WeChatWin-$current_version.exe.sha256
    echo "DownloadFrom: $download_link" >> WeChatWin/$current_version/WeChatWin-$current_version.exe.sha256
}

function clean_data() {
    printf "#%.0s" {1..60}
    echo -e "## \033[1;33mClean runtime and exit...\033[0m"
    printf "#%.0s" {1..60}

    rm -rfv WeChatWin/*
    exit $1
}

function main() {
    mkdir -p ${temp_path}/temp
    install_depends
    login_gh
    download_wechat
    now_sum256=`shasum -a 256 ${temp_path}/WeChatWin.exe | awk '{print $1}'`
    local latest_sum256=`gh release view  --json body --jq ".body" | awk '/Sha256/{ print $2 }'`

    if [ "$now_sum256" = "$latest_sum256" ]; then
        >&2 echo -e "\n\033[1;32mThis is the newest Version!\033[0m\n"
        clean_data 0
    fi

    extract_version
    prepare_commit
    gh release create v$current_version ./WeChatWin/$current_version/WeChatWin-$current_version.exe -F ./WeChatWin/$current_version/WeChatWin-$current_version.exe.sha256 -t "WeChatWin v$current_version"
    gh auth logout --hostname github.com | echo "y"
    clean_data 0
}

main
