#!/usr/bin/env bash

set -e
 
mkdir -p ${TOPAZ_DIR}/config
mkdir -p ${TOPAZ_DIR}/certs
mkdir -p ${TOPAZ_DIR}/db

/app/topazd run -c ${TOPAZ_DIR}/config/config.yaml

