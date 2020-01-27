require 'date'

module V1
  class EventsController < ApplicationController
    before_action :authorize_request
    before_action :comprobe_admin

    def index
      render json: Notification.all.where(created_by: @current_user.id).order(publication_date: :asc).order(category: :asc)
    end

    def show_by_user_id
      @events = Event.where(created_by: params[:user_id])
      if @notifications
        render json: @events.order(publication_date: :asc).order(category: :asc)
      else
        head(:unauthorized)
      end
    end



    Parent = Struct.new(:email, :assist, :seen, :total_kids, :kids)
    private

    def event_params
      params.require(:event).permit(:category, :title, :description, :publication_date, :total,
                                           :assist, :view, :not_view, :total_kids,
                                           :role,:campuses => [], :grades => [], :groups => [],
                                           :student_names => [])
    end
  end
end