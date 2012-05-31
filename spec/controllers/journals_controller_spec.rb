require 'spec_helper'

describe JournalsController do
  before :all do
    article_file = DataFile.create(filename: '1test1', tag: Article::ARTICLE_FILE_TAG)
    resume_rus_file = DataFile.create(filename: '2test2', tag: Article::RESUME_RUS_FILE_TAG)
    resume_eng_file = DataFile.create(filename: '3test3', tag: Article::RESUME_ENG_FILE_TAG)
    cover_note_file = DataFile.create(filename: '4test4', tag: Article::COVER_NOTE_FILE_TAG)
    @data_files = [article_file, resume_rus_file, resume_eng_file, cover_note_file]
  end

  before :each do
    Category.destroy_all
    Article.destroy_all
    DataFile.destroy_all
  end

  def create_article
    Article.create!(title: 'test',
                   data_files: [FactoryGirl.create(:article_file), FactoryGirl.create(:resume_rus), FactoryGirl.create(:resume_eng), FactoryGirl.create(:cover_note)],
                   author_ids: [FactoryGirl.create(:author).id])
  end

  describe '.new' do
    it 'assign new journal' do
      get :new
      assigns(:journal).should be_a_new(Journal)
    end

    it 'assign categories' do
      2.times { FactoryGirl.create(:category) }
      get :new
      assigns(:categories).should_not be_nil
      assigns(:categories).should =~ Category.all
    end

    it 'assign approved articles' do
      get :new
      a = create_article
      a.update_attribute(:status, Article::STATUS_APPROVED)
      create_article
      assigns(:articles).count.should be 1
      assigns(:articles)[0].should eql a
    end

    it 'assign articles with category_id' do
      a1 = create_article
      a2 = create_article
      category_id = FactoryGirl.create(:category).id
      a1.update_attribute(:category_id, FactoryGirl.create(:category).id)
      a2.update_attribute(:category_id, category_id)
      get :new, journal: { category_id: category_id }
      assigns(:articles).count.should be 1
      assigns(:articles)[0].should eql a2
    end
    it 'response with js' do
      get :new, format: :js
      response.should be_success
    end
  end
end