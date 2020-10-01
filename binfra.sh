#!/bin/bash
set -euf
IFS=$'\n\t'

# Entry point of binfra lib

import lib/aws/profile
import lib/aws/ssm
import lib/aws/vpc
import lib/aws/rds
import lib/aws/fargate
import lib/aws/expose
