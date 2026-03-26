class Api::V1::MeetingsController < ApplicationController
  def export_items
    @meeting = Meeting.joins(:project).where(projects: { user_id: current_user.id }).find(params[:id])
    respond_to do |format|
      format.csv do
        send_data ExportService.to_csv(@meeting), filename: "meeting-#{@meeting.id}.csv", type: "text/csv"
      end
      format.pdf do
        send_data ExportService.to_pdf(@meeting), filename: "meeting-#{@meeting.id}.pdf", type: "application/pdf"
      end
    end
  end
end
