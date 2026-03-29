class ExtractedItemsController < ApplicationController
  before_action :set_project
  before_action :set_meeting
  before_action :set_item, only: %i[update destroy]

  def index
    @items = @meeting.extracted_items.order(:position, :created_at)
  end

  def update
    if @item.update(item_params)
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            dom_id(@item),
            partial: "extracted_items/item",
            locals: { item: @item, project: @project, meeting: @meeting }
          )
        end
        format.html { redirect_to project_path(@project) }
      end
    else
      head :unprocessable_entity
    end
  end

  def destroy
    @item.destroy
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.remove(dom_id(@item)) }
      format.html { redirect_to project_path(@project) }
    end
  end

  private
    def set_project
      @project = current_user.projects.find(params[:project_id])
    end

    def set_meeting
      @meeting = @project.meetings.find(params[:meeting_id])
    end

    def set_item
      @item = @meeting.extracted_items.find(params[:id])
    end

    def item_params
      params.expect(extracted_item: [ :status, :description, :owner, :due_date ])
    end
end
