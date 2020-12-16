#!/bin/bash

EXIT_CODE=0

function log_error() {
  echo $1 >> /nodestatus/errors
  >&2 echo $1

  # There's no point in waiting for buckets that aren't going to exist, so short circuit
  exit 1
}

if [[ $CB_SERVICES == *"n1ql"* ]]; then
  # Wait for the query service to be up and running
  for attempt in $(seq 10)
  do
    curl -s http://127.0.0.1:8093/admin/ping > /dev/null \
      && QUERY_INITIALIZED=1 \
      && break

    echo "Waiting for query service..."
    sleep 1
  done

  if [[ $QUERY_INITIALIZED != "1" ]]; then
    log_error "Query service not available within timeout"
    exit $EXIT_CODE
  fi

  # We're seeing sporadic issues with "Operation not supported" creating indexes
  # As painful as it is, an extra sleep is called for to make sure N1QL is fully up and running
  sleep 5
fi

if [[ $CB_SERVICES == *"fts"* ]]; then
  # Wait for the FTS service to be up and running
  for attempt in $(seq 10)
  do
    curl -s http://127.0.0.1:8094/api/ping > /dev/null \
      && FTS_INITIALIZED=1 \
      && break

    echo "Waiting for FTS service..."
    sleep 1
  done

  if [[ $FTS_INITIALIZED != "1" ]]; then
    log_error "FTS service not available within timeout"
    exit $EXIT_CODE
  fi
fi

if [[ $CB_SERVICES == *"eventing"* ]]; then
  # Wait for the eventing service to be up and running
  for attempt in $(seq 10)
  do
    curl -s http://127.0.0.1:8096/api/v1/functions > /dev/null \
      && EVENTING_INITIALIZED=1 \
      && break

    echo "Waiting for eventing service..."
    sleep 1
  done

  if [[ $EVENTING_INITIALIZED != "1" ]]; then
    log_error "Eventing service not available within timeout"
    exit $EXIT_CODE
  fi
fi

exit $EXIT_CODE
