package main

import "testing"

func TestName(t *testing.T) {
	if got, want := name(), "issue-token"; got != want {
		t.Errorf("name() = %q, want %q", got, want)
	}
}
