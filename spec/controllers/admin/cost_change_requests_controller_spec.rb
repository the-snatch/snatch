require 'spec_helper'

describe Admin::CostChangeRequestsController, type: :controller do
  let(:cost_change_request) { CostChangeRequestManager.new(user: create_profile(email: 'profile@lol.com')).create(new_cost: 10) }

  describe 'GET #index' do
    subject { get 'index' }

    context 'as an admin' do
      before { sign_in create_admin }
      it { should be_success }
    end

    context 'as a non admin' do
      before { sign_in create_user }
      it { should_not be_success }
    end
  end

  describe 'GET #confirm_reject' do
    subject { get 'confirm_reject', id: cost_change_request.id }

    context 'as an admin' do
      before { sign_in create_admin }
      it { should be_success }
    end

    context 'as a non admin' do
      before { sign_in create_user }
      it { should_not be_success }
    end
  end

  describe 'GET #confirm_approve' do
    subject { get 'confirm_approve', id: cost_change_request.id }

    context 'as an admin' do
      before { sign_in create_admin }
      it { should be_success }
    end

    context 'as a non admin' do
      before { sign_in create_user }
      it { should_not be_success }
    end
  end

  describe 'POST #approve' do
    subject { post 'approve', id: cost_change_request.id }

    context 'as an admin' do
      before { sign_in create_admin }
      it { should be_success }
    end

    context 'as a non admin' do
      before { sign_in create_user }
      it { should_not be_success }
    end
  end

  describe 'POST #reject' do
    subject { post 'reject', id: cost_change_request.id }

    context 'as an admin' do
      before { sign_in create_admin }
      it { should be_success }
    end

    context 'as a non admin' do
      before { sign_in create_user }
      it { should_not be_success }
    end
  end
end
