class Article < ActiveRecord::Base
  ARTICLE_FILE_TAG = 'article'
  RESUME_RUS_FILE_TAG = 'resume_rus'
  RESUME_ENG_FILE_TAG = 'resume_eng'
  COVER_NOTE_FILE_TAG = 'cover_note'
  REVIEW_FILE_TAG = 'review'
  STATUS_CREATED = 0
  STATUS_TO_REVIEW = 1
  STATUS_REVIEWED = 2
  STATUS_REJECTED_BY_CENSOR = 3
  STATUS_APPROVED = 4
  STATUS_REJECTED = 5
  STATUS_PUBLISHED = 6

  attr_accessible :status, :title, :data_files, :author_ids, :censor_id, :category_id, :reject_reason
  has_many :data_files, dependent: :destroy
  has_and_belongs_to_many :authors
  belongs_to :censor
  belongs_to :category
  belongs_to :journal
  accepts_nested_attributes_for :authors
  accepts_nested_attributes_for :censor
  validates :title, :status, presence: true
  validates :article, :resume_rus, :resume_eng, :cover_note, presence: true, if: 'status != STATUS_REJECTED'
  validates :data_files, :length => { maximum: 5 }
  validates :authors, :length => { in: 1..11 }
  validates_associated :censor  #TODO test
  validates :review, presence: true, if: 'status == STATUS_REVIEWED || self.status == STATUS_REJECTED_BY_CENSOR'
  validates :reject_reason, presence: true, if: 'status == STATUS_REJECTED_BY_CENSOR'
  after_save :after_save_action

  def article
    data_files.find_by_tag(ARTICLE_FILE_TAG)
  end

  def resume_rus
    data_files.find_by_tag(RESUME_RUS_FILE_TAG)
  end

  def resume_eng
    data_files.find_by_tag(RESUME_ENG_FILE_TAG)
  end

  def cover_note
    data_files.find_by_tag(COVER_NOTE_FILE_TAG)
  end

  def review
    data_files.find_by_tag(REVIEW_FILE_TAG)
  end

  private

  def after_save_action
    DataFile.destroy_unowned
    self.update_attribute(:data_files, [review]) if status == STATUS_REJECTED && data_files.count > 1
  end
end
