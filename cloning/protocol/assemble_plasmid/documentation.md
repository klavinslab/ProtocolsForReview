Assembles Plasmid.

The technician combines the input array of fragments and, using Gibson Assembly, assembles a plasmid. Each Gibson reaction is fixed at a volume of 5 uL, and so the volume of each fragment is calculated using an algorithm that takes in the number of total fragments in the Gibson reaction and the concentration in ng/uL of each individual fragment. The lower bounds for volume is 0.2 uL; if any fragment is below 0.2 uL, or if the overall reaction is greater than 5 uL, the volumes are tweaked for each fragment until the reaction is once more balanced. The reaction is then placed on a 42 F heat block for one hour.

Ran after **Make PCR Fragment** (if the fragment is not already in inventory) and is a precursor to **Transform Cells**.