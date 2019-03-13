#!/bin/bash

REQUIRED_SW="kubectl aws-iam-authenticator"

for i in ${REQUIRED_SW}; do
  which ${i} &> /dev/null
  if [[ ${?} -ne 0 ]]; then
    echo "${i} not found in your path"
    exit 2
  fi 
done

AWS_PROF="${1}"
if [[ -z ${AWS_PROF} ]]; then
   echo "USAGE: $(basename $0) <AWS_PROFILE>"
   exit 1
fi

function print_log() {
if [[ ${1} -ne 0 ]]; then
  echo
  echo "######"
  echo "###### NOK - $(date +"%Y-%m-%d %H:%M:%S") - ${2} - exitting"
  echo "######"
  echo
else
  echo
  echo "######"
  echo "###### OK - $(date +"%Y-%m-%d %H:%M:%S") - ${2}"
  echo "######"
  echo
fi
}

echo "Make sure ../vars.tf is configured PROPERLY!"
echo "DO YOU REALLY WANT TO CONTINUE? (y/N)"
read question
[[ ${question} != "y" ]] && [[ ${question} != "yes" ]] && [[ ${question} != "Y" ]] && [[ ${question} != "YES" ]] && exit

CURDIR=$(pwd)

cd .. && \
AWS_PROFILE=${AWS_PROF} terraform init && \
AWS_PROFILE=${AWS_PROF} terraform apply -auto-approve  && \
cd ${CURDIR} && \
print_log $? "Terraform Applied Sucessfully"

# configuring kubectl
[[ $(stat ~/.kube/config &> /dev/null) ]] && echo "Moving ~/.kube/config to ~/.kube/config.bak" && mv ~/.kube/config stat ~/.kube/config.bak
CLUSTER_NAME=$(grep 'create_cluster.sh' ../vars.tf | awk '{ print $3 }' | sed 's/"//g')
aws eks --region us-east-1 update-kubeconfig --name ${CLUSTER_NAME} --profile ${AWS_PROF}
print_log $? "~/.kube/config configured"

# configuring ALB
curl -s -O https://raw.githubusercontent.com/kubernetes-sigs/aws-alb-ingress-controller/v1.1.0/docs/examples/alb-ingress-controller.yaml
curl -s -O https://raw.githubusercontent.com/kubernetes-sigs/aws-alb-ingress-controller/v1.1.0/docs/examples/rbac-role.yaml
sed -i '' "s/devCluster/${CLUSTER_NAME}/g" alb-ingress-controller.yaml
kubectl apply -f rbac-role.yaml
kubectl apply -f alb-ingress-controller.yaml
print_log $? "alb-ingress-controller"

# TODO add more stuff

print_log $? "Kubernetes Cluster ${CLUSTER_NAME} Successfully deployed"

# Just proving it works fine
echo "DO YOU WANT TO DEPLOY A TEST APP (ECHOSERVER) TO PROVE IT'S WORKING?"
read question
[[ ${question} != "y" ]] && [[ ${question} != "yes" ]] && [[ ${question} != "Y" ]] && [[ ${question} != "YES" ]] && exit

kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/aws-alb-ingress-controller/v1.1.0/docs/examples/echoservice/echoserver-namespace.yaml && \
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/aws-alb-ingress-controller/v1.1.0/docs/examples/echoservice/echoserver-service.yaml && \
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/aws-alb-ingress-controller/v1.1.0/docs/examples/echoservice/echoserver-deployment.yaml

curl -s -O https://raw.githubusercontent.com/kubernetes-sigs/aws-alb-ingress-controller/v1.1.0/docs/examples/echoservice/echoserver-ingress.yaml
sed -i '' 's/echoserver.example.com//g' echoserver-ingress.yaml
kubectl apply -f echoserver-ingress.yaml
print_log $? "echoserver-ingress"
sleep 15
LB_ADDR=$(kubectl describe ing -n echoserver echoserver | grep 'Address:' | awk '{ print $NF }')

WAIT_FOR_LB=30
TRY_LB=10
COUNT=0
while [[ ${COUNT} -lt ${TRY_LB} ]]; do
  echo waiting $LB_ADDR to be provisioned.
  curl $LB_ADDR &> /dev/null
  if [[ ${?} -eq 0 ]]; then
    print_log $? "$LB_ADDR"
    curl "$LB_ADDR"
    break
  else
   sleep $WAIT_FOR_LB
   ((COUNT++))
  fi
done

echo
echo

print_log $? "echoserver up and running on http://${LB_ADDR}"
