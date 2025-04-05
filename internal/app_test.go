package internal

import (
	"bytes"
	"context"
	"fmt"
	"os"
	"strings"
	"testing"

	"github.com/google/go-cmp/cmp"
)

func TestApp_Run_Valid(t *testing.T) {
	cases := []struct {
		annotation string
		args       []string
		expected   string
	}{
		{
			annotation: "valid",
			args:       []string{"--help"},
			expected:   "The template repository for Go",
		},
	}

	for _, tc := range cases {
		sut := NewApp(FakeTestIO())
		err := sut.Run(context.Background(), tc.args)

		if err != nil {
			t.Fatalf(fmt.Sprintf("expected: <no-error>, actual: %#v, args: %v", err, tc.args))
		}

		actual := sut.IO.OutWriter.(*bytes.Buffer).String()
		if !strings.Contains(actual, tc.expected) {
			t.Errorf(fmt.Sprintf("expected: %s, actual: %#v, args: %v", tc.expected, actual, tc.args))
		}
	}
}

func TestApp_Run_Invalid(t *testing.T) {
	cases := []struct {
		annotation string
		args       []string
		expected   string
	}{
		{
			annotation: "invalid",
			args:       []string{"--invalid"},
			expected:   "unknown flag: --invalid",
		},
	}

	for _, tc := range cases {
		sut := NewApp(FakeTestIO())
		err := sut.Run(context.Background(), tc.args)

		if err == nil {
			t.Errorf(fmt.Sprintf("expected: %s, actual: <no-error>, args: %v", tc.expected, tc.args))
		} else if diff := cmp.Diff(err.Error(), tc.expected); diff != "" {
			t.Errorf(fmt.Sprintf("diff: %s, expected: %s, actual: %#v, args: %v", diff, tc.expected, err, tc.args))
		}
	}
}

func FakeTestIO() *IO {
	return &IO{
		InReader:  &bytes.Buffer{},
		OutWriter: &bytes.Buffer{},
		ErrWriter: os.Stderr,
	}
}
