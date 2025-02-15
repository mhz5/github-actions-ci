instanceip:
	terraform -chdir=tf output public_ip | tr -d '"' > .vm-ip
	cat .vm-ip

a:
	terraform -chdir=tf apply -auto-approve \
		-var="github_token=$$(cat ~/.github-token)"

d:
	terraform -chdir=tf destroy -auto-approve

ssh: instanceip
	$$(echo "ssh -i ~/.ssh/github-runner-key ubuntu@$$(cat .vm-ip) -o StrictHostKeyChecking=no")

flow:
	make d
	make a