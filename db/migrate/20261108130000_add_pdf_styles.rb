# PDF design (layout) and accent colour. Users keep defaults for timesheet reports and invoices;
# each invoice stores the style it was generated with. Blank means the built-in default (see PdfStyle).
class AddPdfStyles < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :report_design, :string
    add_column :users, :report_color, :string
    add_column :users, :invoice_design, :string
    add_column :users, :invoice_color, :string
    add_column :invoices, :design, :string
    add_column :invoices, :color, :string
  end
end
