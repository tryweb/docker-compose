#!/bin/bash

# 安裝 mysql client 相關套件
apk add --no-cache mysql-client php-mysqli

# 重啟 PHP-FPM 讓套件生效
s6-svc -r /run/service/svc-php-fpm
