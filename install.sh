RED='\033[0;31m'
NC='\033[0m' # No Color
printf "${RED}TM-Manager Installtion${NC}\n"
echo "Installion assumes a clean install of Ubuntu 14.04"
echo "Installion prompts are for creating a subdomain 'tm-manager for a domain name 'domain.tld' and accessing tm-manager via it"
echo "you wil be prompted to provide both."
echo "By default, a cer-key pair is generated using OpenSSL for HTTPS, if HTTPS is enabled"
echo "You can find the cer-key pair in the /etc/ssl/<domain>/ folder."
echo "You will be promted to enter details for the certificate"
echo "TM-Manager uses these commands: lsof, ps, netstat, du, cat, free, df, tail, last, ifconfig, uptime, tar"

# Root check
if [[ $EUID -ne 0 ]]; then
    printf "${RED}You must be a root user${NC}" 2>&1
    exit 1
fi

#User Consent
printf "${RED}This setup requires the installation of the Nginx, Node.js and GraphicsMagick packages using apt-get!${NC}\n"
read -p "Do you wish to permit this ? (y/n) : " userConsent

if [ "$userConsent" == "y" ]; then
    read -p "Do you want to provide TM-Manager via HTTP? (y/n) : " httpEn
    read -p "Do you want to provide TM-Manager via HTTPS? (y/n) : " httpsEn

    #User Input
    read -p "Domain without protocol (e.g. domain.tk): " domain
    read -p "Subdomain without protocol (e.g. manager): " subdomain

    if [ "$httpsEn" == "y" ]; then
        read -p "Country Name (2 letter code) (e.g. IN): " certC
        read -p "State or Province Name (e.g. Kerala): " certST
        read -p "Locality Name (e.g. Kochi): " certL
        read -p "Organization Name (e.g. Novocorp Industries Inc): " certO
        read -p "Organizational Unit Name (e.g. IT department): " certOU
    fi

    #Prerequisits
    apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 7F0CEB10
    apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv EA312927
    apt-get install -y cron curl
    apt-get install -y python-software-properties
    apt-get install -y software-properties-common
    curl -sL https://deb.nodesource.com/setup_4.x | bash -
    echo "deb http://repo.mongodb.org/apt/ubuntu trusty/mongodb-org/3.2 multiverse" | tee /etc/apt/sources.list.d/mongodb-org-3.2.list
    add-apt-repository ppa:chris-lea/redis-server
    add-apt-repository ppa:ubuntu-toolchain-r/test
    apt-get update
    apt-get install -y nginx
    apt-get install -y nodejs
    apt-get install -y graphicsmagick
    apt-get install -y mongodb-org
    apt-get install -y redis-server
    apt-get install -y texlive-latex-base
    apt-get install -y texlive-fonts-recommended texlive-fonts-extra texlive-latex-extra texlive-lang-french
    apt-get install -y libstdc++-4.9-dev libssl-dev g++
    apt-get upgrade -y
    curl https://get.acme.sh | sh
    mkdir /www/
    mkdir /www/logs/
    mkdir /www/nginx/
    mkdir /www/acme/
    mkdir /www/ssl/
    mkdir /www/www/
    mkdir /www/node_modules/
    cd /www/
    npm install

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
    cp /www/manager/config.sample /www/manager/config
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

    if [ -f "/www/manager/user.guid" ]; then
        rm /www/manager/user.guid
    fi
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

else
    echo "Sorry, this installation cannot continue."
fi
