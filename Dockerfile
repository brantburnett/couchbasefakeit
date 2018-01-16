FROM couchbase:enterprise-4.6.3

# Configure apt-get for NodeJS
# Install NPM and NodeJS and jq, with apt-get cleanup
RUN curl -sL https://deb.nodesource.com/setup_6.x | sudo -E bash - && \
	apt-get install -yq nodejs build-essential jq && \
    apt-get autoremove && apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
	
# Upgrade to jq 1.5
RUN wget https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64 && \
	chmod +x jq-linux64 && \
	mv jq-linux64 $(which jq)

# Install fakeit
RUN npm install -g fakeit && \
    rm -rf /tmp/* /var/tmp/*
	
# Install nodejs couchbase package
# prc use this version because auth problems
RUN npm install -g couchbase@2.2.2
	
# Configure default environment
ENV CB_DATARAM=512 CB_INDEXRAM=256 CB_SEARCHRAM=256 \
	CB_SERVICES=kv,n1ql,index,fts CB_INDEXSTORAGE=forestdb \
	CB_USERNAME=Administrator CB_PASSWORD=password \
	FAKEIT_BUCKETTIMEOUT=5000 \	
	NODE_PATH=/usr/lib/node_modules

RUN mkdir /nodestatus
VOLUME /nodestatus
	
# Copy startup scripts
COPY ./ /

ENTRYPOINT ["/scripts/configure-node.sh"]