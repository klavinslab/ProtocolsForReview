# SG
# estimate transformation efficiency based on series of dilution plates 
# input is serial dilution, 3 plates taped together
needs "Standard Libs/UploadHelper"
class Protocol
    
    include UploadHelper
    
    # I/O
    INPUT="Dilution Plates" 
     
    # other
    LABELS=["A","B","C"]
    MIN_COLONY_COUNT=100 # minimum allowed number of colonies on lowest concentration plate  
    PREFIX="serial"
    DIR="(wherever you saved file)"
    
    def main
        
        # no output so no make
        operations.retrieve
        
        # intro
        show do
            title "Before you begin..."
            note "You will take images of sets of plates and estimate the number of colonies on the plates. Each set of <b>#{LABELS.length}</b> plates corresponds to a single experiment. The plates are labeled <b>#{LABELS.to_sentence}</b>, with an additional number that is not used in this protocol. Plate <b>#{LABELS[0]}</b> is additionally labeled with an Aquarium ID."
            warning "Be careful not to mix plates from different experiments! Only plate #{LABELS[0]} of each set has an Aquarium item number!"
        end
        
        # estimate number of colonies
        show do
            title "Estimate the number of colonies"
            note "Count the number of colonies on plates <b>#{LABELS.to_sentence}</b>. If relevant, you may estimate the number by counting a portion of the plate and multiplying."
            warning "Count for one set at a time. Be careful not to mix plates from different sets!"
            note "Enter the number of colonies on ech plate into the table below:"
            table operations.start_table
              .custom_column(heading: "Set ID (on Plate <b>#{LABELS[0]}</b>) ", checkable: true) { |op| op.input(INPUT).item.id }
              .get(:"colonies_#{LABELS[0]}", type: 'number', heading: "Plate <b>#{LABELS[0]}</b>", default: 0) 
              .get(:"colonies_#{LABELS[1]}", type: 'number', heading: "Plate <b>#{LABELS[1]}</b>", default: 0) 
              .get(:"colonies_#{LABELS[2]}", type: 'number', heading: "Plate <b>#{LABELS[2]}</b>", default: 0) 
              .end_table   
        end
        # associate colony numbers
        operations.each { |op|
            (0..(LABELS.length-1)).to_a.each { |ind|
                op.input(INPUT).item.associate :"colonies_#{LABELS[ind]}", op.temporary[:"colonies_#{LABELS[ind]}"].to_f
            }
            op.input(INPUT).item.associate :efficiency, ("%.1E" % ((op.input(INPUT).item.get_association(:colonies_B).value * 8000 + op.input(INPUT).item.get_association(:colonies_C).value * 80000) / 2))
            op.input(INPUT).item.associate :pass, (op.input(INPUT).item.get("colonies_#{LABELS[LABELS.length-1]}").to_f >= MIN_COLONY_COUNT) 
        }
        
        # associate efficiency for glyercol stocks in another operation if it exists
        # debug breaks because it doesn't have any predecessors. only works in plan with a predecessor
        if (!debug)
            operations.each do |op|
                other_operations_from_predecessor = Operation.find(op.id).predecessors[0].successors
                if (other_operations_from_predecessor.length == 2)
                  stocks_operation = other_operations_from_predecessor.select { |op| op.operation_type_id == OperationType.find_by_name("Make Library Glycerol Stocks").id}[0]
                  if (stocks_operation.status == 'done')
                      stocks_outputs = stocks_operation.output_array('Yeast Culture')
                      stocks_outputs.each do | fv |
                        fv.item.associate(:efficiency, op.input(INPUT).item.get_association(:efficiency).value)
                      end
                  end
                end
            end
        end
        
        # image plates and upload 
        tab=[]
        tab[0]=["Dilution Set (#{LABELS.length} plates)","Image name"]
        operations.each_with_index { |op,ii|
            tab[ii+1]=[{content: "#{op.input(INPUT).item} #{LABELS.to_sentence}", check: true}, "#{PREFIX}_#{op.input(INPUT).item.id}"]
        }
        show do
            title "Image dilution plates"
            warning "Use your phone to take images. If you do not have a phone or can't upload from your phone, notify a lab manager."
            note "Take a single image for each row in the table, upload to the desktop of your computer."
            note "Rename the images as follows:"
            table tab
            note "You will now upload the images to aquarium, one at a time"    
        end
        
        # upload and associate to dilution set
        operations.each { |op|
            ups=uploadData("#{DIR}/#{PREFIX}_#{op.input(INPUT).item.id}", 1, 3) # 1 upload, 3 tries 
            if(!ups.nil?)
                if(!ups[0].nil?)
                    up=ups[0]
                    # associate to item, plan
                    op.input(INPUT).item.associate "image", up  
                    op.plan.associate "#{PREFIX}_#{op.input(INPUT).item.id}", "#{PREFIX} #{up[:id]} #{up[:name]} plan note", up
                end
            end
        }
        
        # find source culture and associate results 
        bad_stocks=[]
        operations.each { |op|
            source=nil # 'source culture' for these plates 
            stocks=nil  # glycerol stocks made from the source culture 
            begin
                source=Item.find(op.input(INPUT).item.get(:source)) # 'source' is an item id, otherwise nil
                stocks=source.get(:glycerol_stocks) # 'glycerol_stocks' is an array of item ids, otherwise nil
                
                # assume source, stocks ok - otherwise see rescue
                source.associate :pass, op.input(INPUT).item.get(:pass) 
                source.associate :pass_item, op.input(INPUT).item
                stocks.each { |st|
                    stock=Item.find(st)
                    stock.associate :pass, op.input(INPUT).item.get(:pass) # true/false
                    stock.associate :pass_item, op.input(INPUT).item.id # id of plates used to determine pass true/false
                }
                if(! (op.input(INPUT).item.get(:pass) ) ) # if failed (less than 2 colonies)
                        bad_stocks=[bad_stocks,stocks].flatten 
                end 
            rescue
                if(source.nil?)
                    show do
                        title "Problem!"
                        note "There is no 'source culture' defined for dilution plates item #{op.input(INPUT).item}. Please notify a lab manager before continuing."
                    end
                elsif(stocks.nil?)
                    show do
                        title "Problem!"
                        note "There are no 'glycerol stocks' defined for source #{source} of dilution plates item #{op.input(INPUT).item}. Please notify a lab manager before continuing."
                    end
                end
            end
        }
        
        if(! (bad_stocks.empty?) ) # get rid of "failed" glycerol stocks
            tab=[]
            tab[0]=["Glycerol Stock Item ID", "Location"]
            bad_stocks.each_with_index { |bs, ii| # bad_stocks is an array of item ids
                bstock=Item.find(bs)
                tab[ii + 1]=["#{bstock}", "#{bstock.location}"]
                bstock.mark_as_deleted # delete stocks
            }
            show do
                title "Dispose of low-efficiency transformed glycerol stocks"
                check "Remove the following glycerol stocks from the M80 and trash them in a biohazard bin:"
                table tab
            end
        end
        
        # delete plates and trash them
        show do
            title "Cleanup"
            check "Trash set(s) #{operations.map { |op| op.input(INPUT).item }.to_sentence } of dilution plates <B>#{LABELS.to_sentence}</b>"
        end
        operations.each { |op|
            op.input(INPUT).item.mark_as_deleted
        }
        
        # no store - no outputs
        
        return {}
        
    end # main

end # Protocol
