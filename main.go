package main

import (
	"errors"
	"flag"
	"fmt"
	"io"
	"os"

	"github.com/tmknom/playground-workflows/internal/greeting"
)

// version is overwritten at release build time with -ldflags "-X main.version=<version>".
var version = "dev"

func main() {
	os.Exit(run(os.Args[1:], os.Stdout, os.Stderr))
}

// run returns 2 for usage errors, following the exit code that the flag package uses with ExitOnError.
func run(args []string, stdout, stderr io.Writer) int {
	flags := flag.NewFlagSet("playground-workflows", flag.ContinueOnError)
	flags.SetOutput(stderr)
	showVersion := flags.Bool("version", false, "print the version and exit")
	if err := flags.Parse(args); err != nil {
		if errors.Is(err, flag.ErrHelp) {
			return 0
		}
		return 2
	}
	if flags.NArg() > 0 {
		fmt.Fprintf(stderr, "unexpected argument: %s\n", flags.Arg(0))
		flags.Usage()
		return 2
	}

	if *showVersion {
		fmt.Fprintln(stdout, version)
		return 0
	}
	fmt.Fprintln(stdout, greeting.Message())
	return 0
}
