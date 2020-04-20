needs "Standard Libs/Units"
needs "Standard Libs/CommonInputOutputNames"

class PCRProgram

    include CommonInputOutputNames, Units

    FINAL_STEP = "12C (in final step of program)"

    PROGRAMS = {
        "qPCR1" => {
            name: "NGS_qPCR1.prcl", volume: 32, plate: "NGS_qPCR1.pltd",
            steps: {
                step1: {temp: {qty: 95, units: DEGREES_C}, time: {qty:  3, units: MINUTES}},
                step2: {temp: {qty: 98, units: DEGREES_C}, time: {qty: 15, units: SECONDS}},
                step3: {temp: {qty: 62, units: DEGREES_C}, time: {qty: 30, units: SECONDS}},
                step4: {temp: {qty: 72, units: DEGREES_C}, time: {qty: 30, units: SECONDS}},
                step5: {goto: 2, times: 34},
                # step6: {temp: {qty: 72, units: DEGREES_C}, time: {qty:  5, units: MINUTES}},
                step6: {temp: {qty: 12, units: DEGREES_C}, time: {qty: "forever", units: ""}}
            }
        },

        "qPCR2" => {
            name: "NGS_qPCR2", volume: 50, plate: "NGS_qPCR1.pltd",
            steps: {
                step1: {temp: {qty: 98, units: DEGREES_C}, time: {qty:  3, units: MINUTES}},
                step2: {temp: {qty: 98, units: DEGREES_C}, time: {qty: 15, units: SECONDS}},
                step3: {temp: {qty: 64, units: DEGREES_C}, time: {qty: 30, units: SECONDS}},
                step4: {temp: {qty: 72, units: DEGREES_C}, time: {qty: 30, units: SECONDS}},
                step5: {goto: 2, times: 29},
                step6: {temp: {qty: 72, units: DEGREES_C}, time: {qty:  5, units: MINUTES}},
                step7: {temp: {qty: 12, units: DEGREES_C}, time: {qty: "forever", units: ""}}
            }
        },

        "lib_qPCR1" => {
            name: "LIB_qPCR1.prcl", volume: 25, plate: "LIB_qPCR.pltd",
            steps: {
                step1: {temp: {qty: 95, units: DEGREES_C}, time: {qty:  3, units: MINUTES}},
                step2: {temp: {qty: 98, units: DEGREES_C}, time: {qty: 15, units: SECONDS}},
                step3: {temp: {qty: 65, units: DEGREES_C}, time: {qty: 30, units: SECONDS}},
                step4: {temp: {qty: 72, units: DEGREES_C}, time: {qty: 30, units: SECONDS}},
                step5: {goto: 2, times: 34},
                step6: {temp: {qty: 72, units: DEGREES_C}, time: {qty:  5, units: MINUTES}},
                step7: {temp: {qty: 12, units: DEGREES_C}, time: {qty: "forever", units: ""}}
            }
        },

        "lib_qPCR2" => {
            name: "LIB_qPCR2.prcl", volume: 50, plate: "LIB_qPCR.pltd",
            steps: {
                step1: {temp: {qty: 95, units: DEGREES_C}, time: {qty:  3, units: MINUTES}},
                step2: {temp: {qty: 98, units: DEGREES_C}, time: {qty: 15, units: SECONDS}},
                step3: {temp: {qty: 65, units: DEGREES_C}, time: {qty: 30, units: SECONDS}},
                step4: {temp: {qty: 72, units: DEGREES_C}, time: {qty: 30, units: SECONDS}},
                step5: {goto: 2, times: 34},
                step6: {temp: {qty: 72, units: DEGREES_C}, time: {qty:  5, units: MINUTES}},
                step7: {temp: {qty: 12, units: DEGREES_C}, time: {qty: "forever", units: ""}}
            }
        }
    }

    attr_reader :program_name, :name, :plate, :steps, :volume

    def initialize(args={})
        @program_name = args[:program_name]
        program = PCRProgram::PROGRAMS[program_name]
        @name = program[:name]
        @plate = program[:plate]
        @steps = {}
        program[:steps].each { |k,v| @steps[k] = PCRStep.new(v) }
        @volume = args[:volume] || program[:volume]
    end

    def table
        table = []
        steps.each do |k,v|
            row = ["#{k}"]
            if v.incubation?
                row += [v.temperature_display, v.duration_display]
            elsif v.goto?
                row += [v.goto_display, v.times_display]
            else
                raise "Unable to interpret #{v} as a PCRStep"
            end
            table.append(row)
        end
        table
    end

    def final_step
        FINAL_STEP
    end
end

class PCRStep
    attr_reader :temperature, :duration, :goto, :times

    def initialize(args={})
        @temperature = args[:temp]
        @duration = args[:time]
        @goto = args[:goto]
        @times = args[:times]
    end

    def incubation?
        temperature && duration
    end

    def goto?
        goto && times
    end

    def temperature_display
        Units.qty_display(temperature)
    end

    def duration_display
        Units.qty_display(duration)
    end

    def goto_display
        "goto step #{goto}"
    end

    def times_display
        "#{times} times"
    end
end