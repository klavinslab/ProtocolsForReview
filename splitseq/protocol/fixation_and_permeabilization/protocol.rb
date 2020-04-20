# Adapted from Charlie Rocco (Seelig Lab)
# 2018-07-19

class Protocol

  def main

    operations.retrieve.make
    
    tin  = operations.io_table "input"
    tout = operations.io_table "output"
    
    show do 
      title "Input Table"
      table tin.all.render
    end
    
    show do 
      title "Output Table"
      table tout.all.render
    end
    
    show do
        title "Prepare the following buffers (calculated for two experiments)"
        
        check "1.33% formalin (360 uL of 37% formadlehyde solution (Sigma) + 9.66 mL PBS"
        check "6 mL of 1X PBS+RI (15uL of SUPERase In and 7.5 uL of Enzymatics RNase inhibitor)"
        check "2 mL of 0.5X PBS+RI (5 uL of SUPERASE in and 2.5 of Enzymatics RNase inhibitor)"
        check "500uL of 5% Triton X-100 + RI (2 uL of SUPERase In)"
        check "1.1 mL of 100 mM Tris pH 8.0 + 4uL of SUPERase In"
        check "Set the centrifuge to 4C"
    end
    
    show do
        title "Pellet and resuspend cells"
        
        check "Pellet cells by centrifugaing at 500 x g for 3 minutes at 4C"
        check "Resuspend cells in 1mL of cold PBS+RI."
        check "pass cells through a 40um straining into a fresh 15mL Falcon tube and place on ice"
        warning "Keep cells on ice during all steps"
        note "Note: The cell resuspension is not likely to passively go through the strainer,
which can cause cell loss. Instead, with a 1ml pipette filled with the resuspension,
press the end of the tip directly onto the strainer and actively push the liquid
through. The motion should take ~1 second."
    end
    
    show do
        title "Permeabilize"
        
        check "Add 3mL of cold 1.33% formadlehyde (final concentration 1%). Fix cells on ice for 10 minutes."
        check "Add 160uL of 5% Triton-X100+RI to fixed cells and mix by gently pipetting up and down
5x with a 1mL pipette. Permeabilize cells for 3 mins on ice"
        
    end
    
    show do
        title ""
        
        check "Centrifuge cells at 500g for 3 mins at 4C."
        check "Aspirate carefully and resuspend cells in 500 uL of cold PBS+RI."
        check "Add 500uL of cold 100 mM Tris-HCl, pH 8.0."
        check "Add 20 uL of 5% Triton X-100."
    end
    
    show do
        check "Centrifuge cells at 500g for 3 mins at 4C."
        check "Aspirate and resuspend cells in 300 ul of cold <b>0.5x</b> PBS+RI."
        check "pass cells through a 40um straining into a fresh 15mL Falcon tube and place on ice"
        note "Note: The cell resuspension is not likely to passively go through the strainer,
which can cause cell loss. Instead, with a 1ml pipette filled with the resuspension,
press the end of the tip directly onto the strainer and actively push the liquid
through. The motion should take ~1 second."
    end
    
    show do
        title "Count cells"
        
        check "Count cells using a hemacytometer or a flow-cytometer"
        check "Dilute cell suspension to 1,000,000 cells/mL"
        warning "While counting cells, keep cell suspension on ice"
        note "Note: This step will dictate how many cells enter the split-pool rounds. It will be possible
to sequence only a subset of the cells that enter the split-pool rounds (can be done
during sublibrary generation at lysis step). The total number of barcode combinations
you will be using should be calculated to determine the maximum number of cells you
can sequence with minimal barcode collisions. As a rule of thumb, the number of cells
you process should not exceed more than 5% of total barcode combinations. We usually
have a dilution between 500k to 1M cells/mL here (equates to 4-8k cells going into each
well for reverse transcription barcoding rounds)."
    end
    
    operations.store
    
    return {}
    
  end

end
