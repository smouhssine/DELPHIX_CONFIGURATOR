#!/bin/sh

#This script will automate the configure of your DELPIX ENGINE.

#Script to be executed after the ova load and data storage disks have been affected affect 

#Also you have to have and IP to connect to the engine either in dhcp or static one

 

 

#Initiated by Marcin Przepiorowski Jul 2017

#Updated by Mouhssine SAIDI Jul 2017

#Updated by Mouhssine SAIDI 02-03 Jul 2019 for 5.3.x version 1.0

#Updated by Mouhssine SAIDI 11 Jul 2019 for setting the engine type

 

# The guest running this script should have curl binary

###############################

#         Var section         #

###############################

#Replace x.x.x.x with the IP of the engine

URL=http://x.x.x.x

OLD_SYSADMIN_PASS=sysadmin

NEW_SYSADMIN_PASS=delphix

OLD_ADMIN_PASS=delphix

NEW_ADMIN_PASS=Delphix_123

EMAILADDRESS=noreplay@cutomer.com

ENGTYPE=VIRTUALIZATION #use MASKING value for a masking engine 

 

echo

echo

echo "STARTING ENGINE CONFIGURATION"

echo

echo

echo "Create session"

curl -s -X POST -k --data @- ${URL}/resources/json/delphix/session \

    -c ~/cookies.txt -H "Content-Type: application/json" <<EOF

{

    "type": "APISession",

    "version": {

        "type": "APIVersion",

        "major": 1,

        "minor": 10,

        "micro": 3

    }

}

EOF

 

 

echo

echo

 

#echo "Logon as:" ${USR}/${PASS}

echo "Logon as: syadmin/sysadmin"

curl -s -X POST -k --data @- ${URL}/resources/json/delphix/login \

    -b ~/cookies.txt -c ~/cookies.txt -H "Content-Type: application/json" <<EOF

{

    "type": "LoginRequest",

    "username": "sysadmin",

                "password": "$OLD_SYSADMIN_PASS"

}

EOF

echo

echo

 

#S2 - SETUP SYSADMIN ACCOUNT

echo "Set new password for sysadmin"

curl -s -X POST -k --data @- ${URL}/resources/json/delphix/user/USER-1/updateCredential \

    -b ~/cookies.txt -H "Content-Type: application/json" <<EOF

    {

        "type": "CredentialUpdateParameters",

        "newCredential": {

            "type": "PasswordCredential",

            "password": "$NEW_SYSADMIN_PASS"

        }

    }

EOF

echo

echo

 

echo "Set sysadmin to not ask for new password after change"

curl -s -X POST -k --data @- ${URL}/resources/json/delphix/user/USER-1 \

    -b ~/cookies.txt -H "Content-Type: application/json" <<EOF

    {

        "type": "User",

        "passwordUpdateRequested": false,

        "emailAddress": "$EMAILADDRESS"

    }

EOF

echo

echo

 

#S2.1 - Create domain storage

# This step also plays the role of click on submit buton in GUI during configuration

#POSTDEVICES="{\"type\": \"ControlNodeInitializationParameters\",\"devices\": ["

POSTDEVICES="{\"type\": \"SystemInitializationParameters\",\"defaultUser\":\"admin\", \"defaultPassword\": \"$NEW_SYSADMIN_PASS\", \"devices\": ["

 

echo "Grab a list of disk devices"

echo

disks=`curl -s -X GET ${URL}/resources/json/delphix/storage/device -b ~/cookies.txt -H "Content-Type: application/json"`

#echo $disks

echo

echo

# line split

#lines=`echo $disks | cut -d "[" -f2 | cut -d "]" -f1 | awk -v RS='},{}' -F: '{print $0}'`

lines=`echo $disks | cut -d "[" -f2 | cut -d "]" -f1 | awk -v RS='},{' -F: '{print $0}'`

echo $lines

 

# add non configured devices to intialization string

while read -r line ; do

  type=`echo $line | sed -e 's/[{}]/''/g' | sed s/\"//g | awk -v RS=',' -F: '$1=="configured"{print $2}'`

  echo $type;

  echo

  echo

  if [[ "$type" == "false" ]]; then

    POSTDEVICES+="\""

    dev=`echo $line | sed -e 's/[{}]/''/g' | sed s/\"//g | awk -v RS=',' -F: '$1=="reference"{print $2}'`

    POSTDEVICES+=$dev

    POSTDEVICES+="\","

  fi

done <<< "echo $lines"

 

POSTDEVICES=${POSTDEVICES::${#POSTDEVICES}-1}

POSTDEVICES+="]}"

echo $POSTDEVICES

echo

echo "Kick off configuration"

 

echo $POSTDEVICES | curl -s -X POST -k --data @- ${URL}/resources/json/delphix/domain/initializeSystem \

    -b ~/cookies.txt -H "Content-Type: application/json"

 

echo

 

#Wait for the management stack to restart following storage domaine creation

sleep 60

 

echo "Create session"

curl -s -X POST -k --data @- ${URL}/resources/json/delphix/session \

    -c ~/cookies.txt -H "Content-Type: application/json" <<EOF

{

    "type": "APISession",

    "version": {

        "type": "APIVersion",

        "major": 1,

        "minor": 10,

        "micro": 3

    }

}

EOF

echo

echo

 

#echo "Logon as:" ${USR}/${PASS}

echo "Logon as: syadmin/sysadmin"

curl -s -X POST -k --data @- ${URL}/resources/json/delphix/login \

    -b ~/cookies.txt -c ~/cookies.txt -H "Content-Type: application/json" <<EOF

{

    "type": "LoginRequest",

    "username": "sysadmin",

                "password": "$NEW_SYSADMIN_PASS"

}

EOF

echo

echo

 

#S4 - SETUP TIME

echo "Set Date and Time manually"

curl -s -X POST -k --data @- ${URL}/resources/json/delphix/service/time \

    -b ~/cookies.txt -H "Content-Type: application/json" <<EOF

    {  

      "type": "TimeConfig",

      "systemTimeZone": "Europe/Paris"

  }

EOF

echo

echo

 

 

#S5 - SETUP NETWORK

#     IP / GW / NETMASK / DNS / HOTNAME

#     THIS PART WILL BE ALREADY SET BY BP2I

#     LEAVE AS DEFAULT

 

 

#S6 - NETWORK SECURITY

#     LEAVE AS DEFAULT

 

#S7 - STORAGE

#     LEAVE AS DEFAULT

#     3 data disks assigned each with 300G

   

#S8 - SERVICEABILITY

# Disable (phone home service) and (usage analytics)

echo "Disable serviceability"

curl -s -X POST -k --data @- ${URL}/resources/json/delphix/service/phonehome \

    -b ~/cookies.txt -H "Content-Type: application/json" <<EOF

{

    "type": "PhoneHomeService",

    "enabled": false

}

EOF

echo

echo

 

curl -s -X POST -k --data @- ${URL}/resources/json/delphix/service/userInterface \

    -b ~/cookies.txt -H "Content-Type: application/json" <<EOF

{

    "type": "UserInterfaceConfig",

    "analyticsEnabled": false

}

EOF

 

echo

echo

 

#S9 - AUTHENTICATION

#     LEAVE AS DEFAULT

 

#S10 - KERBEROS

#     LEAVE AS DEFAULT

 

#S11 - LEAVE AS UNREGISTRED

#      THE REGISTRATION PROCESS WILL BE DONE

#      MANUALLY AFTERWARD

 

: <<EOC

#S10 - REGISTRATION OF THE ENGINE

echo "Register appliance"

curl -s -X POST -k --data @- ${URL}/resources/json/delphix/registration/status \

    -b ~/cookies.txt -H "Content-Type: application/json" <<EOF

    {

      "status":"REGISTERED",

      "type":"RegistrationStatus"

    }

EOF

EOC

echo

echo

 

#S12 - SETUP ADMIN ACCOUNT

 

# Create API session

curl -s -X POST -k --data @- ${URL}/resources/json/delphix/session \

    -c ~/cookies.txt -H "Content-Type: application/json" <<EOF

{

    "type": "APISession",

    "version": {

        "type": "APIVersion",

        "major": 1,

        "minor": 10,

        "micro": 3

    }

}

EOF

echo

 

echo "Authenticating to $DE as admin..."

echo

# Authenticate to the DelphixEngine

curl -s -X POST -k --data @- ${URL}/resources/json/delphix/login \

        -b ~/cookies.txt -c ~/cookies.txt -H "Content-Type: application/json" <<EOF

{

        "type": "LoginRequest",

        "username": "admin",

        "password": "$OLD_ADMIN_PASS"

}

EOF

echo

 

echo "Set new password for admin"

curl -s -X POST -k --data @- ${URL}/resources/json/delphix/user/USER-2/updateCredential \

    -b ~/cookies.txt -H "Content-Type: application/json" <<EOF

    {

                    "type": "CredentialUpdateParameters",

        "newCredential": {

        "type": "PasswordCredential",

        "password": "$NEW_ADMIN_PASS"

        }

    }

EOF

echo

echo

 

echo "Set admin to not ask for new password after change"

echo

curl -s -X POST -k --data @- ${URL}/resources/json/delphix/user/USER-2 \

    -b ~/cookies.txt -H "Content-Type: application/json" <<EOF

    {

        "type": "User",

        "passwordUpdateRequested": false,

        "emailAddress": "$EMAILADDRESS"

    }

EOF

 

sleep 100

 

echo "Create session"

curl -s -X POST -k --data @- ${URL}/resources/json/delphix/session \

    -c ~/cookies.txt -H "Content-Type: application/json" <<EOF

{

    "type": "APISession",

    "version": {

        "type": "APIVersion",

        "major": 1,

        "minor": 10,

        "micro": 3

    }

}

EOF

echo

echo

 

#echo "Logon as:" ${USR}/${PASS}

echo "Logon as: syadmin/sysadmin"

curl -s -X POST -k --data @- ${URL}/resources/json/delphix/login \

    -b ~/cookies.txt -c ~/cookies.txt -H "Content-Type: application/json" <<EOF

{

    "type": "LoginRequest",

    "username": "sysadmin",

                "password": "$NEW_SYSADMIN_PASS"

}

EOF

echo

echo

 

#S3 - SETUP ENGINE TYPE

#     MAKIKING OR VIRTUALIZATION

echo "Set engine type to Virtualization"

curl -s -X POST -k --data @- ${URL}/resources/json/delphix/system \

    -b ~/cookies.txt -H "Content-Type: application/json" <<EOF

{

    "type": "SystemInfo",

    "engineType": "$ENGTYPE"

}

EOF

echo

echo

 

 

echo

echo

echo "END OF ENGINE CONFIGURATION"

echo

echo
