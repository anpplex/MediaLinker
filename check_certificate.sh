#!/bin/bash

# 申请证书、检查证书
check_certificate() {
  # 申请证书
  /bin/sh /opt/ssl

  # 检查证书是否被 Let's Encrypt 成功签发
  if ls /.lego/certificates | grep "${SSL_DOMAIN}"; then
      if [ -e /.lego/certificates/"${SSL_DOMAIN}".crt ] && [ -e /.lego/certificates/"${SSL_DOMAIN}".key ]; then
          echo '证书签发成功，服务正在重启'
          # 删除原证书
          rm -rf /opt/fullchain.pem /opt/privkey.key
          # 将证书复制到特定目录
          cp /.lego/certificates/"${SSL_DOMAIN}".crt /opt/fullchain.pem
          cp /.lego/certificates/"${SSL_DOMAIN}".key /opt/privkey.key
          # 软连接证书到 nginx 配置目录
          mkdir -p /etc/nginx/conf.d/cert/
          ln -s /opt/fullchain.pem /etc/nginx/conf.d/cert/fullchain.pem
          ln -s /opt/privkey.key /etc/nginx/conf.d/cert/privkey.key

          # 判断nginx是否正在运行，如果正在运行重启 nginx
          if pgrep nginx >/dev/null; then
              echo "Nginx is running, reloading..."
              nginx -s reload
              echo 'Nginx reloading success'
          fi
      else
          echo '证书文件不存在，证书签发失败'
          exit 1
      fi
  else
      echo '证书签发失败'
      exit 1
  fi
}

if [ "${SSL_ENABLE}" = "true" ]; then
  # 检查 /opt/ssl 文件是否存在
  if [ -e /opt/ssl ]; then

      # 检查证书和私钥文件是否存在
      if [ -e /opt/fullchain.pem ] && [ -e /opt/privkey.key ]; then
          # 获取当前日期和时间
          current_date=$(date +%s)
          # 提取证书的到期日期，并将其转换为 Unix 时间戳
          expiry_date=$(openssl x509 -enddate -noout -in /opt/fullchain.pem | cut -d= -f2 | awk '{sub(/ GMT/, ""); print}' | xargs -I {} date -d "{}" +%s)
          echo "Certificate expiry date in Unix timestamp: $expiry_date"
          # 计算证书到期的天数
          days_until_expiry=$(( (expiry_date - current_date) / 86400 ))
          echo "证书有效期: $days_until_expiry 天"

          # 判断证书是否在 30 天内到期
          if [ $days_until_expiry -le 30 ]; then
              echo "证书将在 $days_until_expiry 天内到期，执行证书申请脚本"
              check_certificate
          else
              echo "证书还在有效期, 无需更新"
              # 判断nginx证书是否正确配置
              if [ -e /etc/nginx/conf.d/cert/fullchain.pem ] && [ -e /etc/nginx/conf.d/cert/privkey.key ]; then
                  echo "证书配置正确"
              fi
          fi
      else
          echo "开始申请域名证书"
          check_certificate
      fi
  else
      echo "SSL脚本不存在。"
      exit 1
  fi
else
    echo "SSL未启用。"
fi

