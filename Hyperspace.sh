#!/bin/bash

# 脚本保存路径
SCRIPT_PATH="$HOME/Hyperspace.sh"


# 检查并安装 screen
function check_and_install_screen() {
    if ! command -v screen &> /dev/null; then
        echo "screen 未安装，正在安装..."
        apt update && apt install -y screen
    else
        echo "screen 已安装。"
    fi
}

# 主菜单函数
function main_menu() {
    while true; do
        clear
        echo "Hyper0.5B模型"
        echo "模型：QuantFactory/Qwen2-0.5B-GGUF/Qwen2-0.5B.Q6_K.gguf"
        echo "================================================================"
        echo "退出脚本，请按键盘 ctrl + C 退出即可"
        echo "请选择要执行的操作:"
        echo "1. 部署hyperspace节点"
        echo "2. 查看日志"
        echo "3. 查看积分"
        echo "4. 删除节点（停止节点）"
        echo "5. 启用日志监控"
        echo "6. 查看使用的私钥"
        echo "7. 查看aios daemon状态"
        echo "8. 启用积分监控"
        echo "9. 退出脚本"
        echo "================================================================"
        read -p "请输入选择 (1/2/3/4/5/6/7/8/9): " choice

        case $choice in
            1)  deploy_hyperspace_node ;;
            2)  view_logs ;; 
            3)  view_points ;;
            4)  delete_node ;;
            5)  start_log_monitor ;;
            6)  view_private_key ;;
            7)  view_status ;;
            8)  start_points_monitor ;;
            9)  exit_script ;;
            *)  echo "无效选择，请重新输入！"; sleep 2 ;;
        esac
    done
}

# 部署hyperspace节点
function deploy_hyperspace_node() {
    # 执行安装命令
    echo "正在执行安装命令：curl https://download.hyper.space/api/install | bash"
    curl https://download.hyper.space/api/install | bash

    # 获取安装后新添加的路径
    NEW_PATH=$(bash -c 'source /root/.bashrc && echo $PATH')
    export PATH="$NEW_PATH"

    # 确保路径正确（关键修复1：显式添加路径）
    export PATH="/root/.aios:$HOME/.local/bin:$PATH"
    echo "当前 PATH: $PATH"

    # 验证 aios-cli 是否可用（关键修复2：直接使用绝对路径）
    if ! /root/.aios/aios-cli --version &>/dev/null; then
        echo "错误：aios-cli 未正确安装！请手动执行 'source /root/.bashrc'"
        exit 1
    fi

    # 清理并创建 screen 会话（关键修复3：增加错误处理）
    screen_name="hyper"
    if screen -ls | grep -q "$screen_name"; then
        echo "清理旧会话 '$screen_name'..."
        screen -S "$screen_name" -X quit || true
        sleep 2
    fi
    screen -dmS "$screen_name"
    echo "已创建 screen 会话: $screen_name"

    # 启动服务（关键修复4：避免路径依赖）
    screen -S "$screen_name" -X stuff "/root/.aios/aios-cli start\n"
    sleep 5
    screen -S "$screen_name" -X detach

    # 导入私钥
    echo "请输入私钥（CTRL+D 结束输入）："
    cat > my.pem
    /root/.aios/aios-cli hive import-keys ./my.pem
    sleep 2

    # 添加模型（关键修复5：严格模型路径+超时+重试）
    model="hf:QuantFactory/Qwen2-0.5B-GGUF:Qwen2-0.5B.Q6_K.gguf"  # ⚠️大小写敏感！
    echo "添加模型: $model"
    retry=0
    max_retries=3
    while [ $retry -lt $max_retries ]; do
        if /root/.aios/aios-cli models add "$model" --timeout 1800; then  # ⚠️超时30分钟
            echo "✅ 模型下载成功"
            break
        else
            retry=$((retry+1))
            echo "❌ 下载失败，重试 $retry/$max_retries..."
            sleep 30
        fi
    done
    [ $retry -eq $max_retries ] && echo "致命错误：模型下载失败！" && exit 1

    # 后续配置
    /root/.aios/aios-cli hive login
    echo "选择等级 (1-5):"
    select tier in {1..5}; do
        /root/.aios/aios-cli hive select-tier $tier && break
    done
    /root/.aios/aios-cli hive connect

    # 重启服务并记录日志（关键修复6：强制清理旧日志）
    echo "重启服务..."
    /root/.aios/aios-cli kill
    echo "初始化日志..." > /root/aios-cli.log
    screen -S "$screen_name" -X stuff "/root/.aios/aios-cli start --connect >> /root/aios-cli.log 2>&1\n"

    echo "部署完成！"
    read -n 1 -s -r -p "按任意键返回主菜单..."
    main_menu
}

# 其他函数保持不变
# ... [view_points, delete_node 等函数无需修改] ...

# 调用主菜单
check_and_install_screen
main_menu
