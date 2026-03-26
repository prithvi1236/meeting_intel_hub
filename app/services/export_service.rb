require "csv"

class ExportService
  class << self
    def to_csv(meeting)
      CSV.generate(headers: true) do |csv|
        csv << %w[Type Description Owner Due\ Date Status Source\ Quote]
        meeting.extracted_items.order(:position, :created_at).find_each do |item|
          csv << [
            item.item_type,
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
        pdf.text "Meeting: #{meeting.title}", size: 18, style: :bold
        pdf.move_down 12
        rows = [ %w[Type Description Owner Due Status Quote] ]
        meeting.extracted_items.order(:position, :created_at).each do |item|
          rows << [
            item.item_type,
            item.description.to_s.truncate(200),
            item.owner.to_s,
            item.due_date&.to_s,
            item.status,
            item.source_quote.to_s.truncate(300)
          ]
        end
        pdf.table(rows, header: true, width: pdf.bounds.width) do
          row(0).font_style = :bold
        end
      end.render
    end
  end
end
