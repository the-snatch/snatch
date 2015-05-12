class Api::ContributionsController < Api::BaseController
  include Concerns::PublicProfileHandler

  before_action :load_target_user!, only: [:create]
  before_action :load_contribution!, only: [:destroy]

  protect(:create) { can? :make, Contribution.new(target_user: @target_user) }
  protect(:destroy) { can? :delete, @contribution }

  def index
    @contributions = Contribution.where(target_user_id: current_user.id)
    json_success contributions_data(@contributions)
  end

  def create
    if params[:amount].to_i.zero?
      amount = params[:custom_amount].to_i * 100
    else
      amount = params[:amount]
    end

    manager.create({target_user: @target_user, amount: amount, recurring: params.bool(:recurring), message: params[:message]})
    json_success
  end

  def destroy
    manager.delete
    json_success
  end

  private

  def contributions_data(contributions = [])
    data = { present: contributions.any? }
    if contributions.any?
      data[:total_amount] = contributions.total_amount
      data[:contributions] = []
      contributions.each_year_month do |year_month, contributions|
        data[:contributions] << {
          date: year_month.to_s,
          count: contributions.count,
          amount: contributions.sum(&:amount)
        }
      end
    end
    data
  end

  def load_target_user!
    @target_user = User.where(slug: params[:target_user_id]).first or error(400)
  end

  def load_contribution!
    @contribution = Contribution.where(id: params[:id]).first or error(404)
  end

  def manager
    ContributionManager.new(user: current_user.object, contribution: @contribution)
  end
end


