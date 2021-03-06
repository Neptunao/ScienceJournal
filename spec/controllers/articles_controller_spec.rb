require 'spec_helper'

describe ArticlesController do
  before :all do
    DataFile.destroy_all
    User.destroy_all
    @author_user = FactoryGirl.create(:user)
    @censor_user = FactoryGirl.create(:censor_user)
    @censor_user.update_attribute(:is_approved, true)
    @censor_user.update_attribute(:person, FactoryGirl.create(:censor))
    @users = [@author_user, @censor_user]
    @admin_user = FactoryGirl.create(:admin_user)
    @author = FactoryGirl.create(:author)

    @article_file = fixture_file_upload('/test_data/test_pdf_file.pdf')
    @resume_rus_file = fixture_file_upload('/test_data/test_pdf_file1.pdf')
    @resume_eng_file = fixture_file_upload('/test_data/test_pdf_file2.pdf')
    @cover_note_file = fixture_file_upload('/test_data/test_pdf_file3.pdf')
    @review_file = fixture_file_upload('/test_data/test_pdf_file4.pdf')

    @category = Category.create(title: 'test1234')
  end

  after :each do
    DataFile.destroy_all
  end

  after :all do
    User.destroy_all
  end

  describe '.new' do
    it 'redirect to login if guest' do
      get :new
      response.should redirect_to new_user_session_path
    end

    it 'redirect to root if not author' do
      sign_in @censor_user
      get :new
      response.should redirect_to root_path
      sign_out @censor_user
    end

    it 'assigns new article to @article' do
      sign_in @author_user
      get :new
      assigns(:article).should be_a_new(Article)
      sign_out @author_user
    end

    it 'redirect to edit personal info if user.person is nil' do
      sign_in @author_user
      get :new
      response.should redirect_to edit_personal_path
    end

    it 'assign to @authors all authors without current' do
      Author.destroy_all
      user = create_user
      author = FactoryGirl.create(:author)
      author1 = FactoryGirl.create(:author)
      sign_in user
      get :new
      assigns(:authors).should eql [author, author1]
      sign_out user
    end
  end

  describe '.create' do
    def full_params
      author = Author.create(first_name: 'a', middle_name: 'b', last_name: 'c')
      { article: { title: 'test', author_ids: ['', author.id], category_id: @category.id,
                   data_files: {
                       article: @article_file, resume_rus: @resume_rus_file, resume_eng: @resume_eng_file, cover_note: @cover_note_file },
                   has_review: '1', review: @review_file, censor_attributes: { first_name: 'a1', middle_name: 'a2' ,last_name: 'a3', degree: 'a4', post: 'a5' }
      } }
    end

    before :all do
      @min_params = { article: { title: 'test', author_ids: [''], data_files: {
          article: @article_file, resume_rus: @resume_rus_file, resume_eng: @resume_eng_file, cover_note: @cover_note_file },
                                 category_id: @category.id, has_review: '0', censor_attributes: { first_name: '', last_name: '' }
      } }
    end

    it 'redirect to login if guest' do
      post :create
      response.should redirect_to new_user_session_path
    end

    it 'redirect to root if not author' do
      sign_in @censor_user
      post :create
      assigns(:article).should be_a_new(Article)
      assigns(:article).censor.should be_a_new(Censor)
      response.should redirect_to root_path
      sign_out @censor_user
    end

    it 'render new if errors' do
      user = create_user
      sign_in user
      post :create, { article: { title: 'test', author_ids: [''] } }
      response.should render_template 'articles/new'

      post :create, { article: { title: 'test', data_files: { article: @article_file }, author_ids: [''] } }
      response.should render_template 'articles/new'

      post :create, { article: { title: 'test', data_files: { resume_rus: @resume_rus_file }, author_ids: [''] } }
      response.should render_template 'articles/new'

      post :create, { article: { title: 'test', data_files: { resume_eng: @resume_eng_file }, author_ids: [''] } }
      response.should render_template 'articles/new'

      post :create, { article: { title: 'test', data_files: { cover_note: @cover_note_file }, author_ids: [''] } }
      response.should render_template 'articles/new'

      sign_out user
    end

    it 'create new article and redirect to root (min params)' do
      user = create_user
      sign_in user
      expect { post :create, @min_params }.to change(Article, :count).by(1)
      response.should redirect_to root_path
      sign_out user
      DataFile.destroy_all
    end

    it 'delete files if errors' do
      DataFile.destroy_all
      user = create_user
      sign_in user
      post :create, { article: { title: 'test', data_files: { article: @article_file }, author_ids: [''] } }
      DataFile.all.should be_empty
      sign_out user
    end

    it 'with coauthors' do
      user = create_user
      sign_in user
      post :create, full_params
      Article.last.authors.count.should be 2
      Article.last.authors.any? { |a| a ==  user.person }.should be_true
      Article.last.authors.any? { |a| a.first_name == 'a' && a.middle_name == 'b' && a.last_name == 'c' }.should be_true
      sign_out user
    end

    it 'assign review file' do
      Article.destroy_all
      user = create_user
      sign_in user
      post :create, full_params
      Article.last.review.filename.should eql 'data/test_pdf_file4.pdf'
      sign_out user
    end

    it 'create and assign new censor' do
      Article.destroy_all
      user = create_user
      sign_in user
      post :create, full_params
      Article.last.censor.first_name.should eql 'a1'
      Article.last.censor.middle_name.should eql 'a2'
      Article.last.censor.last_name.should eql 'a3'
      Article.last.censor.degree.should eql 'a4'
      Article.last.censor.post.should eql 'a5'
      sign_out user
    end

    it 'change status when review attached' do
      Article.destroy_all
      user = create_user
      sign_in user
      post :create, full_params
      Article.last.status.should be Article::STATUS_REVIEWED
      sign_out user
    end

    it 'destroy censor if invalid' do
      Censor.destroy_all
      user = create_user
      sign_in user
      invalid_params = full_params
      invalid_params[:article].delete(:data_files)
      post :create, invalid_params
      Censor.count.should be 0
      sign_out user
    end

    it 'not throw exception when review without review file' do
      user = create_user
      sign_in user
      invalid_params = full_params
      invalid_params[:article].delete(:review)
      lambda { post :create, invalid_params }.should_not raise_exception
      sign_out user
    end

    it 'fixed B11 - exception when add data_file with filename that already exists' do
      user = create_user
      sign_in user
      post :create, full_params
      lambda { post :create, full_params }.should_not raise_exception
      sign_out user
    end

    it 'create article with category' do
      user = create_user
      sign_in user
      post :create, @min_params
      Article.last.category_id.should be @category.id
      sign_out user
    end
  end

  describe '.index' do
    before :each do
      Article.destroy_all
      data_files = [FactoryGirl.create(:article_file), FactoryGirl.create(:resume_rus), FactoryGirl.create(:resume_eng), FactoryGirl.create(:cover_note)]
      Article.create(title: 'test', data_files: data_files, author_ids: [FactoryGirl.create(:author).id])
      Article.create(title: 'test',
                     data_files: [FactoryGirl.create(:article_file), FactoryGirl.create(:resume_rus), FactoryGirl.create(:resume_eng), FactoryGirl.create(:cover_note)],
                     author_ids: [FactoryGirl.create(:author).id], status: Article::STATUS_REVIEWED)
      Article.create(title: 'test',
                     data_files: [FactoryGirl.create(:article_file), FactoryGirl.create(:resume_rus), FactoryGirl.create(:resume_eng), FactoryGirl.create(:cover_note)],
                     author_ids: [FactoryGirl.create(:author).id], status: Article::STATUS_TO_REVIEW)
      @censor_article = Article.create(title: 'test',
                                       data_files: [FactoryGirl.create(:article_file), FactoryGirl.create(:resume_rus), FactoryGirl.create(:resume_eng), FactoryGirl.create(:cover_note)],
                                       author_ids: [FactoryGirl.create(:author).id], status: Article::STATUS_TO_REVIEW, censor_id: @censor_user.person.id)
    end

    it 'assigns articles without review as @articles' do
      sign_in @admin_user
      get :index, { status: Article::STATUS_CREATED }
      assigns(:articles).should_not be_nil
      assigns(:articles).should_not eql Article.all
      assigns(:articles).should be =~ Article.find_all_by_status(Article::STATUS_CREATED)
      sign_out @admin_user
    end

    it 'assigns articles with review as @articles' do
      sign_in @admin_user
      get :index, { status: Article::STATUS_REVIEWED }
      assigns(:articles).should_not be_nil
      assigns(:articles).should_not eql Article.all
      assigns(:articles).should be =~ Article.where(status: Article::STATUS_REVIEWED)
      sign_out @admin_user
    end

    it 'assigns articles without params as @articles' do
      sign_in @admin_user
      get :index
      assigns(:articles).should_not be_nil
      assigns(:articles).should be =~ Article.all
      sign_out @admin_user
    end

    it 'assigns censor articles as @articles' do
      sign_in @censor_user
      get :index, { status: Article::STATUS_TO_REVIEW, censor_id: @censor_user.person.id }
      assigns(:articles).count.should be 1
      assigns(:articles)[0].should eql @censor_article
      sign_out @censor_user
    end

    it 'assigns user articles as @articles' do
      user = create_user
      sign_in user
      article = create_article
      article.author_ids = [user.person.id]
      article.save!
      get :index
      assigns(:articles).should_not be_empty
      assigns(:articles).should eql [article]
      sign_out user
    end

    it 'B13 - my articles links in author layout display all published articles' do
      user = create_user
      a = create_article
      a1 = create_article
      expected = [a, a1]
      expected.each { |ar| ar.update_attribute(:author_ids, [user.person.id]) }
      invalid = create_article
      invalid.update_attribute(:status, Article::STATUS_PUBLISHED)
      sign_in user
      get :index, author_id: user.person.id
      assigns(:articles).should =~ expected
      sign_out user
    end
  end

  describe '.show' do
    it 'assigns @article' do
      sign_in @admin_user
      article = create_article
      get :show, id: article.id
      assigns(:article).should eql article
      sign_out @admin_user
    end
  end

  describe '.edit' do
    it 'assigns @article' do
      sign_in @censor_user
      article = create_article
      get :edit, id: article.id
      assigns(:article).should_not be_nil
      assigns(:article).should eql article
      sign_out @censor_user
    end
  end

  describe 'update' do
    def min_update_params
      { article: { review: @review_file, status: Article::STATUS_REVIEWED }, reject: 0, id: @article.id }
    end

    def rejected_params
      { article: { review: @review_file, status: Article::STATUS_REJECTED_BY_CENSOR, reject_reason: 'rejected' }, reject: 1, id: @article.id }
    end

    def no_review_params
      { article: { status: Article::STATUS_REVIEWED }, reject: 0, id: @article.id }
    end

    before :each do
      @article = create_article
      @article.update_attribute(:status, Article::STATUS_TO_REVIEW)
      @article.update_attribute(:censor, @censor_user.person)
      sign_in @censor_user
    end

    after :each do
      sign_out @censor_user
    end

    it 'attach review to article' do
      put :update, min_update_params
      @article.review.filename.should eql 'data/test_pdf_file4.pdf'
      @article.review.tag.should eql Article::REVIEW_FILE_TAG
    end

    it 'recover review file if invalid params' do
      invalid_params = { article: { title: nil, review: @article_file, status: Article::STATUS_REVIEWED }, reject: 0, id: @article.id }
      data_files = @article.data_files
      data_files << FactoryGirl.create(:review)
      @article.update_attribute(:status, Article::STATUS_REVIEWED)
      @article.update_attribute(:data_files, data_files)
      expected_filename = @article.review.filename
      put :update, invalid_params
      @article.reload
      @article.review.filename.should eql expected_filename
      @article.review.tag.should eql Article::REVIEW_FILE_TAG
    end

    it 'delete invalid review' do
      pending 'TODO'
      #TODO
      #invalid_params = { article: { title: nil, review: @article_file, status: Article::STATUS_REVIEWED }, reject: 0, id: @article.id }
      #data_files = @article.data_files
      #data_files << FactoryGirl.create(:review)
      #@article.update_attribute(:data_files, data_files)
      #put :update, invalid_params
      #@article.reload
      #@article.review.should be_nil
    end

    it 'change status to reviewed' do
      put :update, min_update_params
      @article.reload
      @article.status.should be Article::STATUS_REVIEWED
    end

    it 'should not update without review file' do
      expect { put :update, no_review_params }.to_not change(@article.reload, :status).to(Article::STATUS_REVIEWED)
    end

    describe 'reject' do
      it 'change status to rejected' do
        put :update, rejected_params
        @article.reload.status.should be Article::STATUS_REJECTED_BY_CENSOR
      end

      it 'change reject_reason' do
        put :update, rejected_params
        @article.reload.reject_reason.should eql rejected_params[:article][:reject_reason]
      end

      it 'invalid not change article' do
        invalid_params = { article: { status: Article::STATUS_REJECTED_BY_CENSOR, reject_reason: 'rejected' }, reject: 1, id: @article.id }
        put :update, invalid_params
        @article.reload.status.should_not be Article::STATUS_REJECTED_BY_CENSOR
        @article.reload.reject_reason.should_not eql rejected_params[:article][:reject_reason]
      end
    end
  end
end
