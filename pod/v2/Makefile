CONVERTERS = pod2html

POD2HTML = $(P2H) \
	    --htmlroot=./ \
	    --podpath=./ \
	    --verbose \
	    --noindex \
	    --libpods=afsperlcm:afsperlfs:afsperlacl:afsperlcell:afsperlpts:afsperlkas:afsperlktct:afsperlktcp:afsperlktck:afsperlutils:afsperlbase

all: $(CONVERTERS)

converters: $(CONVERTERS)

P2H = /usr/local/bin/pod2html

POD = \
	afsperl.pod	\
	afsperlacl.pod	\
	afsperlbase.pod	\
	afsperlcell.pod	\
	afsperlcm.pod	\
	afsperlfs.pod	\
	afsperlkas.pod	\
	afsperlktck.pod	\
	afsperlktcp.pod	\
	afsperlktct.pod	\
	afsperlpts.pod	\
	afsperlutils.pod

HTML = \
	afsperl.html	\
	afsperlacl.html	\
	afsperlbase.html	\
	afsperlcell.html	\
	afsperlcm.html	\
	afsperlfs.html	\
	afsperlkas.html	\
	afsperlktck.html	\
	afsperlktcp.html	\
	afsperlktct.html	\
	afsperlpts.html	\
	afsperlutils.html
# not perltoc.html

html:	$(P2H) $(HTML)

.SUFFIXES: .pm .pod

.SUFFIXES: .html

.pod.html:
	$(POD2HTML) --infile=$*.pod --outfile=$*.html

clean:
	rm -f $(HTML)
	rm -f pod2html-*cache
	rm -f pod2htmi.x* pod2htmd.x*

realclean:	clean
	rm -f $(CONVERTERS)

distclean:	realclean

