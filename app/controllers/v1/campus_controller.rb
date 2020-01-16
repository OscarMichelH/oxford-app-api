module V1
  class CampusController < ApplicationController
    before_action :authorize_request
    before_action :comprobe_admin, only: :create
    before_action :set_campus, only: [:show, :update, :destroy]

    # GET /v1/campus
    # GET /v1/campus.json
    def index
      @campus = Campus.all
    end

    # GET /v1/campus/1
    # GET /v1/campus/1.json
    def show
    end

    def show_by_name
      @campus = Campus.where(name: params['names'])
      @names = []
      grades = []
      @campus.each do |campus|
        @names << campus.name
        campus.groups.split(',').each do |group|
          if group.length == 3
            grades << group[0..1]
          else
            grades << group[0]
          end
        end
      end
      @names = @names.uniq
      @grades = grades.uniq
      render :show_grades
    end

    def show_groups_by_campus_and_grades
      @campus = Campus.where(name: params['names'])
      grades = params["grades"]
      @groups = []
      @names = []
      @campus.each do |campus|
        @names << campus.name
        campus.groups.split(',').each do |group|
          if group.length == 3
            @groups << group[2] if grades.include?(group[0..1])
          else
            @groups << group[1] if grades.include?(group[0])
          end
        end
      end
      @names = @names.uniq
      @groups = @groups.uniq
      render :show_groups
    end

    # POST /v1/campus
    # POST /v1/campus.json
    def create
      @campus = Campus.new(campus_params)
      if Campus.where(name: campus_params['name'].upcase).any?
        campuses = Campus.where(name: campus_params['name'].upcase)
        campuses.destroy_all
      end

      if @campus.save
        render 'v1/campus/show', status: :created
      else
        render json: @campus.errors, status: :unprocessable_entity
      end
    end

    # PATCH/PUT /v1/campus/1
    # PATCH/PUT /v1/campus/1.json
    def update
      if @campus.update(campus_params)
        render :show, status: :ok, location: @campus
      else
        render json: @campus.errors, status: :unprocessable_entity
      end
    end

    # DELETE /v1/campus/1
    # DELETE /v1/campus/1.json
    def destroy
      @campus.destroy
    end

    def delete_campus_by_name
      @campus = Campus.where(name: params['names'])
      @campus.destroy_all
      head(:ok)
    end

    private
      # Use callbacks to share common setup or constraints between actions.
      def set_campus
        @campus = Campus.find(params[:id])
      end

      # Never trust parameters from the scary internet, only allow the white list through.
      def campus_params
        params.require(:campus).permit(:name, :groups)
      end
  end
end