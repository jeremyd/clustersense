#!/bin/bash

##
### The following commands are examples of running agents inside this code checkout
## 

jruby -S bin/clustersense --agent basic --config test/homebase-test.yml
jruby -S bin/clustersense --agent reelweb --config test/reelweb-test.yml
jruby -S bin/clustersense --agent dispatch --config test/dispatch-test.yml
jruby -S bin/clustersense --agent create_image --config test/create-image-test.yml
