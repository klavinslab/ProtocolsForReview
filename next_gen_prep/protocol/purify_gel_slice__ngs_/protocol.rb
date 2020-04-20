# Purify Gel Protocol

# This protocol purfies gel slices into DNA fragment stocks
needs "Library Cloning/PurificationHelper"
needs "Standard Libs/PrinterHelper"
needs "Standard Libs/Feedback"
needs "Next Gen Prep/NextGenPrepHelper"

class Protocol

    include PurificationHelper, NextGenPrepHelper
    include PrinterHelper
    include Feedback

    # I/O
    FRAGMENT="Fragment"
    GEL="Gel"
    KIT="QiagenPink" #"Promega" # "Qiagen" or "Promega". must match a key in KIT_SETTINGS hash in Library Cloning/PurificationHelper.

    # other
    LIB_CONTAINER="Library Gel Slice"

    def main
        associate_random_barcodes(operations: operations, in_handle: GEL) if debug

        if debug
           operations.shuffle!
        end

        keep_gel_slices = operations.first.plan.get(:choice) == "Yes"

        # use only "approved" slices, sort by increasing item id
        operations.retrieve interactive: keep_gel_slices
        operations.sort! { |op1, op2| op1.input(GEL).item.id <=> op2.input(GEL).item.id }
        operations.make

        heatElutionBuffer(GEL,KIT)

        volumeSetup(GEL,KIT)

        addLoadingBuffer(GEL, KIT)

        meltGel(GEL,KIT)

        loadSample(GEL,KIT)

        washSample(KIT)

        printLabels(FRAGMENT)

        eluteSample(FRAGMENT, KIT, 1) # ==1 for two rounds of elution

        # Library Gel Slice concentrations will be measured by Qubit, so don't waste material here
        ops=operations.select { |op| !(op.input(GEL).item.object_type.name == LIB_CONTAINER) }

        # measureConcentration(FRAGMENT,"output",ops)

        # saveOrDiscard(FRAGMENT,ops)

        operations.running.each do |op|
            txfr_barcode(op, GEL, FRAGMENT)
            txfr_bin(op, GEL, FRAGMENT)
        end

        operations.running.each { |op| op.input(GEL).item.mark_as_deleted }
        operations.store

        get_protocol_feedback

        if debug
            display_barcode_associations(
                operations: operations,
                in_handle: GEL,
                out_handle: FRAGMENT
            )
        end

        return {}

    end

end
