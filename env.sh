#!/bin/sh
set -eu

stage=${1:-'default'}

cat <<EOF
COMPOSE_PROJECT_NAME=step-ca
PROVISIONER_USERNAME=admin
STEP_CA_ADDRESS=:9000
STEP_CA_NAME=Step
STEP_CA_DNS=localhost
STEP_CA_PORT=9001
EOF

case "$stage" in
	"default")
		cat <<-EOF
		PROVISIONER_PASSWORD=secret
		EOF
		;;
	"production")
		cat <<-EOF
		PROVISIONER_PASSWORD=$(head /dev/urandom | sha1sum | cut -d ' ' -f 1)
		EOF
		;;

	*)
		echo "Unknown stage $stage" >&2
		exit 1
		;;
esac
