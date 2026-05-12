class AddBenchmarkOptInToClubs < ActiveRecord::Migration[7.2]
  def change
    add_column :clubs, :benchmark_opt_in, :boolean, default: false, null: false
    add_index  :clubs, :benchmark_opt_in
  end
end
