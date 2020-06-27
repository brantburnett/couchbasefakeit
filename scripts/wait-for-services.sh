#!/bin/bash

if [[ $CB_SERVICES == *"n1ql"* ]]; then
  # Wait for the query service to be up and running
  for attempt in $(seq 10)
  do
    curl -s http://127.0.0.1:8093/admin/ping > /dev/null \
      && break

    echo "Waiting for query service..."
    sleep 1
  done

  # We're seeing sporadic issues with "Operation not supported" creating indexes
  # As painful as it is, an extra sleep is called for to make sure N1QL is fully up and running
  sleep 5
fi

if [[ $CB_SERVICES == *"fts"* ]]; then
  # Wait for the FTS service to be up and running
  for attempt in $(seq 10)
  do
    curl -s http://127.0.0.1:8094/api/ping > /dev/null \
      && break

    echo "Waiting for FTS service..."
    sleep 1
  done
fi
