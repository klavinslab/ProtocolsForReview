

# This is a default, one-size-fits all protocol that shows how you can
# access the inputs and outputs of the operations associated with a job.
# Add specific instructions for this protocol!

class Protocol

  def main
    
    m1 =[[27915, 27916, 27917, 27918, 27919, 27920, 27921, 27922, 27923, 27924, 27925, 27926], [-1, 27927, 27928, 27929, 27930, 27931, 27932, 27933, 27934, 27935, 27936, 27937], [27938, 27939, 27940, 27941, 27942, 27943, 27944, 27945, 27946, 27947, 27948, 27949], [27950, 27951, 27952, 27953, 27954, 27955, 27956, 27957, 27958, 27959, 27960, 27961], [27962, 27963, 27964, 27965, 27966, 27967, 27968, 27969, 27970, 27971, 27972, 27973], [27974, 27975, 27976, 27977, 27978, 27979, 27980, 27981, 27982, 27983, 27984, 27985], [27986, 27987, 27988, 27989, 27990, 27991, 27992, 27993, 27994, 27995, 27996, 27997], [27998, 27999, 28000, 28001, 28002, 28003, 28004, 28005, 28006, 28007, 28008, 28009]]
    m2 =[[28010, 28011, 28012, 28013, 28014, -1, -1, -1, -1, -1, -1, -1], [28015, 28016, 28017, 28018, -1, -1, -1, -1, -1, -1, -1, -1], [-1, 28019, 28020, 28021, -1, -1, -1, -1, -1, -1, -1, -1], [28022, 28023, 28024, 28025, -1, -1, -1, -1, -1, -1, -1, -1], [28026, 28027, 28028, 28029, -1, -1, -1, -1, -1, -1, -1, -1], [28030, 28031, 28032, 28033, -1, -1, -1, -1, -1, -1, -1, -1], [28034, 28035, 28036, 28037, -1, -1, -1, -1, -1, -1, -1, -1], [28038, 28039, 28040, 28041, -1, -1, -1, -1, -1, -1, -1, -1]]
    
    new_plates_to_generate = [m1,m2]
    
    new_plates_to_generate.each do |plt|
       new_collection = produce_new_plate() 
       new_collection.matrix = plt
       new_collection.save
       show do 
           title "TEST"
           note "#{new_collection.matrix}"
       end
    end
    

  end
    def produce_new_plate()
        # Produce 96 Well Adapter Plate collection
        container = ObjectType.find_by_name('96 Well PCR Plate')
        plt = produce new_collection container.name
        plt.location = "-80°C"
        # log_info 'Produced plt collection', plt
        return plt
    end

end
