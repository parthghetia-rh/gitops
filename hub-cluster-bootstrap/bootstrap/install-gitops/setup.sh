#!/bin/bash

LANG=C
SLEEP_SECONDS=45

echo ""
echo "Installing GitOps Operator."

kustomize build ../../components/policies/gitops/base/manifests/gitops-subscription | oc apply -f -

echo "Pause $SLEEP_SECONDS seconds for the creation of the gitops-operator..."
sleep $SLEEP_SECONDS

echo "Waiting for operator to start"
until oc get deployment gitops-operator-controller-manager -n openshift-operators
do
  sleep 5;
done

echo "Waiting for openshift-gitops namespace to be created"
until oc get ns openshift-gitops
do
  sleep 5;
done

echo "Waiting for deployments to start"
until oc get deployment cluster -n openshift-gitops
do
  sleep 5;
done

echo "Waiting for all pods to be created"
deployments=(cluster kam openshift-gitops-applicationset-controller openshift-gitops-redis openshift-gitops-repo-server openshift-gitops-server)
for i in "${deployments[@]}";
do
  echo "Waiting for deployment $i";
  oc rollout status deployment $i -n openshift-gitops
done

echo "Apply overlay to override default instance"
# echo "Create default instance of gitops operator"
kustomize build ../../components/policies/gitops/base/manifests/gitops-instance/base  |
  yq -y ".spec.repo.env |= map(select(.name == \"INFRASTRUCTURE_ID\").value=\"$INFRASTRUCTURE_ID\")" |
  yq -y ".spec.repo.env |= map(select(.name == \"CLUSTER_ID\").value=\"$CLUSTER_ID\")" |
  yq -y ".spec.repo.env |= map(select(.name == \"CLUSTER_NAME\").value=\"$CLUSTER_NAME\")" |
  yq -y ".spec.repo.env |= map(select(.name == \"SUB_DOMAIN\").value=\"$SUB_DOMAIN\")" |
  oc apply -f -

sleep 10
echo "Waiting for all pods to redeploy"
deployments=(cluster kam openshift-gitops-applicationset-controller openshift-gitops-redis openshift-gitops-repo-server openshift-gitops-server)
for i in "${deployments[@]}";
do
  echo "Waiting for deployment $i";
  oc rollout status deployment $i -n openshift-gitops
done

echo "GitOps Operator ready"