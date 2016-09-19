class ContributionManager < BaseManager
  WEEKLY_CONTRIBUTION_LIMIT = 120_00
  VERIFIED_PROFILE_CONTRIBUTION_LIMIT = 250_00
  VERIFIED_PROFILE_WEEKLY_CONTRIBUTION_LIMIT = 500_00
  INTEGER_RANGE_LIMIT = 2_147_483_647

  # @param user [User]
  # @param target_user [User]
  def initialize(user: , contribution: nil)
    @user = user
    @contribution = contribution
  end

  # @param target_user [User]
  # @param amount [Integer, String] Amount in cents
  # @param message [String, nil]
  # @return [Contribution]
  def create(target_user: , amount: nil, recurring: false, message: nil)
    amount = amount.to_i
    fail_with! amount: :zero if amount < 1
    fail_with! amount: :too_large if amount > INTEGER_RANGE_LIMIT
    fail_with! "You can't contribute to this profile" unless target_user.contributions_allowed?

    if limit_reached?(amount, target_user)
      submit_contribution_request(target_user: target_user, amount: amount, recurring: recurring, message: message)
      fail_with! amount: :contribution_limit_reached
    end

    if weekly_limit_reached?(amount, target_user)
      submit_contribution_request(target_user: target_user, amount: amount, recurring: recurring, message: message)
      UserManager.new(@user).lock(type: :billing, reason: :contribution_limit) do |user|
        user.contribution_limit_reached_at = Time.zone.now
        save_or_die! user
      end
    end

    fail_with! 'Account locked' if @user.locked?

    @contribution = create_contribution(target_user: target_user,
                                        amount: amount,
                                        recurring: recurring)

    fail_with! 'Payment has been failed' if @contribution.new_record?

    message = message.presence || 'Contribution'
    MessagesManager.new(user: @user).create(target_user: target_user,
                                            message: message,
                                            contribution: @contribution)

    @contribution
  end

  # Creates child from recurring contribution
  def create_child
    raise ArgumentError, 'Requires recurring contribution' unless @contribution.try(:recurring?)
    create_contribution(target_user: @contribution.target_user,
                        amount: @contribution.amount,
                        recurring: false,
                        parent: @contribution).tap do
      @contribution.touch
    end
  end

  # Stops recurring contribution
  # @return [Contribution]
  def cancel
    recurring_contribution = @contribution.parent || @contribution

    fail_with! 'Already cancelled' if recurring_contribution.cancelled?
    fail_with! 'Can\'t cancel not recurring contribution' unless recurring_contribution.recurring?

    recurring_contribution.cancelled = true
    recurring_contribution.cancelled_at = Time.zone.now
    save_or_die! recurring_contribution do
      EventsManager.contribution_cancelled(user: @user, contribution: recurring_contribution)
    end

    @contribution
  end

  def approve!(contribution_request)
    UserManager.new(@user).update_daily_contributions_limit(limit: 120_00)
    create(target_user: contribution_request.target_user,
           amount: contribution_request.amount,
           recurring: contribution_request.recurring,
           message: contribution_request.message).tap do
      contribution_request.approve!
      contribution_request.perform!
    end
  end

  private

  def weekly_limit_reached?(amount, target_user)
    recently_contributed = Contribution.where(user: @user)
                             .where('created_at > ? AND created_at > ?', 7.days.ago, (@user.contribution_limit_reached_at || 7.days.ago))
                             .sum(:amount)

    limit = target_user.accepts_large_contributions? ? VERIFIED_PROFILE_WEEKLY_CONTRIBUTION_LIMIT : WEEKLY_CONTRIBUTION_LIMIT
    recently_contributed + amount >= limit
  end

  def limit_reached?(amount, target_user)
    if target_user.accepts_large_contributions?
      recently_contributed = Contribution.where(user: @user, target_user: target_user)
                               .where("created_at > ?", 24.hours.ago)
                               .sum(:amount)
      limit = VERIFIED_PROFILE_CONTRIBUTION_LIMIT
    else
      return true if amount > @user.daily_contributions_limit
      recently_contributed = Contribution.where(user: @user)
                               .where("created_at > ?", 24.hours.ago)
                               .sum(:amount)
      limit = @user.daily_contributions_limit
    end

    recently_contributed + amount > limit
  end

  def submit_contribution_request(target_user: , amount: , recurring: false, message: nil)
    unless @user.contribution_requests.by_target_user(target_user).pending.any?
      @user.contribution_requests.create!(target_user: target_user,
                                          amount: amount,
                                          recurring: recurring,
                                          message: message)
    end
  end

  def create_contribution(target_user: , amount: , recurring: , parent: nil)
    contribution = Contribution.new(user: @user, target_user: target_user, amount: amount, recurring: recurring, parent: parent)

    ActiveRecord::Base.transaction do
      contribution.save!
      PaymentManager.new(user: @user).create_charge(amount: amount,
                                                    customer: @user.stripe_user_id,
                                                    description: "Contribution #{target_user.profile_name.first(20)}",
                                                    statement_description: 'Contribution',
                                                    metadata: {target_id: contribution.id, target_type: contribution.class.name, user_id: @user.id})
      EventsManager.contribution_created(user: @user, contribution: contribution)
      UserStatsManager.new(target_user).increment_gross_contributions_log_by(amount)
      ContributionFeedEvent.create! subscription_target_user: @user, target_user: target_user, target: contribution, data: {recurring: recurring, amount: (amount / 100).to_i}
      NotificationManager.delay.notify_contributed(contribution)
      contribution
    end
  rescue Stripe::StripeError
    EventsManager.contribution_failed(user: @user, contribution: contribution)
    UserManager.new(@user).mark_billing_failed
  rescue ManagerError
    EventsManager.contribution_failed(user: @user, contribution: contribution)
    raise
  ensure
    return contribution
  end
end
