provision: keys/ansible.pub
	pipenv run ansible-playbook playbooks/create.yml

vars/credentials.yml:
	cp {.templates,vars}/credentials.yml

vars/server.yml:
	cp {.templates,vars}/server.yml

destroy:
	pipenv run ansible-playbook playbooks/destroy.yml

keys/ansible.pub:
	ssh-keygen -C minecraft-ansible -N '' -f keys/ansible

init: vars/credentials.yml vars/server.yml

setup: init
	pip install -U -r requirements.txt
	pipenv install
	ansible-galaxy install -r requirements.yml
