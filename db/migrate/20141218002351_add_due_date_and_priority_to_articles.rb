class AddDueDateAndPriorityToArticles < ActiveRecord::Migration
  def change
    add_column :articles, :due_date, :date
    add_column :articles, :priority, :integer
  end
end
