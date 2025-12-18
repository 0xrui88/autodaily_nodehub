#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

TOKEN_FILE="/root/nodehub_token"

clear
echo -e "${BLUE}================================================"
echo "      Node-X 日常任务脚本"
echo "      功能: 1. 领取RP 2. 签到"
echo -e "${YELLOW}     ⭐ 作者X: 加密锐锐 @0xrui88 ⭐"
echo -e "     📢 麻烦关注下哦(*^▽^*) 使用教程在推文${NC}"
echo -e "${BLUE}================================================"
echo -e "${NC}"

if ! command -v python3 &> /dev/null; then
    echo -e "${YELLOW}检测到Python3未安装，正在自动安装...${NC}"
    apt-get update && apt-get install -y python3 python3-pip
    if [ $? -ne 0 ]; then
        echo -e "${RED}Python3 安装失败，请手动安装${NC}"
        exit 1
    fi
    echo -e "${GREEN}Python3 安装成功${NC}"
fi

if ! python3 -c "import requests" 2>/dev/null; then
    echo -e "${YELLOW}正在安装 Python requests 库...${NC}"
    pip3 install requests --quiet
    if [ $? -ne 0 ]; then
        echo -e "${RED}安装 requests 库失败，请手动运行: pip3 install requests${NC}"
        exit 1
    fi
    echo -e "${GREEN}requests 库安装成功${NC}"
fi

read_token() {
    if [ -f "$TOKEN_FILE" ] && [ -s "$TOKEN_FILE" ]; then
        JWT_TOKEN=$(cat "$TOKEN_FILE" | tr -d '\n\r ')
        
        if [ ${#JWT_TOKEN} -ge 50 ]; then
            echo -e "${GREEN}✓ 使用已保存的Token (长度: ${#JWT_TOKEN} 字符)${NC}"
            echo -e "${YELLOW}提示: 如需重新输入Token，请删除文件 $TOKEN_FILE${NC}"
            return 0
        else
            echo -e "${RED}⚠ 保存的Token长度过短，需要重新输入${NC}"
            return 1
        fi
    else
        echo -e "${YELLOW}未找到保存的Token文件${NC}"
        return 1
    fi
}

get_new_token() {
    echo -e "\n${BLUE}请输入您的 Node-X JWT Token:${NC}"
    echo -e "${YELLOW}(输入时会显示字符，粘贴完成后回车)${NC}"
    read -r JWT_TOKEN
    echo

    if [ -z "$JWT_TOKEN" ]; then
        echo -e "${RED}错误: Token 不能为空${NC}"
        return 1
    fi

    if [ ${#JWT_TOKEN} -lt 50 ]; then
        echo -e "${RED}错误: Token 长度过短，请检查是否正确${NC}"
        return 1
    fi

    echo "$JWT_TOKEN" > "$TOKEN_FILE"
    chmod 600 "$TOKEN_FILE"
    echo -e "${GREEN}✓ Token 已保存到 $TOKEN_FILE${NC}"
    echo -e "${GREEN}✓ Token 长度: ${#JWT_TOKEN} 字符${NC}"
    return 0
}

if ! read_token; then
    if ! get_new_token; then
        exit 1
    fi
fi

PYTHON_SCRIPT=$(cat << 'EOF'
#!/usr/bin/env python3

import sys
import json
import requests
from datetime import datetime

def main():
    if len(sys.argv) < 2:
        print("错误: 未提供Token参数")
        return 1
    
    jwt_token = sys.argv[1]
    base_url = "https://hub.node-x.xyz"
    
    headers = {
        'accept': 'application/json, text/plain, */*',
        'accept-language': 'zh-CN,zh;q=0.9',
        'jwttoken': jwt_token,
        'language': 'zh_CN',
        'User-Agent': 'NodeX-Daily-Tasks/1.0'
    }
    
    print(f"🕐 执行时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("=" * 50)
    
    def make_request(endpoint, method='GET', data=None):
        url = base_url + endpoint
        try:
            if method.upper() == 'GET':
                response = requests.get(url, headers=headers, timeout=10)
            else:
                response = requests.post(url, headers=headers, json=data, timeout=10)
            
            if response.status_code != 200:
                return {"error": f"HTTP错误: {response.status_code}"}
            return response.json() if response.content else {}
        except Exception as e:
            return {"error": f"请求异常: {str(e)}"}
    
    def get_points():
        result = make_request("/api/user-points/personal-points")
        if result and result.get('code') == 1000:
            data = result.get('result', {})
            return {
                'rp': float(data.get('integral', 0)),
                'ap': float(data.get('taskIntegral', 0)),
            }
        return None
    
    print("1. 验证Token有效性...")
    result = make_request("/api/sys/user/balance")
    
    if "error" in result:
        print(f"❌ Token验证失败: {result['error']}")
        return 1
    
    code = result.get('code')
    if code == 1000:
        print("✅ Token验证成功")
    else:
        print(f"❌ Token无效 (错误码: {code})")
        return 1
    
    initial_points = get_points()
    if not initial_points:
        initial_points = {'rp': 0, 'ap': 0}
    
    print("\n2. 执行RP领取...")
    result = make_request("/api/user-integral/rp-receive-by-user", method='POST')
    
    if "error" in result:
        print(f"❌ 领取失败: {result['error']}")
    
    code = result.get('code') if result else None
    message = result.get('message', '') if result else ''
    
    if code == 1000:
        result_data = result.get('result', {})
        total_rp = result_data.get('totalRp')
        device_count = result_data.get('deviceCount', 0)
        ratio = result_data.get('ratio', 0)
        
        if total_rp is not None:
            print("\n" + "=" * 45)
            print("✅ RP 领取成功！")
            print("=" * 45)
            print(f"当前总 RP: {total_rp}")
            print(f"在线设备: {device_count}台")
            print(f"收益比率: {ratio}%")
            print(f"服务器消息: {message}")
            print("=" * 45)
        else:
            print(f"ℹ️  今日已领取过RP")
    elif code == 400 or "已领取" in str(message) or "already" in str(message).lower():
        print(f"ℹ️  {message or '今日已领取过'}")
    elif result and "error" not in result:
        print(f"❌ 领取失败 (代码: {code}, 消息: {message})")
    
    print("\n3. 执行签到...")
    sign_result = make_request("/api/check-in/do-check-in", method='POST')
    
    if "error" in sign_result:
        print(f"❌ 签到失败: {sign_result['error']}")
    else:
        sign_code = sign_result.get('code')
        sign_message = sign_result.get('message', '')
        
        if sign_code == 1000:
            print(f"✅ 签到成功: {sign_message}")
        elif sign_code == 400 or sign_code == 500 or "已签到" in sign_message or "already" in sign_message.lower():
            print(f"ℹ️  {sign_message or '今日已签到过'}")
        else:
            print(f"❌ 签到失败 (代码: {sign_code}, 消息: {sign_message})")
    
    print("\n4. 积分状态对比...")
    final_points = get_points()
    
    if initial_points and final_points:
        rp_change = final_points['rp'] - initial_points['rp']
        ap_change = final_points['ap'] - initial_points['ap']
        
        print("=" * 60)
        print("📊 积分变化对比")
        print("=" * 60)
        print(f"{'项目':<10} {'执行前':<15} {'执行后':<15} {'变化量':<15}")
        print("-" * 60)
        
        rp_change_str = f"+{rp_change:.2f}" if rp_change > 0 else f"{rp_change:.2f}"
        print(f"{'RP':<10} {initial_points['rp']:<15.2f} {final_points['rp']:<15.2f} {rp_change_str:<15}")
        
        ap_change_str = f"+{ap_change:.2f}" if ap_change > 0 else f"{ap_change:.2f}"
        print(f"{'AP':<10} {initial_points['ap']:<15.2f} {final_points['ap']:<15.2f} {ap_change_str:<15}")
        
        print("=" * 60)
    else:
        print("⚠️  无法获取完整的积分对比信息")
    
    return 0

if __name__ == "__main__":
    exit_code = main()
    sys.exit(exit_code)
EOF
)

TEMP_SCRIPT="/tmp/nodex_daily_$$.py"
echo "$PYTHON_SCRIPT" > "$TEMP_SCRIPT"

chmod +x "$TEMP_SCRIPT"

echo -e "\n${BLUE}正在执行日常任务...${NC}"
echo -e "${YELLOW}--------------------------------${NC}"

python3 "$TEMP_SCRIPT" "$JWT_TOKEN"
EXIT_CODE=$?

echo -e "\n${YELLOW}--------------------------------${NC}"

rm -f "$TEMP_SCRIPT"

if [ $EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}✅ 脚本执行完成${NC}"
else
    echo -e "${RED}❌ 脚本执行失败 (退出码: $EXIT_CODE)${NC}"
fi

echo -e "\n${CYAN}📁 Token存储信息:${NC}"
echo "  Token已保存到: $TOKEN_FILE"
echo "  如需重新输入Token，请删除此文件或运行: rm $TOKEN_FILE"

echo -e "\n${YELLOW}⭐ 作者X: 加密锐锐 @0xrui88 ⭐"
echo -e "📢 麻烦关注下哦(*^▽^*) 使用教程在推文${NC}"

echo -e "\n按任意键退出..."
read -n 1 -s

exit $EXIT_CODE
