#!/bin/sh

TEAM=$1
UPGRADE_VERSION=$2
APP=$3
CLUSTER_ID=$4 #c-jpxcn
PROJECT_ID=$5 #p-zwxgj
TOKEN=$6

if [[ -z $TEAM || -z $UPGRADE_VERSION || -z $APP || -z $CLUSTER_ID || -z $PROJECT_ID ]]; then
  echo 'One or more variables are undefined, exiting script ...'
  exit 1
fi

echo "Fetching required metadata ..."
HOSTNAME=$(kubectl get --all-namespaces ingress -l app=$APP,team=$TEAM -o jsonpath="{.items[0].spec.rules[0].host}")
WEBCONTEXT=$(kubectl get --all-namespaces ingress -l app=$APP,team=$TEAM -o jsonpath="{.items[0].spec.rules[0].http.paths[0].path}")
POD=$(kubectl get pod --all-namespaces -l app=$APP,team=$TEAM -o jsonpath="{.items[0].metadata.name}")
CURRENT_VERSION=$(kubectl get --all-namespaces deployment -l app=$APP,team=$TEAM -o jsonpath="{.items[0].spec.template.spec.containers[1].image}")
CURRENT_VERSION=$(cut -d ":" -f2 <<< "$CURRENT_VERSION")
CURRENT_VERSION_NUMBER=$(echo "$CURRENT_VERSION" | rev | cut -d "-" -f2 | rev)

if [[ -z $HOSTNAME || -z $WEBCONTEXT || -z $POD || -z $CURRENT_VERSION || -z $CURRENT_VERSION_NUMBER ]]; then
  echo 'One or more variables could not be fetched, exiting script ...'
  exit 1
fi

echo "All metadata fetched successfully, starting the upgrade process..."

echo "Logging in to rancher ..."
rancher login https://rancher.cd.murex.com/ --token $TOKEN --context $CLUSTER_ID:$PROJECT_ID
APP_VERSION=$(rancher app | grep $TEAM-$APP | awk '{print $6}')
echo "Successfully logged in to rancher"

echo "Removing ingress ..."
rancher app upgrade $TEAM-$APP $APP_VERSION --set ingress.enabled='false' --set $APP.image.tag="$CURRENT_VERSION" --set hostname="$HOSTNAME" --set team="$TEAM"
echo "Ingress removed"

echo "Backing up database ..."
kubectl -n $APP exec $POD -c sonardb -- bash -c "pg_dump -U sonar sonar > /var/lib/postgresql/backups/db_dump-$CURRENT_VERSION_NUMBER.sql"
echo "Dump db_dump-$CURRENT_VERSION_NUMBER.sql created, you can find it in /var/lib/postgresql/backups"

echo "Waiting for 5 seconds..."
sleep 5s

echo "Deploying the upgrade ..."
rancher app upgrade $TEAM-$APP $APP_VERSION --set ingress.enabled='true' --set $APP.image.tag="$UPGRADE_VERSION" --set hostname="$HOSTNAME" --set team="$TEAM"

echo "Initiating playbook ..."
ansible-playbook /data/$TEAM/$APP/upgrade/upgrade.yaml --extra-vars "web_context=$WEBCONTEXT hostname=$HOSTNAME"

echo "SonarQube successfully upgrade it to $UPGRADE_VERSION, you can access the app via http://$HOSTNAME$WEBCONTEXT/new"
