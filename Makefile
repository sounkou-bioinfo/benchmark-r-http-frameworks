.PHONY: all render readme report benchmark quick clean clean-results status

R ?= Rscript
WRK_DURATION ?= 30s

all: render

render: readme report

readme: README.Rmd
	$(R) -e 'rmarkdown::render("README.Rmd", quiet = TRUE)'

report: benchmarks.Rmd
	$(R) -e 'rmarkdown::render("benchmarks.Rmd", quiet = TRUE)'

benchmark:
	WRK_DURATION=$(WRK_DURATION) bash tools/bench/run.sh

quick:
	$(MAKE) benchmark WRK_DURATION=1s
	$(MAKE) render

clean:
	rm -f README.html benchmarks.html

clean-results:
	rm -rf results

status:
	git status --short
