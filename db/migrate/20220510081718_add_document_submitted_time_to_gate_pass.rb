class AddDocumentSubmittedTimeToGatePass < ActiveRecord::Migration[6.0]
  def change
    add_column :gate_passes, :document_submitted_time, :datetime
  end
end
