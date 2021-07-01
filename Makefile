default: help
include *.mk

start: docker-compose-start ##- Start
deploy: docker-compose-deploy ##- Deploy (start remotely)
stop: docker-compose-stop ##- Stop

.PHONY: console
console: environment
	$(load_env); docker-compose exec step-ca /bin/ash

.PHONY: initialize
initialize: environment
	$(load_env); docker-compose run step-ca /bin/ash -c "\
		mkdir -p /home/step/secrets; \
		echo -n $$PROVISIONER_PASSWORD > /home/step/secrets/password; \
		cat /home/step/secrets/password; \
		step ca init --name=$$STEP_CA_NAME --dns=$$STEP_CA_DNS --address=$$STEP_CA_ADDRESS --provisioner=$$PROVISIONER_USERNAME --password-file=/home/step/secrets/password \
	"

.PHONY: fix-arm
fix-arm: environment
	$(load_env); docker-compose run step-ca /bin/ash -c "\
		sed -i -e 's/\(\"type\": \)\"badger\"/\1\"badgerV2\"/' /home/step/config/ca.json; \
		rm -rf /home/step/db \
	"

.PHONY: initialize-arm
initialize-arm: initialize fix-arm

.PHONY: fingerprint
fingerprint: environment
	$(load_env); docker-compose run step-ca /bin/ash -c "\
		cat config/defaults.json | awk '/fingerprint/ { print \$$2 }' | tr -d '\",'; \
	"

.PHONY: root-ca.crt
root-ca.crt: environment
	$(eval fingerprint=$(shell read -p "Fingerprint : "; echo $$REPLY))
	$(load_env); step-cli ca root root-ca.crt --ca-url https://$$STEP_CA_DNS:$$STEP_CA_PORT --fingerprint ${fingerprint}

.PHONY: add-acme
add-acme: environment
	$(load_env); docker-compose exec step-ca /bin/ash -c "\
		step ca provisioner add acme --type ACME \
	"
	$(load_env); docker-compose restart step-ca

.PHONY: add-ca
add-ca: environment
	$(eval fingerprint=$(shell read -p "Fingerprint : "; echo $$REPLY))
	$(load_env); step-cli ca bootstrap --ca-url https://$$STEP_CA_DNS:$$STEP_CA_PORT --install --fingerprint ${fingerprint}

.PHONY: remove-ca
remove-ca:
	step-cli certificate uninstall --all ${HOME}/.step/certs/root_ca.crt

.PHONY: clean
clean: environment
	$(load_env); docker-compose down -v

.PHONY: logs
logs: environment
	$(load_env); docker-compose logs -f

.PHONY: reset
reset: clean initialize start add-acme
