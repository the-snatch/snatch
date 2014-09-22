require 'spec_helper'

describe BillingPeriodsPresenter do
  let(:user) { create_user }
  let(:target_user) { create_profile(email: 'target@user.com') }
  let(:subscription) { SubscriptionManager.new(subscriber: user).subscribe_and_pay_for(target_user) }

  subject { described_class.new(user: target_user).collection.first }

  before { StripeMock.start }
  after { StripeMock.stop }

  before do
    UserProfileManager.new(user).update_cc_data(number: '4242424242424242', cvc: '333', expiry_month: '12', expiry_year: 2018)
    subscription
  end

  describe '#total_gross' do
    specify do
      expect(subject.total_gross).to eq(500)
    end
  end

  describe '#connectpal_fee' do
    specify do
      expect(subject.connectpal_fee).to eq(54.5)
    end
  end

  describe '#stripe_fee' do
    specify do
      expect(subject.stripe_fee).to eq(44.5)
    end
  end

  context 'canceled subscriptions' do
    before do
      SubscriptionManager.new(subscription: subscription).unsubscribe
    end

    describe '#tos_fee' do
      specify do
        expect(subject.tos_fee).to eq(500)
      end
    end

    describe '#unsubscribed' do
      it 'return canceled subscriptions' do
        expect(subject.unsubscribed).to eq([subscription])
      end
    end

    describe '#unsubscribed_count' do
      specify do
        expect(subject.unsubscribed_count).to eq(1)
      end
    end
  end

  # describe '#payout' do
  #   before do
  #     TransferManager.new(recipient: target_user).transfer(amount: '666', descriptor: 'Ha BoTky', month: '12')
  #   end
  #
  #   specify do
  #     expect(subject.payout).to eq(666)
  #   end
  # end
end