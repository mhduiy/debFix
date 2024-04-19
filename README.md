## Deepin Deb Fix

由于部分商店应用启动脚本未添加shebang，导致systemd无法执行脚本造成应用启动失败，经过讨论后，现准备通过执行一个脚本将有问题的启动脚本手动加上shebang，并将修补过的启动脚本和desktop文件作为源码放在deepin-deb-fix中，安装此包后会将修补目录添加到XDG_DATA_DIRS环境变量中，即可在启动应用时执行修补过的启动脚本，达到修复问题的目的

## License

Deepin Deb Fix is licensed under [GPL-3.0-or-later](LICENSE).
