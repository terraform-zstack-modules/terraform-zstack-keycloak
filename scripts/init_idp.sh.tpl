#!/bin/bash


# 从 Terraform 传入的环境变量获取管理员账号和密码
idp_admin="${admin_username}"
idp_pwd="${admin_password}"

echo "使用管理员账号: $idp_admin"


# 管理员登录统一认证
echo "正在登录统一认证管理控制台..."
docker exec root-keycloak-1 /opt/keycloak/bin/kcadm.sh config credentials --server http://localhost:8080/ --realm master --user "$idp_admin" --password "$idp_pwd"
if [ $? -ne 0 ]; then
  echo "登录失败，请检查管理员账号和密码"
  exit 1
fi
echo "登录成功"

# 更新 master realm 信息
echo "统一认证初始化中..."
docker exec root-keycloak-1 /opt/keycloak/bin/kcadm.sh update realms/master \
  -s "adminTheme=zstack-theme" \
  -s "loginTheme=zstack-theme" \
  -s "internationalizationEnabled=true" \
  -s 'supportedLocales=[ "en", "zh-CN" ]' \
  -s "defaultLocale=zh-CN" \
  -s "sslRequired=none"

echo "统一认证初始化完成"

# 创建 realm 和 client 给 Cloud 使用
echo "创建 ZSCloud realm..."
docker exec root-keycloak-1 /opt/keycloak/bin/kcadm.sh create realms -s realm=ZSCloud -s enabled=true
if [ $? -ne 0 ]; then
  echo "ZSCloud realm 可能已存在，尝试更新..."
  docker exec root-keycloak-1 /opt/keycloak/bin/kcadm.sh update realms/ZSCloud -s enabled=true
fi

echo "创建 cloud_sso 客户端..."
CLIENT_ID=$(docker exec root-keycloak-1 /opt/keycloak/bin/kcadm.sh get clients -r ZSCloud --fields id,clientId | grep -B1 '"clientId" : "cloud_sso"' | grep '"id"' | cut -d'"' -f4)

if [ -z "$CLIENT_ID" ]; then
  docker exec root-keycloak-1 /opt/keycloak/bin/kcadm.sh create clients -r ZSCloud \
    -s clientId=cloud_sso \
    -s enabled=true \
    -s 'redirectUris=["*"]'
else
  echo "cloud_sso 客户端已存在，ID: $CLIENT_ID"
  docker exec root-keycloak-1 /opt/keycloak/bin/kcadm.sh update clients/$CLIENT_ID -r ZSCloud \
    -s enabled=true \
    -s 'redirectUris=["*"]'
fi

echo "更新 ZSCloud realm 设置..."
docker exec root-keycloak-1 /opt/keycloak/bin/kcadm.sh update realms/ZSCloud \
  -s "loginTheme=zstack-theme" \
  -s "internationalizationEnabled=true" \
  -s 'supportedLocales=[ "en", "zh-CN" ]' \
  -s "defaultLocale=zh-CN" \
  -s "sslRequired=none"

echo "已创建 cloud_sso 客户端，请通过管理控制台访问所需配置，以便 Cloud 的接入统一认证"
echo "初始化脚本执行完成"

# 返回状态给 Terraform
exit 0
