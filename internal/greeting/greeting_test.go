package greeting

import "testing"

func TestMessage(t *testing.T) {
	if got, want := Message(), "Hello, broken world"; got != want {
		t.Errorf("Message() = %q, want %q", got, want)
	}
}
