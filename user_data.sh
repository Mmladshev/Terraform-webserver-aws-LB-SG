#!/bin/bash
yum -y update
yum -y install httpd


myip=`curl http://169.254.169.254/latest/meta-data/local-ipv4`

cat <<EOF > /var/www/html/index.html
<html>
<body bgcolor="white">
<h2><font color="gold">Build by Power of Terraform <font color="red"> v1.3.6</font></h2><br><p>
<h2><font color="gold">Hello world form $myip</h2><br><p>
</body>
</html>
EOF

sudo service httpd start
chkconfig httpd on