.PHONY: help setup-operator setup-connector upgrade-operator upgrade-connector destroy-operator destroy-connector

# the below lines are used to include the .env file and export the variables
-include .env
export

help:
	@echo "Available commands:"
	@echo "  make setup-operator          	- Install Twingate Operator on EKS cluster"
	@echo "  make setup-connector         	- Install Twingate Connector on EKS cluster"
	@echo "  make upgrade-operator        	- Upgrade Twingate Operator Helm release"
	@echo "  make upgrade-connector       	- Upgrade Twingate Connector Helm release"
	@echo "  make destroy-operator        	- Uninstall Twingate Operator"
	@echo "  make destroy-connector       	- Uninstall Twingate Connector"


setup-operator:
	@echo "Creating namespace..."
	kubectl create namespace tg || true
	
	@echo "\n Adding Helm repositories..."
	helm repo add twingate https://twingate.github.io/helm-charts || true
	
	@echo "\n Installing Twingate Operator..."
	helm install twop oci://ghcr.io/twingate/helmcharts/twingate-operator \
		--version $(TWINGATE_OPERATOR_VERSION) \
		--namespace tg \
		--values helm-values/twingate-operator-values.yml \
		--set twingateOperator.network=$(TWINGATE_NETWORK) \
		--set twingateOperator.apiKey=$(TWINGATE_API_KEY) \
		--set twingateOperator.remoteNetworkName=$(TWINGATE_REMOTE_NETWORK_NAME)
	
	@echo "\n Applying Twingate resources..."
	kubectl apply -f twingate-resources.yml
	
	@echo "\n Applying test whoami application..."
	kubectl apply -f test-whoami.yml
	
	@echo "\n Setup complete! Twingate Operator is ready."
	@echo "To verify installation:"
	@echo "  kubectl get pods -n twingate"

setup-connector:
	@echo "Creating namespace..."
	kubectl create namespace tg || true
	
	@echo "\n Adding Helm repositories..."
	helm repo add twingate https://twingate.github.io/helm-charts || true
	
	@echo "\n Installing Twingate Connector..."
	helm install twingate-connector twingate/connector \
		--version $(TWINGATE_CONNECTOR_VERSION) \
		--namespace tg \
		--values helm-values/twingate-connector-values.yml \
		--set connector.network=$(TWINGATE_NETWORK) \
		--set connector.accessToken=$(KUBERNETES_CONNECTOR_ACCESS_TOKEN) \
		--set connector.refreshToken=$(KUBERNETES_CONNECTOR_REFRESH_TOKEN)
	
	@echo "\n Applying test whoami application..."
	kubectl apply -f test-whoami.yml
	
	@echo "\n Setup complete! Twingate Connector is ready."
	@echo "To verify installation:"
	@echo "  kubectl get pods -n twingate"

upgrade-operator:
	@echo "\n Upgrading Twingate Operator..."
	helm upgrade twop oci://ghcr.io/twingate/helmcharts/twingate-operator \
		--version $(TWINGATE_OPERATOR_VERSION) \
		--namespace tg \
		--values helm-values/twingate-operator-values.yml \
		--set twingateOperator.network=$(TWINGATE_NETWORK) \
		--set twingateOperator.apiKey=$(TWINGATE_API_KEY) \
		--set twingateOperator.remoteNetworkName=$(TWINGATE_REMOTE_NETWORK_NAME)
	@echo "\n Upgrade complete!"

upgrade-connector:
	@echo "\n Upgrading Twingate Connector..."
	helm upgrade twingate-connector twingate/connector \
		--version $(TWINGATE_CONNECTOR_VERSION) \
		--namespace tg \
		--values helm-values/twingate-connector-values.yml \
		--set connector.network=$(TWINGATE_NETWORK) \
		--set connector.accessToken=$(KUBERNETES_CONNECTOR_ACCESS_TOKEN) \
		--set connector.refreshToken=$(KUBERNETES_CONNECTOR_REFRESH_TOKEN)
	
	@echo "\n Upgrade complete!"

destroy-operator:
	@echo "Uninstalling Twingate Operator..."
	helm uninstall twop -n tg || true
	@echo "\n Twingate Operator chart has been removed."

destroy-connector:
	@echo "Uninstalling Twingate Connector..."
	helm uninstall twingate-connector -n tg || true
	@echo "\n Twingate Connector chart has been removed."
