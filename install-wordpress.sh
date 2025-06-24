#!/bin/bash

set -e

# === Запит параметрів ===
read -p "Введіть домен (наприклад: example.com): " DOMAIN
read -p "Введіть назву бази даних: " DB_NAME
read -p "Введіть ім'я користувача БД: " DB_USER
read -s -p "Введіть пароль для користувача БД: " DB_PASS
echo

# === Оновлення системи ===
apt update && apt upgrade -y

# === Встановлення Apache, PHP, MariaDB ===
apt install -y apache2 mariadb-server php php-mysql libapache2-mod-php \
    php-curl php-gd php-mbstring php-xml php-xmlrpc php-soap php-intl php-zip \
    unzip wget

# === Створення бази даних ===
mysql -u root <<MYSQL_SCRIPT
CREATE DATABASE ${DB_NAME} DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci;
CREATE USER '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
MYSQL_SCRIPT

# === Завантаження WordPress ===
wget -q https://wordpress.org/latest.zip -O /tmp/wordpress.zip
unzip -q /tmp/wordpress.zip -d /var/www/
mv /var/www/wordpress /var/www/${DOMAIN}

# === Права доступу ===
chown -R www-data:www-data /var/www/${DOMAIN}
chmod -R 755 /var/www/${DOMAIN}

# === Налаштування wp-config.php ===
cp /var/www/${DOMAIN}/wp-config-sample.php /var/www/${DOMAIN}/wp-config.php
sed -i "s/database_name_here/${DB_NAME}/" /var/www/${DOMAIN}/wp-config.php
sed -i "s/username_here/${DB_USER}/" /var/www/${DOMAIN}/wp-config.php
sed -i "s/password_here/${DB_PASS}/" /var/www/${DOMAIN}/wp-config.php

# === Apache конфігурація (HTTP) ===
cat > /etc/apache2/sites-available/${DOMAIN}.conf <<EOF
<VirtualHost *:80>
    ServerName ${DOMAIN}
    DocumentRoot /var/www/${DOMAIN}

    <Directory /var/www/${DOMAIN}>
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/${DOMAIN}_error.log
    CustomLog \${APACHE_LOG_DIR}/${DOMAIN}_access.log combined
</VirtualHost>
EOF

# === Активуємо сайт і перезапускаємо Apache ===
a2ensite ${DOMAIN}
a2enmod rewrite
systemctl reload apache2

echo "✅ WordPress встановлено. Перейдіть до http://${DOMAIN} для завершення налаштування."

