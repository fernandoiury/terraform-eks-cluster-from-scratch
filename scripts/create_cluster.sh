#!/bin/bash

REQUIRED_SW="kubectl aws-iam-authenticator"

for i in ${REQUIRED_SW}; do
  which ${i} &> /dev/null
  if [[ ${?} -ne 0 ]]; then
    echo "${i} not found in your path"
    exit 1
  fi 
done

AWS_PROF="${1}"
if [[ -z ${AWS_PROF} ]]; then
   echo "USAGE: $(basename $0) <AWS_PROFILE>"
   exit 2
fi

function print_log() {
if [[ ${1} -ne 0 ]]; then
  echo
  echo "######"
  echo "###### NOK - $(date +"%Y-%m-%d %H:%M:%S") - ${2} - exitting"
  echo "######"
  echo
  exit 3
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
CLUSTER_NAME=$(grep 'create_cluster.sh name' ../vars.tf | awk '{ print $3 }' | sed 's/"//g')
CLUSTER_REGION=$(grep 'create_cluster.sh region' ../vars.tf | awk '{ print $3 }' | sed 's/"//g')
aws eks --region ${CLUSTER_REGION} update-kubeconfig --name ${CLUSTER_NAME} --profile ${AWS_PROF}
print_log $? "~/.kube/config configured"

# configuring ALB
curl -s -O https://raw.githubusercontent.com/kubernetes-sigs/aws-alb-ingress-controller/v1.1.0/docs/examples/alb-ingress-controller.yaml && \
curl -s -O https://raw.githubusercontent.com/kubernetes-sigs/aws-alb-ingress-controller/v1.1.0/docs/examples/rbac-role.yaml && \
sed -i '' "s/devCluster/${CLUSTER_NAME}/g" alb-ingress-controller.yaml && \
kubectl apply -f rbac-role.yaml && \
kubectl apply -f alb-ingress-controller.yaml && \
rm -f rbac-role.yaml alb-ingress-controller.yaml
print_log $? "alb-ingress-controller"

# Configuring cluster-autoscaler - for now fixing the version 1.3.6 which is the recommended for k8s 1.11.X (some users report master works, but let's not break things (: )
curl -s -O https://raw.githubusercontent.com/kubernetes/autoscaler/cluster-autoscaler-1.3.6/cluster-autoscaler/cloudprovider/aws/examples/cluster-autoscaler-autodiscover.yaml && \
sed -i '' "s:k8s.io/cluster-autoscaler/<YOUR CLUSTER NAME>:kubernetes.io/cluster/${CLUSTER_NAME}:g" cluster-autoscaler-autodiscover.yaml && \
sed -i '' "s/us-east-1/${CLUSTER_REGION}/g" cluster-autoscaler-autodiscover.yaml && \
sed -i '' '$s:/etc/ssl/certs/ca-certificates.crt:/etc/ssl/certs/ca-bundle.crt:' cluster-autoscaler-autodiscover.yaml && \
kubectl apply -f cluster-autoscaler-autodiscover.yaml && \
rm -f cluster-autoscaler-autodiscover.yaml
print_log $? "cluster-autoscaler"

# TODO add more stuff


# remove temp files
rm -f ../*${CLUSTER_NAME}*
print_log $? "Kubernetes Cluster ${CLUSTER_NAME} Successfully deployed"


# Just proving it works fine
echo "DO YOU WANT TO DEPLOY A TEST APP (ECHOSERVER) TO PROVE IT'S WORKING?"
read question
[[ ${question} != "y" ]] && [[ ${question} != "yes" ]] && [[ ${question} != "Y" ]] && [[ ${question} != "YES" ]] && exit

kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/aws-alb-ingress-controller/v1.1.0/docs/examples/echoservice/echoserver-namespace.yaml && \
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/aws-alb-ingress-controller/v1.1.0/docs/examples/echoservice/echoserver-service.yaml && \
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/aws-alb-ingress-controller/v1.1.0/docs/examples/echoservice/echoserver-deployment.yaml && \
curl -s -O https://raw.githubusercontent.com/kubernetes-sigs/aws-alb-ingress-controller/v1.1.0/docs/examples/echoservice/echoserver-ingress.yaml && \
sed -i '' 's/echoserver.example.com//g' echoserver-ingress.yaml && \
kubectl apply -f echoserver-ingress.yaml && \
rm -f echoserver-ingress.yaml && \
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
