/*

* See https://github.com/puhitaku/empera for the original source code.

MIT License

Copyright (c) 2020 Takumi Sueda

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

*/

package main

import (
	"flag"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"time"
)

type Proxy struct {
	remote string

	cli *http.Client
	cache map[string]struct{}
	cacheLock sync.Mutex
}

func NewProxy() (*Proxy, error) {
	p := &Proxy{
		cli: http.DefaultClient,
		cache: map[string]struct{}{},
	}

	stat, err := os.Stat("cache")
	if err != nil {
		if err.(*os.PathError).Err != syscall.ENOENT {
			return nil, fmt.Errorf("failed to stat cache directory: %s", err)
		}
		err = os.Mkdir("cache", 0755)
		if err != nil {
			return nil, fmt.Errorf("failed to create cache directory: %s", err)
		}
	} else if !stat.IsDir() {
		return nil, fmt.Errorf("non-directory 'cache' exists")
	}

	matches, err := filepath.Glob("cache/*")
	if err != nil {
		return nil, fmt.Errorf("failed to glob cache directory: %s", err)
	}

	for i := range matches {
		p.cache[strings.TrimPrefix(matches[i], "cache/")] = struct{}{}
	}
	return p, nil
}

func (p *Proxy) Run(local, remote string) {
	p.remote = remote
	err := http.ListenAndServe(local, p)
	if err != nil {
		panic(err)
	}
}

// ServeHTTP implements http.Handler interface
func (p *Proxy) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	var err error
	encoded := url.PathEscape(r.URL.Path)

	exclude := []string{"Release", "Packages", "Contents"}
	nocache := false
	for _, ex := range exclude {
		nocache = nocache || strings.Contains(encoded, ex)
	}

	if nocache {
		fmt.Printf("GET (no cache): %s%s -> ", p.remote, r.URL.Path)
		err = p.fetchFromRemote(w, r, false)
	} else if _, ok := p.cache[encoded]; ok {
		fmt.Printf("GET (cache hit): %s%s -> ", p.remote, r.URL.Path)
		err = p.fetchFromCache(w, r)
	} else {
		fmt.Printf("GET (cache miss): %s%s -> ", p.remote, r.URL.Path)
		err = p.fetchFromRemote(w, r, true)
	}

	if err != nil {
		fmt.Printf("%s\n", err)
	} else {
		fmt.Printf("200\n")
	}
}

func (p *Proxy) fetchFromRemote(w http.ResponseWriter, r *http.Request, cache bool) error {
	var f io.WriteCloser = NullWriter{}
	var err error

	encoded := url.PathEscape(r.URL.Path)
	fpath := filepath.Join("cache", encoded)

	newURL, err := url.Parse(r.URL.String())
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		w.Write([]byte(err.Error()))
		return fmt.Errorf("failed to parse URL: %s", err)
	}
	newURL.Scheme = "http"
	newURL.Host = p.remote

	req, err := http.NewRequest(http.MethodGet, newURL.String(), nil)
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		w.Write([]byte(err.Error()))
		return fmt.Errorf("failed to create a new request: %s", err)
	}

	req.Header = r.Header
	res, err := p.cli.Do(req)
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		w.Write([]byte(err.Error()))
		return fmt.Errorf("failed to GET: %s", err)
	}
	defer res.Body.Close()

	_, err = os.Stat(fpath)
	if err != nil {
		if err.(*os.PathError).Err != syscall.ENOENT {
			w.WriteHeader(http.StatusInternalServerError)
			w.Write([]byte(err.Error()))
			return fmt.Errorf("failed to stat cached file: %s", err)
		}
	}

	if cache && res.StatusCode == http.StatusOK {
		f, err = os.Create(fpath)
		if err != nil {
			w.WriteHeader(http.StatusInternalServerError)
			w.Write([]byte(err.Error()))
			return fmt.Errorf("failed to create file: %s", err)
		}
		defer f.Close()
	}

	for k, vs := range res.Header {
		for _, v := range vs {
			w.Header().Add(k, v)
		}
	}
	w.WriteHeader(res.StatusCode)

	_, err = io.Copy(w, io.TeeReader(res.Body, f))
	if err != nil {
		return fmt.Errorf("failed to copy: %s", err)
	}

	if res.StatusCode == http.StatusOK {
		p.cacheLock.Lock()
		defer p.cacheLock.Unlock()
		p.cache[encoded] = struct{}{}
		return nil
	} else {
		return fmt.Errorf(strconv.Itoa(res.StatusCode))
	}
}

func (p *Proxy) fetchFromCache(w http.ResponseWriter, r *http.Request) error {
	encoded := url.PathEscape(r.URL.Path)
	f, err := os.Open(filepath.Join("cache", encoded))
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		w.Write([]byte(err.Error()))
		return fmt.Errorf("failed to open '%s': %s", encoded, err)
	}
	defer f.Close()

	_, err = io.Copy(w, f)
	if err != nil {
		return fmt.Errorf("failed to copy: %s", err)
	}
	return nil
}

type NullWriter struct{}

func (w NullWriter) Write(b []byte) (int, error) {
	return len(b), nil
}

func (w NullWriter) Close() error {
	return nil
}

type rule struct {
	Local, Remote string
}

type rules []rule

func (r *rules) String() string {
	return ""
}

func (r *rules) Set(raw string) error {
	var local, remote string

	kvs := strings.Split(raw, ",")
	for _, kv := range kvs {
		tokens := strings.Split(kv, "=")
		if len(tokens) != 2 {
			return fmt.Errorf("rule is malformed")
		}
		tokens[0], tokens[1] = strings.TrimSpace(tokens[0]), strings.TrimSpace(tokens[1])
		switch tokens[0] {
		case "local":
			local = tokens[1]
		case "remote":
			remote = tokens[1]
		default:
			return fmt.Errorf("rule has unknown key: '%s'", tokens[0])
		}
	}

	if local == "" || remote == "" {
		return fmt.Errorf("rule lacks mendatory keys: 'local' and/or 'remote'")
	}

	*r = append(*r, rule{Local: local, Remote: remote})
	return nil
}

func main() {
	var rules rules
	flag.Var(&rules, "rule", "Proxy rule. example: -rule 'local=localhost:8080, remote=super.slow.repository.example.com'")
	flag.Parse()

	if len(rules) == 0 {
		fmt.Fprintf(os.Stderr, "Fatal: specify one or more rules.\n")
		flag.Usage()
		os.Exit(1)
	}

	for i, rule := range rules {
		fmt.Printf("Proxy Rule %d: %s -> %s\n", i+1, rule.Local, rule.Remote)

		p, err := NewProxy()
		if err != nil {
			panic(err)
		}
		go p.Run(rule.Local, rule.Remote)
	}
	for {
		time.Sleep(9999999999)
	}
}
