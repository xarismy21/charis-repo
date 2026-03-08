# charis-repo DevOps Assessment #Papaoikonomou Charis#

## Quick Start

Clone repository

git clone https://github.com/xarismy21/charis-repo

cd charis-repo

## Build API

cd api

go build

## Build container

docker build -t charis-api ./docker

## Validate infrastructure

cd terraform

terraform init

terraform plan
