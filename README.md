benchmark-r-http-frameworks
================

A standalone benchmark harness for comparing R HTTP / REST serving
frameworks on the same tiny endpoints.

The harness is intentionally independent of any framework source
checkout: it runs installed R packages and records raw `wrk` output plus
machine/package metadata.

## Frameworks

Current variants:

- `drogonR-native` — `drogonR::dr_app()` + R handler closures
- `drogonR-plumber-shim` — a `plumber` router served by
  `drogonR::pr_run()`
- `plumber` — classic `plumber::pr_run()`
- `plumber2` — `plumber2::api_run()` with synchronous handlers
- `plumber2-mirai` — `plumber2::api_run()` with `async = TRUE` and
  persistent `mirai` daemons
- `RestRserve` — `RestRserve::Application` served by the `Rserve`
  backend

## Workload

All variants expose:

- `GET /ping` — JSON object equivalent to `{"ok": true}` where possible
- `GET /ping-text` — scalar string `"ok"` through the framework’s normal
  response path

Default load:

``` bash
wrk -t4 -c50 -d30s http://127.0.0.1:<port>/<route>
```

Override benchmark load and framework concurrency options with
environment variables:

``` bash
WRK_THREADS=8 WRK_CONNECTIONS=100 WRK_DURATION=60s bash tools/bench/run.sh
```

Server options exposed by the harness:

``` bash
# drogonR
DROGONR_THREADS=4 DROGONR_WORKERS=1 bash tools/bench/run.sh

# plumber2 async/mirai variant
PLUMBER2_MIRAI_DAEMONS=5 bash tools/bench/run.sh

# RestRserve / Rserve backend
RESTRSERVE_JIT_LEVEL=0 RESTRSERVE_PRECOMPILE=false bash tools/bench/run.sh
```

RestRserve uses the Rserve HTTP backend; on Unix-like systems Rserve
uses forked request processing for concurrent work.
`RESTRSERVE_RSERVE_PORT` can be set if you need to pin the internal
Rserve/QAP port instead of letting RestRserve choose one.

## Requirements

System tools:

``` bash
sudo apt-get install curl wrk
```

R packages:

``` r
install.packages(c("plumber", "plumber2", "mirai", "RestRserve", "rmarkdown", "knitr"))
# plus drogonR from wherever you install it
```

## Run

Run the benchmark only:

``` bash
bash tools/bench/run.sh
```

Render the report from latest results:

``` bash
Rscript -e 'rmarkdown::render("benchmarks.Rmd")'
```

Run and render in one command:

``` bash
Rscript -e 'rmarkdown::render("benchmarks.Rmd", params = list(run_benchmark = TRUE))'
```

Outputs are written to `results/`:

- raw `wrk` files per framework/route
- server logs
- `comparison-<timestamp>.csv`
- `latest.csv`

Generated `README.md`, `benchmarks.md`, and `benchmarks.html` should be
produced from their `.Rmd` sources. Do not edit generated Markdown by
hand.
