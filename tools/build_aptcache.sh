#!/bin/sh

CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o aptcache_linux_amd64 .
strip aptcache_linux_amd64
