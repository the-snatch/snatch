class ProfilesMailer < ApplicationMailer

  # @param user [User]
  # @param cost [Integer]
  def changed_cost(user, old_cost, cost)
    @user = user
    @cost = cost
    @old_cost = cost
    mail to: 'support@connectpal.com', subject: 'Requested cost change'
  end

  # @param user [User]
  # @param cost [Integer]
  def changed_cost_blast(recipient, user, old_cost, cost)
    @user = user
    @cost = cost
    @old_cost = cost
    mail to: recipient.email, subject: 'Requested cost change'
  end

  # @param subscription [Subscription]
  def vacation_enabled(subscription)
    @subscriber = subscription.user
    @profile_owner = subscription.target_user
    mail to: @subscriber.email, subject: "#{@profile_owner.name} has gone on away mode"
  end

  # @param subscription [Subscription]
  def vacation_disabled(subscription)
    @subscriber = subscription.user
    @profile_owner = subscription.target_user
    mail to: @subscriber.email, subject: "#{@profile_owner.name} has returned from away mode"
  end
end
