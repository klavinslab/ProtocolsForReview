# This protocol will move all operation types and libraries in the `current category name` category into the `new category name` category (If the new category doesn't exist yet, it will be created.)
# You can think of it like renaming a category.

class Protocol
  def main
    operations.each do |op|
        show { title "Moving everything from \"#{op.input("Current Category Name").value}\" into \"#{op.input("New Category Name").value}\""}
        category_elements = OperationType.where(category: op.input("Current Category Name").value).concat Library.where(category: op.input("Current Category Name").value)
        if !category_elements.nil? && !category_elements.empty?
            show do
                title "Affected OperationTypes and Libraries"
                category_elements.each do |el|
                    note "Changing category for #{el.name}"
                    note "#{el.name} was in #{el.category}"
                    el.category = op.input("New Category Name").value
                    el.save
                    note "Now #{el.name} in #{el.category}"
                    note "------------------------------------------------"
                end
            end
        else
            raise "#{op.input("Current Category Name").value} is not a Category that exists in Aquarium"
        end
    end
  end
end
