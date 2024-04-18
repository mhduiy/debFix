#!/bin/bash

cd "$(dirname "$0")" || exit
arch=$(dpkg --print-architecture)
apt_cache_path=/var/lib/apt/lists/com-store-packages.uniontech.com_appstorev23_dists_beige_appstore_binary-${arch}_Packages

if [ ! -f "${apt_cache_path}" ]; then
    echo "apt缓存文件未找到, 退出"
    exit 1
fi

pwd_dir=$(pwd)
cache_dir=${pwd_dir}/DEBS     # deb包下载目录
extract_dir=${pwd_dir}/tmp    # deb包解压目录
IFS=$'\n'  # 设置分隔符为换行符
fix_application_dir=/usr/share/deepin-desktop-fix/applications/ # 修补包desktop文件目录
fix_app_file_dir=/opt/deepin-apps-fix/ # 修补包文件目录

mkdir -p $cache_dir
mkdir -p $extract_dir

rm -rf ${pwd_dir}${fix_application_dir}*
rm -rf ${extract_dir}/*
rm -rf ${pwd_dir}${fix_app_file_dir}*

check_desktop() {
    source_desktop_path=$1
    output_desktop_path=${pwd_dir}${fix_application_dir}$(basename "$source_desktop_path")
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
                new_script_path=${pwd_dir}${fix_app_file_dir}$(echo "$exec_cmd_origin_path" | sed "s|^${extract_dir}/opt/apps/||")
                mkdir -p $(dirname $new_script_path)
                cp  $exec_cmd_origin_path  $new_script_path

                # 修改Desktop的Exec字段的内容，指向新启动脚本
                line=Exec=$(echo "$line" | sed "s|^[^[:space:]]*|${fix_app_file_dir}$(echo "$exec_cmd_origin_path" | sed "s|^${extract_dir}/opt/apps/||")|")
            fi

        fi
        echo "$line" >> "$output_desktop_path"
    done < "$source_desktop_path"
    if [ $fix_desktop -eq 0 ]; then
        rm -f "$output_desktop_path"
        echo -e "\e[32m[符合规范]\e[0m"
    else
        echo -e "\e[31m[不符合规范，已修改]\e[0m"
    fi
}

check_deb () {
    cd $cache_dir
    total=$(grep -c "^Package: "  ${apt_cache_path})
    count=0
    awk '/^Package:/ {print $2}' ${apt_cache_path} | while read -r package_name; do
        count=$((count+1))
        echo "[${count}/${total}]处理: ${package_name}"
        apt download -d $package_name
        deb_file=$(find . -maxdepth 1 -type f -name "${package_name}*.deb" -print -quit)
        dpkg-deb -x "${deb_file}" "${extract_dir}" 1>/dev/null
        if [ $? -ne 0 ]; then
            echo -e "\e[31m[解压失败，跳过]\e[0m"
            rm -rf ${extract_dir}/*
            rm -rf ${deb_file}
            continue
        fi
        desktop_files=$(find ${extract_dir}/opt/apps/*/entries/applications/ -type f -name "*.desktop")
        for file_path in $desktop_files; do
            check_desktop ${file_path}
        done
        rm -rf ${extract_dir}/*
        rm -rf ${deb_file}
    done
}

check_deb