#!/bin/sh
sleep 3
clear

# 颜色
RED='\033[1;31m'        # 鲜红
PINK='\033[1;35m'       # 亮紫
CYAN='\033[1;36m'       # 亮青
GREEN='\033[1;32m'      # 亮绿
YELLOW='\033[1;33m'     # 亮黄
BLUE='\033[1;34m'       # 亮蓝
WHITE='\033[1;37m'      # 亮白
NC='\033[0m'            # 清除颜色


WARN() { echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] WARN: $1${NC}"; }
INFO() { echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"; }

# ======================
# 基础设置 sh 版本
# ======================
VIDEO_DIR="/media"
STREAM_KEY="${STREAM_KEY:-live}"
RTMP_URL="rtmp://localhost:1935/hls/$STREAM_KEY"

# ======================
# 初始化 HLS 输出目录
# ======================
INFO "初始化 HLS 输出目录..."
rm -rf /opt/data/hls/*

INFO "自动推流脚本启动，监控目录: $VIDEO_DIR"

# ======================
# 主循环
# ======================
while true; do
    INFO "扫描 mp4 文件..."
    mp4_list="/tmp/mp4_list.txt"
    find "$VIDEO_DIR" -type f -iname "*.mp4" | sort > "$mp4_list"

    if [ ! -s "$mp4_list" ]; then
        WARN "没有发现 mp4 文件，3 秒后重试..."
        sleep 3
        continue
    fi

    INFO "视频文件列表数量: $(wc -l < "$mp4_list")"

    # ======================
    # 读取每行到单独变量
    # ======================
    FILE_NUM=0
    while IFS= read -r line || [ -n "$line" ]; do
        # 去掉可能的 \r
        line=$(printf '%s' "$line" | tr -d '\r')
        FILE_NUM=$((FILE_NUM+1))
        eval "FILE$FILE_NUM=\$line"
    done < "$mp4_list"

    # ======================
    # 按顺序推流
    # ======================
    i=1
    while [ $i -le $FILE_NUM ]; do
        eval "mp4file=\$FILE$i"

        INFO "====================================================="
        INFO "当前文件: $mp4file"

        if [ ! -f "$mp4file" ]; then
            WARN "[ERROR] 文件不存在: $mp4file"
            i=$((i+1))
            continue
        fi

        # 检查编码
        codec=$(ffprobe -v error -select_streams v:0 \
            -show_entries stream=codec_name \
            -of default=noprint_wrappers=1:nokey=1 "$mp4file" 2>/dev/null)

        if [ "$codec" != "h264" ]; then
            WARN "[SKIP] 跳过: 编码不是 h264，而是 $codec"
            i=$((i+1))
            continue
        fi

        INFO "视频编码 OK: $codec"
        INFO "开始推流..."
        ffmpeglog="/tmp/ffmpeg_$(date +'%F').log"

        ffmpeg -re -i "$mp4file" -c copy -f flv "$RTMP_URL" >>"$ffmpeglog" 2>&1

        INFO "播放完成，等待 3 秒..."
        sleep 3
        i=$((i+1))
    done

    INFO "全部文件播放完毕，3 秒后重新开始..."
    sleep 3
done

