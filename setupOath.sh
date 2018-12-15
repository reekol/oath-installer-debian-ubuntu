#!/bin/bash


apt-get install libpam-oath oathtool qrencode 2>&1 > /dev/null

me=$(whoami)
host=$(hostname)
seed=$(head -10 /dev/urandom | sha512sum | cut -b 1-30)
authType="required" # required || sufficient || requisite
type="HOTP"
window="30"
pinLen="6"
cnf="/etc/users.oath"
sshdConfig="/etc/ssh/sshd_config"
sshdPam="/etc/pam.d/sshd"
typeLower=$(echo $type | tr '[:upper:]' '[:lower:]')



setSeed(){
#    echo -e "\n$type/T$window/$pinLen $1  -   $2" > $cnf
    echo -e "$type $1  -   $2\n" > $cnf
    chmod 600 $cnf && chown root $cnf
    echo -e "\e[32m" && cat $cnf && echo -e "\e[32m"
}


setSshdConfig(){
    local now=$(date +%Y-%m-%d-%H-%M-%s)
    read -p $'\e[33mReconfigure $sshdConfig [Y/N]?\e[0m' -n 1 -r REPLY
    echo
    echo "[$REPLY]"
    if [[  $REPLY =~ ^[Yy]$ ]]
    then
        cp --verbose $sshdConfig $sshdConfig.$now.bak
        sed -i "s/^UsePAM\ .*/UsePAM\ yes/g" $sshdConfig
        sed -i "s/^ChallengeResponseAuthentication\ .*/ChallengeResponseAuthentication\ yes/g" $sshdConfig
        echo -e "\e[32m"
        cat $sshdConfig | grep 'UsePAM\|ChallengeResponseAuthentication'
        echo -e "\e[0m"
        service sshd restart
    fi
}

setSshdAuth(){
    pamExists=$(cat $sshdPam | grep "pam_oath.so" | wc -l)
    local now=$(date +%Y-%m-%d-%H-%M-%s)
    cp --verbose $sshdPam $sshdPam.$now.bak
    if [ "$pamExists" -gt "0" ]
    then
        local cnfEscaped=$(echo $cnf | sed 's/\//\\\//g' )
        echo -e "\e[31mpam_oath found in $sshdPam\n Replacing\e[0m"
        sed -i "s/.*pam_oath.*/auth\ $authType\ pam_oath\.so\ usersfile\=$cnfEscaped\ window\=$window\ digits\=$pinLen/g"  $sshdPam
    else
        read -p $'\e[33mAdd pam_oath to $sshdPam [Y/N]?\e[0m' -n 1 -r REPLY
        echo
        echo "[$REPLY]"
        if [[  $REPLY =~ ^[Yy]$ ]]
        then
#            echo -e "auth $authType pam_oath.so usersfile=$cnf\n\n$(cat $sshdPam)" > $sshdPam
            echo -e "auth $authType pam_oath.so usersfile=$cnf window=$window digits=$pinLen\n\n$(cat $sshdPam)" > $sshdPam
        fi
    fi
    echo -e "------------- $sshdPam (3) ------------------\e[32m" && cat $sshdPam | grep pam_oath && echo -e '\e[0m-----------------------------------------------'
}

generateQr(){
    echo -e "\e[107m"
    secret=$(oathtool --$typeLower -v $3 | grep Base32 | cut -d ' ' -f3)
    qrencode -t ASCII "otpauth://$typeLower/$1@$2?secret=$secret" | sed $'s/#/\e[40m \e[0m\e[107m/g'
    echo -e "\e[0m"
    echo -e "Navigate to your Favorite Mobile OS's store and download FreeOTP app to scan qr code and start using OneTime authentication"
    echo -e "Or use this tool [NOT RECOMMENDED- Seed provided]: oathtool --totp -v $3 "
}

getOtp(){
    local pin=$(oathtool -s$window --$typeLower -d6 $seed)
    echo -e "[ Current pin: \e[32m$pin\e[0m ]% oathtool -v -s$window --$typeLower -d6 $seed" && echo ""
}

pause(){
    read -p $'\e[33mEnter to continue\e[0m' -n 1 -r
}

setSeed $me $seed && pause
setSshdConfig && pause
setSshdAuth && pause
generateQr $me $host $seed && getOtp $seed
