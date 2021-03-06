class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable, :omniauthable, :omniauth_providers => [:google_oauth2]
  belongs_to :user_status

  has_many :votes, dependent: :destroy
  has_many :posts, dependent: :destroy
  # The user follows another user is a more complex association
  has_many :active_follow_users, class_name: "FollowUser", foreign_key: "follower_user_id", dependent: :destroy
  has_many :followed_users, through: :active_follow_users
  has_many :passive_follow_users, class_name: "FollowUser", foreign_key: "followed_user_id", dependent: :destroy
  has_many :follower_users, through: :passive_follow_users
  has_many :follow_posts, dependent: :destroy
  has_many :user_shareds, dependent: :destroy
  has_many :shared_files, dependent: :destroy
  has_many :post_flags, dependent: :destroy
  has_many :comments, dependent: :destroy
  has_many :admin_geofences
  has_and_belongs_to_many :geofences
  has_one :user_profile, dependent: :destroy
  alias_attribute :profile, :user_profile
  accepts_nested_attributes_for :user_profile

  validates :username, presence: true, uniqueness: { case_sensitive: false }
  validates :email, presence: true, uniqueness: { case_sensitive: false }
  validates :password, presence: true, length: { minimum: 1 }, format: { with: /\A[a-zA-Z0-9]*\z/i }

  before_validation :load_defaults, on: :create
  after_create :create_profile

  def self.from_omniauth(auth)
    where(provider: auth.provider ,uid: auth.uid).first_or_create do |user|
      user.provider = auth.provider
      user.uid = auth.uid
      user.email = auth.info.email
      user.name = auth.info.name
      user.password = Devise.friendly_token[0, 20]
    end
  end

  def load_defaults
    self.user_status_id ||= 1
    self.karma = 0
    self.is_admin ||= false
    self.is_superadmin ||= false
  end

  def create_profile
    self.profile ||= UserProfile.create(user: self, name: self.username, bio: "#{self.username}'s bio")
  end

  def commented_posts
    self.comments.pluck(:post_id).map { |id| Post.find(id) }
  end

  def voted_posts(type = nil)
    case type
    when :up
      self.votes.where('value > 0').pluck(:post_id).map { |id| Post.find(id) }
    when :down
      self.votes.where('value < 0').pluck(:post_id).map { |id| Post.find(id) }
    else
      self.votes.pluck(:post_id).map { |id| Post.find(id) }
    end
  end

  def voted_post_type(post)
    # Return :up or :down or nil
    vote = self.votes.where(post: post).pluck(:value)[0]
    if vote && vote > 0
      :up
    elsif vote && vote < 0
      :down
    end
  end

  def shared_posts
    self.user_shareds.pluck(:post_id).map { |id| Post.find(id) }
  end

  def admin?
    self.is_admin? || self.is_superadmin?
  end

  def flagged_posts
    self.post_flags.pluck(:post_id).map { |id| Post.find(id) }
  end

  def blacklisted?
    Blacklist.find_by(user_id: self.id)
  end
end
