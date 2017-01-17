kill -9 $(lsof -i :9999 | grep "total" | awk {'print $2'}) > /dev/null
if [ -f "/www/manager/manager.log" ]; then
  cp /www/manager/manager.log /www/manager/manager_$(date +%F_%R).log
fi
/usr/bin/node --nouse-idle-notification --expose-gc --max_inlined_source_size=1200 /www/manager/release.js 9999 1> /www/manager/manager.log 2> /www/manager/manager.err &
