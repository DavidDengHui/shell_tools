#!/usr/bin/bash

acme_root="/root/.acme.sh"
info_root="/www/server/panel/vhost/ssl/covear.top"
cert_root="/www/server/panel/vhost/cert/acme/covear.top_ecc"
host_path="/www/server/panel/vhost/cert"
export LE_WORKING_DIR=$acme_root

cd /root
echo "=============================="
echo "[ DATE: `date` ]"
echo "[ ADDR: `pwd` ]"
echo "[ BASH: Renew-SSL ]"

echo "+--------------------"
$acme_root/acme.sh list
echo "+--------------------"

now_date=$( date +'%Y-%m-%d' )
echo "[  Now_Date  ]: "$now_date
begin_date=$(date -d $($acme_root/acme.sh list | grep *.covear.top | awk '{print $5}') +'%Y-%m-%d')
echo "[ Begin_Date ]: "$begin_date
renew_date=$(date -d "1 day ago $($acme_root/acme.sh list | grep *.covear.top | awk '{print $6}')" +'%Y-%m-%d')
echo "[ Renew_Date ]: "$renew_date
end_date=$(date -d "90 day $begin_date" +'%Y-%m-%d')
echo "[  End_Date  ]: "$end_date

if [ $(date -d "$now_date" +'%s') -ge $(date -d "$renew_date" +'%s') ]; then 
    while true
    do
        echo "[ Try To Renew ]"
        $acme_root/acme.sh --renew --domain covear.top --ecc --force
        echo "--------------------"
        $acme_root/acme.sh list
        echo "--------------------"
	now_date=$( date +'%Y-%m-%d' )
	begin_date=$( date -d $($acme_root/acme.sh list | grep *.covear.top | awk '{print $5}') +'%Y-%m-%d' )
        if [ "$now_date"x = "$begin_date"x ]; then
            echo "+ [  Now_Date  ]: "$now_date
            echo "+ [ Begin_Date ]: "$begin_date
            renew_date=$(date -d "1 day ago $($acme_root/acme.sh list | grep *.covear.top | awk '{print $6}')" +'%Y-%m-%d')
            echo "+ [ Renew_Date ]: "$renew_date
            end_date=$(date -d "90 day $begin_date" +'%Y-%m-%d')
            echo "+ [  End_Date  ]: "$end_date
            break
        fi
    done
else 
    echo "[ Verification succeeded ]"
fi

function cp_cert() {
\cp -rf $cert_root/fullchain.cer $1/fullchain.pem
\cp -rf $cert_root/covear.top.key $1/privkey.pem
}

function is_cert() {
acme_list=$($acme_root/acme.sh list | grep *.covear.top | awk '{print $1}'),$($acme_root/acme.sh list | grep *.covear.top | awk '{print $3}')
host_list=${acme_list//\*/}
list=${host_list//,/ }
for host in ${list[@]}
do
  len=$(echo $host | grep -o "\." | wc -l)
  if [[ $1 =~ $host ]] && [[ $(echo $1 | grep -o "\." | wc -l) == $len ]]; then
    echo - Find: $host_path/$1
    cp_cert $host_path/$1
    break
  fi
done
}

function read_dir() {
for file in `ls $1`
do
  if [ -d $1/$file ]; then
    is_cert $file
  fi
done
}

echo "[ Import vHost_Cert ]"
read_dir $host_path

echo "[ Reload NGINX Server ]"
nginx -t
service nginx reload

echo "[ Import BT_Panel: $info_root ]"

notAfter=$(date -d "$end_date" +'%Y-%m-%d')
notBefore=$(date -d "$begin_date" +'%Y-%m-%d')
endtime=$((($(date -d "$end_date" +%s)-$(date -d "$now_date" +%s))/60/60/24-1))

echo -n '{"issuer": "ZeroSSL ECC Domain Secure Site CA", "notAfter": "'$notAfter'", "notBefore": "'$notBefore'", "dns": ["covear.top", "*.covear.top", "*.source.host.covear.top", "*.tcc.covear.top", "*.tms.covear.top"], "subject": "covear.top", "endtime": '$endtime'}' > $info_root/info.json
cp_cert $info_root

ls -all $info_root
echo -e "+--------------------"
cat $info_root/info.json
echo -e "\n+--------------------\n"

