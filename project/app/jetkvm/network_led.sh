#!/bin/sh
# -*- coding: utf-8 -*-
#
# 网络LED控制脚本
# 功能：
# - 网线插好时，G1B0_ETH_ACT (GPIO40) 常亮
# - 数据传输时，G1B1_ETH_SPD (GPIO41) 闪烁
#

# GPIO配置
GPIO_ACT=40  # G1B0_ETH_ACT
GPIO_SPD=41  # G1B1_ETH_SPD

# GPIO文件路径
GPIO_BASE="/sys/class/gpio"
GPIO_EXPORT="${GPIO_BASE}/export"
GPIO_UNEXPORT="${GPIO_BASE}/unexport"

# 网络接口
NETWORK_INTERFACE="eth0"

# 监控参数
MONITOR_INTERVAL=0.5  # 监控间隔（秒）
DATA_THRESHOLD=1000   # 数据传输阈值（字节）
BLINK_INTERVAL=0.1    # 闪烁间隔（秒）

# 日志级别: 0=静默, 1=正常, 2=调试
LOG_LEVEL=${LOG_LEVEL:-1}

# PID文件路径（用于服务管理）
PID_FILE=${PID_FILE:-"/var/run/network_led.pid"}

# 状态文件路径（用于进程间通信）
STATE_DIR="/tmp/network_led"
STATE_FILE="${STATE_DIR}/data_transfer"

# 全局变量
data_transfer_detected=0
blink_running=0
blink_pid=""

# 日志函数
log() {
    [ "$LOG_LEVEL" -ge 1 ] && echo "[$(date '+%H:%M:%S')] $*"
}

debug() {
    [ "$LOG_LEVEL" -ge 2 ] && echo "[$(date '+%H:%M:%S')] [DEBUG] $*"
}

# 设置数据传输状态（写入文件）
set_transfer_state() {
    mkdir -p "$STATE_DIR" 2>/dev/null
    echo "$1" > "$STATE_FILE" 2>/dev/null
}

# 读取数据传输状态（从文件）
get_transfer_state() {
    if [ -f "$STATE_FILE" ]; then
        cat "$STATE_FILE" 2>/dev/null
    else
        echo "0"
    fi
}

# 检查服务是否正在运行
check_running() {
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE" 2>/dev/null)
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            return 0
        fi
    fi
    return 1
}

# 保存PID到文件
save_pid() {
    echo $$ > "$PID_FILE"
}

# 删除PID文件
remove_pid() {
    rm -f "$PID_FILE"
}

# 停止服务
stop_service() {
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE" 2>/dev/null)
        if [ -n "$pid" ]; then
            # 发送 SIGHUP 信号触发清理
            kill -HUP "$pid" 2>/dev/null
            sleep 1
            # 如果还在运行，发送 SIGTERM
            if kill -0 "$pid" 2>/dev/null; then
                kill "$pid" 2>/dev/null
                sleep 1
            fi
            # 如果还在运行，发送 SIGKILL
            if kill -0 "$pid" 2>/dev/null; then
                kill -9 "$pid" 2>/dev/null
                sleep 0.5
            fi
        fi
        remove_pid
        
        # 清理所有相关的 network_led.sh 进程（排除当前进程和 grep）
        local my_pid=$$
        for p in $(ps | grep "[n]etwork_led.sh" | grep -v "$my_pid" | cut -d' ' -f1); do
            kill "$p" 2>/dev/null
        done
        sleep 0.5
        for p in $(ps | grep "[n]etwork_led.sh" | grep -v "$my_pid" | cut -d' ' -f1); do
            kill -9 "$p" 2>/dev/null
        done
        
        echo "OK"
        return 0
    fi
    echo "Service not running"
    return 1
}

# 查看服务状态
show_status() {
    if check_running; then
        local pid=$(cat "$PID_FILE" 2>/dev/null)
        echo "Running (PID: $pid)"
        return 0
    else
        echo "Stopped"
        return 1
    fi
}

# 配置GPIO
setup_gpio() {
    local gpio_num=$1
    local gpio_path="${GPIO_BASE}/gpio${gpio_num}"
    
    # 导出GPIO
    if [ ! -d "$gpio_path" ]; then
        echo "$gpio_num" > "$GPIO_EXPORT" 2>/dev/null
        sleep 0.1
    fi
    
    # 设置为输出模式
    if [ -d "$gpio_path" ]; then
        echo "out" > "${gpio_path}/direction" 2>/dev/null
        return 0
    else
        echo "ERROR: 无法配置GPIO${gpio_num}"
        return 1
    fi
}

# 设置GPIO输出值
set_gpio_value() {
    local gpio_num=$1
    local value=$2
    local gpio_value_path="${GPIO_BASE}/gpio${gpio_num}/value"
    
    if [ -f "$gpio_value_path" ]; then
        echo "$value" > "$gpio_value_path" 2>/dev/null
        return 0
    else
        echo "ERROR: 无法设置GPIO${gpio_num}值"
        return 1
    fi
}

# 读取网络接口统计信息（纯Bash，无awk/grep子进程）
read_network_stats() {
    local rx_bytes=0
    local tx_bytes=0
    local iface_pattern="${NETWORK_INTERFACE}:"
    
    if [ -r "/proc/net/dev" ]; then
        while IFS= read -r line; do
            # 去除前导空格后匹配接口名
            local trimmed="${line#*${iface_pattern}}"
            if [ "$trimmed" != "$line" ]; then
                # 提取接收字节数（第一个字段）和发送字节数（第9个字段）
                set -- $trimmed
                rx_bytes=$1
                tx_bytes=$9
                break
            fi
        done < /proc/net/dev
    fi
    
    echo "$rx_bytes $tx_bytes"
}

# 检查网络连接状态（载波状态）
check_network_link() {
    local carrier_file="/sys/class/net/${NETWORK_INTERFACE}/carrier"
    
    if [ -f "$carrier_file" ]; then
        local carrier=$(cat "$carrier_file" 2>/dev/null)
        if [ "$carrier" = "1" ]; then
            return 0  # 连接正常
        fi
    fi
    return 1  # 未连接
}

# LED闪烁控制函数（后台运行）
led_blinker() {
    local blink_state=0
    
    while [ "$blink_running" -eq 1 ]; do
        if [ "$(get_transfer_state)" = "1" ]; then
            # 切换闪烁状态
            if [ "$blink_state" -eq 0 ]; then
                blink_state=1
                set_gpio_value "$GPIO_SPD" 1
            else
                blink_state=0
                set_gpio_value "$GPIO_SPD" 0
            fi
            sleep "$BLINK_INTERVAL"
        else
            # 数据传输停止时，LED熄灭
            set_gpio_value "$GPIO_SPD" 0
            sleep "$MONITOR_INTERVAL"
        fi
    done
    
    # 退出时确保LED熄灭
    set_gpio_value "$GPIO_SPD" 0
}

# 获取所有子进程PID
get_child_pids() {
    if [ -n "$blink_pid" ] && kill -0 "$blink_pid" 2>/dev/null; then
        echo "$blink_pid"
    fi
}

# 启动闪烁线程
start_blinker() {
    blink_running=1
    led_blinker &
    blink_pid=$!
}

# 停止闪烁线程
stop_blinker() {
    blink_running=0
    if [ -n "$blink_pid" ]; then
        kill "$blink_pid" 2>/dev/null
        sleep 0.5
        # 如果还在运行，强制杀死
        if kill -0 "$blink_pid" 2>/dev/null; then
            kill -9 "$blink_pid" 2>/dev/null
        fi
    fi
}

# 清理GPIO资源
cleanup_gpio() {
    log "清理GPIO配置..."
    set_gpio_value "$GPIO_ACT" 0
    set_gpio_value "$GPIO_SPD" 0
    
    # 取消导出GPIO
    echo "$GPIO_ACT" > "$GPIO_UNEXPORT" 2>/dev/null
    sleep 0.1
    echo "$GPIO_SPD" > "$GPIO_UNEXPORT" 2>/dev/null
    
    # 清理状态文件
    rm -rf "$STATE_DIR" 2>/dev/null
    
    log "脚本已停止"
}

# 信号处理
trap_cleanup() {
    log "停止脚本..."
    blink_running=0
    stop_blinker
    cleanup_gpio
    remove_pid
    exit 0
}

# 主函数
main() {
    log "网络LED控制脚本启动..."
    log "监控接口: $NETWORK_INTERFACE"
    log "GPIO_ACT: $GPIO_ACT (G1B0_ETH_ACT)"
    log "GPIO_SPD: $GPIO_SPD (G1B1_ETH_SPD)"
    log "--------------------------------------------------"
    
    # 设置信号处理
    trap trap_cleanup INT TERM
    
    # 配置GPIO
    if ! setup_gpio "$GPIO_ACT" || ! setup_gpio "$GPIO_SPD"; then
        echo "ERROR: GPIO配置失败"
        return 1
    fi
    
    # 启动LED闪烁线程
    start_blinker
    
    # 初始化网络统计
    local prev_rx_bytes prev_tx_bytes link_status=0
    set -- $(read_network_stats)
    prev_rx_bytes=$1
    prev_tx_bytes=$2
    
    # 主循环
    while true; do
        # 检查网络连接状态
        if check_network_link; then
            current_link=1
        else
            current_link=0
        fi
        
        if [ "$current_link" -ne "$link_status" ]; then
            link_status=$current_link
            if [ "$link_status" -eq 1 ]; then
                log "网络连接已建立"
                set_gpio_value "$GPIO_ACT" 1  # 常亮
            else
                log "网络连接已断开"
                set_gpio_value "$GPIO_ACT" 0  # 熄灭
                set_gpio_value "$GPIO_SPD" 0  # 熄灭
                set_transfer_state 0
            fi
        fi
        
        # 检查数据传输
        if [ "$link_status" -eq 1 ]; then
            local rx_bytes tx_bytes
            set -- $(read_network_stats)
            rx_bytes=$1
            tx_bytes=$2
            
            # 计算数据传输量
            local rx_diff=$((rx_bytes - prev_rx_bytes))
            local tx_diff=$((tx_bytes - prev_tx_bytes))
            local total_bytes=$((rx_diff + tx_diff))
            
            if [ "$total_bytes" -gt "$DATA_THRESHOLD" ]; then
                set_transfer_state 1
            else
                set_transfer_state 0
            fi
            
            prev_rx_bytes=$rx_bytes
            prev_tx_bytes=$tx_bytes
        fi
        
        sleep "$MONITOR_INTERVAL"
    done
}

# 命令行参数处理
case "${1:-}" in
    start)
        # 先清理可能存在的旧进程
        if [ -f "$PID_FILE" ]; then
            old_pid=$(cat "$PID_FILE" 2>/dev/null)
            if [ -n "$old_pid" ] && kill -0 "$old_pid" 2>/dev/null; then
                log "发现残留进程 $old_pid，正在清理..."
                kill "$old_pid" 2>/dev/null
                sleep 1
                kill -9 "$old_pid" 2>/dev/null 2>/dev/null
            fi
            remove_pid
        fi
        
        if check_running; then
            echo "Service already running (PID: $(cat "$PID_FILE"))"
            exit 0
        fi
        # 后台运行并保存PID
        nohup "$0" _run > /dev/null 2>&1 &
        MAIN_PID=$!
        echo "$MAIN_PID" > "$PID_FILE"
        sleep 1
        if kill -0 "$MAIN_PID" 2>/dev/null; then
            echo "OK"
            exit 0
        else
            echo "FAIL"
            exit 1
        fi
        ;;
    stop)
        printf "Stopping network LED control: "
        stop_service
        exit $?
        ;;
    status)
        show_status
        exit $?
        ;;
    restart|reload)
        $0 stop
        sleep 1
        $0 start
        exit $?
        ;;
    _run)
        # 内部命令：实际运行主函数（由 start 调用）
        main
        ;;
    *)
        # 直接运行模式（前台运行）
        main
        ;;
esac
