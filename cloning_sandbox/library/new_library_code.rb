# Library code here

module SerialDilution
    include Math

    def determine_dilutions(conc, final, size)
      num_dilutions = log(conc/final) / log(size)
      c = (conc/final)**(1.0/num_dilutions.ceil)
      return [c]*num_dilutions.ceil
    end
    
    MIN_PIPETTE_VOL = 2
    MIN_TOTAL_VOL = 10
    MAX_TOTAL_VOL = 1000
    
    def serial_dilutions(stock_conc, concentrations, min_tot_vol, min_pipette_vol)
    
    
      conc = stock_conc
      _c = stock_conc
      _c_arr = [_c]
      dilutions = concentrations.map do |c|
    
        dilutions = determine_dilutions(conc, c, 25)
        dilutions.each do |d|
          _c = 1.0 * _c / d
          _c_arr << _c
        end
        conc = c
        dilutions
      end
    
      volumes = dilutions.flatten.map do |d|
        v = min_pipette_vol*d
        pvol = min_pipette_vol
        x = (v / min_tot_vol)
        if x.floor == 0
          pvol = pvol / x
          v = v / x
        end
        diluant_vol = v - pvol
        [pvol, diluant_vol]
      end
    
      return dilutions, _c_arr, volumes
    end
    
    # # puts determine_dilutions(1000, 3, 25)
    # dilutions = serial_dilutions(450000, [2000, 500, 20], 10, 2)
    # dilutions.each do |d|
    #   puts "#{d}"
    # end
end