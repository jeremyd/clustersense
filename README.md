# Thank you for flying Cluster Sense!

# What is it?

A real-time API for interacting with clusters of servers.


# Why would I use it?

Quickly build automation workflows with a ruby API.

# Quickstart

## Install from packages (Ubuntu)

http://s3.amazonaws.com/clustersense/repositories.html

### Install the pre-requirements from system packages:

### Ruby

- Ruby >= 1.9 with bundler >= 1.3 -or- jruby

### Zookeeper

    sudo apt-get install zookeeper
    zkServer.sh start

## Install from source

    git clone https://github.com/jeremyd/clustersense
    cd clustersense
    bundle install --standalone
    bin/clustersense --help

# Usage

## Integration Test

    test/run_test.rb

## Agent Config and Daemonize

    # The webserver UI
    clustersense --start reelweb --config test/reelweb.yaml

    # Example wizard that can run scripts.
    clustersense --agent script_wizard --config test/script_wizard.yaml

    # Two app servers that can be managed by basic agent.
    clustersense --agent basic --config test/app1.yaml
    clustersense --agent basic --config test/app2.yaml

    # Enable app1 to start via upstart
    sudo clustersense --enable --agent basic --config test/app1.yaml
