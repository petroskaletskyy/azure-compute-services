#!/bin/bash
sudo apt-get update
sudo apt-get install -y nginx
HOSTNAME=$(hostname)
IP_ADDRESS=$(hostname -I | awk '{print $1}')
echo "<html>" > /var/www/html/index.html
echo "<body>" >> /var/www/html/index.html
echo "<p><h1>Hostname: $HOSTNAME</h1></p>" >> /var/www/html/index.html
echo "<p><h1>IP Address: $IP_ADDRESS</h1></p>" >> /var/www/html/index.html
echo "</body>" >> /var/www/html/index.html
echo "</html>" >> /var/www/html/index.html