module Concerns::Events::SubscriptionTracker
  # @param user [User]
  # @param subscription [Subscription]
  # @param restored: [Boolean]
  # @yield
  # @return [Event]
  def subscription_created(user: , subscription: , restored: false, &block)
    create_event user: user,
                  subject: subscription,
                  action: 'subscription_created',
                  data: {subscription_id: subscription.id,
                         target_user_id:  subscription.target_user_id,
                         restored:        restored},
                  &block
  end

  # @param user [User]
  # @param subscription [Subscription]
  # @yield
  # @return [Event]
  def subscription_cancelled(user: , subscription: , &block)
    create_event user: user,
                  action: 'subscription_canceled',
                  subject: subscription,
                  data: {subscription_id: subscription.id,
                         target_user_id:  subscription.target_user_id},
                  &block
  end

  # @param user [User]
  # @param subscription [Subscription]
  # @yield
  # @return [Event]
  def subscription_deleted(user: , subscription: , &block)
    create_event user: user,
                  action: 'subscription_deleted',
                  subject: subscription,
                  data: {subscription_id: subscription.id,
                         target_user_id:  subscription.target_user_id},
                  &block
  end

  # @param user [User]
  # @param subscription [Subscription]
  # @return [Integer]
  def subscription_notifications_enabled(user: , subscription: )
    subscription.events.where(user_id: user.id, action: 'subscription_notifications_disabled').daily.delete_all
  end

  # @param user [User]
  # @param subscription [Subscription]
  # @yield
  # @return [Event]
  def subscription_notifications_disabled(user: , subscription: , &block)
    create_event user: user,
                  subject: subscription,
                  action: 'subscription_notifications_disabled',
                  data: {subscription_id: subscription.id,
                         target_user_id:  subscription.target_user_id},
                  &block
  end
end
