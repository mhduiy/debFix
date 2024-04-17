#!/bin/bash

# 检测商店所有所有包
# sudo apt update
amd64AptCachePath=/var/lib/apt/lists/com-store-packages.uniontech.com_appstorev23_dists_beige_appstore_binary-amd64_Packages
cacheDir=$(pwd)/DEBS


echo $cacheDir


# 运行awk命令获取数据，并通过管道传递给while循环
awk '/^Package:/ {print $2}' $amd64AptCachePath | while read -r package_name; do
    apt download -d $cacheDir $package_name
done