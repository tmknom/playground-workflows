package main

import (
	"bytes"
	"strings"
	"testing"

	"github.com/tmknom/playground-workflows/internal/greeting"
)

func TestRun(t *testing.T) {
	cases := []struct {
		name       string
		args       []string
		wantCode   int
		wantStdout string
	}{
		{
			name:       "no arguments prints the greeting",
			args:       nil,
			wantCode:   0,
			wantStdout: greeting.Message() + "\n",
		},
		{
			name:       "version flag prints only the version",
			args:       []string{"--version"},
			wantCode:   0,
			wantStdout: "dev\n",
		},
		{
			name:       "help flag exits with 0 without printing to stdout",
			args:       []string{"--help"},
			wantCode:   0,
			wantStdout: "",
		},
		{
			name:       "unknown flag exits with 2",
			args:       []string{"--unknown"},
			wantCode:   2,
			wantStdout: "",
		},
		{
			name:       "positional argument exits with 2",
			args:       []string{"extra"},
			wantCode:   2,
			wantStdout: "",
		},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			var stdout, stderr bytes.Buffer
			if got := run(tc.args, &stdout, &stderr); got != tc.wantCode {
				t.Errorf("run(%q) = %d, want %d", tc.args, got, tc.wantCode)
			}
			if got := stdout.String(); got != tc.wantStdout {
				t.Errorf("stdout = %q, want %q", got, tc.wantStdout)
			}
		})
	}
}

func TestRunUsage(t *testing.T) {
	cases := []struct {
		name string
		args []string
	}{
		{name: "help flag prints the usage to stderr", args: []string{"--help"}},
		{name: "positional argument prints the usage to stderr", args: []string{"extra"}},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			var stdout, stderr bytes.Buffer
			run(tc.args, &stdout, &stderr)
			if got := stderr.String(); !strings.Contains(got, "-version") {
				t.Errorf("stderr = %q, want the usage that lists -version", got)
			}
		})
	}
}
