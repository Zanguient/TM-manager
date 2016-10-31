RED='\033[0;31m'
NC='\033[0m' # No Color
printf "${RED}TM-Manager Installtion${NC}\n"
echo "Installion assumes a clean install of Ubuntu 14.04"
echo "Installion prompts are for creating a subdomain 'tm-manager for a domain name 'domain.tld' and accessing tm-manager via it"
echo "you wil be prompted to provide both."
echo "By default, a cer-key pair is generated using OpenSSL for HTTPS, if HTTPS is enabled"
echo "You can find the cer-key pair in the /etc/ssl/<domain>/ folder."
echo "You will be promted to enter details for the certificate"

# Root check
if [[ $EUID -ne 0 ]]; then
    printf "${RED}You must be a root user${NC}" 2>&1
    exit 1
fi

#User Consent
printf "${RED}This setup requires the installation of the nginx, nodejs, mongodb, latex and graphicsmagick packages using apt-get!${NC}\n"

    read -p "HTTP ? (y/n) : " httpEn
    read -p "HTTPS ? (y/n) : " httpsEn

    #User Input
    read -p "Domain (eg, domain.tk): " domain
    read -p "Subdomain (eg, manager): " subdomain

    if [ "$httpsEn" == "y" ]; then
        read -p "Country Name (2 letter code) (eg, IN): " certC
        read -p "State or Province Name (eg, Kerala): " certST
        read -p "Locality Name (eg, Kochi): " certL
        read -p "Organization Name (eg, Novocorp Industries Inc): " certO
        read -p "Organizational Unit Name (RnD): " certOU
    fi

    #Prerequisits
    apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 7F0CEB10
    apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv EA312927
    apt-get install -y cron
    apt-get install -y python-software-properties
    apt-get install -y software-properties-common
    curl -sL https://deb.nodesource.com/setup_4.x | sudo -E bash -
    echo "deb http://repo.mongodb.org/apt/ubuntu trusty/mongodb-org/3.2 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-3.2.list
    apt-get update
    apt-get install -y nginx
    apt-get install -y nodejs
    apt-get install -y graphicsmagick
    apt-get install -y mongodb-org
    apt-get install -y texlive-latex-base
    apt-get install -y texlive-fonts-recommended texlive-fonts-extra texlive-latex-extra texlive-lang-french
    
    curl https://get.acme.sh | sh
    mkdir /www/
    mkdir /www/logs/
    mkdir /www/nginx/
    mkdir /www/acme/
    mkdir /www/ssl/
    mkdir /www/www/
    mkdir /www/node_modules/
    cd /www/
    npm install -g bower
    npm install -g gulp
    npm install total.js@beta

    #Key Generation

    mkdir /etc/ssl/${domain}
    openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
    -subj "/C=$certC/ST=$certST/L=$certL/O=$certO/OU=$certOU/CN=$subdomain.$domain" \
    -keyout /etc/ssl/${domain}/${subdomain}.key \
    -out /etc/ssl/${domain}/${subdomain}.cer

    #Configuration
    cd
    apt-get install -y git
    git clone https://github.com/ToManage/manager.git
    mv manager /www/
    cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.backup
    cp /www/manager/nginx.conf /etc/nginx/nginx.conf
    cp /www/manager/manager.conf /www/nginx/
    repexp=s/#domain#/$domain/g
    subrepexp=s/#subdomain#/$subdomain/g
    httpenexp=s/#disablehttp#//g
    httpsenexp=s/#disablehttps#//g

    if [ "$httpEn" == "y" ]; then
        sed -i -e $httpenexp /www/nginx/manager.conf
    fi
    if [ "$httpsEn" == "y" ]; then
        sed -i -e $httpsenexp /www/nginx/manager.conf
    fi

    sed -i -e $repexp /www/nginx/manager.conf
    sed -i -e $subrepexp /www/nginx/manager.conf
    service nginx reload

    rm /www/manager/user.guid
    read -p "Which user should TM-Manager use to run your applications ? (default root) : " user
    if id "$user" >/dev/null 2>&1; then
        printf "Using user -> %s\n" "$user"
        uid=$(id -u ${user})
        gid=$(id -g ${user})
        echo "$user:$uid:$gid" >> /www/manager/user.guid
    else
        printf "User %s does not exist. Using root instead.\n" "$user"
        echo "root:0:0" >> /www/manager/user.guid
    fi

    read -p "Do you wish to install cron job to start TM-Manager automaticly after server restart? (y/n) :" autorestart
    if [ "$autorestart" == "y" ]; then
        #write out current crontab
        crontab -l > mycron
        #check cron job exists if not add it
        crontab -l | grep '@reboot /bin/bash /www/manager/run.sh' || echo '@reboot /bin/bash /www/manager/run.sh' >> mycron
        crontab mycron
        rm mycron
        echo "Cron job added."
    fi

    #Starting
    /bin/bash /www/manager/run.sh
