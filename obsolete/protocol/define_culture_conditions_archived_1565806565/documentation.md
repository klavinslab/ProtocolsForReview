
This operation allows a user to define conditions for a High Throughput Culturing Experiment
 

These conditions will be wired to `Inoculate Culture Plate` to define parameters for an experiment.

 
### Defining Culture Conditions
For parameters that will not be used or filled use an empty `{}`

#### Strain
Enter the name or id of the Strain.

#### Media
Enter the name or id of the Media.

#### Inducer(s)
Enter a JSON object to represent 
the type of inducer by `name`,
the desired `final_concentration`, and
the `item_id` of the stock that will
be used and diluted.
    
      { 
        "beta-estradiol": {
          "final_concentration": [
            "100_nM","200_nM"
            ]
          },
        "IPTG": {
          "final_concentration": ["50_nM"]
        }
      }
      
Represents the following conditions:
1. `b-e at 100nM + IPTG at 50nM`
2. `b-e at 200nM + IPTG at 50nM`

#### Antibiotic(s)
Enter a JSON object to represent
additional antibiotics.
Follow the example below:
    
    {
      "Ampicillin Antibiotic": {
        "final_concentration": "10_ug/mL"
      }
    }

You can see the stock concentration
on the sample properties under,
the description of the sample.
    
#### Control Tag
Enter a JSON object to tag control.
The key represents the type of control
and value represents positive or negative.
Then, you can add your own additional
information.
    
    For a flow cytometry control,
    use the example below.
    {
      "flourescence_control": "positive",
      "channel": "tdTomato"
    }
    
    Example growth control:
    {
      "growth_control": "negative"
    }
    
This tag will allow Aq to place these
cultures in all of the plates in the
planned experiment.
    
#### Replicates
Enter an integer of the number of 
replicates (cultures) desired for 
each of the conditions.
    
#### Option(s)
Enter a JSON object for additional 
options. This could be used for 
notes or a way to prototype
new operation features.