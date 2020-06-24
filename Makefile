python=python3

clean: ; rm -rf *.reduce.log *.fuzz.log results fuzzing
clobber: clean;
	-$(MAKE) box-remove
	-rm -rf artifact artifact.tar.gz
	-rm -rf .db
results:; mkdir -p results

find_bugs=07b941b1 93623752 c8491c11 dbcb10e9
grep_bugs=3c3bdace 54d55bba 9c45c193

closure_bugs=2808 2842 2937 3178 3379 1978
clojure_bugs=2092 2345 2450 2473 2518 2521

lua_bugs=5_3_5__4
rhino_bugs=385 386


find_results_src=$(addsuffix .log,$(addprefix results/reduce_find_,$(find_bugs)))
grep_results_src=$(addsuffix .log,$(addprefix results/reduce_grep_,$(grep_bugs)))

lua_results_src=$(addsuffix .log,$(addprefix results/reduce_lua_,$(lua_bugs)))
rhino_results_src=$(addsuffix .log,$(addprefix results/reduce_rhino_,$(rhino_bugs)))
clojure_results_src=$(addsuffix .log,$(addprefix results/reduce_clojure_,$(clojure_bugs)))
closure_results_src=$(addsuffix .log,$(addprefix results/reduce_closure_,$(closure_bugs)))

fuzz_find_results_src=$(addsuffix .log,$(addprefix results/fuzz_find_,$(find_bugs)))
fuzz_grep_results_src=$(addsuffix .log,$(addprefix results/fuzz_grep_,$(grep_bugs)))

fuzz_lua_results_src=$(addsuffix .log,$(addprefix results/fuzz_lua_,$(lua_bugs)))
fuzz_rhino_results_src=$(addsuffix .log,$(addprefix results/fuzz_rhino_,$(rhino_bugs)))
fuzz_closure_results_src=$(addsuffix .log,$(addprefix results/fuzz_closure_,$(closure_bugs)))
fuzz_clojure_results_src=$(addsuffix .log,$(addprefix results/fuzz_clojure_,$(clojure_bugs)))

start_%:; @echo done
stop_%:; @echo done


stop_find: $(addprefix stop_,$(find_bugs))
	@echo done.

stop_grep: $(addprefix stop_,$(grep_bugs))
	@echo done.

$(addprefix start_,$(grep_bugs)):
	sudo docker stop $(subst start_,,$@)
	sudo docker start $(subst start_,,$@)

$(addprefix stop_,$(grep_bugs)):
	sudo docker stop $(subst stop_,,$@)

$(addprefix start_,$(find_bugs)):
	sudo docker stop $(subst start_,,$@)
	sudo docker start $(subst start_,,$@)

$(addprefix stop_,$(find_bugs)):
	sudo docker stop $(subst stop_,,$@)

unbuffer= #unbuffer -p

results/reduce_%.log: src/%.py | results
	@- $(MAKE) start_$(subst find_,,$*)
	@- $(MAKE) start_$(subst grep_,,$*)
	time $(python) $< 2>&1 | $(unbuffer) tee $@_
	@- $(MAKE) stop_$(subst find_,,$*)
	@- $(MAKE) stop_$(subst grep_,,$*)
	mv $@_ $@

results/fuzz_%.log: src/fuzz_%.py results/reduce_%.log
	@- $(MAKE) start_$(subst find_,,$*)
	@- $(MAKE) start_$(subst grep_,,$*)
	time $(python) $< 2>&1 | $(unbuffer) tee $@_
	@- $(MAKE) stop_$(subst find_,,$*)
	@- $(MAKE) stop_$(subst grep_,,$*)
	mv $@_ $@

reduce_find: $(find_results_src); @echo done
reduce_grep: $(grep_results_src); @echo done

reduce_lua: $(lua_results_src); @echo done
reduce_rhino: $(rhino_results_src); @echo done
reduce_clojure: $(clojure_results_src); @echo done
reduce_closure: $(closure_results_src); @echo done

fuzz_find: $(fuzz_find_results_src); @echo done
fuzz_grep: $(fuzz_grep_results_src); @echo done

fuzz_lua: $(fuzz_lua_results_src); @echo done
fuzz_rhino: $(fuzz_rhino_results_src); @echo done
fuzz_clojure: $(fuzz_clojure_results_src); @echo done
fuzz_closure: $(fuzz_closure_results_src); @echo done


all_find: fuzz_find
	tar -cf find.tar results .db
	@echo find done

all_grep: fuzz_grep
	tar -cf grep.tar results .db
	@echo grep done

all_lua: fuzz_lua
	tar -cf lua.tar results .db
	@echo lua done

all_rhino: fuzz_rhino
	tar -cf rhino.tar results .db
	@echo rhino done

all_clojure: fuzz_clojure
	tar -cf clojure.tar results .db
	@echo clojure done

all_closure: fuzz_closure
	tar -cf closure.tar results .db
	@echo closure done

all: all_lua all_rhino all_clojure all_closure all_find all_grep
	@echo done

dbgbench-init: .dbgbench init-find init-grep
	@echo done

.dbgbench:
	git clone https://github.com/vrthra-forks/dbgbench.github.io.git
	touch $@

dbgbench-clobber:
	-$(MAKE) rm-find
	-$(MAKE) rm-grep
	rm -rf dbgbench.github.io .dbgbench

init-find: .dbgbench;
	for i in $(find_bugs); do \
		$(MAKE) -C dbgbench.github.io/docker initfind-$$i; \
		sudo docker stop $$i; \
		done
init-grep: .dbgbench;
	for i in $(grep_bugs); do \
		$(MAKE) -C dbgbench.github.io/docker initgrep-$$i; \
		sudo docker stop $$i; \
		done

rm-find:; $(MAKE) -C dbgbench.github.io/docker rm-find
rm-grep:; $(MAKE) -C dbgbench.github.io/docker rm-grep

prune-find:; sudo docker system prune --filter ancestor=factoring/find || echo
prune-grep:; sudo docker system prune --filter ancestor=factoring/grep || echo

ls-find:; @sudo docker ps -a --filter ancestor=factoring/find --format 'table {{.Image}} {{.ID}} {{.Names}} {{.Status}}'
ls-grep:; @sudo docker ps -a --filter ancestor=factoring/grep --format 'table {{.Image}} {{.ID}} {{.Names}} {{.Status}}'

artifact.tar.gz: Vagrantfile Makefile
	rm -rf artifact && mkdir -p artifact/factoring
	cp README.md artifact/README.txt
	cp -r README.md lang src dbgbench.github.io .dbgbench Makefile Vagrantfile etc/jupyter_notebook_config.py artifact/factoring
	cp -r Vagrantfile artifact/
	tar -cf artifact1.tar artifact
	gzip artifact1.tar
	mv artifact1.tar.gz artifact.tar.gz



# PACKAGING
box-create: factoring.box
factoring.box: artifact.tar.gz
	cd artifact && vagrant up
	cd artifact && vagrant ssh -c 'cd /vagrant; tar -cpf ~/factoring.tar factoring ; cd ~/; tar -xpf ~/factoring.tar; rm -f ~/factoring.tar'
	cd artifact && vagrant ssh -c 'mkdir -p /home/vagrant/.jupyter; cp /vagrant/factoring/jupyter_notebook_config.py /home/vagrant/.jupyter/.jupyter/jupyter_notebook_config.py'
	cd artifact && vagrant ssh -c 'cd ~/factoring && make dbgbench-init'
	cd artifact && vagrant package --output ../factoring1.box --vagrantfile ../Vagrantfile.new
	mv factoring1.box factoring.box

box-hash:
	md5sum factoring.box

box-add: factoring.box
	-vagrant destroy $$(vagrant global-status | grep factoring | sed -e 's# .*##g')
	rm -rf vtest && mkdir -p vtest && cp factoring.box vtest
	cd vtest && vagrant box add factoring ./factoring.box
	cd vtest && vagrant init factoring
	cd vtest && vagrant up

box-status:
	vagrant global-status | grep factoring
	vagrant box list | grep factoring

box-remove:
	-vagrant destroy $$(vagrant global-status | grep factoring | sed -e 's# .*##g')
	vagrant box remove factoring

show-ports:
	 sudo netstat -ln --program | grep 8888

box-up1:
	cd artifact; vagrant up

box-up2:
	cd vtest; vagrant up

box-connect1:
	cd artifact; vagrant ssh
box-connect2:
	cd vtest; vagrant ssh

