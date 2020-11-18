#!/bin/bash

multipass delete worker 2> /dev/null
multipass delete master 2> /dev/null
multipass purge