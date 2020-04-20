**WARNING: BETA VERSION. USE WITH CAUTION**

This is a general purpose experimental workflow logic block

Switch logic is encoded into the JSON parameter as an array of boolean expressions to be evaluated on the input, where each index in the condition array corresponds to an index in the output array. **The amount of output paths must match the amount of conditional expressions.**

The following example assumes 3 output paths. It will trigger the first branch coming from this block if the item passed through has an association: "Verified" => "yes".
It will trigger the second and third branch if the item has "Verified" => "no" instead

```
  {
    [
        'item.get("Verified") == "yes"',
        'item.get("Verified") == "no"',
        'item.get("Verified") == "no"'
    ]
  }
```

At the end of all switch cases, any remaining output routes that have not been triggered will be errored. For the above example, supposing the verification answer was 'yes', then branch 0 would start execution, while branch 1 and 2 would error out.

We can case on any information associated with the input item, the input sample, or any other data relation of the input object. See the [FieldValue Documentation](http://klavinslab.org/aquarium/api/FieldValue.html) for a reference of all the attributes of input objects. Input objects are a form of a FieldValue object.

If you would like to encode an arbitrary conditional expression to be evaluated in the namespace of the functional block rather than fields of the input object, append the condition for that route with `:::`


```
  {
    [
        ':::User.find(op.plan.user_id).name == "Abe Miller"',
        ':::User.find(op.plan.user_id).name == "Bill Gates"',
    ]
  }
```

Now, if Abe owns the plan, branch 0 will run. If Bill owns the plan, branch 1 will run. And if someone else besides Abe or Bill owns the plan, then both branches will cancel. 
