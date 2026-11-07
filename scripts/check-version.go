// Copyright (c) Tailscale Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

//go:build ignore

// Check the actual stamped versions with the same parser used by Tailscale.
package main

import (
	"fmt"
	"os"

	"tailscale.com/hostinfo"
	"tailscale.com/version"
)

func main() {
	if len(os.Args) != 3 {
		fmt.Fprintln(os.Stderr, "usage: check-version expected-short expected-long")
		os.Exit(2)
	}
	short, long := version.Short(), version.Long()
	if short != os.Args[1] || long != os.Args[2] ||
		!version.AtLeast(short, short) || !version.AtLeast(long, short) ||
		hostinfo.New().IPNVersion != long {
		fmt.Fprintf(os.Stderr, "invalid control-plane version: short=%q long=%q\n", short, long)
		os.Exit(1)
	}
	fmt.Printf("Control-plane version verified: short=%s long=%s\n", short, long)
}
