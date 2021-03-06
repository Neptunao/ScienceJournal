class Ability
  include CanCan::Ability

  def initialize(user)
    user ||= User.new
    can :read, Author
    can :read, Journal
    can :read, Category
    can :read, Article, status: Article::STATUS_PUBLISHED

    if user.role? :admin
      can :manage, :all
    end

    if user.role? :author
      can :update, user.person
      can :create, Article
      if user.person
        can :read, Article do |a|
          a.author_ids.include? user.person_id
        end
      else
        can :create, Author
      end
    end

    if user.role?(:censor) && user.is_approved?
      if user.person
        can :read, Article, censor_id: user.person.id
        can :update, Article, censor_id: user.person.id, status: Article::STATUS_TO_REVIEW
      end
    end
    # Define abilities for the passed in user here. For example:
    #
    #   user ||= User.new # guest user (not logged in)
    #   if user.admin?
    #     can :manage, :all
    #   else
    #     can :read, :all
    #   end
    #
    # The first argument to `can` is the action you are giving the user permission to do.
    # If you pass :manage it will apply to every action. Other common actions here are
    # :read, :create, :update and :destroy.
    #
    # The second argument is the resource the user can perform the action on. If you pass
    # :all it will apply to every resource. Otherwise pass a Ruby class of the resource.
    #
    # The third argument is an optional hash of conditions to further filter the objects.
    # For example, here the user can only update published articles.
    #
    #   can :update, Article, :published => true
    #
    # See the wiki for details: https://github.com/ryanb/cancan/wiki/Defining-Abilities
  end
end
