.PHONY: help setup-operator setup-connector destroy-operator destroy-connector

# the below lines are used to include the .env file and export the variables
-include .env
export

help:
	@echo "Available commands:"
	@echo "  make setup-operator          	- Install Twingate Operator on EKS cluster"
	@echo "  make setup-connector         	- Install Twingate Connector on EKS cluster"
	@echo "  make destroy-operator        	- Uninstall Twingate Operator"
	@echo "  make destroy-connector       	- Uninstall Twingate Connector"


setup-operator:
	@echo "Creating namespace..."
	kubectl create namespace tg || true
	
	@echo "\n Adding Helm repositories..."
	helm repo add twingate https://twingate.github.io/helm-charts || true
	
	@echo "\n Installing Twingate Operator..."
	@helm install twop oci://ghcr.io/twingate/helmcharts/twingate-operator \
		--version $(TWINGATE_OPERATOR_VERSION) \
		--namespace tg \
		--values helm-values/twingate-operator-values.yml \
		--set twingateOperator.network=$(TWINGATE_NETWORK) \
		--set twingateOperator.apiKey=$(TWINGATE_API_TOKEN) \
		--set twingateOperator.remoteNetworkName=eks-network \
		--set kubernetes-access-gateway.twingate.network=$(TWINGATE_NETWORK) || (echo "\n ERROR: Failed to install Twingate Operator!" && exit 1)
	
	@echo "\n Applying Twingate resources..."
	@kubectl apply -f twingate-resources.yml || (echo "\n ERROR: Failed to apply Twingate resources!" && exit 1)
	
	@echo "\n Applying whoami application..."
	@kubectl apply -f test-whoami.yml || (echo "\n ERROR: Failed to apply whoami application!" && exit 1)
	
	@echo "\n Setup complete! Twingate Operator is ready."
	@echo "To verify installation:"
	@echo "  kubectl get pods -n twingate"

setup-connector:
	@echo "Creating namespace..."
	kubectl create namespace tg || true
	
	@echo "\n Adding Helm repositories..."
	helm repo add twingate https://twingate.github.io/helm-charts || true
	
	@echo "\n Installing Twingate Connector..."
	@helm install twingate-connector twingate/connector \
		--version $(TWINGATE_CONNECTOR_VERSION) \
		--namespace tg \
		--set connector.network=$(TWINGATE_NETWORK) \
		--set connector.accessToken=$(KUBERNETES_CONNECTOR_ACCESS_TOKEN) \
		--set connector.refreshToken=$(KUBERNETES_CONNECTOR_REFRESH_TOKEN) || (echo "\n ERROR: Failed to install Twingate Connector!" && exit 1)
	
	@echo "\n Applying whoami application..."
	@kubectl apply -f test-whoami.yml || (echo "\n ERROR: Failed to apply whoami application!" && exit 1)
	
	@echo "\n Setup complete! Twingate Connector is ready."
	@echo "To verify installation:"
	@echo "  kubectl get pods -n twingate"

destroy-operator:
	@echo "Removing Twingate resources..."
	@kubectl delete -f twingate-resources.yml || true
	@echo "Removing test application..."
	@kubectl delete -f test-whoami.yml || true
	@echo "Uninstalling Twingate Operator..."
	@helm uninstall twop -n tg || (echo "\n ERROR: Failed to uninstall Twingate Operator!" && exit 1)
	@echo "\n Twingate Operator and resources have been removed."

destroy-connector:
	@echo "Removing test application..."
	@kubectl delete -f test-whoami.yml || true
	@echo "Uninstalling Twingate Connector..."
	@helm uninstall twingate-connector -n tg || (echo "\n ERROR: Failed to uninstall Twingate Connector!" && exit 1)
	@echo "\n Twingate Connector and resources have been removed."
