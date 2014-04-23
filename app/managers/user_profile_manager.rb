class UserProfileManager < BaseManager
  include Concerns::CreditCardValidator
  include Concerns::EmailValidator
  include Concerns::PasswordValidator

  attr_reader :user

  SLUG_REGEXP  = /^[a-zA-Z0-9]+(\w|_|-)+[a-zA-Z0-9]+$/i
  ONLY_DIGITS  = /^[0-9]*$/i

  # @param user [User]
  def initialize(user)
    raise ArgumentError unless user.is_a?(User)
    @user = user
  end

  # @param profile_type [ProfileType]
  def add_profile_type(profile_type)
    raise ArgumentError unless profile_type.is_a?(ProfileType)
    fail_with! profile_type: :already_set if @user.profile_types.where(id: profile_type.id).any?

    @user.profile_types << profile_type
  end

  # @param profile_type [ProfileType]
  def remove_profile_type(profile_type)
    raise ArgumentError unless profile_type.is_a?(ProfileType)
    fail_with! profile_type: :not_set unless @user.profile_types.where(id: profile_type.id).any?

    @user.profile_types.delete(profile_type)
  end

  # @return [User]
  def create_profile_page
    @user.is_profile_owner = true
    @user.save!
    @user
  end

  # @return [User]
  def delete_profile_page
    @user.is_profile_owner = false
    @user.save!
    @user
  end

  # @param cost [Float, String]
  # @param profile_name [String]
  # @param holder_name [String]
  # @param routing_number [String]
  # @param account_number [String]
  # @return [User]
  def update(cost: nil, profile_name: nil, holder_name: nil, routing_number: nil, account_number: nil)
    profile_name   = profile_name.try(:strip).to_s
    holder_name    = holder_name.to_s.strip
    routing_number = routing_number.to_s.strip
    account_number = account_number.to_s.strip

    validate! do
      if profile_name.blank?
        fail_with profile_name: :empty
      elsif profile_name.length > 140
        fail_with profile_name: :too_long
      end

      if cost.blank?
        fail_with cost: :empty
      elsif !cost.to_s.strip.match ONLY_DIGITS
        fail_with! cost: :not_an_integer
      elsif cost.to_f <= 0
        fail_with cost: :zero
      elsif cost.to_f > 9999
        fail_with cost: :reached_maximum
      end

      if holder_name.present? || routing_number.present? || account_number.present?
        fail_with holder_name: :empty if holder_name.blank?

        if routing_number.match ONLY_DIGITS
          fail_with routing_number: :not_a_routing_number if routing_number.try(:length) != 9
        else
          fail_with routing_number: :not_an_integer
        end

        if account_number.match ONLY_DIGITS
          fail_with account_number: :not_an_account_number if account_number.try(:length) != 12
        else
          fail_with account_number: :not_an_integer
        end
      end
    end

    user.cost           = cost
    user.profile_name   = profile_name
    user.holder_name    = holder_name
    user.routing_number = routing_number
    user.account_number = account_number
    user.generate_slug

    user.save or fail_with! user.errors
    user
  end

  # @param benefits [Array<String>]
  # @return [User]
  def update_benefits(benefits)
    fail_with! :benefits if benefits.nil?

    user.benefits.clear

    benefits.each do |ordering, message|
      user.benefits.create!(message: message, ordering: ordering) if message.present?
    end

    user
  end

  # @return [User]
  def update_payment_information(holder_name: nil, routing_number: nil, account_number: nil)
    holder_name    = holder_name.to_s.strip
    routing_number = routing_number.to_s.strip
    account_number = account_number.to_s.strip

    validate! do
      fail_with holder_name: :empty if holder_name.blank?

      if routing_number.match ONLY_DIGITS
        fail_with routing_number: :not_a_routing_number if routing_number.try(:length) != 9
      else
        fail_with routing_number: :not_an_integer
      end

      if account_number.match ONLY_DIGITS
        fail_with account_number: :not_an_account_number if account_number.try(:length) != 12
      else
        fail_with account_number: :not_an_integer
      end
    end

    user.holder_name    = holder_name
    user.routing_number = routing_number
    user.account_number = account_number

    user.save or fail_with! user.errors
    user
  end

  # @param profile_name [String]
  # @return [User]
  def update_profile_name(profile_name)
    fail_with! profile_name: :empty if profile_name.blank?
    fail_with! profile_name: :too_long if profile_name.length > 140

    user.profile_name = profile_name
    user.save or fail_with! user.errors
    user
  end

  # @param cost [Integer, Float, String]
  # @return [User]
  def update_cost(cost)
    fail_with! cost: :zero if cost.to_f <= 0.0
    fail_with! cost: :reached_maximum if cost.to_f > 9999

    unless cost.to_s.strip.match ONLY_DIGITS
      fail_with! cost: :not_an_integer
    end

    user.cost = cost
    user.save or fail_with! user.errors
    user
  end

  # @param contacts_info [Hash]
  # @return [User]
  def update_contacts_info(contacts_info)
    raise ArgumentError unless contacts_info.is_a?(Hash)

    user.contacts_info = {}.tap do |info|
      contacts_info.each do |provider, url|
        if url.present?
          info[provider] = (url =~ /^https?:\/\//) ? url : "http://#{url}"
        end
      end
    end

    user.save or fail_with! user.errors
    user
  end

  # @param number [String]
  # @param cvc [String]
  # @param expiry_month [String]
  # @param expiry_year [String]
  # @return [User]
  def update_cc_data(number: nil, cvc: nil, expiry_month: nil, expiry_year: nil)
    card = CreditCard.new number:       number,
                          cvc:          cvc,
                          expiry_month: expiry_month,
                          expiry_year:  expiry_year

    validate! { validate_cc card }

    metadata      = {user_id:   user.id,
                     full_name: user.full_name}
    customer_data = {metadata:  metadata,
                     email:     user.email,
                     card:      card.to_stripe}

    if user.stripe_user_id
      begin
        customer = Stripe::Customer.retrieve(user.stripe_user_id)
        customer.card     = card.to_stripe
        customer.metadata = metadata
        customer.email    = user.email
        customer = customer.save
      rescue Stripe::InvalidRequestError
        customer = Stripe::Customer.create customer_data
      end
    else
      customer = Stripe::Customer.create customer_data
    end

    user.stripe_user_id       = customer['id']
    user.stripe_card_id       = customer['cards']['data'][0]['id']
    user.last_four_cc_numbers = customer['cards']['data'][0]['last4']
    user.card_type            = customer['cards']['data'][0]['type']

    user.save or fail_with! user.errors
    user
  rescue Stripe::CardError => e
    err = e.json_body[:error]

    case err[:code]
    when 'incorrect_number', 'invalid_number', 'card_declined', 'missing', 'processing_error'
      fail_with! number: err[:message]
    when 'invalid_expiry_month', 'invalid_expiry_year', 'expired_card'
      fail_with! expiry_date: err[:message]
    when 'invalid_cvc', 'incorrect_cvc'
      fail_with! cvc: err[:message]
    else
      fail_with! number: err[:code]
    end
  rescue Stripe::InvalidRequestError
    fail_with! number: 'Invalid stripe request'
  rescue Stripe::AuthenticationError
    fail_with! number: 'Stripe auth error'
  rescue Stripe::APIConnectionError
    fail_with! number: 'Stripe API connection error'
  rescue Stripe::StripeError
    fail_with! number: 'Generic Stripe error'
  end

  # @param full_name [String]
  # @param company_name [String]
  # @param email [String]
  # @return [User]
  def update_general_information(full_name: nil, company_name: nil, email: nil)
    validate! do
      fail_with full_name: :empty unless full_name.present?
      if company_name
        fail_with company_name: :too_long if company_name.length > 200
      end
      validate_email(email) if email != user.email
    end

    user.full_name    = full_name
    user.company_name = company_name
    user.email        = email

    user.save or fail_with! user.errors
    user
  end

  # @param slug [String]
  # @return [User]
  def update_slug(slug)
    validate! { validate_slug slug }

    user.slug = slug
    user.save or fail_with! user.errors
    user
  end

  # @param transloadit_data [Hash]
  # @return [User]
  def update_profile_picture(transloadit_data)
    upload = UploadManager.new(user).create_photo(transloadit_data)

    user.profile_picture_url = upload.url_on_step('resize')
    user.original_profile_picture_url = upload.url_on_step(':original')

    if user.changes.any?
      user.save or fail_with! user.errors
    end

    user
  end

  def update_cover_picture_position(position)
    user.cover_picture_position = position

    if user.changes.any?
      user.save or fail_with! user.errors
    end

    user
  end

  # @param transloadit_data [Hash]
  # @return [User]
  def update_cover_picture(transloadit_data)
    upload = UploadManager.new(user).create_photo(transloadit_data)
    user.cover_picture_position = 0
    user.cover_picture_url = upload.url_on_step('resize')
    user.original_cover_picture_url = upload.url_on_step(':original')

    if user.changes.any?
      user.save or fail_with! user.errors
    end

    user
  end

  # @param current_password [String]
  # @param new_password [String]
  # @param new_password_confirmation [String]
  # @return [User]
  def change_password(current_password: nil, new_password: nil, new_password_confirmation: nil)
    AuthenticationManager.new(email: user.email,
                              password: current_password,
                              password_confirmation: current_password).authenticate
    validate! do
      validate_password password:              new_password,
                        password_confirmation: new_password_confirmation,
                        password_field_name:              :new_password,
                        password_confirmation_field_name: :new_password_confirmation
    end

    user.set_new_password(new_password)
    user.save or fail_with! user.errors
    user
  rescue AuthenticationError
    fail_with! :current_password
  end

  def make_profile_public
    fail_with! 'Profile is already public' if @user.has_public_profile

    user.has_public_profile = true
    user.save or fail_with!(@user.errors)
    user
  end

  def make_profile_private
    fail_with! 'Profile is already private' unless @user.has_public_profile

    user.has_public_profile = false
    user.save or fail_with!(@user.errors)
    user
  end

  private

  # @param slug [String]
  # @return [true, false]
  def slug_taken?(slug)
    User.where.not(id: user.id).where(slug: slug).any?
  end

  def validate_slug(slug)
    return fail_with slug: :empty          if slug.blank?
    return fail_with slug: :not_a_slug unless slug.match SLUG_REGEXP
    return fail_with slug: :taken          if slug_taken?(slug)
  end
end
