class MessagesManager < BaseManager
  attr_reader :user

  # @param user [User] Who is sending the message
  def initialize(user: user)
    @user = user
  end

  # @param target_user [User]
  # @param message [String]
  # @return [Message]
  def create(target_user: target_user, message: text)
    fail_with! message: :empty if message.blank?
    fail_with! message: :too_long if message.length > 1000

    Message.create!(user: user, target_user: target_user, message: message).tap do |_message|
      dialogue = Dialogue.pick(user, target_user)
      dialogue.recent_message = _message
      dialogue.recent_message_at = _message.created_at
      dialogue.unread = true
      dialogue.save!

      MessagesMailer.delay.new_message(_message)
    end
  end

  # @param dialogue [Dialogue]
  # @return [Dialogue]
  def mark_as_read(dialogue)
    if user != dialogue.recent_message.user
      dialogue.unread = false
      dialogue.save!
    end
    dialogue
  end
end

