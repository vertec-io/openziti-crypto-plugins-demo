//go:build hook

package main

import _ "sample-go/plugin" // registers AES-256-GCM provider at init time
