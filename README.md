# Few important tips

----------------------------------------------------------------------------------------------
View the active KubeConfig

kubectl config view  (detailed)

kubectl config current-context

----------------------------------------------------------------------------------------------


----------------------------------------------------------------------------------------------

To generate kubeconfig
aws eks --region {AWS_REGION} update-kubeconfig --name {eks_cluster_name} --profile account-nonprod-admin

To test a temporary context
export KUBECONFIG=/tmp/cluster_01.tmp
aws eks update-kubeconfig --name {eks_cluster_name} --region {AWS_REGION} --profile account-nonprod-developer

To switch
unset KUBECONFIG

----------------------------------------------------------------------------------------------


----------------------------------------------------------------------------------------------

kubectl auth can-i <verb> <resource> 
– Checks RBAC (Role-Based Access Control) permissions to verify if a user or service account can perform a specific action (e.g., kubectl auth can-i create pods)


---------------------------------------------------------------------------------------------
