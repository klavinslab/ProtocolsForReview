needs "Tissue Culture Libs/TissueCulture"

# TODO: Add specific media

class Protocol
    include TissueCulture

    OUTPUT = "Plate"
    def main
    

        operations.retrieve.make
        
        plates = operations.running.map { |op| op.output(OUTPUT).item }
        
        show do
            title "Get Plates"
            plates = get_plates
            plates.each do |plate|
                note "#{plate}" 
            end
        end
        
        vops = get_plates_as_vop
        
        show do
            title "Get Plates as vops"
            table vops.start_table
            .custom_column(heading: "item id") { |op| op.temporary[:plate].id }
            .end_table
        end
        
        plates.each { |plate| plate.confluency }
        show { note 'something' }
        show do
            title "Base Cell Lines vs Parents"
            table vops.start_table
            .custom_column(heading: "Plate") { |op| op.temporary[:plate].id }
            .custom_column(heading: "Sample Type") { |op| SampleType.find_by_id(op.temporary[:plate].sample.sample_type_id).name }
            .custom_column(heading: "Sample") { |op| op.temporary[:plate].sample.name }
            .custom_column(heading: "Properties") { |op| op.temporary[:plate].sample.properties }
            .custom_column(heading: "Parent") { |op| op.temporary[:plate].parent }
            .custom_column(heading: "Cell Line") { |op| op.temporary[:plate].cell_line }
            .end_table
        end
        
        show do
            title "Seed 1"
            plates.each do |plate|
                plate.update_seed 10, 1
            end
            plates.each do |plate|
                note "#{plate.associations}" 
                note "Age: #{plate.age}"
                note "Seed Age: #{plate.age_since_seed}"
            end
        end
        
        show do
            title "Confluency, passage"
            plates.each do |plate|
                note "#{plate.id} confluency: #{plate.confluency}"
                note "#{plate.id} passage: #{plate.passage}"
            end
        end
        
        show do
            title "Update confluency"
            plates.each do |plate|
                plate.confluency = plate.confluency + rand(1..10)
            end
            plates.each do |plate|
                note "#{plate.id} confluency: #{plate.confluency}"
                note "#{plate.id} passage: #{plate.passage}"
            end
        end
        
        show do
            title "Seed 2"
            plates.each do |plate|
                plate.clear_record
                plate.update_seed 10, 3
                note "#{plate.associations}" 
            end
        end
        
        show do
            title "Split 1"
            plates.each { |plate| plate.clear_record }
            p1 = plates.first
            p2 = plates[1]
            s = 90
            p1.update_seed s, 3
            s2 = 10
            x = p2.split_from p1, s2
            note "#{p1.object_type.name} #{x.round(2)} #{p2.object_type.name} at #{s2}"
            plates.each do |plate|
                note "#{plate.associations}" 
            end
        end
        
        operations.store
        
        return {}
    
    end

end
