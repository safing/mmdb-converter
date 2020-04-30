package main

import (
	"flag"
	"io"
	"io/ioutil"
	"log"
	"net/http"
	"os"
	"os/exec"
	"time"
)

var (
	httpListenAddr = flag.String("listen", ":8080", "Address to listen on")
	convertCommand = flag.String("command", "./convert.sh", "Command to execute to convert CSV")
)

func main() {
	flag.Parse()

	http.Handle("/convert/v4", http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		convertRequest("4", w, r)
	}))

	http.Handle("/convert/v6", http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		convertRequest("6", w, r)
	}))

	log.Println("serving on " + *httpListenAddr)
	if err := http.ListenAndServe(*httpListenAddr, nil); err != nil {
		log.Fatal(err)
	}
}

type responseRecorder struct {
	Code int
	Size int
	http.ResponseWriter
}

func (rr *responseRecorder) WriteHeader(code int) {
	rr.Code = code
	rr.ResponseWriter.WriteHeader(code)
}

func (rr *responseRecorder) Write(blob []byte) (int, error) {
	size, err := rr.ResponseWriter.Write(blob)
	rr.Size += size
	return size, err
}

func convertRequest(version string, w http.ResponseWriter, r *http.Request) {
	rr := &responseRecorder{ResponseWriter: w}
	start := time.Now()
	defer func() {
		log.Printf("%s %s with %d in %s (%d bytes)", r.Method, r.URL.Path, rr.Code, time.Since(start), rr.Size)
	}()

	if r.Method != "POST" {
		sendError(rr, http.StatusMethodNotAllowed, "Only POST requests are allowed")
		return
	}

	if r.Header.Get("Content-Type") != "text/csv" {
		sendError(rr, http.StatusNotAcceptable, "Unexpected content type, only text/csv is supported.")
		return
	}

	tmpFile, err := ioutil.TempFile("", "")
	if err != nil {
		sendError(rr, http.StatusInternalServerError, err.Error())
		return
	}
	defer os.Remove(tmpFile.Name())
	defer tmpFile.Close()

	n, err := io.Copy(tmpFile, r.Body)
	if err != nil {
		sendError(rr, http.StatusInternalServerError, err.Error())
		return
	}
	tmpFile.Close()

	target := tmpFile.Name() + ".mmdb"
	log.Printf("received request with %d bytes, converting from %s to %s", n, tmpFile.Name(), target)

	cmd := exec.CommandContext(r.Context(), *convertCommand, tmpFile.Name(), target, version)
	output, err := cmd.CombinedOutput()
	if err != nil {
		if len(output) > 0 {
			sendError(rr, http.StatusInternalServerError, string(output))
		} else {
			sendError(rr, http.StatusInternalServerError, err.Error())
		}
		return
	}

	defer os.Remove(target)
	rr.Header().Set("Content-Type", "application/octet-stream")
	http.ServeFile(rr, r, target)
}

func sendError(w http.ResponseWriter, code int, text string) {
	w.Header().Add("Content-Type", "text/plain")
	w.WriteHeader(code)
	w.Write([]byte(text))
}
