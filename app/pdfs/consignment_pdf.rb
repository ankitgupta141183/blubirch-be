class ConsignmentPdf
  include Prawn::View

  def initialize(data)
    bounding_box([bounds.left,bounds.top], :width => bounds.width, :height => bounds.height) do
      text "Consignment Receipt Summary", :align => :center, :size => 13, :style => :bold
      move_down 30
      table data[:consignment_details], position: :left, :width => bounds.width do
        cells.size = 8
        column(1).font_style = :bold
        cells.border_width = 0
        cells.padding = 1
        cells.style :align => :left
      end
      move_down 25
      table data[:dispatch_documents], position: :left, :width => bounds.width do
        cells.size = 8
        rows(0).font_style = :bold
        # cells.padding = 1
        cells.border_width = 1
        cells.style :align => :right
        column(0).style :align => :left
      end
      if data[:damaged_boxes].present?
        move_down 25
        text "Damaged Box Details", :align => :left, :size => 8, :style => :bold
        move_down 5
        table data[:damaged_boxes], position: :left, :width => bounds.width/2 do
          cells.size = 8
          rows(0).font_style = :bold
          # cells.padding = 1
          cells.border_width = 1
          cells.style :align => :right
          column(0).style :align => :left
        end
      end
      move_down 50
      text "Logistics Partner Acknowledgement", :align => :left, :size => 8
    end
  end
end