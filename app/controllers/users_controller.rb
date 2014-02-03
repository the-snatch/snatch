class UsersController < ApplicationController
  before :show, :load_user!

  # Shows registration form
  def new
  end

  # Registers new user
  def create
    user = AuthenticationManager.new(email: params[:email], password: params[:password], login: params[:login]).register
    session_manager.login(user.email, params[:password])

    redirect_to profile_path
  rescue ManagerError => e
    render text: e.message
  end

  def profile
    @profile = ProfilePresenter.new(current_user.object)
  end

  def show
    render @user.inspect
  end

  private

  def load_user!
    @user = UserDecorator.decorate(User.where(slug: params[:id]).first) or error(404)
  end
end