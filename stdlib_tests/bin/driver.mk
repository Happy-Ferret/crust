#!/usr/bin/make -f

RUSTC ?= rustc
CRUST_HOME ?= ..
RBMC ?= $(CRUST_HOME)/bin/rbmc
PREPROCESS ?= $(CRUST_HOME)/bin/Preprocess
CRUST_NATIVE ?= $(CRUST_HOME)/bin/crust.native

TEST_HOME ?= .
SRC ?= $(TEST_HOME)/src
FILTERS ?= $(TEST_HOME)/filters


STDLIBS = core libc alloc unicode collections
STDLIB_RLIBS = $(patsubst %,lib/lib%.rlib,$(STDLIBS))
STDLIB_IRS = $(patsubst %,ir/lib%.ir,$(STDLIBS))

lib/lib%.rlib: $(SRC)/lib%/lib.rs
	$(RUSTC) -L lib --out-dir=lib --target=x86_64-custom-linux-gnu.json $<

ir/lib%.ir: $(SRC)/lib%/lib.rs $(STDLIB_RLIBS)
	$(RBMC) -L lib $< >$@.tmp
	mv -v $@.tmp $@

ir/stdlibs.ir: $(STDLIB_IRS)
	cat $^ >$@.tmp
	mv -v $@.tmp $@

ir/stdlibs_lib%.ir: ir/lib%.ir ir/stdlibs.ir
	cat $^ >$@.tmp
	mv -v $@.tmp $@

ir/%.scrubbed.ir: ir/%.ir
	$(PREPROCESS) --passes scrub <$< >$@.tmp
	mv -v $@.tmp $@

.SECONDEXPANSION:

driver/%.drv: $(FILTERS)/%.filter \
		ir/$$(shell bin/filter_helper.sh $(FILTERS)/$$*.filter).scrubbed.ir
	cat ir/$(shell bin/filter_helper.sh $<).scrubbed.ir | \
		$(PREPROCESS) --driver-gen --merged-filter $< >$@.tmp
	mv -v $@.tmp $@

misc/drivers.d: $(wildcard filters/*.filter)

.SECONDARY:
