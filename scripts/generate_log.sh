#!/bin/bash

echo "Accessing 35.196.67.21 navigations service"
for i in {1..20}; do
  curl -s http://35.196.67.21/api/navigation > /dev/null
done

echo "Accessing 34.23.221.105 communications service"
for i in {1..20}; do
  curl -s http://34.23.221.105/api/communications > /dev/null
done
