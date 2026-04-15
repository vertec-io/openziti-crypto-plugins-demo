package main

import (
	"flag"
	"fmt"
	"io"
	"os"
	"sync/atomic"
	"time"

	"github.com/michaelquigley/pfxlog"
	"github.com/openziti/sdk-golang/ziti"
	"github.com/sirupsen/logrus"
)

var capturedCipher atomic.Value

type cipherCaptureHook struct{}

func (h *cipherCaptureHook) Levels() []logrus.Level { return logrus.AllLevels }

func (h *cipherCaptureHook) Fire(entry *logrus.Entry) error {
	if v, ok := entry.Data["cipher"]; ok {
		capturedCipher.Store(fmt.Sprintf("%d", v))
	}
	return nil
}

func main() {
	identityPath := flag.String("identity", "", "path to identity JSON")
	serviceName := flag.String("service", "cipher-interop-svc", "service name")
	printCipher := flag.Bool("print-cipher", false, "print negotiated cipher ID and exit")
	flag.Parse()

	if *identityPath == "" {
		fmt.Fprintln(os.Stderr, "error: --identity is required")
		os.Exit(1)
	}

	pfxlog.GlobalInit(logrus.DebugLevel, pfxlog.DefaultOptions())
	logrus.StandardLogger().AddHook(&cipherCaptureHook{})
	logrus.StandardLogger().SetOutput(io.Discard)

	cfg, err := ziti.NewConfigFromFile(*identityPath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "config error: %v\n", err)
		os.Exit(1)
	}

	ctx, err := ziti.NewContext(cfg)
	if err != nil {
		fmt.Fprintf(os.Stderr, "context error: %v\n", err)
		os.Exit(1)
	}

	opts := &ziti.ListenOptions{
		ConnectTimeout: 30 * time.Second,
		MaxTerminators: 1,
	}

	listener, err := ctx.ListenWithOptions(*serviceName, opts)
	if err != nil {
		fmt.Fprintf(os.Stderr, "listen error: %v\n", err)
		os.Exit(1)
	}

	conn, err := listener.Accept()
	if err != nil {
		fmt.Fprintf(os.Stderr, "accept error: %v\n", err)
		os.Exit(1)
	}

	buf := make([]byte, 1024)
	n, err := conn.Read(buf)
	if err != nil {
		fmt.Fprintf(os.Stderr, "read error: %v\n", err)
		os.Exit(1)
	}

	if _, err := conn.Write(buf[:n]); err != nil {
		fmt.Fprintf(os.Stderr, "write error: %v\n", err)
		os.Exit(1)
	}

	conn.Close()
	listener.Close()

	if *printCipher {
		cipherID := "1"
		if v := capturedCipher.Load(); v != nil {
			cipherID = v.(string)
		}
		fmt.Printf("NEGOTIATED-CIPHER:%s\n", cipherID)
	}
}
