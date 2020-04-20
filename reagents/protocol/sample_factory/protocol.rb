
needs "Standard Libs/UploadHelper"
class Protocol
  include UploadHelper
  
  # I/O
  OUT_PLATE="Aquarium Sample"
  
  #enter the path to your file for DIRNAME here  (prompted by default if using manager)
  DIRNAME = "/Users/Jonny/Downloads/Untitled spreadsheet - Sheet1 (1).csv" #the path to CSV value.
  
  # the uploaded file must have this name
  # TODO: Add an upload method that checks for this filename! 
  FILENAME = "media_protocols.csv"

  # This protocol allows you to upload a CSV file of the different reagents and medias that you wish
  # to create. The CSV should contain the sample type name, instructions to create this kind of sample, and
  # the different ingredients necessary for the creation of the sample type.
  # The media/reagent gets created as a sample type in Aquarium. 
  def main
    operations.each { |op|
      template = [['sample: Sample Name', '', '', '', ''],['title: Title 1', 'title 1\'s step 1', 'title 1\'s step 2','title: Title n', '...'],['Ingredient 1', 'Ingredient 1\'s quantity', 'Ingredient k', 'Ingredient k\'s quantity', '...']]
      show {
        title "File format (csv)"
        table template
      }
      
       ups = upload_file
       if ups.nil?
         show { note "No files found..."}
         return
       end

      file = ups[0]
      data = read_url(file)
      
      # Remove nils from the data array.
      remove_data_nils data
      
      if(data.empty?)
        show { note "no data, returning..." } 
        return
      end
      
      # Look through data for duplicates
      create_samples data
  
    }
  end
  
  # Given fields and attributes of a sample, this method 
  # creates a sample in the Aquarium inventory and returns the sample.
  # INPUTS: nameStr, descriptionStr, projectStr
  # OUTPUTS: s 
  def createMedia(nameStr, descriptionStr, projectStr)
    s = Sample.creator(
    {
      sample_type_id: SampleType.find_by_name("Media").id,
      description: descriptionStr,
      name: nameStr, 
      project: projectStr
    }, User.find(1) )
  end

  # Prompts the user to upload the "media_protocols.csv" file and returns it.
  # OUTPUT: ups
  def upload_file

    # attempt to upload .csv file
    ups = uploadData(DIRNAME, 1, 3) #parameters are amount of tries

    if(DIRNAME.empty?)
        show { note "no path file, returning..." }
        return
    end
    
    if(!DIRNAME.include? "csv")
        show { note "not a csv file, returning..." }
        return
    end
    
    if(ups.nil?)
        show { note "no uploads, returning..." } 
        return
    end
    
    if(ups[0].nil?)
        show { note "no uploads, returning..." } 
        return
    end
    
    ups #return
  end
  
  # Accepts a data 2d array and removes nil values from it.
  # INPUTS: data
  def remove_data_nils data
    data.each_index do |i|
      j = 0
      loop do
        if j >= data[i].length
          break
        end
        if data[i][j].nil?
          data[i].delete_at(j)
        end
        
        if !data[i][j].nil?
          j += 1
        end
      end
    end
  end
  
  # Creates the actual samples in Aquarium.
  # INPUTS: data
  def create_samples data
    data.each do |line|
      if !line.empty?
        if line[0].include? "sample"
          # check and see if this sample exists in inventory
          sample_array = line[0].partition(":")
          sample_name = sample_array[2].strip #removes leading and trailing whitespace.
          sample_check = Sample.find_by_name(sample_name)
          if sample_check.nil?
            # create the media
            sample = createMedia(sample_name, "new sample", "media")
            show do
              title "Sample Created"
              
              note "The sample #{sample_name} has been sucessfully created in Aquarium"
            end
          end
        end
      end
    end   
    
    show do
      title "Samples Created"
      
      note "The samples in #{FILENAME} have been sucessfully created in Aquarium."
      note "Please double check and see if you include the word \"sample:\" before your sample name."
    end
  end
end