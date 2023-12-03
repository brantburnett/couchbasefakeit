ARG COUCHBASE_TAG=enterprise-7.2.3
FROM btburnett3/couchbase-quickinit:${COUCHBASE_TAG} as base

# Install Node 12 because fakeit isn't compatible with newer versions
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.5/install.sh | bash && \
    rm -f $HOME/.npmrc
ENV NVM_DIR=/root/.nvm
RUN \. $NVM_DIR/nvm.sh && \
    nvm install 12.22.12



FROM base as restore

# Install build essentials in a separate stage because we only need it during restore
RUN apt-get update && \
    apt-get install build-essential -y

# Copy package.json
WORKDIR /fakeit
COPY ./scripts/package*.json ./

# Install fakeit
RUN \. $NVM_DIR/nvm.sh && \
    nvm use 12.22.12 && \
    npm ci



FROM base as final

# Copy node_modules
COPY --from=restore /fakeit/node_modules/ /fakeit/node_modules/

# Copy startup scripts
COPY ./scripts/ /fakeit/
RUN echo "/fakeit/run-fakeit.sh" >> /scripts/additional-init.sh

# Configure default environment
ENV FAKEIT_BUCKETTIMEOUT=5000
