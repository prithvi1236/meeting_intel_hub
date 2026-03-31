require "csv"

class ExportService
  class << self
    def to_csv(meeting)
      decisions = meeting.extracted_items.decisions.order(:position, :created_at)
      action_items = meeting.extracted_items.action_items.order(:position, :created_at)

      CSV.generate(headers: true) do |csv|
        csv << [ "Decisions" ]
        csv << [ "Description", "Assigned", "Due Date", "Status", "Source Quote" ]
        decisions.each do |item|
          csv << [
            item.description,
            item.owner,
            item.due_date,
            item.status,
            item.source_quote
          ]
        end

        csv << []
        csv << [ "Action items" ]
        csv << [ "Description", "Assigned", "Due Date", "Status", "Source Quote" ]
        action_items.each do |item|
          csv << [
            item.description,
            item.owner,
            item.due_date,
            item.status,
            item.source_quote
          ]
        end
      end
    end

    def to_pdf(meeting)
      require "prawn"
      require "prawn/table"

      Prawn::Document.new do |pdf|
        decisions = meeting.extracted_items.decisions.order(:position, :created_at)
        action_items = meeting.extracted_items.action_items.order(:position, :created_at)

        pdf.text "Meeting: #{meeting.title}", size: 18, style: :bold
        pdf.move_down 12

        pdf.text "Decisions", size: 13, style: :bold
        pdf.move_down 6
        decision_rows = [ [ "Description", "Assigned", "Due", "Status", "Quote" ] ]
        decisions.each do |item|
          decision_rows << [
            item.description.to_s.truncate(200),
            item.owner.to_s,
            item.due_date&.to_s,
            item.status,
            item.source_quote.to_s.truncate(300)
          ]
        end
        pdf.table(decision_rows, header: true, width: pdf.bounds.width) do
          row(0).font_style = :bold
        end

        pdf.move_down 14
        pdf.text "Action items", size: 13, style: :bold
        pdf.move_down 6
        action_rows = [ [ "Description", "Assigned", "Due", "Status", "Quote" ] ]
        action_items.each do |item|
          action_rows << [
            item.description.to_s.truncate(200),
            item.owner.to_s,
            item.due_date&.to_s,
            item.status,
            item.source_quote.to_s.truncate(300)
          ]
        end
        pdf.table(action_rows, header: true, width: pdf.bounds.width) do
          row(0).font_style = :bold
        end
      end.render
    end
  end
end
