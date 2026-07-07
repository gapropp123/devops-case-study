.PHONY: precheck bootstrap-all teardown-all

ANSIBLE_IMAGE := devops-case-study-ansible:local
DELETE_CLUSTER ?= false
DOCKER_GID := $(shell stat -c '%g' /var/run/docker.sock)
ENV_ARG := $(if $(ENV),-e target_env=$(ENV),)

precheck:
	@./scripts/precheck.sh

bootstrap-all: precheck
	docker build -q -f docker/ansible/Dockerfile -t $(ANSIBLE_IMAGE) docker/ansible >/dev/null
	docker run --rm \
		--network host \
		--user $(shell id -u):$(shell id -g) \
		--group-add $(DOCKER_GID) \
		-e HOME=$(HOME) \
		-e ANSIBLE_HOME=/tmp/.ansible-home \
		-e ANSIBLE_LOCAL_TEMP=/tmp/.ansible-local \
		-e ANSIBLE_REMOTE_TMP=/tmp/.ansible-remote \
		-e DOCKER_CONFIG=/tmp/.docker \
		-v /var/run/docker.sock:/var/run/docker.sock \
		-v $(HOME)/.kube:$(HOME)/.kube \
		-v $(HOME)/.minikube:$(HOME)/.minikube \
		-v $(CURDIR):$(CURDIR) \
		-w $(CURDIR)/ansible \
		$(ANSIBLE_IMAGE) ansible-playbook -i inventory.ini bootstrap-all.yml -e repo_root=$(CURDIR) $(ENV_ARG)

teardown-all: precheck
	docker build -q -f docker/ansible/Dockerfile -t $(ANSIBLE_IMAGE) docker/ansible >/dev/null
	docker run --rm \
		--network host \
		--user $(shell id -u):$(shell id -g) \
		--group-add $(DOCKER_GID) \
		-e HOME=$(HOME) \
		-e ANSIBLE_HOME=/tmp/.ansible-home \
		-e ANSIBLE_LOCAL_TEMP=/tmp/.ansible-local \
		-e ANSIBLE_REMOTE_TMP=/tmp/.ansible-remote \
		-e DOCKER_CONFIG=/tmp/.docker \
		-v /var/run/docker.sock:/var/run/docker.sock \
		-v $(HOME)/.kube:$(HOME)/.kube \
		-v $(HOME)/.minikube:$(HOME)/.minikube \
		-v $(CURDIR):$(CURDIR) \
		-w $(CURDIR)/ansible \
		$(ANSIBLE_IMAGE) ansible-playbook -i inventory.ini teardown-all.yml -e repo_root=$(CURDIR) -e delete_cluster=$(DELETE_CLUSTER) $(ENV_ARG)
