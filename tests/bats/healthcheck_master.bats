#!/usr/bin/env bats

load helper

@test "EKS_MASTER: Cluster is setup properly." {
	run kubectl cluster-info
	[ "$status" -eq 0 ]
	assert_contains "$output" "Kubernetes master"

	run kubectl get pods --all-namespaces
	[ "$status" -eq 0 ]
	assert_contains "$output" "kube-dns"
	assert_contains "$output" "kube-proxy"

	run kubectl get svc
	[ "$status" -eq 0 ]
	assert_contains "$output" "kubernetes"
}

