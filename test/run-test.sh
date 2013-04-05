#!/bin/bash

##
### The following commands are examples of running agents inside this code checkout
## 

jruby -S bin/ami-agents --agent basic --config test/homebase-test.yml
jruby -S bin/ami-agents --agent reelweb --config test/reelweb-test.yml
jruby -S bin/ami-agents --agent dispatch --config test/dispatch-test.yml
jruby -S bin/ami-agents --agent create_image --config test/create-image-test.yml
