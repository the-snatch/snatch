class CurrentUserDecorator < UserDecorator
  delegate :pending_post_uploads, :roles, :admin?, :sales?, :email, :billing_failed?, :cc_declined?, :partner_fees, :locked?, :cost_approved?, to: :object

  # @param user [User, nil]
  def initialize(user = nil)
    @object = user || User.new
  end

  def authorized?
    !object.new_record?
  end

  def banned?
    object.locked? || object.cc_declined?
  end

  # @param action [Symbol]
  # @param subject
  # @raise [ArgumentError] if action or subject are not registered
  # @return [true, false]
  def can?(action, subject)
    Ability.new(object).can?(action, subject)
  end

  def staff?
    object.roles.any?
  end

  # @return [Array]
  def recent_subscriptions_options
    recent_subscriptions.map { |s| [s.target_user.name, s.target_user_id] }
  end

  # @return [ActiveRecord::Relation]
  def recent_subscriptions
    object.subscriptions.accessible.includes(:target_user).order(created_at: :desc)
  end

  # @return [Array]
  def latest_subscriptions
    recent_subscriptions.limit(10).map do |subscription|
      [subscription, ProfileDecorator.new(subscription.target_user)]
    end
  end

  def has_posts?
    object.posts.any?
  end

  # @param likable [Post, Comment]
  def likes?(likable)
    case likable
    when Post
      object.likes.where(post_id: likable.id).any?
    when Comment
      object.likes.where(comment_id: likable.id).any?
    else
      raise ArgumentError
    end
  end

  def has_subscriptions?
    object.subscriptions.any?
  end

  def ==(other)
    case other
    when User
      other.id == object.id
    when UserDecorator
      other.object.id == object.id
    else
      super
    end
  end

  def pending_audios
    @pending_audios ||= AudioPost.pending_uploads_for(object).to_a
  end

  def pending_documents
    @pending_documents ||= DocumentPost.pending_uploads_for(object).to_a
  end

  def pending_photos
    @pending_photos ||= PhotoPost.pending_uploads_for(object).to_a
  end

  def pending_videos
    @pending_videos ||= VideoPost.pending_uploads_for(object).to_a
  end

  def pending_video
    @pending_video ||= pending_videos.first
  end

  def pending_video_previews
    @pending_video_previews ||= object.pending_video_preview_photos.to_a
  end
end
