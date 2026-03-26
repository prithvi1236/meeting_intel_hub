class MeetingProcessingChannel < ApplicationCable::Channel
  def subscribed
    meeting = Meeting.find(params[:meeting_id])
    reject unless meeting.project.user_id == current_user.id

    stream_for meeting
  end
end
