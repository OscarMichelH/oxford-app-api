class V1::SessionsController < ApplicationController
  before_action :authorize_request, except: :create

  def show
    @user = User.find(params[:id])
    if @user && show_user?
      render :show , status: :ok
    else
      head(:unauthorized)
    end
  end

  def create
    @user = User.where(email: params[:email]).first

    if @user&.valid_password?(params[:password])
      jwt = JWT.encode(
          { user_id: @user.id, exp: (Time.now + 2.weeks).to_i, email: @user.email },
          ENV["SECRET_KEY_BASE"],
          'HS256'
      )

      if @user&.is_parent?
        if params[:family_key] != @user&.family_key
          return render json: { errors: 'Family key not found' }, status: :unauthorized
        end
      end

      render :create, locals: { token: jwt }, status: :ok
    else
      render json: { errors: @user ? 'Password not valid' : 'Email not valid' }, status: :unauthorized
    end
  end

  def destroy
    current_user&.authentication_token = nil
    if current_user&.save
      head :ok
    else
      head :unauthorized
    end
  end

  private

  def show_user?
    current_user.is_admin? || @user&.id == current_user.id
  end

end