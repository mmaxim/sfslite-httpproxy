CXXFLAGS=-Wall -Wno-mismatched-tags -g -O2
CXX=clang++
LD=clang++
LDFLAGS=-Wl,-rpath,/usr/local/lib/sfslite 
TAME=/usr/local/lib/sfslite/tame
CXXINCLUDES=-I/usr/local/include/sfslite
LDINCLUDES=-L/usr/local/lib/sfslite
LIBS=-lresolv -lpcre -lasync -ltame -larpc

ifndef V
	LDECHO=@echo "+  LD: $@";
	TECHO=@echo "+  TAME: $@";
	CCECHO=@echo "+  CC: $@";
endif

proxy: proxy.o
	$(LDECHO) $(LD) $(LDINCLUDES) $(LDFLAGS) -o $(@) $< $(LIBS)

proxy.o: proxy.C
	$(CCECHO) $(CXX) $(CXXFLAGS) $< $(CXXINCLUDES) -c -o $(@)

proxy.C: proxy.T
	$(TECHO) $(TAME) $< -o $(@)
	
clean:
	rm -f proxy.C proxy.o proxy
