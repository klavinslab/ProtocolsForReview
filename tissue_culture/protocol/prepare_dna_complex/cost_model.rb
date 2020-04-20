# copies directly from TransfectionLibrary
def get_transfection_containers op, cells_fv_name
  input_plate_containers = []

  # Gather plate containers from input or successors' inputs
  if op.input(cells_fv_name)
    input_plate_containers << op.input(cells_fv_name).object_type
  else
    if op.successors.empty?
      # send_error op,  :unable_to_find_plate_sample, "Unable to find field value #{cells_fv_name} and operation has no successors."
    end
    op.successors.each do |suc|
      fv = suc.input(cells_fv_name)
      if fv.nil?
        #   send_error op,  :unable_to_find_plate_sample, "Unable to find input plate #{cells_fv_name} for #{succ.operation_type.name}."
      else
        input_plate_containers << fv.object_type
      end
    end
  end
  input_plate_containers
end

def cost(op)
    return { labor: 0, materials: 0 }
#   pei = "PEI"
#   l3000 = "Lipofectamine 3000"


#   # Make sure these are the same as in the transfection library
#   reagent_ratio = {
#     pei=>3.0,
#     l3000=>1.5
#   }
#   t_to_wv = 0.1 # e.g. 100ul transfection mix per 1mL media in a 12-well dish
#   dna = 10.0 # ng / ul

#   reagent_cost = {
#     pei=>210.0/1000.0/1000.0 + 0.01,
#     l3000=>400/750.0
#   }

#   # Gets the working volume of the container/plate
#   def working_volume_of(container)
#     data = JSON.parse(container.data)
#     data["working_volume"].to_f
#   end

#   transfection_containers = get_transfection_containers op, "Parent Cell Line"
#   total_vol = transfection_containers.map { |c| working_volume_of(c) }.reduce(:+) * t_to_wv * 1000.0
#   dna_amount = total_vol * dna
#   reagent = op.input("Transfection Reagent").val.strip
#   reagent_ratio = reagent_ratio[reagent]
#   reagent_vol = dna_amount * reagent_ratio
#   optimem_vol = total_vol / 2.0

#   cost = reagent_cost[reagent] * reagent_vol
#   { labor: 5.0 + 1.0*op.input("Transfected Plasmids").size, materials: cost }
end