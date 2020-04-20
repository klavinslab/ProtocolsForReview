Checks plates for growth and contamination.

The plates are pulled from the 37 F incubator and checked for growth and contamination. If there is no growth, the plate is thrown out and the user is notified.

Ran the day after **Plate Transformed Cells** and is a precursor to **Make Overnight Suspension**.

##NO ADDITIONAL STEPS REQUIRED FOR NON-FLUORESCENT PLATES##
For fluorecent plates additional plan parameters must be set.
Parameters to be set:
        fluorescent_marker: 'true'
        dark_light: 'dark' or 'light'  designates if the fluorescent
                    'dark' or fluorescent 'light' colonies are desired
        marker_type: 'venus' currently only venus is supported will                 default to venus.
To add parameters press the "Add Data" button below.
In the "key" box type "options"
In the next box type "{"key": "value", "key": "value"}
        eg. `{"fluorescent_marker": true, "dark_light": "dark", "marker_type": "GFP"}`