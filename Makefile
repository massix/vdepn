CC=valac
CFLAGS=--pkg gtk+-2.0 --pkg libxml-2.0

SOURCES=conf_parser.vala helpers.vala mainwindow.vala
PROGRAM=vde_manager

all: $(PROGRAM)

$(PROGRAM): $(SOURCES)
	$(CC) $(CFLAGS) $(SOURCES) -o $(PROGRAM)

$(SOURCES):
	echo source

clean:
	@rm -f $(PROGRAM)

.PHONY: clean