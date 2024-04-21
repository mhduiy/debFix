#!/bin/bash

# 1. 加一个TryExec字段，随便塞一个可执行文件
# 2. 将失败的包保存下来，提示用户需要手动执行
# 3. 开源合规检查

cd "$(dirname "$0")" || exit
archs=amd64,arm64,loongarch64,i386
apt_source_config_file=/etc/apt/sources.list.d/deepin-deb-fix.list

pwd_dir=$(pwd)
cache_dir=${pwd_dir}/DEBS     # deb包下载目录
extract_dir=${pwd_dir}/tmp    # deb包解压目录
IFS=$'\n'  # 设置分隔符为换行符
fix_application_dir=/usr/share/deepin-desktop-fix/applications/ # 修补包desktop文件输出目录
fix_app_file_dir=/opt/deepin-apps-fix/ # 修补包脚本文件输出目录
logPath=${pwd_dir}/check.log

mkdir -p $cache_dir
mkdir -p $extract_dir

echo "" > ${logPath}

rm -rf ${extract_dir}/*

writeLog() {
    echo "[$1][$(date)]  $2" >> ${logPath}
}

# 显示帮助信息
show_help() {
    echo "Usage:"
    echo "  ./checkDeb.sh                                     check all arch and deb"
    echo "  ./checkDeb.sh checkArch <arch>                    check all debs of the arch"
    echo "  ./checkDeb.sh checkDeb  <packageName> <arch>      check this package"
    echo "  ./checkDeb.sh checkDesktop <desktopPath> <arch>   check this desktop"
}

check_desktop() {
    source_desktop_path=$1
    arch=$2
    output_desktop_path=${pwd_dir}/${arch}${fix_application_dir}$(basename "$source_desktop_path")
    mkdir -p $(dirname ${output_desktop_path})
    fix_desktop=0 # 是否修复desktop的标志位

    # 遍历desktop文件的每一行，读取Exec字段，作相应处理
    while IFS= read -r line; do
        if [[ "$line" == Exec=* ]]; then
            exec_cmd_origin_path="${extract_dir}$(echo "${line#Exec=}" | awk '{print $1}' | tr -d '"')"

            # 检查文件类型是否为纯文本文件、是否具有可执行权限，并且不是脚本文件
            file_type=$(file -b "$exec_cmd_origin_path")
            if [[ ($file_type == *"ASCII text"* || $file_type == *"Unicode text"*) && -x "$exec_cmd_origin_path" && "$file_type" != *"script"* ]]; then
                fix_desktop=1
                # echo 不符合规范脚本: "$exec_cmd_origin_path"

                # 启动脚本行首添加shebang，拷贝一份，作为修补包的内容
                sed -i '1i#!/bin/bash' "$exec_cmd_origin_path"
                new_script_path=${pwd_dir}/${arch}${fix_app_file_dir}$(echo "$exec_cmd_origin_path" | sed "s|^${extract_dir}/opt/apps/||")
                mkdir -p $(dirname $new_script_path)
                cp  $exec_cmd_origin_path  $new_script_path

                # 修改Desktop的Exec字段的内容，指向新启动脚本
                line=Exec=$(echo "$line" | sed "s|^[^[:space:]]*|${fix_app_file_dir}$(echo "$exec_cmd_origin_path" | sed "s|^${extract_dir}/opt/apps/||")|")
            fi
        fi
        if [[ ! "$line" == TryExec=* ]]; then
            echo "$line" >> "$output_desktop_path"
        fi
    done < "$source_desktop_path"
    # 添加一个TryExec字段
    absolute_path=$(realpath "$(find ${extract_dir} -type f -executable | head -n 1)")
    absolute_path=${absolute_path#${extract_dir}}
    if [[ $? -eq 0 ]]; then
        echo "TryExec=${absolute_path}" >> "$output_desktop_path"
    else
        echo "TryExec keys error"
        writeLog "warning" "TryExec keys error"
    fi
    if [ $fix_desktop -eq 0 ]; then
        rm -f "$output_desktop_path"
        echo -e "\e[32m[Check passed]\e[0m"
        writeLog "info" "Check passed"
    else
        echo -e "\e[31m[Checked for issues, modified]\e[0m"
        writeLog "modified" "Checked for issues, modified"
    fi
}

check_deb() {
    package_name=$1
    arch=$2
    cd $cache_dir
    apt-get download -o APT::Architecture=${arch} ${package_name}
    deb_file=$(find . -maxdepth 1 -type f -name "${package_name}*.deb" -print -quit)
    dpkg-deb -x "${deb_file}" "${extract_dir}" 1>/dev/null
    if [ $? -ne 0 ]; then
        echo -e "\e[31m[unzip error, skip]\e[0m"
        rm -rf ${extract_dir}/*
        rm -rf ${deb_file}
        return 1
    fi
    desktop_files=$(find ${extract_dir}/opt/apps/*/entries/applications/ -type f -name "*.desktop")
    if [ $? -ne 0 ]; then
        echo -e "\e[31m[desktop not found]\e[0m"
        writeLog "warning" "desktop not found"
        rm -rf ${extract_dir}/*
        rm -rf ${deb_file}
        return 1
    fi
    for file_path in $desktop_files; do
        check_desktop ${file_path} ${arch}
    done
    rm -rf ${extract_dir}/*
    rm -rf ${deb_file}
}

check_all_deb_with_arch() {
    arch=$1
    apt_cache_path="/var/lib/apt/lists/com-store-packages.uniontech.com_appstorev23_dists_beige_appstore_binary-${arch}_Packages"
    # 在这里可以添加你想要执行的操作
    if [[ -f ${apt_cache_path} ]]; then
        rm -rf ${pwd_dir}/${arch}
        total=$(grep -c "^Package: "  ${apt_cache_path})
        count=0
        awk '/^Package:/ {print $2}' ${apt_cache_path} | while read -r package_name; do
            count=$((count+1))
            echo "[${count}/${total}] scanning: ${package_name}-${arch}"
            writeLog "info" "[${count}/${total}] scanning: ${package_name}-${arch}"
            check_deb ${package_name} ${arch}
        done
    else
        echo -e "\e[31m[apt cache not exist, skipping]\e[0m"
    fi
}

# 拿到所有的cache
check_all_arch() {
    echo -e "# Written by deepin-deb-fix
deb [arch=${archs}] https://com-store-packages.uniontech.com/appstorev23 beige appstore" | sudo tee ${apt_source_config_file} >/dev/null
    sudo apt-get update
    IFS=',' read -ra arch_array <<< "$archs"
    # 遍历数组中的每个架构
    for arch in "${arch_array[@]}"; do
        check_all_deb_with_arch ${arch}
    done
}

case "$1" in
"checkArch")
    check_all_deb_with_arch $2
    ;;
"checkDeb")
    check_deb $2 $3 
    ;;
"check_desktop")
    check_desktop $2 $3
    ;;
"--help")
    show_help
    ;;
*)
    check_all_arch
    ;;
esac