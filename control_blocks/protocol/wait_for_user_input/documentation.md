**WARNING: BETA VERSION. USE WITH CAUTION**

This is a control block that waits for specific response from the user. The precondition will:

1. attach a key-value to the operation's plan
2. wait for response
3. re-route the item to either the "Yes Response" or "No Response". Other response will simply have no item.
4. set this operation to "done"
5. attach a response message to this operation and the plan (using special key for each operation)
6. 

If there is already a key-value for the response, the operation will not create a new key-value, but will wait for the value to appear to respond