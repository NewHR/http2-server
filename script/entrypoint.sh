#!/bin/sh
###
echo "Init env"
mkdir -pv /var/log/nginx
[ ! -d "/etc/nginx/conf.d" ] && mkdir -vp "/etc/nginx/conf.d"
[ ! -d "/etc/nginx/ssl"    ] && mkdir -vp "/etc/nginx/ssl"
LELD="/etc/letsencrypt/live"

###
echo "Enviroument variables"
echo "TIMEZONE=$TIMEZONE"
echo "LETSENCRYPT=$LETSENCRYPT"
echo "LE_EMAIL=$LE_EMAIL"
echo "LE_RT=$LE_RT"

###
echo "init and start server daemon"

###
echo "setup time zone to ${TIMEZONE?Not defined!}"
cp -v /usr/share/zoneinfo/$TIMEZONE /etc/localtime && \
    echo $TIMEZONE > /etc/timezone && \

###
echo "nginx config dir ${NGDIR:=/etc/nginx}"
echo "nginx web root dir ${WEBROOT:=/usr/share/nginx/html}"

###
echo "setup ssl"
echo "ssl refresh time ${LE_RT:=80d}"

###
#DOMAIN_LIST=$(echo "${LE_DNAME?Not defined!}" | tr ";" "\n")
DOMAIN_LIST=""

###
cp -vf $NGDIR/services/*.conf $NGDIR/conf.d/
for f in `ls $NGDIR/conf.d/*.conf`
do
    echo "Parse $f"
    dmn=`basename ${f%.conf}`
    DOMAIN_LIST="$DOMAIN_LIST;$dmn"

    d1=`echo $dmn|cut -d. -f1`
    d2=`echo $dmn|cut -d. -f2`
    d3=`echo $dmn|cut -d. -f3`
    if [ ! -z "$d3" ]
    then
        subdomain=$d1
        domain="$d2.$d3"
        echo "Detect subdomain $subdomain / $domain"
    else
        domain=$dmn
        subdomain="error-subdomain-path"
    fi

    sslkey="$NGDIR/ssl/$dmn/privkey.pem"
    sslcrt="$NGDIR/ssl/$dmn/fullchain.pem"

    echo "Configure domain $dmn"
    sed -i "s|DOMAINNAME|$dmn|g;s|WEBROOT|$WEBROOT|g" $f
    sed -i "s|SSL_KEY|$sslkey|g;s|SSL_CRT|$sslcrt|g"  $f
    sed -i "s|SUBDOMAIN|$subdomain|g" $f
    sed -i "s|DOMAIN|$domain|g" $f
done

###
echo "check dhparams.pem"
if [ ! -f "$NGDIR/ssl/dhparams.pem" ]; then
    echo "make dhparams"
    cd $NGDIR/ssl/
    openssl dhparam -out dhparams.pem 2048
    chmod 600 dhparams.pem
fi

###
echo "disable all services"
[ -d "$NGDIR/conf.d.disabled" ] && rm -vrf "$NGDIR/conf.d.disabled"
mv -vf $NGDIR/conf.d $NGDIR/conf.d.disabled

###
(
    echo "await starting nginx daemon 5 seconds ..."
    sleep 5
    echo "start letsencrypt updater"
    while :
    do
	    echo "trying to update letsencrypt ..."

        if [ "true" != "${LETSENCRYPT}" ]
        then
            echo "letsencrypt renew certificates disabled"
        else
            echo "DOMAIN_LIST: $DOMAIN_LIST"
            for dmn in $(echo $DOMAIN_LIST|tr ";" "\n")
            do
                certbot certonly       \
                    -tn                \
                    --agree-tos        \
                    --renew-by-default \
                    --webroot          \
                    --email $LE_EMAIL  \
                    -w $WEBROOT        \
                    -d $dmn            \

                ssld="$NGDIR/ssl/$dmn"
                echo "SSL dir: $ssld"
                [ ! -d $ssld ] && mkdir -vp $ssld
                cp -fv $LELD/$dmn/privkey.pem   $ssld/privkey.pem
                cp -fv $LELD/$dmn/fullchain.pem $ssld/fullchain.pem
            done
        fi

        echo "return back and enable all services"
        mv -v $NGDIR/conf.d.disabled $NGDIR/conf.d
        echo "reload nginx with ssl and http/2"
        nginx -s reload
        sleep ${LE_RT}
    done
) &
nginx -g "daemon off;"

#EOF#