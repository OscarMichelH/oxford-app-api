module V1
  class UsersController < ApplicationController
    before_action :authorize_request, except: :create
    before_action :comprobe_admin, only: :index

    def index
      render json: User.all.order(email: :asc)
    end

    def create
      @user = User.new(user_params)

      if @user.save
        render :create
      else
        render json: { errors: @user&.errors.full_messages }, status: :unauthorized
      end
    end

    def import_data_from_excel
      workbook = Roo::Excel.new(params[:file].path, file_warning: :ignore)
      workbook.default_sheet = workbook.sheets[0]
      headers = Hash.new
      workbook.row(1).each_with_index {|header,i|
        headers[header] = i
      }

      @users_created = 0
      @users_not_created = 0
      @emails_not_created = []
      @emails_already_registered = []
      ((workbook.first_row + 1)..workbook.last_row).each do |row|
        family_key = workbook.row(row)[headers['clafamilia']].to_s.strip[/[^.]+/]
        name = workbook.row(row)[headers['Nombre']].to_s.upcase.strip
        email = workbook.row(row)[headers['eMail']].to_s.strip
        password = workbook.row(row)[headers['password']]
        role = workbook.row(row)[headers['rol']].to_s.upcase.strip
        if User.where(email: email).any?
          @users_not_created += 1
          @emails_already_registered << email
        else
          user = User.new(email: email, password: password,
                          password_confirmation: password, name: name, role: role,
                          family_key: family_key)
          if user.save
            @users_created += 1
          else
            @users_not_created += 1
            @emails_not_created << email
          end
        end

      end

      render 'create_from_excel'
    end

    def update
      @user = User.find(params[:id])
      if current_user.is_admin? || @user&.id == current_user.id
        if @user.update(user_params)
          render json: @user
        else
          render json: @user.errors, status: :unprocessable_entity
        end
      else
        errors.add('User', 'not authorized')
        head :unauthorized
      end
    end

    private

    def user_params
      params.require(:user).permit(:email, :password, :password_confirmation, :name, :role, :relationship, :family_key, :admin_campus)
    end
  end
end