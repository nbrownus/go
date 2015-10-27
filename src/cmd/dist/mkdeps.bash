#!/bin/bash
# Copyright 2015 The Go Authors. All rights reserved.
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

set -e

declare -A alldeps

# We need to test enough GOOS/GOARCH combinations to pick up all the
# package dependencies.
gooslist="windows linux darwin solaris"
goarchlist="386 amd64 arm arm64 ppc64"

for goos in $gooslist; do
  for goarch in $goarchlist; do
    deps=$(GOOS=$goos GOARCH=$goarch go list -tags cmd_go_bootstrap -f '{{join .Deps "\n"}}' cmd/go | grep -v '^unsafe$')
    for dep in $deps cmd/go; do
      alldeps[$dep]="${alldeps[$dep]} $(GOOS=$goos GOARCH=$goarch go list -tags cmd_go_bootstrap -f '{{range .Deps}}{{if not (eq . "unsafe")}}{{print .}} {{end}}{{end}}' $dep)"
    done
  done
done

export GOOS=windows

(
	echo '// generated by mkdeps.bash'
	echo
	echo 'package main'
	echo
	echo 'var builddeps = map[string][]string{'

	for dep in $(for dep in ${!alldeps[@]}; do echo $dep; done | grep -v '^cmd/go$' | sort) cmd/go; do
	  echo -n '"'$dep'"': {
	  for subdep in ${alldeps[$dep]}; do
	    echo $subdep
	  done | sort -u | while read subdep; do
	    echo -n '"'$subdep'"',
	  done
	  echo },
	done

	echo '}'
) |gofmt >deps.go