#!/bin/bash



if [ $# -eq 0 ]; then

     echo "Provide a domain like the following script.sh DOMAIN_NAME"

else

DOMAIN=$1

apt-get update

echo "------------------------------------Installing nginx bind9------------------------------------"

apt-get install -y nginx bind9 bind9utils iptables


echo "------------------------------------Configuring nginx and bind9------------------------------------"

NGINX_CONF="/etc/nginx/sites-available/$DOMAIN"
NGINX_LINK="/etc/nginx/sites-enabled/$DOMAIN"

cat <<EOL > $NGINX_CONF
server {
    listen 80;
    server_name $DOMAIN;

    root /var/www/$DOMAIN;
    index index.html;

    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOL


mkdir -p /var/www/$DOMAIN
chown -R $USER:$USER /var/www/$DOMAIN


echo "<html><head><title>Welcome to $DOMAIN</title></head><body></body></html>" > /var/www/$DOMAIN/index.html


ln -s $NGINX_CONF $NGINX_LINK

mkdir /etc/bind/zones

BIND_CONF="/etc/bind/named.conf.local"
ZONE_FILE="/etc/bind/zones/db.$DOMAIN"
BIND_CONF_OPTIONS=""
CURRENT_IP=$(hostname -I | awk '{print $1}')


cat <<EOL >> $BIND_CONF

zone "$DOMAIN" {
    type master;
    file "$ZONE_FILE";
};
EOL

cat <<EOL > $ZONE_FILE
\$TTL    604800
@       IN      SOA     $DOMAIN. webmaster.$DOMAIN. (
                              2         ; Serial
                         604800         ; Refresh
                          86400         ; Retry
                        2419200         ; Expire
                         604800 )       ; Negative Cache TTL
;
        IN      NS      ns1.$DOMAIN.
ns1     IN      A       $CURRENT_IP
@       IN      A       $CURRENT_IP
EOL



nginx -t
service nginx reload
service named reload
service nginx restart
service named restart

echo "--------------------------------------------------------------------------------------------------"

echo "NGINX and BIND9 have been set up for the domain $DOMAIN."
echo "Ensure your DNS settings point to this server's IP address for the domain $DOMAIN."

fi
