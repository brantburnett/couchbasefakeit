FROM couchbase:enterprise-5.1.0

# Configure apt-get for NodeJS
# Install NPM and NodeJS and jq, with apt-get cleanup
RUN curl -sL https://deb.nodesource.com/setup_6.x | bash - && \
	apt-get install -yq nodejs build-essential jq && \
    apt-get autoremove && apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
	
# Upgrade to jq 1.5
RUN wget https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64 && \
	chmod +x jq-linux64 && \
	mv jq-linux64 $(which jq)
	
# Copy package.json
WORKDIR /scripts
COPY ./scripts/package*.json ./

# Install fakeit, couchbase-index-manager, and couchbase
RUN npm install && \
    rm -rf /tmp/* /var/tmp/*

# Copy startup scripts
COPY ./scripts/ /scripts/
COPY ./startup/ /startup/
	
# Configure default environment
ENV CB_DATARAM=512 CB_INDEXRAM=256 CB_SEARCHRAM=256 \
	CB_SERVICES=kv,n1ql,index,fts CB_INDEXSTORAGE=forestdb \
	CB_USERNAME=Administrator CB_PASSWORD=password \
	FAKEIT_BUCKETTIMEOUT=5000

RUN mkdir /nodestatus
VOLUME /nodestatus

ENTRYPOINT ["./configure-node.sh"]