#!/bin/bash

(
  cd vault
  docker-compose down
)

kind delete cluster --name=so1
kind delete cluster --name=so2
rm -f ./clusters/generated/*
rm -f ./clusters/generated/*