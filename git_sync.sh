#!/bin/bash
# Author: David Deng
# Url: https://covear.top

get_char(){
        SAVEDSTTY=`stty -g`
        stty -echo
        stty cbreak
        dd if=/dev/tty bs=1 count=1 2> /dev/null
        stty -raw
        stty echo
        stty $SAVEDSTTY
}

trap 'echo -e "\n\033[31m\033[1m【 已强制退出脚本！ 】\033[0m\n"; exit 1' INT

# 初始化变量，默认为空或无意义值
gitee_choice=""
github_choice=""
Local=""
User=""
Email=""
Repo=""
MSG=""

# 使用循环和case语句处理参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -ge|--gitee)
            shift
            gitee_choice=$1
            ;;
        -gh|--github)
            shift
            github_choice=$1
            ;;
        -l|--local)
            shift
            Local=$1
            ;;
        -u|--user)
            shift
            User=$1
            ;;
        -e|--email)
            shift
            Email=$1
            ;;
        -r|--repo)
            shift
            Repo=$1
            ;;
        -m|--msg)
            shift
            MSG=$1
            ;;
        *)
            echo ""
            echo -n "未知的参数: $1 " >&2
            shift
            echo "$1" >&2
            echo -e "\033[31m\033[1m【 请检查修正后重试! 】\033[0m\n"
            exit 1
            ;;
    esac
    shift # 移动到下一个参数
done

# 现在变量已经被正确赋值
echo "Gitee Choice: $gitee_choice"
echo "GitHub Choice: $github_choice"
echo "Local: $Local"
echo "User: $User"
echo "Email: $Email"
echo "Repo: $Repo"
echo "Message: $MSG"

echo -e "\n【 初始化操作 】\n"

# 询问用户是否使用 Gitee 服务
in1=true
while true; do
    if [ -n "$gitee_choice" ] && $in1; then
        echo "您是否需要使用 Gitee 服务？您已设置: [$gitee_choice]"
    else
        read -p "您是否需要使用 Gitee 服务？ (请回答 yes 或者 no, 默认 yes): " gitee_choice
    fi
    gitee_choice=${gitee_choice:-y}
    case $gitee_choice in
        [Yy]* ) gitee=yes; break;;
        [Nn]* ) gitee=no; break;;
        * ) echo -e "\n【 错误！请留空 或者输入 yes 或 y 或 on 或 n 】\n"; in1=false; continue;;
    esac
done

# 询问用户是否使用 GitHub 服务
in1=true
while true; do
    if [ -n "$github_choice" ] && $in1; then
        echo "您是否需要使用 GitHub 服务？您已设置: [$github_choice]"
    else
        read -p "您是否需要使用 GitHub 服务？ (请回答 yes 或者 no, 默认 yes): " github_choice
    fi
    github_choice=${github_choice:-y}
    case $github_choice in
        [Yy]* ) github=yes; break;;
        [Nn]* ) github=no; break;;
        * ) echo -e "\n【 错误！请留空 或者输入 yes 或 y 或 on 或 n 】\n"; in1=false; continue;;
    esac
done

# 判断并执行相应操作
if [[ $gitee == "no" && $github == "no" ]]; then
    echo -e "\n【 没有需要进行的操作！ 】\n"
    exit 0
fi

if [[ $gitee == "yes" ]]; then
    echo -e "\n【 尝试连接 Gitee 服务... 】\n"
    echo -e "ssh -T git@gitee.com"
    echo -e "如果提示信任远程服务密钥，请输入 yes 继续！"
    if ssh -T git@gitee.com &>/dev/null; then
        echo -e "\033[32m\033[1m成功:\033[0m \033[32mGitee 服务远程通道正常！\033[0m"
    else
        echo -e "\033[31m\033[1m错误:\033[0m \033[31m请配置 Gitee 密钥后重试！\033[0m"
    fi
fi

if [[ $github == "yes" ]]; then
    echo -e "\n【 尝试连接 GitHub 服务... 】\n"
    echo -e "ssh -T git@gitee.com"
    echo -e "如果提示信任远程服务密钥，请输入 yes 继续！"
    echo -e "如果提示输入密码，并且密码确认无效，请 Ctrl+C 退出脚本，检查是否挂有网络代理！"
    # 执行 ssh -T git@github.com 并获取输出
    output=$(ssh -T git@github.com 2>&1)
    # 检查输出中是否包含 "successfully"
    if echo "$output" | grep -iq 'successfully'; then
        echo -e "\033[32m\033[1m成功:\033[0m \033[32mGitHub 服务远程通道正常！\033[0m"
    else
        echo -e "\033[31m\033[1m错误:\033[0m \033[31m请配置 GitHub 密钥后重试！\033[0m"
    fi
fi

echo -e "\n注意: 如果以上操作中有\033[31m\033[1m错误\033[0m提示，\n      请使用 Ctrl+C 退出修正后重试！\n "
echo -e "【 请按任意键开始设置仓库 】"
char=`get_char`

if [ -n "$Local" ]; then
    echo "您已设置本地文件夹路径: [$Local]"
else
    read -p "请输入本地文件夹路径: " Local
fi
if [ -n "$User" ]; then
    echo "您已设置仓库用户名: [$User]"
else
    read -p "请输入仓库用户名: " User
fi
if [ -n "$Email" ]; then
    echo "您已设置仓库用户邮箱: [$Email]"
else
    read -p "请输入仓库用户邮箱: " Email
fi
if [ -n "$Repo" ]; then
    echo "您已设置远程仓库名: [$Repo]"
else
    read -p "请输入远程仓库名: " Repo
fi
if [ -n "$MSG" ]; then
    echo "您已设置对本次上传的描述: [$MSG]"
else
    read -p "请输入对本次上传的描述: " MSG
fi
SSH="git@github.com:"${User}"/"${Repo}".git"
SSH2="git@gitee.com:"${User}"/"${Repo}".git"

echo -e "\n【 请按任意键开始初始化仓库 】"
char=`get_char`

cd ${Local}

(
cat <<EOF

# The following file types do not need to be uploaded
*.swp
*.inf.php
inf.php
git_sync
EOF
) >> .gitignore


if [ ! -d "./git_sync" ]; then
	echo -e "【 初始化文件夹 】"
	if [ -d "./.git" ]; then
(
cat <<EOF
[core]
        repositoryformatversion = 0
        filemode = true
        bare = false
        logallrefupdates = true

[user]
        email = ${Email}
        name = ${User}

EOF
) >./.git/config

	else
		git init
(
cat <<EOF

[user]
        email = ${Email}
        name = ${User}

EOF
) >>./.git/config
	fi
fi

echo -e "【 添加本地文件 】"
git add ${Local}
echo -e "【 显示文件变化 】"
git status
echo -e "【 请按任意键开始上传 】"
char=`get_char`
echo -e "【 更新本地仓库 】"
git commit -m "${MSG}"

if [[ $gitee == "yes" ]]; then
    echo -e "【 添加Gitee远程仓库 】"
    git remote add ${Repo} ${SSH2}
    echo -e "【 添加Gitee远程链接 】"
    git remote set-url ${Repo} ${SSH2}
    echo -e "【 上传Gitee远程仓库 】"
    git push -u ${Repo} +master
    echo -e "【 删除Gitee远程缓存 】"
    git remote rm ${Repo}
fi

if [[ $github == "yes" ]]; then
    echo -e "【 添加Github远程仓库 】"
    git remote add ${Repo} ${SSH}
    echo -e "【 添加Github远程链接 】"
    git remote set-url ${Repo} ${SSH}
    echo -e "【 上传Github远程仓库 】"
    git push -u ${Repo} +master
    echo -e "【 删除Github远程缓存 】"
    git remote rm ${Repo}
fi

echo -e "\n【 同步完成 】\n"

echo \#!/bin/bash >./git_sync
(
cat <<EOF

get_char(){
	SAVEDSTTY=\`stty -g\`
	stty -echo
	stty cbreak
	dd if=/dev/tty bs=1 count=1 2> /dev/null
	stty -raw
	stty echo
	stty \$SAVEDSTTY
}

trap 'echo -e "\n\033[31m\033[1m【 已强制退出脚本！ 】\033[0m\n"; exit 1' INT

echo -e "\n【 开始同步 】\n"
cd ${Local}
echo -e "【 添加本地文件 】"
git add ${Local}
echo -e "【 显示文件变化 】"
git status
if ( [ "\$1" = "-m" ] || [ "\$1" = "-msg" ] ) && [ -n "\$2" ]; then
    MSG="\$2"
else
    read -p "请输入对本次上传的描述: " MSG
fi
echo -e "【 描述 】: \${MSG}"
echo -e "【 请按任意键开始上传 】"
char=\`get_char\`
echo -e "【 更新本地仓库 】"
git commit -m "\${MSG}"

EOF
) >>./git_sync

if [[ $gitee == "yes" ]]; then
    echo echo -e \"【 添加Gitee远程仓库 】\" >>./git_sync
    echo git remote add ${Repo} ${SSH2} >>./git_sync
    echo echo -e \"【 添加Gitee远程链接 】\" >>./git_sync
    echo git remote set-url ${Repo} ${SSH2} >>./git_sync
    echo echo -e \"【 上传Gitee远程仓库 】\" >>./git_sync
    echo git push -u ${Repo} +master >>./git_sync
    echo echo -e \"【 删除Gitee远程缓存 】\" >>./git_sync
    echo git remote rm ${Repo} >>./git_sync
fi

if [[ $github == "yes" ]]; then
    echo echo -e \"【 添加Github远程仓库 】\" >>./git_sync
    echo git remote add ${Repo} ${SSH} >>./git_sync
    echo echo -e \"【 添加Github远程链接 】\" >>./git_sync
    echo git remote set-url ${Repo} ${SSH} >>./git_sync
    echo echo -e \"【 上传Github远程仓库 】\" >>./git_sync
    echo git push -u ${Repo} +master >>./git_sync
    echo echo -e \"【 删除Github远程缓存 】\" >>./git_sync
    echo git remote rm ${Repo} >>./git_sync
fi

echo echo -e \"\\n【 同步完成 】\\n\" >>./git_sync
echo exit >>./git_sync
chmod +x ./git_sync

echo -e "【 已于目录${Local}生成“git_sync”文件，您下次进入目录运行“./git_sync”即可 】\n"

exit
