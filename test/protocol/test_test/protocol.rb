# This is a default, one-size-fits all protocol that shows how you can 
# access the inputs and outputs of the operations associated with a job.
# Add specific instructions for this protocol!
needs "Standard Libs/Debug"
class Protocol
    include Debug
  def main
    bead_stock = Item.find(119541)
    lot_num = 'AJ03'
    d_beads = bead_stock.sample.in('Diluted beads')#.select{ |item| item.get('Lot No.') == bead_stock.get('Lot No.') }
    show{ note"#{ d_beads.map {|i| log_info i.get('Lot No.')}}"}
    operations.retrieve.make
    
    tin  = operations.io_table "input"
    tout = operations.io_table "output"
    
    show do 
      title "Input Table"
      table tin.all.render
    end
    # - syntax error
    show do 
      title "Output Table"
      table tout.all.render
    end
    
    operations.store
    
    return {}
    
  end

end
