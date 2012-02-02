FILENAME = $(basename $(wildcard *.tex))

all:
	latex $(FILENAME).tex
#	bibtex $(FILENAME)
	latex $(FILENAME).tex
	dvipdf $(FILENAME).dvi $(FILENAME).pdf

clean:
	rm -fv $(FILENAME).dvi $(FILENAME).ps $(FILENAME).log *.aux *.toc *.bbl *.blg *.glo *.out *.nav *.snm *.log
