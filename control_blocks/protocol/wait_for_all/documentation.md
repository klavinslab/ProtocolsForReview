This operation waits for all other "Wait for All" operations to be ready. This is useful for setting up where you require operations *in the same plan* to be batched together. User chooses an experiment number and some notes. The precondition for all operations will simply be delayed until all `Wait for All` operations of the same experiment number are in "delayed", with input items available
Sets precondition notes (e.g. "Waiting for operations ..., ... ,...")

Note that this block only works with operations **in the same plan**. 

Also note that you **must** set the **Experiment Number** parameter for each `Wait for All` operation. This will indicate which experiment the operation belongs to.