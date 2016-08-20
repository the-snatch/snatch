require 'spec_helper'

describe Dashboard::Admin::ProfileTypesController, type: :controller do
  before { sign_in create(:user, :admin) }

  describe 'GET #index' do
    subject { get 'index' }
    it { should be_success }
  end

  describe 'POST #create' do
    subject { post :create, params: {title: 'test'} }
    it { should be_success }
  end

  describe 'DELETE #destroy' do
    let(:profile_type) { ProfileTypeManager.new.create(title: 'test') }
    subject { delete :destroy, params: {id: profile_type.id} }
    it { should be_success }
  end
end
