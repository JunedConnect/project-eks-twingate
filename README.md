# project-kubernetes-twingate

rough noteson what to mention:
- mention to first do the aws eks updatekubeconfig first before they can start working on the created cluster
- how to install twingate connector (also a specific seciton that if you  use wsl, you just need the windows client installed and that will be enough for it to work)
- how to get your twingate: groupID (htats needed for the resoruce), API key,
- updating the terraform variables and provider configurations with the correct information

side point - make sure to add redundency (i.e. 2 connectors for EC2 instance and also inside the cluster)

have two ways to install inside the cluster:
a - through the connector helm package (which I will make a terraform resource for a connector and Twingate resource, or you mannually create the connector yourself on the teingate site, and and then provide the tokens needs to the connector helm chart, you cna press the maunal option on the website in order to generate the tokens)
b - through the operator helm package (which requires you to create a manifest for a connector and a resource and resourceaccess)


IMPORTANT - TEST to see if you need to create a new network on twingate specfically for kubernetes. this is because, although the first time when you installed the connector helm chart it worked, subsequent attempts for the connector chart and also operator chart do not work since they are defaulting to the ec2 connector when they should be using the kubernetes connector. Explain in the readme that there needs to be two seperaet remote netowrks in order for this to work.


Also mention that you can now access interla resorueces by their dns names. i.e.
pod - <pod-ip-with-dashes>.<namespace>.pod.cluster.local
svc - <service-name>.<namespace>.svc.cluster.local
statefulset - <pod-name>.<service-name>.<namespace>.svc.cluster.local