#!/usr/bin/env bats

load helper

@test "KUBECTL: kubectl installed properly." {
	run kubectl help
	[ "$status" -eq 0 ]
}

