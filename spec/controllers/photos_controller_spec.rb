require 'spec_helper'

describe PhotosController, type: :controller do
  let(:owner) { create_user email: 'owner@gmail.com', is_profile_owner: true }

  describe 'GET #show' do
    let(:photo) { UploadManager.new(owner).create_pending_photos(transloadit_photo_data_params).first }
    let(:_post) { PostManager.new(user: owner).create_photo_post(title: 'test', message: 'test') }

    # before do
    #   photo
    #   _post
    # end

    subject { get 'show', id: photo.id }

    context 'unauthorized access' do
    end

    context 'authorized access' do
      before { sign_in owner }

      it { should be_success }

      context 'removed post' do
        before do
          photo
          PostManager.new(user: owner).delete(_post)
        end

        it { should be_success }
      end
    end
  end

  describe 'GET #profile_picture' do
    subject { get 'profile_picture', user_id: owner.slug }

    context 'unauthorized access' do
      it { should be_success }
    end

    context 'authorized access' do
      before { sign_in owner }
      it { should be_success }
    end
  end

  describe 'GET #cover_picture' do
    subject { get 'cover_picture', user_id: owner.slug }

    context 'unauthorized access' do
      it { should be_success }
    end

    context 'authorized access' do
      before { sign_in owner }
      it { should be_success }
    end
  end

  describe 'POST #create' do
    subject { post 'create', transloadit: transloadit_photo_data_params.to_json }

    context 'unauthorized access' do
      its(:status) { should eq(401) }
    end

    context 'authorized access' do
      before { sign_in owner }
      its(:body) { should match_regex /replace/ }
      it { should be_success }
    end
  end

  describe 'DELETE #destroy' do
    let(:photo_upload) { create_photo_upload(owner).first  }
    subject { delete 'destroy', id: photo_upload.id }

    context 'unauthorized access' do
      its(:status) { should == 401 }
    end

    context 'authorized access' do
      before { sign_in owner }
      it { should be_success }
    end
  end
end
