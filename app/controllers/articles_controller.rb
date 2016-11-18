class ArticlesController < ApplicationController
  before_action :check_signed_in, except: [:show]
  before_action :check_activated, except: [:show]

  before_action :find_article_by_id, only: [:show, :edit, :update, :destroy]
  before_action :correct_user, only: [:edit, :update, :destroy]

  before_action :delete_cache_pictures, only: [:new, :edit]

  layout 'blog'

  def index
    redirect_to user_path(current_user.username)
  end

  def show
    if current_user != @article.user && @article.posted.blank?
      return render_404
    end
    get_user_category_and_tags
    get_next_or_pre_article
    if @article.posted
      @article.view_count += 1
      @article.save
    end
  end

  def new
    get_current_user_and_categories
    @article = current_user.articles.build
  end

  def edit
    get_current_user_and_categories @article.category_id
    @article.tagstr = @article.tags2str
  end

  def create
    get_current_user_and_categories article_params[:category_id]
    @article = current_user.articles.build article_params
    if @article.save
      @article.str2tags @article.tagstr
    else
      flash.now[:warning] = @article.errors.full_messages[0]
      return render 'new'
    end

    save_or_post_article
  end

  def update
    get_current_user_and_categories article_params[:category_id]
    if @article.update_attributes article_params
      @article.update_tags @article.tagstr
    else
      flash.now[:warning] = @article.errors.full_messages[0]
      return render 'edit'
    end

    save_or_post_article
  end

  def destroy
    @article.destroy
    flash[:success] = I18n.t "flash.success.delete_article", title: @article.title
    redirect_to drafts_user_path(current_user.username)
  end

  private
    def article_params
      params.require(:article).permit(:title, :category_id, :content, :content_html, :tagstr)
    end

    def get_current_user_and_categories(selected_category_id = 1)
      @user = current_user
      @category = current_user.categories.find_by id: selected_category_id
      @category ||= current_user.categories.first
      @categories = current_user.categories
    end

    def find_article_by_id
      @article = Article.find_by_id params[:id]
      return render_404 unless @article      
    end

    def correct_user
      render_404 unless current_user == @article.user
    end

    def get_user_category_and_tags
      return if @article.blank?
      @user = @article.user
      @category = @article.category
      @tags = @article.tags
    end

    def get_next_or_pre_article 
      return unless @user
      return unless @article.posted
      articles = @user.articles.where(posted: true).to_a
      return if articles.size < 2
      index = articles.index @article
      @next_article = @pre_article = nil
      @next_article = articles[index+1] if index < articles.size-1
      @pre_article = articles[index-1] if index > 0
    end

    def save_or_post_article
      # 标记图片已使用, 并关联文章
      current_user.post_cache_pictures_in_article @article
      
      if params[:article][:save]
        flash.now[:success] = I18n.t "flash.success.save_article"
        @article.update_attribute :posted, false
        render 'edit'
      elsif params[:article][:post]
        unless @article.posted
          @article.update_attribute :posted, true
          @article.update_attribute :created_at, Time.zone.now
        end
        redirect_to article_path(@article.id)
      else
        redirect_to root_path
      end
    end

    def delete_cache_pictures
      current_user.delete_cache_pictures
    end
end
