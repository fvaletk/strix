class AddSummaryToArticles < ActiveRecord::Migration[8.1]
  def change
    add_column :articles, :summary_tldr, :text
    add_column :articles, :summary_key_points, :jsonb, default: [], null: false
  end
end
