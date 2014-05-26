class PaymentManager < BaseManager

  # @param target [Concerns::Payable]
  # @param description [String, nil] optional notes on payment
  # @return [Payment, PaymentFailure]
  def pay_for(target, description = nil)
    unless target.is_a?(Concerns::Payable)
      raise ArgumentError, "Don't know how to pay for #{target.class.name}"
    end

    charge = Stripe::Charge.create amount:      target.cost,
                                   customer:    target.customer.stripe_user_id,
                                   currency:    'usd',
                                   description: description,
                                   statement_description: 'ConnectPal.com',
                                   metadata:    {target_id:   target.id,
                                                 target_type: target.class.name,
                                                 user_id:     target.customer.id}
    Payment.create! target:             target,
                    user:               target.customer,
                    target_user:        target.recipient,
                    amount:             charge['amount'],
                    stripe_charge_data: charge.as_json,
                    description:        description

    target.charged_at = Time.zone.now
    save_or_die! target
  rescue Stripe::StripeError => e
    PaymentFailure.create! exception_data:     "#{e.inspect} | http_body:#{e.http_body} | json_body:#{e.json_body}",
                           target:             target,
                           user:               target.customer,
                           stripe_charge_data: charge.try(:as_json),
                           description:        description
  end
end
