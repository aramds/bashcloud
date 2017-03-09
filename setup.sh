#!/usr/bin/env bash
V_HOST=wphost
V_HOST_TLD=tld

apt-get -y update && apt-get -y upgrade

echo "deb http://nginx.org/packages/debian/ jessie nginx" >> /etc/apt/sources.list
echo "deb-src http://nginx.org/packages/debian/ jessie nginx" >> /etc/apt/sources.list

wget http://nginx.org/keys/nginx_signing.key && apt-key add nginx_signing.key

apt-get -y update
apt-get install -y nginx php5-fpm php5-cgi php5 php5-mysql php5-gd php5-common php5-mysqlnd php5-xmlrpc php5-curl php5-cli php-pear php5-dev php5-imap php5-mcrypt

sed -i "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/" "/etc/php5/fpm/php.ini"
sed -i "s/user  nginx;/user  www-data;/" "/etc/nginx/nginx.conf"

rm -rf /etc/nginx/conf.d/default.conf
rm -rf /etc/php5/fpm/pool.d/www.conf

mkdir -p /var/log/nginx/domains
cd /tmp
wget https://wordpress.org/latest.tar.gz
tar -zxvf latest.tar.gz
mv /tmp/wordpress/* /usr/share/nginx/html
rm -rf /tmp/latest.tar.gz

chmod -R u=rw,g=r,o=r,a+X /usr/share/nginx/html
chown -R www-data:www-data /usr/share/nginx/html

cat <<EOF > /etc/php5/fpm/pool.d/$V_HOST.conf
[www]
listen = /var/run/php5-$V_HOST.sock
listen.allowed_clients = 127.0.0.1

user = www-data
group = www-data

listen.owner = www-data
listen.group = www-data

pm = dynamic
pm.max_children = 50
pm.start_servers = 3
pm.min_spare_servers = 2
pm.max_spare_servers = 10

env[HOSTNAME] = $HOSTNAME
env[PATH] = /usr/local/bin:/usr/bin:/bin
env[TMP] = /tmp
env[TMPDIR] = /tmp
env[TEMP] = /tmp
EOF

cat <<EOF > /etc/nginx/conf.d/$V_HOST80.conf
server {
    listen      80;
    server_name $V_HOST.$V_HOST_TLD www.$V_HOST.$V_HOST_TLD;
    root        /usr/share/nginx/html;
    index       index.php;
    access_log  /var/log/nginx/domains/$V_HOST.log combined;
    error_log   /var/log/nginx/domains/$V_HOST.error.log error;

    location = /favicon.ico {
        log_not_found off;
        access_log off;
    }

    location = /robots.txt {
        allow all;
        log_not_found off;
        access_log off;
    }

    location / {
        try_files $uri $uri/ /index.php?$args;

        location ~* ^.+\.(jpeg|jpg|png|gif|bmp|ico|svg|css|js)$ {
            expires     max;
        }

        location ~ [^/]\.php(/|$) {
            fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
            if (!-f $document_root$fastcgi_script_name) {
                return  404;
            }

            fastcgi_pass    unix:/var/run/php5-$V_HOST.sock;
            fastcgi_index   index.php;
            include         /etc/nginx/fastcgi_params;
        }
    }

    error_page   500 502 503 504  /50x.html;
    location = /50x.html {
        root   /usr/share/nginx/html;
    }

    location ~* "/\.(htaccess|htpasswd)$" {
        deny    all;
        return  404;
    }
}
EOF






