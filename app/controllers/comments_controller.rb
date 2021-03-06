# -*- coding: utf-8 -*-
class CommentsController < ApplicationController
  respond_to :html

  before_filter :check_user, :except => :create

  def create
    @comment = Comment.new params[:comment]
    @kifu_document = KifuDocument.find @comment.kifu_document_id
    if @comment.save
      session[:user].comment_ids[@comment.id] = true
      respond_with @comment do |format|
        format.html { redirect_to kifu_document_path(@kifu_document), :notice => "コメントを投稿しました。" }
      end
    else
      @form = Form.new
      render :template => 'kifu_documents/show', :locals => {:kifu_document => @kifu_document}
    end
  end

  def destroy
    @comment = Comment.find params[:id]
    @comment.destroy
    redirect_to :back, :notice => "コメントを削除しました。"
  end

  protected
  def check_user
    @comment = Comment.find params[:id]
    if not session[:user].comment_ids[@comment.id]
      redirect_to :back, :notice => "許可されていない操作です。"
    end
  end
end
