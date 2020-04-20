This operation can be used as the general starting point for most kinds of high throughput culture experiments. 

When a list of valid culture condition definitions are wired in to this operation, the operation transfers the cultures onto a 96 well plate in an optimal layout with the respective overnight media for each culture, as specified. This plate is then put in the incubator overnight and all cultures within are brought to saturation. 

For a adequetly defined experiment, all `Culture Condition` inputs must be wired in from a filled out `Define Culture Conditions` block.

If the `Prepare Experimental Media now?` parameter is agreed to, a large amount of experimental media is prepared during execution in addition to starting the overnight. Say yes to this option if you intend to start a high throughput induction experiment soon after.

Regardless of whether you intend to start an experiment immediately, or to make a glycerol stock plate for long term storage and shipping; it is recommended to follow up this operation by recovering the cultures from saturation to log phase growth with the `Recover Cultures to Log Phase` operation.