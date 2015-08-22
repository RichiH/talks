FILENAME = $(basename $(wildcard *.tex))

all:
	pdflatex $(FILENAME).tex
#	bibtex $(FILENAME)
	pdflatex $(FILENAME).tex
#	dvipdf $(FILENAME).dvi $(FILENAME).pdf

clean:
	rm -fv $(FILENAME).dvi $(FILENAME).ps $(FILENAME).log *.aux *.toc *.bbl *.blg *.glo *.out *.nav *.snm *.log


# Notes:
#convert weekly_traffic.png -transparent white weekly2.png
#convert weekly2.png weekly2.pdf



