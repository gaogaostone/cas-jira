#
# Makefile to build and install CAS integration
# for Atlassian JIRA v7.x
#

include makefile.inc

help:
	#
	# make targets:
	# help => is what you see now
	# version => show Confluence version
	# build => build all files required for CAS support (.xml, .sh, cacerts, cas-client .jar)
	# install => install all files in Confluence (run with sudo)
	# clean => empty "target" folder, this is where build working files are stored
	#
	# Warning:
	# - make sure this branch is aligned with Confluence version, see make version and git tag
	# - edit makefile.inc to match your site configuration
	#

install: version
	# installing files from "target" folder
	cp target/server.xml $(APP_HOME)/conf/server.xml
	cp target/setenv.sh $(APP_HOME)/bin/setenv.sh
	cp target/seraph-config.xml $(APP_HOME)/atlassian-jira/WEB-INF/classes/seraph-config.xml
	cp target/web.xml $(APP_HOME)/atlassian-jira/WEB-INF/web.xml
	if [ -f target/cacerts ]; then cp target/cacerts $(APP_HOME)/jre/lib/security/cacerts; fi
	rm -f $(APP_HOME)/atlassian-jira/WEB-INF/lib/cas-client-core-?.?.*.jar
	rm -f $(APP_HOME)/atlassian-jira/WEB-INF/lib/cas-client-integration-atlassian-?.?.*.jar
	cp target/cas-client-core-?.?.*.jar $(APP_HOME)/atlassian-jira/WEB-INF/lib/
	cp target/cas-client-integration-atlassian-?.?.*.jar $(APP_HOME)/atlassian-jira/WEB-INF/lib/

build: target/server.xml target/setenv.sh target/seraph-config.xml target/web.xml cacerts jars

target/server.xml: source/server.xml makefile.inc
	# building server.xml
	@mkdir -p target
	@cp $< $@
	@sed -i "s/MY_SERVER_PROXYNAME/$(MY_SERVER_PROXYNAME)/" $@
	@if [ "$(MY_SERVER_KEYSTORE)" ]; then sed -i "s/MY_SERVER_KEYSTORE/$(MY_SERVER_KEYSTORE)/" $@; fi

target/setenv.sh: source/setenv.sh makefile.inc
	# building setenv.sh
	@mkdir -p target
	@cp $< $@
	@sed -i "s/MY_SETENV_OPTS/$(MY_SETENV_OPTS)/" $@

target/seraph-config.xml: source/seraph-config.xml makefile.inc
	# building seraph-config.xml
	@mkdir -p target
	@cp $< $@
	@sed -i "s/MY_CAS_SERVER_PREFIX/$(MY_CAS_SERVER_PREFIX)/" $@
	@sed -i "s/MY_SERVER_PROXYNAME/$(MY_SERVER_PROXYNAME)/" $@

target/web.xml: source/web.xml makefile.inc
	# building web.xml
	@mkdir -p target
	@cp $< $@
	@sed -i "s/MY_CAS_SERVER_PREFIX/$(MY_CAS_SERVER_PREFIX)/" $@
	@sed -i "s/MY_SERVER_PROXYNAME/$(MY_SERVER_PROXYNAME)/" $@

cacerts: .FORCE
	# building cacerts
	@mkdir -p target
	@if [ "$(MY_CACERT_FILE)" ]; then \
	  if [ "$(MY_CACERT_ALIAS)" ]; then \
	    FINGERPRINT=$$(openssl x509 -in $(MY_CACERT_FILE) -sha1 -noout -fingerprint | cut -f2 -d "="); \
	    echo "Local certificate fingerprint $$FINGERPRINT"; \
	    $(APP_HOME)/jre/bin/keytool -list -keystore $(APP_HOME)/jre/lib/security/cacerts -storepass changeit | grep -q $$FINGERPRINT; \
	    if [ $$? -ne 0 ]; then \
	      echo "Adding to keystore in target folder.."; \
	      cp $(APP_HOME)/jre/lib/security/cacerts target/cacerts; \
	      $(APP_HOME)/jre/bin/keytool -importcert -file $(MY_CACERT_FILE) -alias $(MY_CACERT_ALIAS) -keystore target/cacerts -storepass changeit -trustcacerts -noprompt; \
	      if [ $$? -eq 0 ]; then \
	        echo "Done."; \
	      fi \
	    else \
	      echo "Already present in keystore."; \
	    fi \
	  else \
	    echo "Local certificate alias not defined"; \
	  fi \
	else \
	  echo "Local certificate file not configured"; \
	fi

jars: target/cas-client-core-3.4.2-SNAPSHOT.jar target/cas-client-integration-atlassian-3.4.2-SNAPSHOT.jar

target/cas-client-core-3.4.2-SNAPSHOT.jar target/cas-client-integration-atlassian-3.4.2-SNAPSHOT.jar:
	# building CAS client jars
	@mkdir -p target
	@TMP=$$(mvn -v 2>/dev/null); if [ $$? -ne 0 ]; then \
	  echo "Apache Maven (mvn) or JDK missing, see make deps"; \
	  exit 1; \
	fi
	@if [ ! -d target/java-cas-client.197 ]; then git clone https://github.com/jhitt25/java-cas-client.git target/java-cas-client.197; fi
	@if [ ! -f target/cas-client-core-?.?.*.jar ] || [ ! -f target/cas-client-integration-atlassian-?.?.*.jar ]; then \
	  cd target/java-cas-client.197; \
	  git checkout $(JAVA_CAS_CLIENT_COMMIT); \
	  mvn clean package -pl cas-client-support-saml,cas-client-core,cas-client-integration-atlassian; \
	  rm -f ../cas-client-core-?.?.*.jar; \
	  rm -f ../cas-client-integration-atlassian-?.?.*.jar; \
	  cp cas-client-core/target/cas-client-core-3.4.2-SNAPSHOT.jar ../; \
	  cp cas-client-integration-atlassian/target/cas-client-integration-atlassian-3.4.2-SNAPSHOT.jar ../; \
	fi

deps:
	#
	# To build java-cas-client JDK and Apache Maven are required
	# Assuming JDK is installed in /usr/local, Apache Maven can be set up with following recipe sample:
	#
	@mkdir -p target
	@echo "cd target && wget -q http://mirrors.ircam.fr/pub/apache/maven/maven-3/3.3.9/binaries/apache-maven-3.3.9-bin.tar.gz && \\"
	@echo "wget -q https://www.apache.org/dist/maven/maven-3/3.3.9/binaries/apache-maven-3.3.9-bin.tar.gz.asc && \\"
	@echo "wget -q https://www.apache.org/dist/maven/KEYS && \\"
	@echo "gpg --import KEYS && \\"
	@echo "gpg --verify apache-maven-3.3.9-bin.tar.gz.asc apache-maven-3.3.9-bin.tar.gz && \\"
	@echo "tar -C /usr/local/ -xvzf apache-maven-3.3.9-bin.tar.gz && \\"
	@echo "export JAVA_HOME=/usr/local/jdk1.8.0_121 && export PATH=\$$JAVA_HOME/bin:/usr/local/apache-maven-3.3.9/bin:\$$PATH && cd .."
	#

version: .FORCE
	@VERSION=$$(ls $(APP_HOME)/atlassian-jira/WEB-INF/lib/jira-api-?.?.?.jar | sed -e "s/.*jira-api-\(.*\).jar/\1/"); \
	echo "JIRA version is $$VERSION"

clean:
	@rm -Rf target/*

.FORCE:
